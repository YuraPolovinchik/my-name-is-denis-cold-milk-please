# PourController.gd
# Управляет процессом наливания жидкости из контейнера (чайник/пакет молока).
# §7 миссии: ЛКМ — наклон, отпускание — стоп, ПКМ — стабилизация.
# §8 миссии: ЕДИНАЯ баллистическая траектория (визуал == физика).
# §3 миссии: закон сохранения — removed = accepted + spilled (±1-2 мл).
class_name PourController
extends Node

## Сигнал: наливание началось
signal pour_started()
signal pour_stopped(hit_ml: float, spilled_ml: float, liquid_id: String)

## Сигнал: наливание закончилось (hit_ml, spilled_ml, liquid_id)
signal pour_finished(hit_ml: float, spilled_ml: float, liquid_id: String)

## Сигнал: жидкость попала в приёмник
signal liquid_hit(amount_ml: float, receiver: Node)
signal liquid_hit_receiver(amount_ml: float, receiver: Node)

## Сигнал: жидкость пролилась мимо
signal liquid_spilled(amount_ml: float, position: Vector3)
signal pour_feedback_changed(state: String, flow_rate_ml_s: float, spilled_session_ml: float)


# --- Параметры наклона (§7 миссии) ---
## Скорость наклона (град/с) при зажатой ЛКМ
const TILT_SPEED: float = 120.0
## Скорость возврата в вертикаль (град/с)
const RETURN_SPEED: float = 200.0
## Максимальный угол наклона
const MAX_TILT: float = 80.0
## Порог срабатывания квеста (мл)
const QUEST_TRIGGER_ML: float = 50.0
## Маска столкновений струи: слой 1 (статика/пол) + слой 8 (приёмники жидкости)
const STREAM_MASK: int = 1 | 2 | 8
const ASSIST_DISTANCE: float = 0.30
const ASSIST_MAX_ANGLE_DEG: float = 20.0
const ASSIST_ROTATION_CAP_DEG: float = 12.0
const RIM_FORGIVENESS: float = 0.022


var tilt_angle: float = 0.0
var target_tilt: float = 0.0

var source_item: Node = null
var source_volume: ContainerVolume = null
var liquid_def: LiquidDefinition = null
var powder_emitter: CoffeePowderEmitter = null
var powder_mode: bool = false

var hit_ml: float = 0.0
var spilled_ml: float = 0.0
var _pouring: bool = false
var _stabilizing: bool = false
var _quest_triggered: bool = false
var _last_receiver: Node = null
var last_feedback_state := "aiming"
var current_flow_rate_ml_s := 0.0
var prediction_state := "gray"
var prediction_point := Vector3.ZERO
var prediction_receiver: Node = null

var _stream: MeshInstance3D = null
var _predictor_dot: MeshInstance3D = null
var _receiver_ring: MeshInstance3D = null
const STREAM_RENDERER_SCRIPT := preload("res://scripts/liquid/stream_renderer.gd")


func _ready():
	_stream = STREAM_RENDERER_SCRIPT.new()
	_stream.name = "StreamRenderer"
	add_child(_stream)
	# Точки траектории хранятся в мировых координатах; визуал не должен
	# повторно наследовать transform игрока.
	_stream.top_level = true
	_create_predictor_visuals()

func _create_predictor_visuals() -> void:
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.018
	dot_mesh.height = 0.036
	_predictor_dot = MeshInstance3D.new()
	_predictor_dot.name = "PourImpactDot"
	_predictor_dot.mesh = dot_mesh
	_predictor_dot.top_level = true
	_predictor_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_predictor_dot)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.065
	ring_mesh.outer_radius = 0.078
	_receiver_ring = MeshInstance3D.new()
	_receiver_ring.name = "PourReceiverRing"
	_receiver_ring.mesh = ring_mesh
	_receiver_ring.top_level = true
	_receiver_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_receiver_ring)
	_set_prediction_visuals(false, false, Color.GRAY)

