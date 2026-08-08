extends "res://scripts/interactions/hinged_door.gd"

signal secret_visibility_changed(opened: bool)

var discovered := false

func _ready() -> void:
    super._ready()
    add_to_group("payment_altar_door")

func get_prompt(_actor) -> String:
    if is_open:
        return "E — ЗАКРЫТЬ СТВОРКУ"
    return "E — ВОЙТИ В СВЯТИЛИЩЕ" if discovered else "E — ОТКРЫТЬ СТАРОЕ ЗЕРКАЛО"

func perform_interaction(actor, mode: int) -> String:
    var result := super.perform_interaction(actor, mode)
    if is_open and not discovered:
        discovered = true
        result = "ЗА ЗЕРКАЛОМ ОКАЗАЛАСЬ КОМНАТА  •  THE ПЛАТЕЖ ЖДАЛ"
    secret_visibility_changed.emit(is_open)
    return result

func force_open_for_capture() -> void:
    discovered = true
    is_open = true
    rotation = _rotation_for_state(true)
    NoiseManager.set_door_open(door_id, true)
    secret_visibility_changed.emit(true)

