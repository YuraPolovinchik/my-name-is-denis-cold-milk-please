# LiquidSurface.gd
# Визуальная поверхность жидкости внутри кружки (§10/§17 миссии).
# Всегда горизонтальна в мире, отстаёт от движения кружки (lag),
# наклоняется против ускорения (slosh-модель). Высота по объёму, цвет по составу.
class_name LiquidSurface
extends MeshInstance3D

## Радиус поверхности (чуть меньше стенок кружки)
@export var surface_radius: float = 0.105

## Макс. высота заполнения (от дна кружки)
@export var max_fill_height: float = 0.20

## Высота дна кружки (local Y)
@export var bottom_y: float = -0.11

## Скорость "догоняния" горизонтали (1/с) — lag (§17 миссии)
@export var level_lerp_speed: float = 6.0

## Макс. наклон поверхности при slosh (рад)
@export var max_slosh_tilt: float = 0.35

## Коэффициент slosh от ускорения
@export var slosh_sensitivity: float = 0.05


var _mug_node: Node3D = null
var _mug_controller: Node = null
var _mat: StandardMaterial3D = null

# Текущий наклон поверхности (мировой), отстаёт от кружки
var _slosh_tilt: Vector2 = Vector2.ZERO  # (pitch, roll)
var _last_mug_velocity: Vector3 = Vector3.ZERO


func _ready():
	var cm := CylinderMesh.new()
	cm.top_radius = surface_radius
	cm.bottom_radius = surface_radius
	cm.height = 0.004
	cm.radial_segments = 20
	mesh = cm

	_mat = StandardMaterial3D.new()
	_mat.flags_transparent = true
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.metallic = 0.1
	_mat.roughness = 0.25
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	top_level = true  # Позиция в мировых координатах — не наследует наклон кружки
	_update_from_controller()


## Привязать кружку и контроллер содержимого.
func setup(mug: Node3D, controller: Node) -> void:
	_mug_node = mug
	_mug_controller = controller
	if _mug_controller and _mug_controller.has_signal("content_changed"):
		_mug_controller.content_changed.connect(_on_content_changed)
	if is_node_ready():
		_update_from_controller()


func _process(delta: float) -> void:
	if _mug_node == null or _mug_controller == null:
		visible = false
		return
	var total_ml: float = 0.0
	if _mug_controller.has_method("total_liquid_ml"):
		total_ml = _mug_controller.call("total_liquid_ml")
	if total_ml <= 0.5:
		visible = false
		return
	visible = true

	# --- Высота по объёму ---
	var capacity: float = 350.0
	if "capacity_ml" in _mug_controller:
		capacity = float(_mug_controller.capacity_ml)
	var fill_frac: float = clampf(total_ml / capacity, 0.0, 1.0)
	var local_h: float = bottom_y + fill_frac * max_fill_height

	# Поверхность всегда горизонтальна в мире: позиция = центр кружки + world UP * h
	var mug_origin: Vector3 = _mug_node.global_position
	var target_pos: Vector3 = mug_origin + Vector3(0, local_h, 0)
	global_position = global_position.lerp(target_pos, clampf(level_lerp_speed * delta, 0.0, 1.0))

	# --- Slosh (§17 миссии): наклон против ускорения кружки ---
	var vel: Vector3 = Vector3.ZERO
	if _mug_node is RigidBody3D:
		vel = (_mug_node as RigidBody3D).linear_velocity
	var accel: Vector3 = (vel - _last_mug_velocity) / maxf(delta, 0.0001)
	_last_mug_velocity = vel

	# Целевой наклон от горизонтального ускорения (ограничен)
	var target_tilt := Vector2(
		clampf(accel.z * slosh_sensitivity, -max_slosh_tilt, max_slosh_tilt),
		clampf(-accel.x * slosh_sensitivity, -max_slosh_tilt, max_slosh_tilt)
	)
	_slosh_tilt = _slosh_tilt.lerp(target_tilt, clampf(4.0 * delta, 0.0, 1.0))
	# Медленное выравнивание к горизонтали
	_slosh_tilt = _slosh_tilt.lerp(Vector2.ZERO, clampf(2.0 * delta, 0.0, 1.0))

	# Применяем: поверхность горизонтальна + небольшой slosh-наклон
	global_rotation = Vector3(_slosh_tilt.x, 0.0, _slosh_tilt.y)


func _on_content_changed(_components: Dictionary) -> void:
	_update_from_controller()


func _update_from_controller() -> void:
	if _mat and _mug_controller and _mug_controller.has_method("get_surface_color"):
		_mat.albedo_color = _mug_controller.call("get_surface_color")
