class_name CatStuckRecovery
extends Node

var cat: Node
var last_position := Vector3.ZERO
var still_time := 0.0

func setup(host: Node) -> void:
	cat = host
	last_position = cat.global_position

func sample(delta: float, wants_motion: bool) -> void:
	if cat == null or not wants_motion:
		still_time = 0.0
		return
	if cat.global_position.distance_to(last_position) < 0.025:
		still_time += delta
	else:
		still_time = 0.0
	last_position = cat.global_position
	if still_time >= 3.0:
		cat.call("rebuild_route")
		still_time = 0.0
