extends RigidBody3D

@export var item_id: StringName = &"item"
@export var display_name := "ПРЕДМЕТ"
@export var impact_noise_scale := 1.0
@export var quest_critical := false

# === GRIP POINTS (опциональные дочерние Node3D) ===
## Точка хвата для обычного ношения (относительно RigidBody)
@export var grip_point_path: NodePath = NodePath()
## Точка хвата для режима розлива (правая сторона, как FPS оружие)
@export var pour_grip_point_path: NodePath = NodePath()
## Точка, откуда вытекает струя (носик чайника)
@export var pour_origin_path: NodePath = NodePath()
## Точка направления струи (куда целиться)
@export var pour_direction_path: NodePath = NodePath()
## Ссылка на ContainerVolume (для жидкостей)
@export var container_volume_path: NodePath = NodePath()
@export var powder_emitter_path: NodePath = NodePath()

var held = false
var last_safe_transform: Transform3D
var _noise_cooldown = 0.0
var _rest_time = 0.0
var _last_speed = 0.0
var _next_impact_noise_bonus := 0.0

# Режим розлива
var pour_mode: bool = false

# Кэшированные ссылки на grip-узлы
var _grip_point: Node3D = null
var _pour_grip_point: Node3D = null
var _pour_origin: Node3D = null
var _pour_direction: Node3D = null
var _container_volume: ContainerVolume = null
var _powder_emitter: CoffeePowderEmitter = null

## Возвращает глобальную позицию grip-точки для обычного ношения.
func get_grip_global_position() -> Vector3:
    if _grip_point:
        return _grip_point.global_position
    return global_position

## Возвращает глобальную позицию grip-точки для режима розлива.
func get_pour_grip_global_position() -> Vector3:
    if _pour_grip_point:
        return _pour_grip_point.global_position
    return global_position

## Возвращает глобальную позицию носика (откуда льётся струя).
func get_pour_origin_global_position() -> Vector3:
    if _pour_origin:
        return _pour_origin.global_position
    return global_position + Vector3(0.0, 0.05, -0.15)

## Возвращает глобальное направление струи (нормализованный вектор).
func get_pour_direction_global() -> Vector3:
    if _pour_direction:
        var dir_vec: Vector3 = _pour_direction.global_position - _pour_origin.global_position
        if dir_vec.length_squared() > 0.0001:
            return dir_vec.normalized()
    return -global_transform.basis.z

## Войти в режим розлива (вызывается из player_controller).
func enter_pour_mode() -> void:
    pour_mode = true
    var kettle_state := get_node_or_null("KettleStateMachine")
    if kettle_state and kettle_state.has_method("transition_to"):
        kettle_state.call("transition_to", KettleStateMachine.KettleState.POURING)

## Выйти из режима розлива.
func exit_pour_mode() -> void:
    pour_mode = false
    var kettle_state := get_node_or_null("KettleStateMachine")
    if kettle_state and kettle_state.has_method("stop_pouring"):
        kettle_state.call("stop_pouring")

## Есть ли контейнер с жидкостью?
func has_liquid_container() -> bool:
    return _container_volume != null

## Есть ли жидкость для розлива?
func has_pourable_liquid() -> bool:
    return _container_volume != null and not _container_volume.is_empty()

## Вернуть ContainerVolume (для PourController/WaterSource).
func get_container_volume() -> ContainerVolume:
    return _container_volume

func get_powder_emitter() -> CoffeePowderEmitter:
    return _powder_emitter

func has_powder_emitter() -> bool:
    return _powder_emitter != null

func has_pourable_powder() -> bool:
    return _powder_emitter != null and not _powder_emitter.is_empty()

## Tilt angle в градусах относительно нормального положения (0 = вертикально, 90 = горизонтально).
## Вычисляется по разнице между глобальной -Y и направлением носика.
func get_tilt_angle_deg() -> float:
    var pour_dir: Vector3 = get_pour_direction_global()
    # Угол между направлением носика и вектором вниз (-Y)
    var angle_down: float = pour_dir.angle_to(Vector3.DOWN)
    return rad_to_deg(angle_down)

func _ready() -> void:
    add_to_group("carryable")
    add_to_group(String(item_id))
    contact_monitor = true
    max_contacts_reported = 6
    impact_noise_scale = maxf(impact_noise_scale, 0.55 + sqrt(maxf(mass, 0.05)) * 0.22)
    last_safe_transform = global_transform
    body_entered.connect(_on_body_entered)
    
    # Кэшируем grip-узлы
    if grip_point_path:
        var node = get_node(grip_point_path)
        if node is Node3D:
            _grip_point = node as Node3D
    if pour_grip_point_path:
        var node = get_node(pour_grip_point_path)
        if node is Node3D:
            _pour_grip_point = node as Node3D
    if pour_origin_path:
        var node = get_node(pour_origin_path)
        if node is Node3D:
            _pour_origin = node as Node3D
    if pour_direction_path:
        var node = get_node(pour_direction_path)
        if node is Node3D:
            _pour_direction = node as Node3D
    if container_volume_path:
        var node = get_node(container_volume_path)
        if node is ContainerVolume:
            _container_volume = node as ContainerVolume
    if powder_emitter_path:
        var node = get_node(powder_emitter_path)
        if node is CoffeePowderEmitter:
            _powder_emitter = node as CoffeePowderEmitter

