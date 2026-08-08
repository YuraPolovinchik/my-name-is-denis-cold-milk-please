class_name CatRitaDoorStory
extends CatStory

var door: Node3D
var next_meow := 1.0
var meow_count := 0

func _init() -> void:
	story_id = &"RITA_DOOR_STORY"
	category = &"HOUSEHOLD_EVENT"

func can_start(next_context: Dictionary) -> bool:
	door = next_context.get("objects", {}).get("bedroom_door") as Node3D
	return is_instance_valid(door) and RitaSleep.wake_level < 60.0

func get_target() -> Node3D:
	return door

func begin_development() -> void:
	cat.call("set_intention", CatIntentionController.Intention.SEEK_RITA)
	cat.call("set_body_state", CatBodyController.BodyState.SIT)
	QuestManager.set_bonus_objective(&"cat_rita_door", "БАТОН ПРОСИТСЯ К РИТЕ — УВЕДИ ЕГО ОТ ДВЕРИ")

func advance_development(_delta: float) -> void:
	if phase_time >= next_meow and meow_count < 3:
		meow_count += 1
		next_meow += 4.0
		cat.call("meow", 4.5)
	if phase_time >= 15.0:
		resolve(&"cat_gave_up")

func cleanup() -> void:
	QuestManager.clear_bonus_objective(&"cat_rita_door")
