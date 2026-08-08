class_name CatVacuumStory
extends CatStory

var vacuum: Node3D
var vacuum_was_processing := true

func _init() -> void:
	story_id = &"VACUUM_STORY"
	category = &"HOUSEHOLD_EVENT"

func can_start(next_context: Dictionary) -> bool:
	vacuum = next_context.get("objects", {}).get("vacuum") as Node3D
	return is_instance_valid(vacuum) and bool(vacuum.get("active"))

func get_target() -> Node3D:
	return vacuum

func begin_development() -> void:
	vacuum_was_processing = vacuum.is_physics_processing()
	vacuum.set_physics_process(false)
	cat.call("set_body_state", CatBodyController.BodyState.PAW)
	cat.call("set_intention", CatIntentionController.Intention.INTERFERE)

func advance_development(_delta: float) -> void:
	if not is_instance_valid(vacuum):
		abort_safely(&"vacuum_lost")
	elif phase_time >= 2.8:
		vacuum.set_physics_process(vacuum_was_processing)
		cat.call("set_body_state", CatBodyController.BodyState.STARTLED)
		cat.call("set_intention", CatIntentionController.Intention.REACT_TO_DANGER)
		resolve(&"startled")

func cleanup() -> void:
	if is_instance_valid(vacuum):
		vacuum.set_physics_process(vacuum_was_processing)