func _prediction_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.flags_transparent = true
	material.flags_no_depth_test = true
	material.albedo_color = color
	return material

func _set_prediction_visuals(show_dot: bool, show_ring: bool, color: Color) -> void:
	if _predictor_dot != null:
		_predictor_dot.visible = show_dot
		_predictor_dot.material_override = _prediction_material(color)
	if _receiver_ring != null:
		_receiver_ring.visible = show_ring
		_receiver_ring.material_override = _prediction_material(Color(color, 0.72))


## Начать наливание из указанного предмета.
## Возвращает false, если лить нечего.
func start_pouring(item_node: Node) -> bool:
	source_item = item_node
	source_volume = null
	powder_emitter = null
	powder_mode = false
	if item_node and item_node.has_method("get_container_volume"):
		source_volume = item_node.call("get_container_volume")
	elif item_node:
		source_volume = item_node.get_node_or_null("ContainerVolume") as ContainerVolume

	if item_node and item_node.has_method("get_powder_emitter"):
		powder_emitter = item_node.call("get_powder_emitter") as CoffeePowderEmitter
	elif item_node:
		powder_emitter = item_node.get_node_or_null("CoffeePowderEmitter") as CoffeePowderEmitter
	powder_mode = powder_emitter != null and not powder_emitter.is_empty()

	if not powder_mode and (source_volume == null or source_volume.is_empty()):
		push_warning("PourController: нет жидкости для розлива")
		queue_free()
		return false

	liquid_def = null if powder_mode else source_volume.liquid
	if not powder_mode and liquid_def == null:
		push_warning("PourController: у контейнера нет LiquidDefinition")
		queue_free()
		return false

	_pouring = true
	hit_ml = 0.0
	spilled_ml = 0.0
	_quest_triggered = false
	_last_receiver = null
	last_feedback_state = "aiming"
	current_flow_rate_ml_s = 0.0
	if _stream and _stream.has_method("set_stream_color"):
		_stream.set_stream_color(Color(0.32, 0.16, 0.055, 1.0) if powder_mode else liquid_def.color)
	pour_started.emit()
	return true


## Остановить наливание и вернуть статистику.
func stop_pouring() -> Dictionary:
	_pouring = false
	if _stream:
		_stream.update_stream(Vector3.ZERO, Vector3.DOWN, 0.0, 0.0)
	_set_prediction_visuals(false, false, Color.GRAY)
	var lid: String = "coffee_powder" if powder_mode else (liquid_def.id if liquid_def else "")
	pour_finished.emit(hit_ml, spilled_ml, lid)
	pour_stopped.emit(hit_ml, spilled_ml, lid)
	return {
		"hit_ml": hit_ml,
		"spilled_ml": spilled_ml,
		"liquid_id": lid,
	}


func _process(delta: float):
	if not _pouring:
		return
	if source_item == null or not is_instance_valid(source_item):
		stop_pouring()
		return

	# --- Наклон (§7) ---
	var stab_mult: float = 0.35 if _stabilizing else 1.0
	if target_tilt > tilt_angle:
		tilt_angle = minf(tilt_angle + TILT_SPEED * stab_mult * delta, target_tilt)
	elif target_tilt < tilt_angle:
		tilt_angle = maxf(tilt_angle - RETURN_SPEED * delta, target_tilt)
	tilt_angle = clampf(tilt_angle, 0.0, MAX_TILT)

	if powder_mode:
		_process_powder(delta)
		return
	if source_volume == null or liquid_def == null:
		return

	# --- Поток по углу (§7) ---
	var flow_rate: float = liquid_def.get_flow_rate(tilt_angle)
	current_flow_rate_ml_s = flow_rate
	if flow_rate <= 0.0:
		_set_feedback("aiming", 0.0)
		_stream.update_stream(Vector3.ZERO, Vector3.DOWN, 0.0, 0.0)
		return

	# Истончение струи у пустого контейнера (§7 миссии)
	var flow_fraction: float = clampf(source_volume.current_ml / 120.0, 0.15, 1.0)
	flow_rate *= flow_fraction
	current_flow_rate_ml_s = flow_rate

	# --- Забираем жидкость из источника (закон сохранения §3) ---
	var removed: float = source_volume.remove_liquid(flow_rate * delta)
	if removed <= 0.0:
		_stream.update_stream(Vector3.ZERO, Vector3.DOWN, 0.0, 0.0)
		return

	# --- Траектория (§8: та же, что рисует StreamRenderer) ---
	var origin: Vector3 = _get_pour_origin()
	var direction: Vector3 = _get_assisted_direction(origin, _get_pour_direction())
	var width: float = liquid_def.get_stream_width(flow_rate) * flow_fraction
	_stream.update_stream(origin, direction, flow_rate, width, flow_fraction)
	_update_prediction()

	# --- Физика попадания по тем же точкам ---
	_check_hit_ballistic(removed)

	# Триггер квеста при пороге
	if not _quest_triggered and _quest_threshold_met():
		_quest_triggered = true
		_trigger_quest()