func _physics_process(delta: float) -> void:
    _noise_cooldown = maxf(0.0, _noise_cooldown - delta)
    if held:
        return
    var speed = linear_velocity.length()
    if speed < 0.15 and global_position.y > -0.2:
        _rest_time += delta
        if _rest_time > 1.0:
            last_safe_transform = global_transform
            _rest_time = 0.0
    else:
        _rest_time = 0.0
    _last_speed = speed
    if global_position.y < -4.0 or absf(global_position.x) > 30.0 or absf(global_position.z) > 30.0:
        recover()

func on_picked_up() -> void:
    held = true
    freeze = true
    collision_layer = 0
    collision_mask = 0
    if item_id == &"kettle":
        var kettle_state := get_node_or_null("KettleStateMachine") as KettleStateMachine
        if kettle_state != null and kettle_state.state in [
            KettleStateMachine.KettleState.FILLED,
            KettleStateMachine.KettleState.ON_BASE,
            KettleStateMachine.KettleState.BOILED,
            KettleStateMachine.KettleState.COOLING,
            KettleStateMachine.KettleState.BOILING_AWAY
        ]:
            kettle_state.transition_to(KettleStateMachine.KettleState.HELD)
    if item_id == &"mug":
        QuestManager.register_mug()
    elif item_id == &"coffee_jar":
        QuestManager.register_coffee()
    elif item_id == &"milk_carton":
        QuestManager.register_milk()

func on_released() -> void:
    held = false
    freeze = false
    collision_layer = 2
    collision_mask = 3
    impact_noise_scale = maxf(impact_noise_scale, 0.55 + sqrt(maxf(mass, 0.05)) * 0.22)
    last_safe_transform = global_transform

func arm_forced_impact_noise(bonus: float) -> void:
    _next_impact_noise_bonus = maxf(_next_impact_noise_bonus, maxf(0.0, bonus))

func recover() -> void:
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    global_transform = last_safe_transform.translated(Vector3.UP * 0.15)
    freeze = false
    held = false
    collision_layer = 2
    collision_mask = 3

func interact(actor, mode: int) -> String:
    if item_id == &"mug" and not held:
        return await _mug_interact(actor, mode)
    return "НАЖМИ ЛКМ, ЧТОБЫ ВЗЯТЬ %s" % display_name

func _mug_interact(actor, mode: int) -> String:
    if held:
        return "ПОСТАВЬ КРУЖКУ НА СТОЛ"
    if bool(get_meta("coffee_ready", false)):
        if actor != null and actor.has_method("begin_drink_coffee") and actor.call("begin_drink_coffee", self):
            return "ДЕНИС ПЬЁТ КОФЕ"
        return "НЕ УДАЁТСЯ ВЫПИТЬ КОФЕ"
    return "ЛКМ — ВЗЯТЬ КРУЖКУ"

func get_prompt(_actor) -> String:
    if item_id == &"mug" and not held:
        if bool(get_meta("coffee_ready", false)):
            return "E — ВЫПИТЬ КОФЕ"
        return "E — ВЗАИМОДЕЙСТВИЕ  |  ЛКМ — ВЗЯТЬ: %s  [%.1f кг]" % [display_name, mass]
    if item_id == &"mug" and bool(get_meta("coffee_ready", false)):
        return "ЛКМ — ВЗЯТЬ ГОРЯЧИЙ КОФЕ  •  ПОТОМ E — ВЫПИТЬ"
    return "ЛКМ — ВЗЯТЬ: %s  [%.1f кг]" % [display_name, mass]

func _on_body_entered(_body: Node) -> void:
    if held or _noise_cooldown > 0.0:
        return
    var impact_speed = maxf(_last_speed, linear_velocity.length())
    if impact_speed < 1.25:
        return
    _noise_cooldown = 0.45
    var dampened = _is_dampened()
    var strength: float = clampf(impact_speed * 4.5 * impact_noise_scale + _next_impact_noise_bonus, 2.0, 58.0)
    _next_impact_noise_bonus = 0.0
    var undampened_strength: float = strength
    if dampened:
        strength *= 0.35
    if bool(get_meta("felt_pads", false)):
        strength *= 0.52
    RunStats.record_noise_prevented(undampened_strength - strength)
    NoiseManager.emit_noise(global_position, strength, &"OBJECT_IMPACT", item_id)
    AudioManager.play_3d(&"clink", global_position, -8.0, clampf(0.85 + impact_speed * 0.04, 0.85, 1.25))
    # Визуальные эффекты при ударе
    if not dampened:
        VisualEffects.spawn_impact_sparks(global_position, int(clampf(impact_speed * 2.0, 3.0, 12.0)))
        VisualEffects.spawn_impact_shake(clampf(impact_speed * 0.08, 0.05, 0.25))
    RunStats.record_drop()

func _is_dampened() -> bool:
    for node in get_tree().get_nodes_in_group("noise_dampeners"):
        if node is RigidBody3D and bool(node.get("held")):
            continue
        if node is Node3D and global_position.distance_to(node.global_position) <= 1.0:
            return true
    return false
