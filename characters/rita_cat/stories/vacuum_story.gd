class_name CatVacuumStory
extends CatStory

var vacuum: Node3D
var next_yowl := 0.0
var next_route_change := 0.0
var quiet_time := 0.0

const TRIGGER_DISTANCE := 2.35
const TELEGRAPH_TIME := 2.2
const PANIC_SAFETY_TIMEOUT := 24.0

func _init() -> void:
	story_id = &"VACUUM_STORY"
	category = &"HOUSEHOLD_EVENT"

func can_start(next_context: Dictionary) -> bool:
	vacuum = next_context.get("objects", {}).get("vacuum") as Node3D
	var host := cat as Node3D
	if host == null:
		host = next_context.get("objects", {}).get("rita_cat") as Node3D
	if host == null or not is_instance_valid(vacuum) or not bool(vacuum.get("active")):
		return false
	var flat_distance := Vector2(
		vacuum.global_position.x - host.global_position.x,
		vacuum.global_position.z - host.global_position.z
	).length()
	return flat_distance <= TRIGGER_DISTANCE

func get_target() -> Node3D:
	return vacuum

func start(host: Node, next_context: Dictionary) -> void:
	cat = host
	context = next_context
	vacuum = next_context.get("objects", {}).get("vacuum") as Node3D
	target = vacuum
	phase = Phase.TELEGRAPH
	phase_time = 0.0
	telegraph_seconds = TELEGRAPH_TIME
	cat.call("set_intention", CatIntentionController.Intention.REACT_TO_DANGER)
	cat.call("set_body_state", CatBodyController.BodyState.STARTLED)
	cat.call("face_world_point", vacuum.global_position)
	cat.call("meow", 5.0)
	QuestManager.notification_requested.emit("КОТ ЗАМЕТИЛ ПЫЛЕСОС • УСПОКОЙ ЕГО, ПОКА НЕ НАЧАЛАСЬ ПАНИКА")

func begin_development() -> void:
	next_yowl = 0.0
	next_route_change = 0.0
	quiet_time = 0.0
	var memory := cat.get("relationship_memory") as CatRelationshipMemory
	if memory != null:
		memory.frighten(12.0)
	cat.call("begin_vacuum_panic", vacuum)
	cat.call("panic_yowl", 10.0)
	QuestManager.notification_requested.emit("КОТ В ПАНИКЕ • ПОГЛАДЬ, ДАЙ КОРМ ИЛИ ИГРУШКУ")

func advance_development(delta: float) -> void:
	if not is_instance_valid(vacuum):
		abort_safely(&"vacuum_lost")
		return
	next_yowl -= delta
	next_route_change -= delta
	if next_yowl <= 0.0:
		next_yowl = randf_range(0.85, 1.35)
		cat.call("panic_yowl", randf_range(8.0, 11.0))
	if next_route_change <= 0.0:
		next_route_change = randf_range(1.35, 2.15)
		cat.call("continue_vacuum_panic", vacuum)
	if not bool(vacuum.get("active")):
		quiet_time += delta
		if quiet_time >= 2.0 and quiet_time - delta < 2.0:
			QuestManager.notification_requested.emit("ПЫЛЕСОС ЗАМОЛК, НО КОТА ЕЩЁ ТРЯСЁТ • УСПОКОЙ ЕГО")
	else:
		quiet_time = 0.0
	if phase_time >= PANIC_SAFETY_TIMEOUT:
		QuestManager.notification_requested.emit("КОТ САМ СПРЯТАЛСЯ ПОДАЛЬШЕ ОТ ПЫЛЕСОСА")
		resolve(&"escaped")

func cleanup() -> void:
	if cat != null:
		cat.call("finish_vacuum_panic")
