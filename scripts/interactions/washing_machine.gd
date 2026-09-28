extends "res://scripts/interactions/movable_furniture.gd"

## A deliberately badly-balanced washing machine.  It is fixed furniture while
## idle, but a spin cycle makes the whole unit vibrate and crawl out through the
## bathroom door. Denis can catch it and hold E to rebalance the drum. Once
## stopped it becomes a heavy physics object that can be dragged with LMB+WASD,
## so it can never become a permanent blocker in the apartment route.

enum InteractionMode { NORMAL, QUIET, FAST }

@export var first_cycle_delay_min := 62.0
@export var first_cycle_delay_max := 105.0
@export var rearm_delay_min := 135.0
@export var rearm_delay_max := 225.0
@export var pulse_interval := 1.15
@export var pulse_noise := 20.0
@export var crawl_speed := 0.34
@export var calm_required := 1.0

var active := false
var calm_progress := 0.0
var cycle_count := 0
var _activation_left := 80.0
var _pulse_left := 0.0
var _route_index := 0
var _cycle_time := 0.0
var _base_rotation := Vector3.ZERO
var _base_height := 0.0
var _drum: Node3D
var _indicator: Node3D
var _settling_clear_of_door := false
var busy := false
var normal_duration := 2.35
var quiet_duration := 1.65
var fast_duration := 0.85
var normal_noise := 4.0
var quiet_noise := 1.2
var fast_noise := 11.0
var noise_category: StringName = &"APPLIANCE"
var source_id: StringName = &"washing_machine"

const ESCAPE_ROUTE: Array[Vector3] = [
    Vector3(2.42, 0.0, 2.42),
    # The bathroom door is hinged at z=3.12 and opens into the room. Passing
    # through the middle of its 1.28 m leaf keeps the cabinet clear of both
    # the open panel and the jamb.
    Vector3(2.42, 0.0, 3.76),
    Vector3(1.72, 0.0, 3.76),
    Vector3(0.38, 0.0, 3.76),
    Vector3(0.18, 0.0, 1.62),
]

func _ready() -> void:
    super._ready()
    add_to_group("washing_machine")
    add_to_group("household_hazards")
    display_name = "СТИРАЛЬНАЯ МАШИНА"
    _activation_left = randf_range(first_cycle_delay_min, first_cycle_delay_max) * DifficultyManager.get_hazard_delay()
    _base_rotation = rotation
    _base_height = position.y
    _drum = get_node_or_null("Drum") as Node3D
    _indicator = get_node_or_null("Indicator") as Node3D
    _set_indicator(false)

func _process(delta: float) -> void:
    if not RunStats.run_active:
        return
    if not active:
        if _settling_clear_of_door:
            _settle_clear_of_door(delta)
            return
        _activation_left -= delta
        if _activation_left <= 0.0 and not RitaSleep.is_angry and not RitaDemands.has_active_demand():
            var player := get_tree().get_first_node_in_group("player")
            if player != null and player.get("pushed_body") == self:
                _activation_left = 1.0
                return
            start_spin_cycle()
        return

    _cycle_time += delta
    _pulse_left -= delta
    _animate_spin(delta)
    _crawl_toward_exit(delta)
    if _pulse_left <= 0.0:
        _pulse_left = pulse_interval
        var intensity := pulse_noise + minf(8.0, _cycle_time * 0.28)
        NoiseManager.emit_noise(global_position, intensity, &"APPLIANCE", &"washing_machine")
        AudioManager.play_3d(&"vacuum", global_position, -3.5, randf_range(0.58, 0.68))
        if int(_cycle_time / pulse_interval) % 3 == 0:
            AudioManager.play_3d(&"clink", global_position, -7.0, randf_range(0.72, 0.90))
        _set_indicator(not _indicator_visible())

func start_spin_cycle() -> void:
    if active:
        return
    freeze = true
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    _base_rotation = rotation
    _base_height = position.y
    active = true
    calm_progress = 0.0
    cycle_count += 1
    _cycle_time = 0.0
    _pulse_left = 0.05
    _route_index = _nearest_route_index()
    _open_bathroom_door()
    _set_indicator(true)
    QuestManager.notification_requested.emit("СТИРАЛКА ВОШЛА В ОТЖИМ И ПОЛЗЁТ ИЗ ВАННОЙ")

func force_start_cycle() -> void:
    start_spin_cycle()

func _animate_spin(delta: float) -> void:
    if _drum != null:
        _drum.rotation.z = wrapf(_drum.rotation.z + delta * 11.5, -PI, PI)
    var violence := clampf(0.45 + _cycle_time * 0.035, 0.45, 1.0)
    rotation.x = _base_rotation.x + sin(_cycle_time * 24.0) * 0.018 * violence
    rotation.z = _base_rotation.z + sin(_cycle_time * 31.0 + 0.8) * 0.022 * violence
    position.y = _base_height + absf(sin(_cycle_time * 28.0)) * 0.015 * violence

