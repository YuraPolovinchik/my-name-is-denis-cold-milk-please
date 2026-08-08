class_name SpillCleanupController
extends Node

var player: CharacterBody3D
var target: SpillCluster
var cleaning := false
var _sound_timer := 0.0
var cleaned_session_ml := 0.0
var scrub_phase := 0.0

func bind_player(value: CharacterBody3D) -> void:
	player = value

func has_target() -> bool:
	return target != null and is_instance_valid(target)

func start_cleaning() -> void:
	cleaning = has_target() and _get_absorption_controller() != null
	if cleaning:
		cleaned_session_ml = 0.0

func stop_cleaning() -> void:
	cleaning = false

func get_prompt() -> String:
	var absorption := _get_absorption_controller()
	if absorption == null:
		return ""
	if absorption.remaining_capacity_ml() <= 0.1:
		return "ШВАБРА НАБРАЛА ВОДУ  •  ЛКМ — ПОЛОЖИТЬ"
	if has_target():
		var manager := get_tree().get_first_node_in_group("spill_manager") as SpillManager
		var cleanliness := 100.0
		if manager != null:
			cleanliness = float(manager.get_required_cleanup_state().get("cleanliness_percent", 100.0))
		return "УДЕРЖИВАЙ E И ВОДИ ШВАБРОЙ • ЛУЖА %.0f МЛ • ЧИСТОТА %d%%" % [target.volume_ml, roundi(cleanliness)]
	return "НАВЕДИ ШВАБРУ НА ЛУЖУ  •  ЛКМ — ПОЛОЖИТЬ"

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		target = null
		cleaning = false
		return
	var absorption := _get_absorption_controller()
	var camera := player.get("camera") as Camera3D
	var manager := get_tree().get_first_node_in_group("spill_manager") as SpillManager
	if absorption == null or camera == null or manager == null:
		target = null
		cleaning = false
		return
	target = manager.find_cleanup_target(
		camera.global_position,
		-camera.global_transform.basis.z,
		2.8,
		0.48
	)
	if target == null:
		target = manager.find_nearest_cleanable(player.global_position, 1.45)
	if not cleaning or not has_target():
		if not has_target():
			cleaning = false
		return
	var held_mop := player.get("held_item") as RigidBody3D
	if held_mop != null:
		held_mop.global_position = held_mop.global_position.lerp(get_scrub_world_position(), minf(1.0, delta * 16.0))
	scrub_phase += delta * 11.0
	var rate := 118.0
	if target.liquid_type == "milk":
		rate = 74.0
	elif target.liquid_type == "coffee_mix":
		rate = 86.0
	var requested := rate * delta
	var absorbed := absorption.absorb(target.liquid_type, requested)
	manager.absorb_cluster(target, absorbed)
	cleaned_session_ml += absorbed
	_sound_timer -= delta
	if absorbed > 0.0 and _sound_timer <= 0.0:
		_sound_timer = 0.46
		AudioManager.play_3d(&"cloth_step", target.global_position, -20.0, 0.72)
		NoiseManager.emit_noise(target.global_position, 1.4, &"CLEANUP", &"bathroom_mop")

func get_scrub_world_position() -> Vector3:
	if not has_target():
		return Vector3.ZERO
	var side := Vector3(cos(scrub_phase), 0.0, sin(scrub_phase * 0.47)).normalized()
	return target.global_position + side * minf(0.16, target.radius * 0.62) + Vector3.UP * 0.035

func _get_absorption_controller() -> AbsorptionController:
	if player == null:
		return null
	var held := player.get("held_item") as RigidBody3D
	if held == null or not is_instance_valid(held) or StringName(held.get("item_id")) != &"mop":
		cleaning = false
		return null
	return held.get_node_or_null("AbsorptionController") as AbsorptionController
