class_name CatBodyController
extends Node

signal body_state_changed(state: BodyState)

enum BodyState {
    STAND,
    WALK,
    TROT,
    SIT,
    LIE,
    SLEEP,
    GROOM,
    JUMP,
    PAW,
    EAT,
    DRINK,
    STARTLED,
}

var state := BodyState.STAND

func set_state(next_state: BodyState) -> void:
    if state == next_state:
        return
    state = next_state
    body_state_changed.emit(state)

func get_state_name() -> String:
    return BodyState.keys()[state]