func _process_powder(delta: float) -> void:
	if powder_emitter == null or powder_emitter.is_empty():
		_stream.update_stream(Vector3.ZERO, Vector3.DOWN, 0.0, 0.0)
		return
	var flow_rate := powder_emitter.get_flow_rate(tilt_angle)
	current_flow_rate_ml_s = flow_rate
	if flow_rate <= 0.0:
		_set_feedback("aiming", 0.0)
		_stream.update_stream(Vector3.ZERO, Vector3.DOWN, 0.0, 0.0)
		return
	var removed_g := powder_emitter.remove_powder(flow_rate * delta)
	if removed_g <= 0.0:
		return
	var origin := _get_pour_origin()
	var direction := _get_assisted_direction(origin, _get_pour_direction())
	_stream.update_stream(origin, direction, flow_rate * 18.0, 0.012, 1.0)
	_update_prediction()
	_check_hit_ballistic(removed_g, true)
	if not _quest_triggered and _quest_threshold_met():
		_quest_triggered = true
		_trigger_quest()


func _get_pour_origin() -> Vector3:
	if source_item == null:
		return Vector3.ZERO
	if source_item.has_method("get_pour_origin_global_position"):
		var value: Variant = source_item.call("get_pour_origin_global_position")
		if value is Vector3:
			return value
	if source_item is Node3D:
		return (source_item as Node3D).global_position
	return Vector3.ZERO


func _get_pour_direction() -> Vector3:
	var direction := Vector3.FORWARD
	if source_item and source_item.has_method("get_pour_direction_global"):
		var value: Variant = source_item.call("get_pour_direction_global")
		if value is Vector3:
			direction = value
	elif source_item is Node3D:
		direction = -(source_item as Node3D).global_transform.basis.z
	if direction.is_zero_approx():
		return Vector3.FORWARD
	return direction.normalized()

func _get_assisted_direction(origin: Vector3, raw_direction: Vector3) -> Vector3:
	var receiver := _nearest_assist_receiver(origin)
	if receiver == null:
		return raw_direction
	var desired := _ballistic_direction_to(origin, receiver.global_position, 1.0)
	var angle := rad_to_deg(raw_direction.angle_to(desired))
	var max_angle := 28.0 if powder_mode else ASSIST_MAX_ANGLE_DEG
	if angle > max_angle:
		return raw_direction
	var strength := (0.92 if _stabilizing else 0.70) if powder_mode else (0.82 if _stabilizing else 0.54)
	var rotation_cap := 16.0 if powder_mode else ASSIST_ROTATION_CAP_DEG
	var applied_angle := minf(angle * strength, rotation_cap)
	if angle <= 0.01:
		return raw_direction
	return raw_direction.slerp(desired, applied_angle / angle).normalized()

