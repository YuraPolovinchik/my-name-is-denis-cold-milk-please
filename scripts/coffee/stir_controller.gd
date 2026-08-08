# StirController.gd
# Управляет перемешиванием кофе ложкой (§16 миссии).
# SpoonTip движется по кругу внутри жидкости; считаем угловые обороты.
# 3+ оборота → is_stirred = true. Быстрое перемешивание → шум (звон) + возможные брызги.
class_name StirController
extends Node

## Сигнал: перемешивание завершено (3+ оборотов)
signal stirring_complete()

## Сигнал: прогресс перемешивания (обороты, доля до цели)
signal stirring_progress(rotations: float, fraction: float)


## Минимальные обороты для готовности (§16 миссии)
const MIN_ROTATIONS: float = 3.0
## Рекомендуемые обороты
const REC_ROTATIONS: float = 4.0
## Порог "быстрого" перемешивания (рад/с) — звон + брызги
const FAST_STIR_SPEED: float = 9.0
## Порог выплеска при слишком быстром помешивании (рад/с)
const SPLASH_STIR_SPEED: float = 14.0

## Ссылка на MugContentController (куда перемешиваем)
@export var mug_controller_path: NodePath = NodePath()

## SpoonTip — Node3D кончика ложки (должен быть в жидкости)
var spoon_tip: Node3D = null

var _mug_controller: Node = null
var _mug_node: Node3D = null
var _last_angle: float = 0.0
var _accumulated_angle: float = 0.0  # радианы, накопленный поворот
var _rotations: float = 0.0
var _active: bool = false
var _was_complete: bool = false
var _noise_cooldown: float = 0.0


func _ready():
	if mug_controller_path:
		_mug_controller = get_node_or_null(mug_controller_path)
	var spoon := get_parent() as Node3D
	if spoon:
		spoon_tip = spoon.get_node_or_null("SpoonTip") as Node3D


## Начать отслеживание перемешивания.
## spoon — Node3D кончика ложки, mug — Node3D кружки, controller — MugContentController.
func begin_stir(spoon: Node3D, mug: Node3D, controller: Node) -> void:
	spoon_tip = spoon
	_mug_node = mug
	_mug_controller = controller
	_active = true
	_accumulated_angle = 0.0
	_rotations = 0.0
	_was_complete = false
	# Начальный угол кончика относительно центра кружки
	_last_angle = _tip_angle()


## Остановить перемешивание.
func end_stir() -> void:
	_active = false
	spoon_tip = null


## Текущие обороты.
func get_rotations() -> float:
	return _rotations


## Перемешано ли (3+ оборотов).
func is_stirred() -> bool:
	return _was_complete


func _process(delta: float) -> void:
	_noise_cooldown = maxf(0.0, _noise_cooldown - delta)
	if not _active:
		_try_begin_from_nearby_mug()
	if not _active or spoon_tip == null or _mug_node == null:
		return
	if _mug_controller == null:
		return
	var spoon := get_parent()
	if spoon != null and "held" in spoon and not bool(spoon.get("held")):
		end_stir()
		return
	if spoon_tip.global_position.distance_to(_mug_node.global_position) > 0.38:
		end_stir()
		return

	# Кончик ложки должен быть внутри жидкости (§16: только в жидкости)
	if not _tip_in_liquid():
		_last_angle = _tip_angle()
		return

	var angle: float = _tip_angle()
	var diff: float = angle - _last_angle
	# Нормализуем кратчайший путь (-PI..PI)
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	_last_angle = angle

	# Считаем полный направленный путь: движения туда-сюда взаимно
	# компенсируются и не превращаются в фиктивные обороты.
	_accumulated_angle += diff
	_rotations = absf(_accumulated_angle) / TAU

	# Скорость вращения (рад/с)
	var speed: float = absf(diff) / maxf(delta, 0.0001)

	# Быстрое перемешивание → звон ложки о кружку + шум Рите (§16/§21)
	if speed > FAST_STIR_SPEED and _noise_cooldown <= 0.0:
		_noise_cooldown = 0.5
		var strength: float = clampf((speed - FAST_STIR_SPEED) * 2.0, 3.0, 20.0)
		NoiseManager.emit_noise(_mug_node.global_position, strength, &"DISHES", &"stir")
		AudioManager.play_3d(&"clink", _mug_node.global_position, -14.0, 1.3)
		QuestManager.notification_requested.emit("ЛОЖКА ЗВЕНИТ  •  МЕШАЙ ТИШЕ")

	# Слишком быстрое → брызги (§16)
	if speed > SPLASH_STIR_SPEED and _noise_cooldown <= 0.0:
		_noise_cooldown = 0.6
		_splash()

	# Прогресс
	var frac: float = clampf(_rotations / MIN_ROTATIONS, 0.0, 1.0)
	stirring_progress.emit(_rotations, frac)

	# Завершение (3+ оборотов)
	if not _was_complete and _rotations >= MIN_ROTATIONS:
		_was_complete = true
		if _mug_controller.has_method("set_stirred"):
			_mug_controller.call("set_stirred")
		stirring_complete.emit()
		QuestManager.notification_requested.emit("КОФЕ ПЕРЕМЕШАН")


