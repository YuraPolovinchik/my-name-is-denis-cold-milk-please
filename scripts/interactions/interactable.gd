extends Node3D

enum InteractionMode { NORMAL, QUIET, FAST }

@export var display_name := "ПРЕДМЕТ"
@export var normal_noise := 8.0
@export var quiet_noise := 2.0
@export var fast_noise := 20.0
@export var normal_duration := 0.25
@export var quiet_duration := 1.0
@export var fast_duration := 0.05
@export var noise_category: StringName = &"OBJECT_IMPACT"
@export var source_id: StringName = &"interactable"

var busy = false

func get_prompt(_actor) -> String:
    return display_name

func interact(actor, mode: int) -> String:
    if busy:
        return "ПОДОЖДИ"
    busy = true
    var duration: float = _duration_for(mode)
    if duration > 0.01:
        await get_tree().create_timer(duration).timeout
    if not RunStats.run_active:
        busy = false
        return "ЗАБЕГ ЗАВЕРШЁН"
    if actor != null and not is_instance_valid(actor):
        busy = false
        return "ДЕЙСТВИЕ ПРЕРВАНО"
    var result: String = perform_interaction(actor, mode)
    var noise: float = _noise_for(mode)
    if noise > 0.01:
        NoiseManager.emit_noise(global_position, noise, noise_category, source_id)
    busy = false
    return result

func perform_interaction(_actor, _mode: int) -> String:
    return display_name

func _noise_for(mode: int) -> float:
    match mode:
        InteractionMode.QUIET:
            return quiet_noise
        InteractionMode.FAST:
            return fast_noise
        _:
            return normal_noise

func _duration_for(mode: int) -> float:
    match mode:
        InteractionMode.QUIET:
            return quiet_duration
        InteractionMode.FAST:
            return fast_duration
        _:
            return normal_duration