func _ballistic_direction_to(origin: Vector3, target: Vector3, flow_fraction: float = 1.0) -> Vector3:
	var speed: float = float(_stream.base_velocity) * lerpf(0.55, 1.0, clampf(flow_fraction, 0.0, 1.0))
	var displacement := target - origin
	var travel_time := clampf(displacement.length() / maxf(speed, 0.1), 0.06, 0.48)
	var compensated_velocity: Vector3 = (displacement - 0.5 * Vector3(_stream.gravity) * travel_time * travel_time) / travel_time
	return compensated_velocity.normalized()

func _nearest_assist_receiver(origin: Vector3) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := 0.38 if powder_mode else ASSIST_DISTANCE
	for candidate in get_tree().get_nodes_in_group("liquid_receiver"):
		if not candidate is Node3D:
			continue
		if candidate.has_method("is_opening_upright") and not bool(candidate.call("is_opening_upright")):
			continue
		var distance := origin.distance_to((candidate as Node3D).global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = candidate as Node3D
	return nearest

func _find_receiver_intersection(points: PackedVector3Array) -> Dictionary:
	var best: Dictionary = {}
	var best_segment := 9999
	for candidate in get_tree().get_nodes_in_group("liquid_receiver"):
		if not candidate is Node3D:
			continue
		if candidate.has_method("is_opening_upright") and not bool(candidate.call("is_opening_upright")):
			continue
		var receiver := candidate as Node3D
		var radius := float(receiver.call("get_opening_radius")) if receiver.has_method("get_opening_radius") else 0.072
		var height := float(receiver.call("get_opening_height")) if receiver.has_method("get_opening_height") else 0.034
		for index in range(points.size() - 1):
			if index >= best_segment:
				break
			var local_from := receiver.to_local(points[index])
			var local_to := receiver.to_local(points[index + 1])
			if local_from.y < -height or local_to.y > height:
				continue
			var segment_direction := (points[index + 1] - points[index]).normalized()
			if receiver.has_method("accepts_stream_direction") and not bool(receiver.call("accepts_stream_direction", segment_direction)):
				continue
			var denominator := local_from.y - local_to.y
			var t := clampf(local_from.y / denominator, 0.0, 1.0) if absf(denominator) > 0.0001 else 0.5
			var local_hit := local_from.lerp(local_to, t)
			var radial := Vector2(local_hit.x, local_hit.z).length()
			var rim_forgiveness := 0.035 if powder_mode else RIM_FORGIVENESS
			if radial > radius + rim_forgiveness:
				continue
			var acceptance := 1.0
			var quality := "direct"
			if radial > radius * 0.82 and radial <= radius:
				acceptance = 0.90
				quality = "inner_rim"
			elif radial > radius:
				var rim_t := clampf((radial - radius) / rim_forgiveness, 0.0, 1.0)
				acceptance = lerpf(0.70, 0.45, rim_t)
				quality = "outer_rim"
			best = {
				"receiver": receiver,
				"point": receiver.to_global(Vector3(local_hit.x, 0.0, local_hit.z)),
				"acceptance": acceptance,
				"quality": quality,
			}
			best_segment = index
			break
	return best

func _update_prediction() -> void:
	var points: PackedVector3Array = _stream.last_trajectory
	if points.size() < 2:
		_set_prediction_visuals(false, false, Color.GRAY)
		return
	var result := _find_receiver_intersection(points)
	var color := Color(0.30, 0.95, 0.50, 0.95)
	prediction_receiver = result.get("receiver") as Node
	if not result.is_empty():
		prediction_point = result.get("point", points[points.size() - 1])
		prediction_state = "green" if float(result.get("acceptance", 0.0)) >= 0.80 else "orange"
		color = Color(0.30, 0.95, 0.50, 0.95) if prediction_state == "green" else Color(1.0, 0.55, 0.12, 0.95)
	else:
		prediction_point = points[points.size() - 1]
		prediction_state = "red"
		color = Color(1.0, 0.20, 0.16, 0.95)
	_set_prediction_visuals(true, prediction_receiver != null, color)
	_predictor_dot.global_position = prediction_point
	if prediction_receiver is Node3D:
		_receiver_ring.global_transform = (prediction_receiver as Node3D).global_transform


## Проверка попадания по баллистическим сегментам (§8 миссии).
## Лучи: collide_with_areas + collide_with_bodies, исключены источник и игрок.
func _check_hit_ballistic(volume_this_frame: float, is_powder: bool = false):
	var world = get_tree().root.world_3d
	if world == null:
		return
	var space_state = world.direct_space_state
	var points: PackedVector3Array = _stream.last_trajectory
	if points.size() < 2:
		return
	var receiver_result := _find_receiver_intersection(points)
	if not receiver_result.is_empty():
		_deliver_receiver_hit(
			receiver_result.get("receiver"),
			receiver_result.get("point", points[points.size() - 1]),
			volume_this_frame,
			float(receiver_result.get("acceptance", 1.0)),
			is_powder
		)
		return

	# Исключения: сам источник + игрок
	var exclude: Array[RID] = []
	if source_item is CollisionObject3D:
		exclude.append(source_item.get_rid())
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		exclude.append(player.get_rid())

	# Идём по сегментам траектории — первое попадание решает судьбу порции
	for i in range(points.size() - 1):
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var query := PhysicsRayQueryParameters3D.create(from, to, STREAM_MASK, exclude)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result: Dictionary = space_state.intersect_ray(query)
		if result.is_empty():
			continue

		var collider: Object = result.get("collider")
		var hit_pos: Vector3 = result.get("position", to)

		# Приёмник жидкости (кружка) — Area3D с on_liquid_hit
		if collider and (collider.has_method("on_powder_hit") if is_powder else collider.has_method("on_liquid_hit")):
			# Отверстие принимает только нисходящую струю сверху.
			var segment_direction := (to - from).normalized()
			if (
				segment_direction.dot(Vector3.DOWN) < 0.20
				or (
					collider.has_method("accepts_stream_direction")
					and not bool(collider.call("accepts_stream_direction", segment_direction))
				)
			):
				spilled_ml += volume_this_frame
				liquid_spilled.emit(volume_this_frame, hit_pos)
				_spawn_spill_at(hit_pos, volume_this_frame)
				_set_feedback("mug_wall", current_flow_rate_ml_s)
				return
			var accepted_value: Variant
			if is_powder:
				accepted_value = collider.call("on_powder_hit", volume_this_frame)
			else:
				var temp_c: float = _get_source_temperature()
				accepted_value = collider.call("on_liquid_hit", volume_this_frame, liquid_def, temp_c)
			var accepted := clampf(float(accepted_value), 0.0, volume_this_frame)
			var overflow := volume_this_frame - accepted
			hit_ml += accepted
			spilled_ml += overflow
			if accepted > 0.0:
				_last_receiver = collider as Node
				liquid_hit.emit(accepted, collider)
				liquid_hit_receiver.emit(accepted, collider)
			if overflow > 0.0:
				liquid_spilled.emit(overflow, hit_pos)
				_spawn_spill_at(hit_pos, overflow)
				_set_feedback("mug_wall" if accepted <= 0.0 else "overflow", current_flow_rate_ml_s)
			else:
				_set_feedback("in_mug", current_flow_rate_ml_s)
			return

		# Любое другое тело — пролив в точке попадания (§11 миссии)
		spilled_ml += volume_this_frame
		liquid_spilled.emit(volume_this_frame, hit_pos)
		_spawn_spill_at(hit_pos, volume_this_frame)
		_set_feedback("mug_wall" if _belongs_to_mug(collider) else "miss", current_flow_rate_ml_s)
		return

	# Ничего не задели — струя падает в конечную точку (пол/стол)
	var end_point: Vector3 = points[points.size() - 1]
	# Луч вниз из конца дуги, чтобы найти поверхность
	var down_query := PhysicsRayQueryParameters3D.create(end_point, end_point + Vector3(0, -1.2, 0), 1, exclude)
	down_query.collide_with_areas = false
	down_query.collide_with_bodies = true
	var down_result: Dictionary = space_state.intersect_ray(down_query)
	if not down_result.is_empty():
		end_point = down_result.get("position", end_point)
	spilled_ml += volume_this_frame
	liquid_spilled.emit(volume_this_frame, end_point)
	_spawn_spill_at(end_point, volume_this_frame)
	_set_feedback("miss", current_flow_rate_ml_s)

func _deliver_receiver_hit(receiver: Object, hit_pos: Vector3, amount: float, rim_acceptance: float, is_powder: bool) -> void:
	var offered := amount * clampf(rim_acceptance, 0.0, 1.0)
	var accepted_value: Variant
	if is_powder:
		accepted_value = receiver.call("on_powder_hit", offered)
	else:
		accepted_value = receiver.call("on_liquid_hit", offered, liquid_def, _get_source_temperature())
	var accepted := clampf(float(accepted_value), 0.0, offered)
	var spilled := amount - accepted
	hit_ml += accepted
	spilled_ml += spilled
	if accepted > 0.0:
		_last_receiver = receiver as Node
		liquid_hit.emit(accepted, receiver)
		liquid_hit_receiver.emit(accepted, receiver)
	if spilled > 0.0:
		liquid_spilled.emit(spilled, hit_pos)
		_spawn_spill_at(hit_pos, spilled)
		_set_feedback("overflow" if accepted > 0.0 else "mug_wall", current_flow_rate_ml_s)
	else:
		_set_feedback("in_mug", current_flow_rate_ml_s)

func _belongs_to_mug(collider: Object) -> bool:
	var node := collider as Node
	while node != null:
		if node.is_in_group("mug"):
			return true
		node = node.get_parent()
	return false

func _set_feedback(state: String, flow_rate: float) -> void:
	last_feedback_state = state
	current_flow_rate_ml_s = flow_rate
	pour_feedback_changed.emit(last_feedback_state, current_flow_rate_ml_s, spilled_ml)


func _get_source_temperature() -> float:
	# Температура чайника (если есть KettleStateMachine)
	if source_item:
		var ksm := source_item.get_node_or_null("KettleStateMachine")
		if ksm and "temperature_c" in ksm:
			return float(ksm.temperature_c)
	return 20.0


func _trigger_quest():
	QuestManager.sync_story_mug()

func _quest_threshold_met() -> bool:
	if (liquid_def == null and not powder_mode) or _last_receiver == null:
		return false
	var mug_controller: MugContentController = null
	if _last_receiver.has_method("get_mug_controller"):
		mug_controller = _last_receiver.call("get_mug_controller") as MugContentController
	if mug_controller == null:
		return hit_ml >= QUEST_TRIGGER_ML
	if powder_mode:
		return mug_controller.coffee_powder_g >= MugContentController.POWDER_MIN_G
	if liquid_def.id == "water":
		return mug_controller.water_ml >= MugContentController.WATER_MIN_ML
	if liquid_def.id == "milk":
		return mug_controller.milk_ml >= MugContentController.MILK_MIN_ML
	return hit_ml >= QUEST_TRIGGER_ML


func _spawn_spill_at(position: Vector3, amount_ml: float):
	var spill_manager = get_tree().get_first_node_in_group("spill_manager")
	if spill_manager and spill_manager.has_method("spawn_spill_typed"):
		var lid: String = "coffee_powder" if powder_mode else (liquid_def.id if liquid_def else "water")
		spill_manager.call("spawn_spill_typed", position, lid, amount_ml)
	elif spill_manager and spill_manager.has_method("spawn_spill"):
		var col: Color = Color(0.25, 0.12, 0.04) if powder_mode else (liquid_def.color if liquid_def else Color.WHITE)
		spill_manager.call("spawn_spill", position, col)
