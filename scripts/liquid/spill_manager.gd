# SpillManager.gd
# Управляет лужами на поверхностях (§11 миссии).
# Типизированные проливы: WATER/MILK/COFFEE_MIX/COFFEE_POWDER.
# Создаёт SpillCluster при разливе, объединяет близкие лужи (не более merge_radius),
# пулит до max_spills — старые удаляются (§23 миссии: производительность).
class_name SpillManager
extends Node

signal spills_changed(state: Dictionary)
signal spill_cleaned(liquid_type: String, amount_ml: float)

## Максимум одновременных луж (§23 миссии)
@export var max_spills: int = 20

## Радиус объединения луж (м)
@export var merge_radius: float = 0.3

## Цвета по типу жидкости (§11 миссии)
const TYPE_COLORS := {
	"water": Color(0.55, 0.75, 0.95, 0.45),
	"milk": Color(0.95, 0.95, 0.92, 0.75),
	"coffee_mix": Color(0.25, 0.13, 0.05, 0.85),
	"coffee_powder": Color(0.20, 0.11, 0.05, 0.95),
}

var _spills: Array[Node] = []
var _cleanup_latched := false
var _cleanup_peak_ml := 300.0


func _ready():
	add_to_group("spill_manager")


## Создать типизированную лужу (§11 миссии).
## liquid_type: "water" | "milk" | "coffee_mix" | "coffee_powder"
## amount_ml — объём (влияет на радиус; 0 = разовая капля потока)
func spawn_spill_typed(position: Vector3, liquid_type: String, amount_ml: float = 0.0) -> void:
	var color: Color = TYPE_COLORS.get(liquid_type, TYPE_COLORS["water"])
	# Порошок — рассыпчатое пятно, не растекается
	var grow: float = 0.02 if liquid_type == "coffee_powder" else (0.015 + amount_ml * 0.0004)
	_spawn_or_merge(position, color, grow, liquid_type, maxf(amount_ml, 0.5))


## Обратная совместимость (старый API — цвет).
func spawn_spill(position: Vector3, color: Color) -> void:
	_spawn_or_merge(position, color, 0.015, "water", 0.5)


func _spawn_or_merge(position: Vector3, color: Color, grow_amount: float, liquid_type: String, amount_ml: float) -> void:
	# Поднимаем чуть над поверхностью — без z-fighting (§11 миссии)
	var spawn_pos: Vector3 = position + Vector3(0, 0.004, 0)

	# Проверка на объединение с ближайшей лужей
	var nearest: Node = null
	var nearest_dist: float = merge_radius
	for spill in _spills:
		if not is_instance_valid(spill):
			continue
		# Вода, молоко и кофейная смесь сохраняют собственный визуальный тип:
		# близкие пятна разных жидкостей не должны перекрашивать друг друга.
		if String(spill.get("liquid_type")) != liquid_type:
			continue
		var dist: float = spill.global_position.distance_to(spawn_pos)
		if dist < nearest_dist:
			nearest = spill
			nearest_dist = dist

	if nearest:
		nearest.call("add_volume", amount_ml)
		_emit_state()
		return

	# Пул: удаляем самую старую при переполнении (§23 миссии)
	_cleanup_invalid()
	if _spills.size() >= max_spills:
		var oldest: Node = _spills.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var cluster := SpillCluster.new()
	cluster.liquid_color = color
	cluster.liquid_type = liquid_type
	cluster.radius = clampf(0.04 + grow_amount, 0.04, 0.25)
	cluster.volume_ml = amount_ml
	cluster.initial_volume_ml = amount_ml
	# Добавляем в корень сцены, чтобы лужа не зависела от источника
	var scene := get_tree().current_scene
	if scene:
		scene.add_child(cluster)
	else:
		add_child(cluster)
	cluster.global_position = spawn_pos
	_spills.append(cluster)
	cluster.call("_update_radius_from_volume")
	_emit_state()


func _cleanup_invalid() -> void:
	for i in range(_spills.size() - 1, -1, -1):
		if not is_instance_valid(_spills[i]):
			_spills.remove_at(i)


## Общий объём всех луж (для статистики/уборки §12).
func get_total_spill_count() -> int:
	_cleanup_invalid()
	return _spills.size()

func get_volume_by_type(liquid_type: String) -> float:
	_cleanup_invalid()
	var total := 0.0
	for spill in _spills:
		if String(spill.get("liquid_type")) == liquid_type:
			total += float(spill.get("volume_ml"))
	return total

