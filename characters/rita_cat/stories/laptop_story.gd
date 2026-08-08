class_name CatLaptopStory
extends CatStory

var laptop: Node3D

func _init() -> void:
	story_id = &"LAPTOP_STORY"
	category = &"WORK_EVENT"

func can_start(next_context: Dictionary) -> bool:
	laptop = next_context.get("objects", {}).get("laptop") as Node3D
	return is_instance_valid(laptop) and not CallManager.question_active and not bool(laptop.get_meta("cat_blocked", false))

func get_target() -> Node3D:
	return laptop

func begin_development() -> void:
	laptop.set_meta("cat_blocked", true)
	cat.call("controlled_jump_to", laptop.global_position + Vector3(0.0, 0.10, 0.0))
	cat.call("set_intention", CatIntentionController.Intention.INTERFERE)
	QuestManager.set_bonus_objective(&"cat_laptop", "БАТОН ЛЁГ НА НОУТБУК — ПОГЛАДЬ ИЛИ ОТВЛЕКИ ЕГО")

func advance_development(_delta: float) -> void:
	if not is_instance_valid(laptop):
		abort_safely(&"laptop_lost")
	elif phase_time >= 18.0 or CallManager.question_active:
		resolve(&"cat_left")

func cleanup() -> void:
	QuestManager.clear_bonus_objective(&"cat_laptop")
	if is_instance_valid(laptop):
		laptop.remove_meta("cat_blocked")
