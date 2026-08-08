# LiquidReceiver.gd
# Area3D, размещается на отверстии кружки (MugOpeningArea — §9 миссии).
# Радиус 0.040-0.045 м, принимает жидкость только сверху.
# Детектирует попадание струи и передаёт жидкость в MugContentController.
class_name LiquidReceiver
extends Area3D

## Ссылка на MugContentController
@export var mug_content_controller_path: NodePath = NodePath()
@export var opening_normal_path: NodePath = NodePath("../OpeningNormal")
@export_range(20.0, 70.0, 1.0) var maximum_upright_tilt_degrees: float = 42.0

## Радиус отверстия (м) — §9 миссии: 0.040-0.045
@export var detection_radius: float = 0.072

## Высота зоны приёма (м) — §9: 0.015-0.025
@export var detection_height: float = 0.034

var _mug_controller: Node = null
var _opening_normal: Node3D = null

signal liquid_received(amount_ml: float, definition: LiquidDefinition)


func _ready():
	add_to_group("liquid_receiver")
	collision_layer = 8
	collision_mask = 0
	monitoring = true
	monitorable = true

	# Цилиндр приёма — принимает только попадания сверху
	var shape := CylinderShape3D.new()
	shape.radius = detection_radius
	shape.height = detection_height
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	if mug_content_controller_path:
		_mug_controller = get_node_or_null(mug_content_controller_path)
	if _mug_controller == null:
		var ancestor := get_parent()
		while ancestor != null and _mug_controller == null:
			_mug_controller = ancestor.get_node_or_null("MugContentController")
			ancestor = ancestor.get_parent()
	if opening_normal_path:
		_opening_normal = get_node_or_null(opening_normal_path) as Node3D
	if _mug_controller == null:
		push_error("LiquidReceiver: MugContentController НЕ НАЙДЕН — жидкость некуда принимать!")


## Вызывается PourController при попадании струи (§8 миссии).
## Принимает жидкость только если струя идёт сверху (§9 миссии).
func on_liquid_hit(amount_ml: float, defn: LiquidDefinition, source_temp_c: float = 20.0) -> float:
	if _mug_controller == null or not is_opening_upright():
		return 0.0
	if not _mug_controller.has_method("add_liquid"):
		return 0.0
	var accepted: float = _mug_controller.call("add_liquid", amount_ml, defn, source_temp_c)
	if accepted > 0.0:
		liquid_received.emit(accepted, defn)
	return accepted

func on_powder_hit(amount_g: float) -> float:
	if _mug_controller == null or not is_opening_upright():
		return 0.0
	if not _mug_controller.has_method("add_powder"):
		return 0.0
	return float(_mug_controller.call("add_powder", amount_g))

func is_opening_upright() -> bool:
	var normal := global_transform.basis.y.normalized()
	if _opening_normal != null:
		normal = _opening_normal.global_transform.basis.y.normalized()
	return normal.dot(Vector3.UP) >= cos(deg_to_rad(maximum_upright_tilt_degrees))

func accepts_stream_direction(direction: Vector3) -> bool:
	if not is_opening_upright():
		return false
	var normal := global_transform.basis.y.normalized()
	if _opening_normal != null:
		normal = _opening_normal.global_transform.basis.y.normalized()
	return direction.normalized().dot(-normal) >= 0.20

func get_mug_controller() -> Node:
	return _mug_controller

func get_opening_radius() -> float:
	return detection_radius

func get_opening_height() -> float:
	return detection_height

func get_opening_normal() -> Vector3:
	if _opening_normal != null:
		return _opening_normal.global_transform.basis.y.normalized()
	return global_transform.basis.y.normalized()


## Есть ли контроллер содержимого.
func is_ready() -> bool:
	return _mug_controller != null
