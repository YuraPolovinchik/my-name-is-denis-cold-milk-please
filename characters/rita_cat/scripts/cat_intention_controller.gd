class_name CatIntentionController
extends Node

signal intention_changed(intention: Intention)

enum Intention {
    REST,
    OBSERVE,
    INVESTIGATE,
    FOLLOW,
    PLAY,
    HELP,
    INTERFERE,
    HIDE,
    SEEK_RITA,
    REACT_TO_DANGER,
}

var intention := Intention.REST

func set_intention(next_intention: Intention) -> void:
    if intention == next_intention:
        return
    intention = next_intention
    intention_changed.emit(intention)

func get_intention_name() -> String:
    return Intention.keys()[intention]

