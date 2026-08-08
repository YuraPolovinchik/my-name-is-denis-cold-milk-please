extends "res://scripts/interactions/interactable.gd"

@export var open_distance := 0.75
var is_open = false
var _closed_position = Vector3.ZERO
var _motion_tween: Tween = null

func _ready() -> void:
    add_to_group("drawer")
    add_to_group("cabinet_moving_part")
    _closed_position = position

func get_prompt(_actor) -> String:
    return "%s — %s" % [display_name, "ЗАКРЫТЬ" if is_open else "ОТКРЫТЬ"]

func perform_interaction(_actor, mode: int) -> String:
    is_open = not is_open
    if _motion_tween != null and _motion_tween.is_valid():
        _motion_tween.kill()
    var target: Vector3 = _closed_position + transform.basis.z.normalized() * (open_distance if is_open else 0.0)
    var duration := 0.36
    if mode == InteractionMode.QUIET:
        duration = 0.68
    elif mode == InteractionMode.FAST:
        duration = 0.22
    _motion_tween = create_tween()
    _motion_tween.set_trans(Tween.TRANS_QUART if is_open else Tween.TRANS_CUBIC)
    _motion_tween.set_ease(Tween.EASE_OUT if is_open else Tween.EASE_IN_OUT)
    _motion_tween.tween_property(self, "position", target, duration)
    AudioManager.play_3d(&"drawer", global_position, -13.0 if mode == InteractionMode.QUIET else -8.0, 1.05 if is_open else 0.92)
    return "ЯЩИК %s" % ("ОТКРЫТ" if is_open else "ЗАКРЫТ")