func get_required_cleanup_state() -> Dictionary:
	var water := get_volume_by_type("water")
	var milk := get_volume_by_type("milk")
	var coffee := get_volume_by_type("coffee_mix")
	var total := water + milk + coffee
	var major := water >= 80.0 or milk >= 30.0 or coffee >= 20.0
	_cleanup_peak_ml = maxf(maxf(_cleanup_peak_ml, total), 300.0)
	if major:
		_cleanup_latched = true
	elif total <= 1.0:
		_cleanup_latched = false
	var contamination := clampf(total / _cleanup_peak_ml * 100.0, 0.0, 100.0)
	if total <= 1.0:
		_cleanup_peak_ml = 300.0
	return {
		"required": _cleanup_latched,
		"water_ml": water,
		"milk_ml": milk,
		"coffee_mix_ml": coffee,
		"total_ml": total,
		"peak_ml": _cleanup_peak_ml,
		"contamination_percent": contamination,
		"cleanliness_percent": 100.0 - contamination,
	}

func has_required_cleanup() -> bool:
	return bool(get_required_cleanup_state().get("required", false))

## Найти пятно, на которое направлены руки игрока. Поиск работает по уже
## зарегистрированным SpillCluster и не зависит от центрального физического raycast.
func find_cleanup_target(origin: Vector3, direction: Vector3, max_distance: float = 2.8, max_lateral: float = 0.52) -> SpillCluster:
	_cleanup_invalid()
	var dir := direction.normalized()
	var best: SpillCluster = null
	var best_score := INF
	for node in _spills:
		if not node is SpillCluster:
			continue
		var spill := node as SpillCluster
		if spill.liquid_type == "coffee_powder" or spill.is_empty():
			continue
		var offset := spill.global_position - origin
		var along := offset.dot(dir)
		if along < 0.15 or along > max_distance:
			continue
		var closest := origin + dir * along
		var lateral := closest.distance_to(spill.global_position)
		var allowed := max_lateral + spill.radius
		if lateral > allowed:
			continue
		var score := along + lateral * 1.8
		if score < best_score:
			best = spill
			best_score = score
	return best

func find_nearest_cleanable(position: Vector3, max_distance: float = 1.45) -> SpillCluster:
	_cleanup_invalid()
	var best: SpillCluster = null
	var best_distance := max_distance
	for node in _spills:
		if not node is SpillCluster:
			continue
		var spill := node as SpillCluster
		if spill.liquid_type == "coffee_powder" or spill.is_empty():
			continue
		var flat_distance := Vector2(
			spill.global_position.x - position.x,
			spill.global_position.z - position.z
		).length()
		if flat_distance <= best_distance:
			best = spill
			best_distance = flat_distance
	return best

func absorb_cluster(cluster: SpillCluster, amount_ml: float) -> float:
	if cluster == null or not is_instance_valid(cluster):
		return 0.0
	var liquid_type := cluster.liquid_type
	var absorbed := cluster.absorb_ml(amount_ml)
	if absorbed <= 0.0:
		return 0.0
	spill_cleaned.emit(liquid_type, absorbed)
	if cluster.is_empty():
		_spills.erase(cluster)
		cluster.queue_free()
	_emit_state()
	return absorbed

func has_major_spill_near_segment(from: Vector3, to: Vector3, clearance: float = 0.48) -> bool:
	if not has_required_cleanup():
		return false
	var segment := to - from
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return false
	for node in _spills:
		if not node is SpillCluster:
			continue
		var spill := node as SpillCluster
		if spill.liquid_type == "coffee_powder" or spill.is_empty():
			continue
		var t := clampf((spill.global_position - from).dot(segment) / length_sq, 0.0, 1.0)
		var closest := from + segment * t
		if closest.distance_to(spill.global_position) <= clearance + spill.radius:
			return true
	return false


## Убрать ближайшую лужу (для полотенца §12). Возвращает радиус убранной.
func absorb_nearest(position: Vector3, max_dist: float) -> float:
	_cleanup_invalid()
	var nearest: Node = null
	var nearest_dist: float = max_dist
	for spill in _spills:
		var dist: float = spill.global_position.distance_to(position)
		if dist < nearest_dist:
			nearest = spill
			nearest_dist = dist
	if nearest == null:
		return 0.0
	var absorbed: float = absorb_cluster(nearest as SpillCluster, float(nearest.get("volume_ml")))
	return absorbed

func _emit_state() -> void:
	var state := get_required_cleanup_state()
	spills_changed.emit(state)
	QuestManager.set_spill_cleanup_required(bool(state.get("required", false)), state)
