class_name CatCourierBoxStory
extends CatStory

var box: Node3D

func _init() -> void:
	story_id = &"COURIER_BOX_STORY"
	category = &"OPTIONAL_EVENT"

func can_start(next_context: Dictionary) -> bool:
	box = next_context.get("objects", {}).get("cat_box") as Node3D
	return is_instance_valid(box) and (QuestManager.has_milk or bool(CoffeeDelivery.get_state().get("collected", false)))

func get_target() -> Node3D:
	return box

func begin_development() -> void:
	cat.call("controlled_jump_to", box.global_position + Vector3(0.0, 0.10, 0.0))
	cat.call("set_intention", CatIntentionController.Intention.REST)
	cat.call("set_body_state", CatBodyController.BodyState.LIE)

func advance_development(_delta: float) -> void:
	if phase_time >= 18.0:
		resolve(&"box_nap")
