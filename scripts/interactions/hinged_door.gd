extends "res://scripts/interactions/interactable.gd"

@export var door_id: StringName = &"door"
@export var open_angle_degrees := 92.0
@export var closed_angle_degrees := 0.0
@export var starts_open := false
@export_enum("y", "x", "z") var motion_axis: String = "y"

var is_open = false
var oiled = false
var _closed_rotation := Vector3.ZERO
var _motion_tween: Tween = null

func _ready() -> void:
    add_to_group("door")
    add_to_group("cabinet_moving_part")
    _closed_rotation = rotation
    is_open = starts_open
    rotation = _rotation_for_state(is_open)
    NoiseManager.set_door_open(door_id, is_open)

func get_prompt(_actor) -> String:
    return "%s — %s" % [display_name, "ЗАКРЫТЬ" if is_open else "ОТКРЫТЬ"]

func perform_interaction(actor, mode: int) -> String:
    var freshly_oiled := false
    if not oiled and actor != null and actor.has_method("has_hinge_oil") and bool(actor.call("has_hinge_oil")):
        oiled = true
        freshly_oiled = true
    is_open = not is_open
    if _motion_tween != null and _motion_tween.is_valid():
        _motion_tween.kill()
    var duration := 0.42
    if mode == InteractionMode.QUIET:
        duration = 0.78
    elif mode == InteractionMode.FAST:
        duration = 0.24
    _motion_tween = create_tween()
    _motion_tween.set_trans(Tween.TRANS_QUART if is_open else Tween.TRANS_CUBIC)
    _motion_tween.set_ease(Tween.EASE_OUT if is_open else Tween.EASE_IN_OUT)
    _motion_tween.tween_property(self, "rotation", _rotation_for_state(is_open), duration)
    NoiseManager.set_door_open(door_id, is_open)
    AudioManager.play_3d(&"door", global_position, -12.0 if mode == InteractionMode.QUIET else -7.0, 0.9 if is_open else 1.05)
    var result := "ДВЕРЬ %s" % ("ОТКРЫТА" if is_open else "ЗАКРЫТА")
    if freshly_oiled:
        result += "  •  ПЕТЛИ СМАЗАНЫ"
    return result

func _rotation_for_state(opened: bool) -> Vector3:
    var result := _closed_rotation
    var angle := deg_to_rad(closed_angle_degrees + (open_angle_degrees if opened else 0.0))
    match motion_axis:
        "x":
            result.x += angle
        "z":
            result.z += angle
        _:
            result.y += angle
    return result

func _noise_for(mode: int) -> float:
    var base_noise: float = super._noise_for(mode)
    var result: float = base_noise * 0.38 if oiled else base_noise
    RunStats.record_noise_prevented(base_noise - result)
    return result
