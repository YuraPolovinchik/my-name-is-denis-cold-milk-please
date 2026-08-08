class_name CatChaosObserver
extends Node

signal chaos_changed(value: int, reasons: PackedStringArray)

var chaos_budget := 0
var reasons := PackedStringArray()
var world_objects: Dictionary = {}
var story_active := false
var _sample_left := 0.0

func setup(objects: Dictionary) -> void:
    world_objects = objects
    RitaSleep.wake_changed.connect(_on_urgent_state_changed)
    CallManager.call_updated.connect(_on_call_updated)
    MilkDelivery.delivery_updated.connect(_on_delivery_updated)
    CoffeeDelivery.delivery_updated.connect(_on_delivery_updated)
    QuestManager.quest_updated.connect(_on_quest_updated)
    sample_now()

func _process(delta: float) -> void:
    _sample_left -= delta
    if _sample_left <= 0.0:
        _sample_left = 0.5
        sample_now()

func sample_now() -> int:
    var next_value := 0
    var next_reasons := PackedStringArray()
    var phone := world_objects.get("phone") as Node
    if phone != null and bool(phone.get("active")):
        next_value += 2
        next_reasons.append("phone")
    if CallManager.question_active:
        next_value += 3
        next_reasons.append("work_question")
    if bool(MilkDelivery.get_state().get("at_door", false)) or bool(CoffeeDelivery.get_state().get("at_door", false)):
        next_value += 2
        next_reasons.append("courier")
    var vacuum := world_objects.get("vacuum") as Node
    if vacuum != null and bool(vacuum.get("active")):
        next_value += 2
        next_reasons.append("vacuum")
    var washer := world_objects.get("washing_machine") as Node
    if washer != null and bool(washer.get("active")):
        next_value += 3
        next_reasons.append("washing_machine")
    if QuestManager.spill_cleanup_required:
        next_value += 3
        next_reasons.append("large_spill")
    var kettle := world_objects.get("kettle") as Node
    var kettle_state := kettle.get_node_or_null("KettleStateMachine") if kettle != null else null
    if kettle_state != null and int(kettle_state.get("state")) == 7:
        next_value += 2
        next_reasons.append("kettle_boiling_away")
    if RitaSleep.wake_level >= 74.0:
        next_value += 3
        next_reasons.append("rita_near_wake")
    if story_active:
        next_value += 2
        next_reasons.append("cat_story")
    if next_value != chaos_budget or next_reasons != reasons:
        chaos_budget = next_value
        reasons = next_reasons
        chaos_changed.emit(chaos_budget, reasons)
    return chaos_budget

func permits_story() -> bool:
    return sample_now() <= 2 and not CallManager.question_active and not QuestManager.spill_cleanup_required

func _on_urgent_state_changed(_value = null, _state = null) -> void:
    sample_now()

func _on_call_updated(_data: Dictionary) -> void:
    sample_now()

func _on_delivery_updated(_data: Dictionary) -> void:
    sample_now()

func _on_quest_updated(_data: Dictionary) -> void:
    sample_now()

