extends "res://scripts/interactions/interactable.gd"

@export_enum("phone", "vacuum") var hazard_type := "phone"
@export var activation_delay := 30.0
@export var pulse_interval := 2.0
@export var pulse_noise := 12.0
@export var rearm_delay_min := 55.0
@export var rearm_delay_max := 90.0
@export var movement_speed := 0.72
@export var flee_speed := 1.42
@export var flee_radius := 2.65
@export var obstacle_lookahead := 0.48
@export var turn_speed := 5.0

var armed := true
var active := false
var _elapsed := 0.0
var _pulse_elapsed := 0.0
var _notified := false
var _rearm_left := 0.0
var _heading := Vector3(-1.0, 0.0, 0.0)
var _patrol_index := 0
var _blocked_elapsed := 0.0
var _avoidance_sign := 1.0
var _collision_exclusions: Array[RID] = []
var station_anchor: Node3D
var exit_direction := Vector3.RIGHT
var exit_clearance_distance := 0.72
var _station_exit_remaining := 0.0
var _station_blocked := false
var _avoidance_shape: CylinderShape3D
# Позиции для случайного появления телефона — задаются из apartment_builder.gd
var available_spots: Array = []
# Предыдущая позиция телефона, чтобы не появиться в том же месте
var _last_spot_index := -1

const VACUUM_PATROL_POINTS: Array[Vector3] = [
    Vector3(6.95, 0.12, 1.25),
    Vector3(6.55, 0.12, -0.85),
    Vector3(4.15, 0.12, -1.10),
    Vector3(1.90, 0.12, -1.70),
    Vector3(0.00, 0.12, -1.70),
    Vector3(0.00, 0.12, 1.65),
    Vector3(-1.10, 0.12, 3.80),
    Vector3(-3.20, 0.12, 3.80),
    Vector3(-4.45, 0.12, 4.25),
    Vector3(-3.20, 0.12, 3.80),
    Vector3(-1.10, 0.12, 3.80),
    Vector3(0.00, 0.12, 1.65),
    Vector3(0.00, 0.12, -1.70),
    Vector3(-1.90, 0.12, -1.70),
    Vector3(-4.40, 0.12, -1.10),
    Vector3(-6.55, 0.12, -3.20),
    Vector3(-4.10, 0.12, -4.45),
    Vector3(-1.90, 0.12, -1.70),
    Vector3(0.00, 0.12, -1.70),
    Vector3(1.90, 0.12, -1.70),
    Vector3(4.45, 0.12, -1.25),
    Vector3(6.70, 0.12, -0.65),
]

func _ready() -> void:
    add_to_group("household_hazards")
    if hazard_type == "vacuum":
        _avoidance_shape = CylinderShape3D.new()
        _avoidance_shape.radius = 0.33
        _avoidance_shape.height = 0.12
        call_deferred("_cache_collision_exclusions")
        # The builder adds the visual collision children immediately after this
        # node enters the tree. Disable them on the next frame while the robot
        # is parked, so a low switched-off vacuum cannot soft-lock a doorway.
        call_deferred("_set_vacuum_blocking", active)

func _process(delta: float) -> void:
    if not RunStats.run_active:
        return
    if not armed:
        _rearm_left -= delta
        if _rearm_left <= 0.0 and not RitaSleep.is_angry and not RitaDemands.has_active_demand():
            armed = true
            _elapsed = activation_delay * DifficultyManager.get_hazard_delay()
            _pulse_elapsed = 0.0
            _notified = false
            # Телефон каждый раз появляется в новом месте
            if hazard_type == "phone" and available_spots.size() > 1:
                var new_index: int
                while true:
                    new_index = randi() % available_spots.size()
                    if new_index != _last_spot_index:
                        break
                _last_spot_index = new_index
                position = available_spots[new_index]
        return
    _elapsed += delta
    if not active and _elapsed >= activation_delay * DifficultyManager.get_hazard_delay() and _can_activate_now():
        active = true
        _set_indicator(true)
        if hazard_type == "vacuum":
            _start_vacuum_motion()
        if not _notified:
            _notified = true
            QuestManager.notification_requested.emit(
                "ТЕЛЕФОН ВИБРИРУЕТ НА СТОЛЕ" if hazard_type == "phone" else "РОБОТ-ПЫЛЕСОС РЕШИЛ, ЧТО УЖЕ УТРО"
            )
    if not active:
        return
    _pulse_elapsed += delta
    if _pulse_elapsed >= pulse_interval:
        _pulse_elapsed = 0.0
        NoiseManager.emit_noise(global_position, pulse_noise, &"APPLIANCE", StringName(hazard_type))
        AudioManager.play_3d(&"buzz" if hazard_type == "phone" else &"vacuum", global_position, -5.0)
        _set_indicator(not _indicator_visible())

