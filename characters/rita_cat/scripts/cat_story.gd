class_name CatStory
extends Node

signal completed(story_id: StringName, outcome: StringName)

enum Phase { IDLE, APPROACH, TELEGRAPH, DEVELOPMENT, FINISHED }

@export var story_id: StringName
@export var category: StringName
@export var telegraph_seconds := 4.0

var phase := Phase.IDLE
var cat: Node
var context: Dictionary = {}
var target: Node3D
var phase_time := 0.0
var outcome: StringName = &""

func can_start(_next_context: Dictionary) -> bool:
	return false

func start(host: Node, next_context: Dictionary) -> void:
	cat = host
	context = next_context
	target = get_target()
	phase = Phase.APPROACH
	phase_time = 0.0
	cat.call("set_intention", CatIntentionController.Intention.INVESTIGATE)
	cat.call("move_to_world", target.global_position if is_instance_valid(target) else cat.global_position)

func advance(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.APPROACH:
			if not is_instance_valid(target) or cat.call("at_target") or phase_time >= 12.0:
				phase = Phase.TELEGRAPH
				phase_time = 0.0
				telegraph()
		Phase.TELEGRAPH:
			if phase_time >= telegraph_seconds:
				phase = Phase.DEVELOPMENT
				phase_time = 0.0
				begin_development()
		Phase.DEVELOPMENT:
			advance_development(delta)

func telegraph() -> void:
	cat.call("set_body_state", CatBodyController.BodyState.SIT)
	cat.call("face_world_point", target.global_position if is_instance_valid(target) else cat.global_position)

func prevent(_reason: StringName = &"player") -> void:
	if phase != Phase.TELEGRAPH and phase != Phase.APPROACH:
		return
	var memory := cat.get("relationship_memory") as Node
	if memory != null:
		memory.call("successful_prevention")
	resolve(&"prevented")

func player_resolve(_reason: StringName = &"player") -> void:
	if phase == Phase.DEVELOPMENT:
		resolve(&"resolved")

func begin_development() -> void:
	pass

func advance_development(_delta: float) -> void:
	pass

func get_target() -> Node3D:
	return null

func resolve(next_outcome: StringName = &"resolved") -> void:
	if phase == Phase.FINISHED:
		return
	outcome = next_outcome
	cleanup()
	phase = Phase.FINISHED
	completed.emit(story_id, outcome)

func abort_safely(_reason: StringName = &"invalid") -> void:
	resolve(&"aborted")

func cleanup() -> void:
	pass

func is_active() -> bool:
	return phase != Phase.IDLE and phase != Phase.FINISHED
