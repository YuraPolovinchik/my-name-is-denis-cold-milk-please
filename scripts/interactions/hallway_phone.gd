class_name HallwayPhone
extends "res://scripts/interactions/physical_item.gd"

signal ringing_started(phone: HallwayPhone)
signal ringing_stopped(phone: HallwayPhone)

@export var activation_delay := 34.0
@export var activation_delay_min := 24.0
@export var activation_delay_max := 52.0
@export var pulse_interval := 1.7
@export var pulse_noise := 13.0
@export var reminder_delay := 18.0
@export var return_delay := 2.0
@export var rearm_delay_min := 48.0
@export var rearm_delay_max := 92.0

var armed := true
var active := false
var placement_anchor: Node3D
var placement_anchors: Array[Node3D] = []
var _placement_index := -1
var _elapsed := 0.0
var _pulse_elapsed := 0.0
var _active_elapsed := 0.0
var _return_elapsed := 0.0
var _rearm_left := 0.0
var _next_activation_delay := 34.0
var _reminder_shown := false
var _screen: MeshInstance3D
var _indicator: MeshInstance3D
var _screen_light: OmniLight3D
var _visual: Node3D
var _screen_material: StandardMaterial3D

func _ready() -> void:
	super._ready()
	add_to_group("phone_locator")
	add_to_group("household_hazards")
	_screen = get_node_or_null("PhoneScreen") as MeshInstance3D
	_indicator = get_node_or_null("Indicator") as MeshInstance3D
	_screen_light = get_node_or_null("ScreenGlow") as OmniLight3D
	_visual = get_node_or_null("PhoneVisual") as Node3D
	_next_activation_delay = randf_range(activation_delay_min, activation_delay_max) * DifficultyManager.get_hazard_delay()
	if _screen != null and _screen.material_override is StandardMaterial3D:
		_screen_material = (_screen.material_override as StandardMaterial3D).duplicate()
		_screen.material_override = _screen_material
	_set_active_visual(false)

func _process(delta: float) -> void:
	if not RunStats.run_active:
		return
	if not armed:
		if not held:
			_rearm_left -= delta
			if _rearm_left <= 0.0 and not RitaSleep.is_angry:
				place_randomly()
				armed = true
				_elapsed = 0.0
				_next_activation_delay = randf_range(activation_delay_min, activation_delay_max) * DifficultyManager.get_hazard_delay()
		return
	if armed and not active:
		_elapsed += delta
		if _elapsed >= _next_activation_delay:
			activate_phone()
	if active:
		_active_elapsed += delta
		_pulse_elapsed += delta
		var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.007) * 0.5
		if _screen_light != null:
			_screen_light.light_energy = lerpf(0.12, 0.28, pulse)
		if _screen_material != null:
			_screen_material.emission_energy_multiplier = lerpf(0.75, 1.35, pulse)
		if _visual != null and not held:
			_visual.rotation.y = sin(Time.get_ticks_msec() * 0.026) * 0.018
		if _pulse_elapsed >= pulse_interval:
			_pulse_elapsed = 0.0
			NoiseManager.emit_noise(global_position, pulse_noise, &"APPLIANCE", &"phone")
			AudioManager.play_3d(&"buzz", global_position, -4.0, randf_range(0.94, 1.08))
		if not _reminder_shown and _active_elapsed >= reminder_delay:
			_reminder_shown = true
			QuestManager.notification_requested.emit(_current_location_hint())
	if held or placement_anchor == null:
		_return_elapsed = 0.0
		return
	var anchor_distance := global_position.distance_to(placement_anchor.global_position)
	if anchor_distance <= 0.62:
		_return_elapsed = 0.0
		return
	_return_elapsed += delta
	if _return_elapsed >= return_delay and not _player_is_looking():
		_return_to_anchor()

func activate_phone() -> void:
	if active:
		return
	active = true
	armed = true
	_active_elapsed = 0.0
	_pulse_elapsed = pulse_interval
	_reminder_shown = false
	_set_active_visual(true)
	ringing_started.emit(self)
	QuestManager.notification_requested.emit("ЭКРАН ТЕЛЕФОНА МИГАЕТ ГДЕ-ТО В КВАРТИРЕ")

func on_picked_up() -> void:
	super.on_picked_up()
	if active:
		active = false
		armed = false
		_rearm_left = randf_range(rearm_delay_min, rearm_delay_max) * DifficultyManager.get_hazard_delay()
		_elapsed = 0.0
		_pulse_elapsed = 0.0
		_set_active_visual(false)
		ringing_stopped.emit(self)
		QuestManager.notification_requested.emit("ТЕЛЕФОН ЗАГЛУШЕН  •  НО ОН ЕЩЁ ЗАЗВОНИТ")

func on_released() -> void:
	super.on_released()
	_return_elapsed = 0.0

func _set_active_visual(value: bool) -> void:
	if _indicator != null:
		_indicator.visible = value
	if _screen_light != null:
		_screen_light.visible = value
	if _screen_material != null:
		_screen_material.emission_enabled = value
		_screen_material.emission = Color("68cfff")
		_screen_material.emission_energy_multiplier = 1.0
	if not value and _visual != null:
		_visual.rotation = Vector3.ZERO

func _return_to_anchor() -> void:
	if placement_anchor == null:
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = placement_anchor.global_transform
	freeze = true
	sleeping = true
	last_safe_transform = global_transform
	_return_elapsed = 0.0

func configure_random_anchors(anchors: Array[Node3D]) -> void:
	placement_anchors = anchors.duplicate()
	place_randomly()

func place_randomly() -> void:
	if placement_anchors.is_empty():
		return
	var next_index := randi() % placement_anchors.size()
	if placement_anchors.size() > 1 and next_index == _placement_index:
		next_index = (next_index + randi_range(1, placement_anchors.size() - 1)) % placement_anchors.size()
	place_at_anchor_index(next_index)

func place_at_anchor_index(index: int) -> void:
	if placement_anchors.is_empty():
		return
	_placement_index = posmod(index, placement_anchors.size())
	placement_anchor = placement_anchors[_placement_index]
	_return_to_anchor()

func _current_location_hint() -> String:
	if placement_anchor == null:
		return "ИЩИ МИГАЮЩИЙ ЭКРАН ТЕЛЕФОНА"
	return String(placement_anchor.get_meta("phone_hint", "ИЩИ МИГАЮЩИЙ ЭКРАН ТЕЛЕФОНА"))

func _player_is_looking() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var camera := player.get("camera") as Camera3D
	if camera == null or not camera.is_position_in_frustum(global_position):
		return false
	var to_phone := (global_position - camera.global_position).normalized()
	return (-camera.global_transform.basis.z).dot(to_phone) > 0.93
