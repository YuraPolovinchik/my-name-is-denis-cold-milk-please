extends "res://scripts/interactions/interactable.gd"

@export var hide_position := Vector3.ZERO
@export var exit_position := Vector3.ZERO
@export var hide_yaw_degrees := 180.0

func _ready() -> void:
    add_to_group("hide_spot")

func get_prompt(actor) -> String:
    if actor != null and bool(actor.get("is_hidden")):
        return "ВЫЙТИ ИЗ УКРЫТИЯ"
    return "СПРЯТАТЬСЯ В ГАРДЕРОБНОЙ"

func perform_interaction(actor, _mode: int) -> String:
    if actor == null or not actor.has_method("enter_hide_spot"):
        return "ЗДЕСЬ НЕЛЬЗЯ СПРЯТАТЬСЯ"
    actor.call("enter_hide_spot", self, hide_position, exit_position, hide_yaw_degrees)
    return "ДЕНИС СПРЯТАЛСЯ. НЕ ШЕВЕЛИСЬ, ПОКА РИТА НЕ УСПОКОИТСЯ"