func _physics_process(delta: float) -> void:
    if hazard_type != "vacuum" or not RunStats.run_active or not active:
        return
    _move_vacuum(delta)

func _start_vacuum_motion() -> void:
    _station_blocked = false
    _set_vacuum_blocking(true)
    _open_route_door(&"kitchen_door")
    _station_exit_remaining = exit_clearance_distance if station_anchor != null and _flat_distance(global_position, station_anchor.global_position) < 0.42 else 0.0
    if _station_exit_remaining > 0.0:
        _heading = exit_direction.normalized()
    if VACUUM_PATROL_POINTS.is_empty():
        return
    var nearest_index := 0
    var nearest_distance := INF
    for index in range(VACUUM_PATROL_POINTS.size()):
        var distance := _flat_distance(global_position, VACUUM_PATROL_POINTS[index])
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = index
    _patrol_index = (nearest_index + 1) % VACUUM_PATROL_POINTS.size()
    _blocked_elapsed = 0.0
    _avoidance_sign = -1.0 if randf() < 0.5 else 1.0
    var initial_direction := VACUUM_PATROL_POINTS[_patrol_index] - global_position
    initial_direction.y = 0.0
    if initial_direction.length_squared() > 0.001:
        _heading = initial_direction.normalized()

func _move_vacuum(delta: float) -> void:
    if VACUUM_PATROL_POINTS.is_empty() or _avoidance_shape == null:
        return
    if _station_exit_remaining > 0.0:
        var straight_step := minf(movement_speed * delta, _station_exit_remaining)
        var straight_target := global_position + exit_direction.normalized() * straight_step
        straight_target.y = global_position.y
        # The dock lane is authored as a clear strip. During this short phase
        # the robot must not soft-lock on Denis, a dropped prop or a puddle.
        # Normal collision avoidance resumes as soon as it reaches the hall.
        global_position = straight_target
        _station_exit_remaining -= straight_step
        _heading = exit_direction.normalized()
        rotation.y = atan2(-_heading.x, -_heading.z)
        if _station_exit_remaining <= 0.001:
            var nearest_after_exit := 0
            var nearest_after_exit_distance := INF
            for point_index in range(VACUUM_PATROL_POINTS.size()):
                var point_distance := _flat_distance(global_position, VACUUM_PATROL_POINTS[point_index])
                if point_distance < nearest_after_exit_distance:
                    nearest_after_exit_distance = point_distance
                    nearest_after_exit = point_index
            _patrol_index = nearest_after_exit
        return
    _open_nearby_doors()
    var target := VACUUM_PATROL_POINTS[_patrol_index]
    var to_target := target - global_position
    to_target.y = 0.0
    if to_target.length() < 0.48:
        _advance_patrol_point()
        target = VACUUM_PATROL_POINTS[_patrol_index]
        to_target = target - global_position
        to_target.y = 0.0
    if to_target.length_squared() < 0.001:
        return

    var desired := to_target.normalized()
    var current_speed := movement_speed
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player != null:
        var away_from_player := global_position - player.global_position
        away_from_player.y = 0.0
        var player_distance := away_from_player.length()
        if player_distance < flee_radius and player_distance > 0.05:
            var tangent := away_from_player.normalized().rotated(Vector3.UP, _avoidance_sign * 0.58)
            desired = (away_from_player.normalized() * 0.78 + tangent * 0.22).normalized()
            current_speed = lerpf(flee_speed, movement_speed, clampf(player_distance / flee_radius, 0.0, 1.0))
    var steering := _find_clear_direction(desired)
    if steering == Vector3.ZERO:
        _blocked_elapsed += delta
        _heading = _heading.rotated(Vector3.UP, _avoidance_sign * turn_speed * delta).normalized()
        if _blocked_elapsed >= 1.25:
            _advance_patrol_point()
        return

    if steering.dot(desired) < 0.62:
        _blocked_elapsed += delta
    else:
        _blocked_elapsed = maxf(0.0, _blocked_elapsed - delta * 2.0)
    if _blocked_elapsed >= 3.0:
        _advance_patrol_point()

    _heading = _heading.lerp(steering, clampf(turn_speed * delta, 0.0, 1.0)).normalized()
    var step := _heading * current_speed * delta
    var next_position := global_position + step
    next_position.y = global_position.y
    if _major_spill_blocks(global_position, next_position + _heading * 0.42):
        _heading = _heading.rotated(Vector3.UP, PI * 0.72 * _avoidance_sign).normalized()
        _advance_patrol_point()
        QuestManager.notification_requested.emit("ПЫЛЕСОС ОБЪЕЗЖАЕТ МОКРЫЙ ПОЛ")
        return
    if not _position_is_clear(next_position):
        _heading = steering
        next_position = global_position + steering * current_speed * delta
        next_position.y = global_position.y
    if _position_is_clear(next_position):
        global_position = next_position
    else:
        _blocked_elapsed += delta
        return

    var target_yaw := atan2(-_heading.x, -_heading.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))

