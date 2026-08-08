class_name CatRelationshipMemory
extends Node

signal relationship_changed(state: Dictionary)

var trust := 28.0
var interest := 48.0
var wariness := 18.0
var play_history := 0
var feeding_history := 0
var petting_history := 0
var feed_uses := 0

const MAX_FEED_USES := 3

func pet() -> bool:
    if wariness > 68.0:
        return false
    petting_history += 1
    trust = minf(100.0, trust + 7.0)
    wariness = maxf(0.0, wariness - 10.0)
    _emit()
    return true

func feed() -> bool:
    if feed_uses >= MAX_FEED_USES:
        return false
    feed_uses += 1
    feeding_history += 1
    trust = minf(100.0, trust + 14.0)
    interest = minf(100.0, interest + 8.0)
    wariness = maxf(0.0, wariness - 15.0)
    _emit()
    return true

func play() -> void:
    play_history += 1
    trust = minf(100.0, trust + 9.0)
    interest = maxf(12.0, interest - 18.0)
    wariness = maxf(0.0, wariness - 8.0)
    _emit()

func frighten(amount := 16.0) -> void:
    wariness = minf(100.0, wariness + amount)
    trust = maxf(0.0, trust - amount * 0.35)
    _emit()

func successful_prevention() -> void:
    trust = minf(100.0, trust + 4.0)
    interest = maxf(8.0, interest - 10.0)
    _emit()

func helpful_probability() -> float:
    return clampf(0.14 + trust / 500.0 + float(feeding_history + play_history) * 0.025, 0.14, 0.42)

func get_state() -> Dictionary:
    return {
        "trust": trust,
        "interest": interest,
        "wariness": wariness,
        "play_history": play_history,
        "feeding_history": feeding_history,
        "petting_history": petting_history,
        "feed_uses": feed_uses,
    }

func load_state(saved: Dictionary) -> void:
    trust = clampf(float(saved.get("trust", trust)), 0.0, 100.0)
    interest = clampf(float(saved.get("interest", interest)), 0.0, 100.0)
    wariness = clampf(float(saved.get("wariness", wariness)), 0.0, 100.0)
    play_history = maxi(0, int(saved.get("play_history", play_history)))
    feeding_history = maxi(0, int(saved.get("feeding_history", feeding_history)))
    petting_history = maxi(0, int(saved.get("petting_history", petting_history)))
    feed_uses = clampi(int(saved.get("feed_uses", feed_uses)), 0, MAX_FEED_USES)
    _emit()

func _emit() -> void:
    relationship_changed.emit(get_state())
