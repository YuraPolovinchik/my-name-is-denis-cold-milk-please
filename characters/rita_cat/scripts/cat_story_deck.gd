class_name CatStoryDeck
extends Node

const CATEGORIES := {
    &"COFFEE_EVENT": [&"SPOON_STORY", &"MUG_STORY"],
    &"WORK_EVENT": [&"LAPTOP_STORY", &"PHONE_STORY"],
    &"HOUSEHOLD_EVENT": [&"VACUUM_STORY", &"RITA_DOOR_STORY"],
    &"OPTIONAL_EVENT": [&"COURIER_BOX_STORY", &"PAYMENT_ALTAR_STORY"],
}

var selected_stories: Array[StringName] = []
var completed_cat_stories: Array[StringName] = []
var seed_value := 0

func build_deck(forced_seed := 0, forced_count := 0) -> Array[StringName]:
    seed_value = forced_seed if forced_seed != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var category_names: Array = CATEGORIES.keys()
    for index in range(category_names.size() - 1, 0, -1):
        var swap_index := rng.randi_range(0, index)
        var held_category = category_names[index]
        category_names[index] = category_names[swap_index]
        category_names[swap_index] = held_category
    var count := clampi(forced_count if forced_count > 0 else rng.randi_range(2, 4), 2, 4)
    selected_stories.clear()
    for category in category_names:
        if selected_stories.size() >= count:
            break
        var alternatives: Array = CATEGORIES[category]
        selected_stories.append(alternatives[rng.randi_range(0, alternatives.size() - 1)])
    return selected_stories.duplicate()

func mark_completed(story_id: StringName) -> void:
    if story_id not in completed_cat_stories:
        completed_cat_stories.append(story_id)

func is_available(story_id: StringName) -> bool:
    return story_id in selected_stories and story_id not in completed_cat_stories

func remaining() -> Array[StringName]:
    var result: Array[StringName] = []
    for story_id in selected_stories:
        if story_id not in completed_cat_stories:
            result.append(story_id)
    return result

func get_state() -> Dictionary:
    return {
        "seed": seed_value,
        "selected": selected_stories.duplicate(),
        "completed": completed_cat_stories.duplicate(),
    }

func load_state(saved: Dictionary) -> void:
    seed_value = int(saved.get("seed", seed_value))
    selected_stories.assign(saved.get("selected", []))
    completed_cat_stories.assign(saved.get("completed", []))