func _open_nearby_doors() -> void:
    for door in get_tree().get_nodes_in_group("door"):
        if not door is Node3D or not "is_open" in door or not "door_id" in door:
            continue
        var route_door_id := StringName(door.get("door_id"))
        if route_door_id not in [&"kitchen_door", &"bedroom_door", &"bathroom_door", &"wardrobe_door"]:
            continue
        var door_node := door as Node3D
        if global_position.distance_to(door_node.global_position) > 1.18:
            continue
        if not bool(door.get("is_open")) and door.has_method("perform_interaction"):
            door.call("perform_interaction", null, InteractionMode.FAST)
            NoiseManager.emit_noise(door_node.global_position, 10.0, &"DOOR", StringName(door_node.name.to_snake_case()))

func _open_route_door(route_door_id: StringName) -> void:
    for door in get_tree().get_nodes_in_group("door"):
        if not "door_id" in door or StringName(door.get("door_id")) != route_door_id:
            continue
        if not bool(door.get("is_open")) and door.has_method("perform_interaction"):
            door.call("perform_interaction", null, InteractionMode.FAST)
            NoiseManager.emit_noise((door as Node3D).global_position, 10.0, &"DOOR", route_door_id)
        return

func _find_clear_direction(desired: Vector3) -> Vector3:
    var angles := [0.0, 28.0, -28.0, 58.0, -58.0, 92.0, -92.0, 138.0, -138.0, 180.0]
    for angle_degrees in angles:
        var signed_angle := deg_to_rad(float(angle_degrees) * _avoidance_sign)
        var candidate := desired.rotated(Vector3.UP, signed_angle).normalized()
        if _position_is_clear(global_position + candidate * obstacle_lookahead):
            return candidate
    return Vector3.ZERO

