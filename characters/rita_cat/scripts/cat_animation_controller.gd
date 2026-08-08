class_name CatAnimationController
extends Node

var animation_player: AnimationPlayer
var _animation_names: Array[StringName] = []
var _last_token := ""

const STATE_TOKENS := {
    CatBodyController.BodyState.STAND: ["idle", "stand"],
    CatBodyController.BodyState.WALK: ["walk"],
    CatBodyController.BodyState.TROT: ["run", "walk"],
    CatBodyController.BodyState.SIT: ["sit", "idle"],
    CatBodyController.BodyState.LIE: ["sleep", "idle"],
    CatBodyController.BodyState.SLEEP: ["sleep", "idle"],
    CatBodyController.BodyState.GROOM: ["scratch", "idle"],
    CatBodyController.BodyState.JUMP: ["jump", "run"],
    CatBodyController.BodyState.PAW: ["attack", "scratch", "idle"],
    CatBodyController.BodyState.EAT: ["eat", "idle"],
    CatBodyController.BodyState.DRINK: ["eat", "idle"],
    CatBodyController.BodyState.STARTLED: ["jump", "run"],
}

func setup(visual_root: Node) -> void:
    animation_player = visual_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if animation_player == null:
        return
    for library_name in animation_player.get_animation_library_list():
        var library := animation_player.get_animation_library(library_name)
        for animation_name in library.get_animation_list():
            _animation_names.append(StringName("%s/%s" % [String(library_name), String(animation_name)]) if not String(library_name).is_empty() else animation_name)
    play_body_state(CatBodyController.BodyState.STAND)

func play_body_state(state: CatBodyController.BodyState) -> void:
    var tokens: Array = STATE_TOKENS.get(state, ["idle"])
    var chosen := _find_animation(tokens)
    if chosen.is_empty() or chosen == _last_token or animation_player == null:
        return
    _last_token = chosen
    animation_player.play(chosen, 0.22)

func available_animations() -> PackedStringArray:
    var result := PackedStringArray()
    for animation_name in _animation_names:
        result.append(String(animation_name))
    return result

func _find_animation(tokens: Array) -> String:
    for token in tokens:
        for animation_name in _animation_names:
            if String(animation_name).to_lower().contains(String(token)):
                return String(animation_name)
    return String(_animation_names[0]) if not _animation_names.is_empty() else ""