func _try_begin_from_nearby_mug() -> void:
	var spoon := get_parent()
	if spoon == null or not ("held" in spoon) or not bool(spoon.get("held")):
		return
	if spoon_tip == null:
		spoon_tip = spoon.get_node_or_null("SpoonTip") as Node3D
	if spoon_tip == null:
		return
	var nearest_mug: Node3D = null
	var nearest_distance := 0.38
	for candidate in get_tree().get_nodes_in_group("mug"):
		if candidate is Node3D:
			var distance := spoon_tip.global_position.distance_to((candidate as Node3D).global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_mug = candidate as Node3D
	if nearest_mug == null:
		return
	var controller := nearest_mug.get_node_or_null("MugContentController")
	if controller != null:
		begin_stir(spoon_tip, nearest_mug, controller)


## Угол кончика ложки относительно центра кружки (в плоскости XZ).
func _tip_angle() -> float:
	if spoon_tip == null or _mug_node == null:
		return 0.0
	var local: Vector3 = _mug_node.global_transform.affine_inverse() * spoon_tip.global_position
	return atan2(local.z, local.x)


## Кончик ложки внутри жидкости (по высоте и радиусу кружки)?
func _tip_in_liquid() -> bool:
	if spoon_tip == null or _mug_node == null or _mug_controller == null:
		return false
	var total_ml: float = 0.0
	if _mug_controller.has_method("total_liquid_ml"):
		total_ml = _mug_controller.call("total_liquid_ml")
	if total_ml <= 0.0:
		return false
	var local: Vector3 = _mug_node.global_transform.affine_inverse() * spoon_tip.global_position
	# Кружка r≈0.105, высота заполнения ~ (total_ml/350)*0.22
	var r: float = Vector2(local.x, local.z).length()
	if r > 0.10:
		return false
	var fill_h: float = clampf(total_ml / 350.0, 0.0, 1.0) * 0.20
	# Кончик ниже поверхности жидкости (от дна кружки local.y≈-0.11)
	return local.y < (-0.11 + fill_h + 0.02)


## Брызги при слишком быстром помешивании (§16).
func _splash() -> void:
	if _mug_controller == null or not _mug_controller.has_method("drink_sip"):
		return
	# Теряем пару мл и создаём лужу рядом с кружкой
	var lost: float = _mug_controller.call("drink_sip", 2.0)
	if lost > 0.0:
		var sm := get_tree().get_first_node_in_group("spill_manager")
		if sm and sm.has_method("spawn_spill_typed") and _mug_node:
			var pos: Vector3 = _mug_node.global_position + Vector3(0.12, 0.0, 0.0)
			sm.call("spawn_spill_typed", pos, "coffee_mix", lost)