func _position_is_clear(candidate_position: Vector3) -> bool:
    if candidate_position.x < -7.55 or candidate_position.x > 7.55 or candidate_position.z < -6.05 or candidate_position.z > 6.05:
        return false
    if _collision_exclusions.is_empty():
        _cache_collision_exclusions()
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = _avoidance_shape
    query.transform = Transform3D(Basis.IDENTITY, candidate_position)
    query.collision_mask = 3
    query.collide_with_areas = false
    query.collide_with_bodies = true
    query.exclude = _collision_exclusions
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _cache_collision_exclusions() -> void:
    _collision_exclusions.clear()
    for node in find_children("*", "StaticBody3D", true, false):
        if node is CollisionObject3D:
            _collision_exclusions.append((node as CollisionObject3D).get_rid())

func _advance_patrol_point() -> void:
    _patrol_index = (_patrol_index + 1) % VACUUM_PATROL_POINTS.size()
    _blocked_elapsed = 0.0
    _avoidance_sign *= -1.0

func _flat_distance(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x - b.x, a.z - b.z).length()

func get_prompt(_actor) -> String:
    if hazard_type == "vacuum" and active:
        return "ОСТАНОВИТЬ ЕДУЩИЙ РОБОТ-ПЫЛЕСОС"
    if not armed:
        return "ТЕЛЕФОН ПОКА НА БЕЗЗВУЧНОМ" if hazard_type == "phone" else "ПЫЛЕСОС ПОКА ОТКЛЮЧЁН"
    if hazard_type == "phone":
        return "ВЫКЛЮЧИТЬ ВИБРАЦИЮ ТЕЛЕФОНА"
    if _station_blocked:
        return "ОСВОБОДИТЬ ВЫЕЗД И ЗАПУСТИТЬ"
    return "ЗАПУСТИТЬ РОБОТ-ПЫЛЕСОС"

func perform_interaction(_actor, _mode: int) -> String:
    if hazard_type == "vacuum" and not active:
        armed = true
        active = true
        _set_indicator(true)
        _start_vacuum_motion()
        return "РОБОТ-ПЫЛЕСОС ВЫЕЗЖАЕТ С БАЗЫ"
    if not armed:
        return "УЖЕ ТИХО"
    armed = false
    active = false
    _rearm_left = randf_range(rearm_delay_min, rearm_delay_max) * DifficultyManager.get_hazard_delay()
    _set_indicator(false)
    if hazard_type == "vacuum":
        _set_vacuum_blocking(false)
    AudioManager.play_3d(&"switch", global_position, -8.0)
    if hazard_type == "phone":
        return "ТЕЛЕФОН ПЕРЕВЕДЁН НА БЕЗЗВУЧНЫЙ"
    return "ПЫЛЕСОС ОСТАНОВЛЕН — ЧЕРЕЗ НИЗКИЙ КОРПУС МОЖНО ПЕРЕШАГНУТЬ"

func _set_vacuum_blocking(value: bool) -> void:
    if hazard_type != "vacuum":
        return
    for child in find_children("*", "CollisionShape3D", true, false):
        if child is CollisionShape3D:
            (child as CollisionShape3D).disabled = not value

func _can_activate_now() -> bool:
    # The vacuum is an independent roaming nuisance. Phone calls and Rita's
    # chores must not silently keep it parked for the entire run.
    if hazard_type == "vacuum":
        return not RitaSleep.is_angry
    if RitaSleep.is_angry or RitaDemands.has_active_demand() or CallManager.question_active:
        return false
    if QuestManager.has_bonus_objective(&"football"):
        return false
    for hazard in get_tree().get_nodes_in_group("household_hazards"):
        if hazard != self and bool(hazard.get("active")):
            return false
    return true

func _set_indicator(value: bool) -> void:
    var indicator := get_node_or_null("Indicator") as Node3D
    if indicator != null:
        indicator.visible = value

func _indicator_visible() -> bool:
    var indicator := get_node_or_null("Indicator") as Node3D
    return indicator != null and indicator.visible

func _major_spill_blocks(from: Vector3, to: Vector3) -> bool:
    var spill_manager := get_tree().get_first_node_in_group("spill_manager")
    return spill_manager != null and spill_manager.has_method("has_major_spill_near_segment") and bool(
        spill_manager.call("has_major_spill_near_segment", from, to, 0.42)
    )
