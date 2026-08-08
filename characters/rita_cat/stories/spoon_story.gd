class_name CatSpoonStory
extends CatStory

const SAFE_HIDES := [
	Vector3(-5.55, 0.76, -4.62), Vector3(-6.35, 0.13, 0.80),
	Vector3(-3.25, 0.13, -0.75), Vector3(2.52, 0.13, 2.65),
]
var spoon: RigidBody3D
var clue_played := false
var safety_revealed := false

func _init() -> void:
	story_id = &"SPOON_STORY"
	category = &"COFFEE_EVENT"

func can_start(next_context: Dictionary) -> bool:
	spoon = next_context.get("objects", {}).get("spoon") as RigidBody3D
	var mug := next_context.get("objects", {}).get("mug") as Node
	var mug_contents := mug.get_node_or_null("MugContentController") if mug != null else null
	return is_instance_valid(spoon) and not bool(spoon.get("held")) and (mug_contents == null or not bool(mug_contents.get("is_stirred")))

func get_target() -> Node3D:
	return spoon

func begin_development() -> void:
	if not is_instance_valid(spoon) or bool(spoon.get("held")):
		abort_safely(&"spoon_unavailable")
		return
	cat.call("set_intention", CatIntentionController.Intention.INTERFERE)
	cat.call("set_body_state", CatBodyController.BodyState.PAW)
	var hide_position: Vector3 = SAFE_HIDES[randi_range(0, SAFE_HIDES.size() - 1)]
	spoon.freeze = true
	spoon.linear_velocity = Vector3.ZERO
	spoon.angular_velocity = Vector3.ZERO
	spoon.global_position = hide_position
	QuestManager.set_bonus_objective(&"cat_spoon", "БАТОН УТАЩИЛ ЛОЖКУ — ЗАБЕРИ ЕЁ ИЗ УКРЫТИЯ")

func advance_development(_delta: float) -> void:
	if not is_instance_valid(spoon):
		abort_safely(&"spoon_lost")
	elif bool(spoon.get("held")):
		resolve(&"recovered")
	elif phase_time >= 48.0:
		resolve(&"recovered_by_safety")
	elif phase_time >= 36.0 and not safety_revealed:
		safety_revealed = true
		spoon.global_position = Vector3(-3.25, 0.16, -0.75)
		QuestManager.notification_requested.emit("ЛОЖКА БЛЕСТИТ У СТЕНЫ В КОРИДОРЕ")
	elif phase_time >= 22.0 and not clue_played:
		clue_played = true
		AudioManager.play_3d(&"clink", spoon.global_position, -8.0, 1.15)

func cleanup() -> void:
	QuestManager.clear_bonus_objective(&"cat_spoon")
	if is_instance_valid(spoon) and not bool(spoon.get("held")):
		spoon.freeze = true
		spoon.sleeping = true