func _crawl_toward_exit(delta: float) -> void:
    if ESCAPE_ROUTE.is_empty():
        return
    _open_bathroom_door()
    var target := ESCAPE_ROUTE[_route_index]
    target.y = global_position.y
    var offset := target - global_position
    offset.y = 0.0
    if offset.length() < 0.16:
        if _route_index < ESCAPE_ROUTE.size() - 1:
            _route_index += 1
        else:
            # Once it escapes, it keeps shuffling around the hall rather than
            # disappearing or blocking the apartment entrance forever.
            _route_index = 3
        return
    var step := minf(crawl_speed * delta, offset.length())
    global_position += offset.normalized() * step

func _nearest_route_index() -> int:
    var nearest := 0
    var nearest_distance := INF
    for index in range(ESCAPE_ROUTE.size()):
        var distance := Vector2(
            global_position.x - ESCAPE_ROUTE[index].x,
            global_position.z - ESCAPE_ROUTE[index].z
        ).length()
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = index
    return mini(nearest + 1, ESCAPE_ROUTE.size() - 1)

func _open_bathroom_door() -> void:
    for door in get_tree().get_nodes_in_group("door"):
        if not "door_id" in door or StringName(door.get("door_id")) != &"bathroom_door":
            continue
        if not bool(door.get("is_open")) and door.has_method("perform_interaction"):
            door.call("perform_interaction", null, InteractionMode.FAST)
        return

func get_prompt(_actor) -> String:
    if active:
        return "УДЕРЖИВАТЬ E — ВЫРОВНЯТЬ БАРАБАН И УТИХОМИРИТЬ"
    if _settling_clear_of_door:
        return "СТИРАЛКА ОСТАНОВЛЕНА — ОСВОБОЖДАЕТ ДВЕРНОЙ ПРОЁМ"
    return "ЛКМ + WASD — ОТТАЩИТЬ СТИРАЛКУ С ПРОХОДА  •  68 КГ"

func interact(actor, mode: int) -> String:
    if busy:
        return "ПОДОЖДИ"
    busy = true
    var duration := _duration_for(mode) if active else 0.0
    if duration > 0.01:
        await get_tree().create_timer(duration).timeout
    if actor != null and not is_instance_valid(actor):
        busy = false
        return "ДЕЙСТВИЕ ПРЕРВАНО"
    var result := perform_interaction(actor, mode)
    if active:
        var noise := _noise_for(mode)
        if noise > 0.01:
            NoiseManager.emit_noise(global_position, noise, noise_category, source_id)
    busy = false
    return result

func _duration_for(mode: int) -> float:
    if mode == InteractionMode.QUIET:
        return quiet_duration
    if mode == InteractionMode.FAST:
        return fast_duration
    return normal_duration

func _noise_for(mode: int) -> float:
    if mode == InteractionMode.QUIET:
        return quiet_noise
    if mode == InteractionMode.FAST:
        return fast_noise
    return normal_noise

func perform_interaction(_actor, mode: int) -> String:
    if not active:
        return "СТИРАЛКА ОСТАНОВЛЕНА  •  ДЕРЖИ ЛКМ И ТАЩИ ЕЁ К СТЕНЕ ЧЕРЕЗ WASD"
    var effort := 0.62
    if mode == InteractionMode.QUIET:
        effort = 1.0
    elif mode == InteractionMode.FAST:
        effort = 0.42
    calm_progress = minf(calm_required, calm_progress + effort)
    if calm_progress < calm_required:
        AudioManager.play_3d(&"clink", global_position, -6.0, 0.78)
        return "БАРАБАН ЕЩЁ БЬЁТ — ЗАЖМИ E И ДЕРЖИ МАШИНУ"
    calm_machine()
    return "БАРАБАН ВЫРОВНЕН — СТИРАЛКА УТИХЛА"

func calm_machine() -> void:
    active = false
    calm_progress = calm_required
    _activation_left = randf_range(rearm_delay_min, rearm_delay_max) * DifficultyManager.get_hazard_delay()
    rotation = _base_rotation
    position.y = _base_height
    _set_indicator(false)
    # If Denis catches it in the doorway, its remaining momentum carries it
    # fully into the wide hall.  A stopped full-size cabinet must never seal
    # the only bathroom exit.
    _settling_clear_of_door = global_position.x < 2.12 and global_position.z > 3.20 and global_position.z < 4.30
    AudioManager.play_3d(&"switch", global_position, -5.0, 0.82)
    QuestManager.notification_requested.emit(
        "СТИРАЛКА УТИХЛА И ВЫКАТЫВАЕТСЯ ИЗ ПРОЁМА" if _settling_clear_of_door
        else "СТИРАЛКА УТИХОМИРЕНА — БАРАБАН ВЫРОВНЕН"
    )

func _settle_clear_of_door(delta: float) -> void:
    var safe_hall_position := Vector3(0.72, global_position.y, 3.76)
    var offset := safe_hall_position - global_position
    offset.y = 0.0
    if offset.length() <= 0.04:
        global_position.x = safe_hall_position.x
        global_position.z = safe_hall_position.z
        _settling_clear_of_door = false
        return
    global_position += offset.normalized() * minf(0.58 * delta, offset.length())

func _set_indicator(value: bool) -> void:
    if _indicator != null:
        _indicator.visible = value

func _indicator_visible() -> bool:
    return _indicator != null and _indicator.visible
