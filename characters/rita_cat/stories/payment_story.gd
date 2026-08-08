class_name CatPaymentStory
extends CatStory

var room: Node3D
var old_status := ""

func _init() -> void:
	story_id = &"PAYMENT_ALTAR_STORY"
	category = &"OPTIONAL_EVENT"

func can_start(next_context: Dictionary) -> bool:
	room = next_context.get("objects", {}).get("payment_altar_room") as Node3D
	return is_instance_valid(room) and bool(room.get("_revealed"))

func get_target() -> Node3D:
	return room

func begin_development() -> void:
	cat.call("set_body_state", CatBodyController.BodyState.SIT)
	cat.call("set_intention", CatIntentionController.Intention.OBSERVE)
	var altar = room.get("altar")
	if altar != null:
		var status := altar.get("phone_status") as Label3D
		if status != null:
			old_status = status.text
			status.text = "КОТ В ОЧЕРЕДИ: 1\nОЖИДАНИЕ: 9 ЖИЗНЕЙ"

func advance_development(_delta: float) -> void:
	if phase_time >= 12.0:
		resolve(&"payment_observed")

func cleanup() -> void:
	if not is_instance_valid(room):
		return
	var altar = room.get("altar")
	if altar != null:
		var status := altar.get("phone_status") as Label3D
		if status != null:
			status.text = old_status
