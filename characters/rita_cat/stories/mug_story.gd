class_name CatMugStory
extends CatStory

var mug: RigidBody3D
var contents: MugContentController
var sip_done := false

func _init() -> void:
	story_id = &"MUG_STORY"
	category = &"COFFEE_EVENT"

func can_start(next_context: Dictionary) -> bool:
	mug = next_context.get("objects", {}).get("mug") as RigidBody3D
	contents = mug.get_node_or_null("MugContentController") as MugContentController if is_instance_valid(mug) else null
	return is_instance_valid(mug) and not bool(mug.get("held")) and contents != null and contents.milk_ml >= 12.0

func get_target() -> Node3D:
	return mug

func begin_development() -> void:
	cat.call("set_body_state", CatBodyController.BodyState.DRINK)
	cat.call("set_intention", CatIntentionController.Intention.INVESTIGATE)

func advance_development(_delta: float) -> void:
	if not is_instance_valid(mug) or bool(mug.get("held")):
		resolve(&"interrupted")
		return
	if not sip_done and phase_time >= 1.4:
		sip_done = true
		contents.call("drink_sip", 8.0)
	if phase_time >= 5.5:
		resolve(&"tiny_sip")

