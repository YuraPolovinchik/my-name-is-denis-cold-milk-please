class_name CatPhoneStory
extends CatStory

var phone: RigidBody3D
var moved := false

func _init() -> void:
	story_id = &"PHONE_STORY"
	category = &"WORK_EVENT"

func can_start(next_context: Dictionary) -> bool:
	phone = next_context.get("objects", {}).get("phone") as RigidBody3D
	return is_instance_valid(phone) and bool(phone.get("active")) and not bool(phone.get("held"))

func get_target() -> Node3D:
	return phone

func begin_development() -> void:
	cat.call("set_body_state", CatBodyController.BodyState.PAW)
	cat.call("set_intention", CatIntentionController.Intention.HELP if randf() < 0.35 else CatIntentionController.Intention.INTERFERE)
	if not bool(phone.get("held")):
		phone.freeze = true
		phone.global_position += Vector3(0.12, 0.0, 0.08)
		moved = true

func advance_development(_delta: float) -> void:
	if not is_instance_valid(phone) or not bool(phone.get("active")) or bool(phone.get("held")):
		resolve(&"phone_found")
	elif phase_time >= 10.0:
		resolve(&"cat_waited")

