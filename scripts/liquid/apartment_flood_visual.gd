class_name ApartmentFloodVisual
extends Node3D

const ZONES: Array[Dictionary] = [
	{"id": &"kitchen", "stage": 0, "center": Vector2(4.70, -2.25), "size": Vector2(6.05, 8.25)},
	{"id": &"north_hall", "stage": 1, "center": Vector2(0.0, -2.25), "size": Vector2(3.05, 8.25)},
	{"id": &"living", "stage": 2, "center": Vector2(-4.70, -2.25), "size": Vector2(6.05, 8.25)},
	{"id": &"south_hall", "stage": 2, "center": Vector2(0.0, 4.25), "size": Vector2(3.05, 4.25)},
	{"id": &"bathroom", "stage": 3, "center": Vector2(4.70, 4.25), "size": Vector2(6.05, 4.25)},
	{"id": &"bedroom", "stage": 3, "center": Vector2(-4.70, 4.25), "size": Vector2(6.05, 4.25)},
	{"id": &"wardrobe", "stage": 3, "center": Vector2(-4.80, 8.00), "size": Vector2(6.20, 2.80)},
]

var active := false
var flood_stage := 0
var elapsed_seconds := 0.0
var water_volume_ml := 0.0
var peak_volume_ml := 1.0
var faucet_running := false
var current_depth := 0.0
var _surfaces: Dictionary = {}
var _zone_progress: Dictionary = {}


func _ready() -> void:
	add_to_group("apartment_flood_visual")
	for definition in ZONES:
		_create_zone(definition)
	set_process(true)


func set_flood_state(is_active: bool, stage: int, elapsed: float, volume_ml: float, running: bool) -> void:
	active = is_active
	flood_stage = clampi(stage, 0, 3)
	elapsed_seconds = maxf(0.0, elapsed)
	water_volume_ml = maxf(0.0, volume_ml)
	faucet_running = running
	if active:
		peak_volume_ml = maxf(peak_volume_ml, water_volume_ml)
	elif current_depth <= 0.01:
		peak_volume_ml = 1.0


func get_water_depth_at(world_position: Vector3) -> float:
	if not active or current_depth <= 0.01:
		return 0.0
	for definition in ZONES:
		var id: StringName = definition["id"]
		if float(_zone_progress.get(id, 0.0)) < 0.55:
			continue
		var center: Vector2 = definition["center"]
		var size: Vector2 = definition["size"]
		if absf(world_position.x - center.x) <= size.x * 0.5 and absf(world_position.z - center.y) <= size.y * 0.5:
			return current_depth
	return 0.0


func _process(delta: float) -> void:
	var target_depth := 0.0
	if active and water_volume_ml > 1.0:
		# Финальная стадия намеренно абсурдна: вода доходит Денису до колен.
		# Объём продолжает влиять на уровень между сюжетными порогами.
		target_depth = clampf(0.035 + water_volume_ml / 12000.0 * 0.72, 0.035, 0.82)
		var stage_floor: float = float([0.055, 0.14, 0.32, 0.68][flood_stage])
		if not faucet_running:
			# После закрытия крана уровень опускается вместе с реально собранным
			# объёмом, а не исчезает одним кадром после последней лужи.
			stage_floor *= sqrt(clampf(water_volume_ml / maxf(peak_volume_ml, 1.0), 0.0, 1.0))
		target_depth = maxf(target_depth, stage_floor)
	var rise_speed := 0.12 + float(flood_stage) * 0.06
	current_depth = move_toward(current_depth, target_depth, delta * (rise_speed if target_depth > current_depth else 0.16))

	for definition in ZONES:
		var id: StringName = definition["id"]
		var required_stage: int = int(definition["stage"])
		var target_progress := 1.0 if active and flood_stage >= required_stage and water_volume_ml > 1.0 else 0.0
		var progress := move_toward(float(_zone_progress.get(id, 0.0)), target_progress, delta * (0.22 if target_progress > 0.0 else 0.65))
		_zone_progress[id] = progress
		var surface := _surfaces.get(id) as MeshInstance3D
		if surface == null:
			continue
		surface.visible = progress > 0.01
		var eased := smoothstep(0.0, 1.0, progress)
		surface.scale = Vector3(lerpf(0.06, 1.0, eased), 1.0, lerpf(0.06, 1.0, eased))
		surface.position.y = current_depth + sin(Time.get_ticks_msec() * 0.0018 + float(required_stage)) * 0.004
		var material := surface.material_override as StandardMaterial3D
		if material != null:
			var depth_alpha := clampf(0.28 + current_depth * 0.72, 0.30, 0.72)
			var tint := material.albedo_color
			tint.a = depth_alpha * eased
			material.albedo_color = tint
			material.emission_energy_multiplier = 0.18 + sin(Time.get_ticks_msec() * 0.002 + float(required_stage)) * 0.035


func _create_zone(definition: Dictionary) -> void:
	var id: StringName = definition["id"]
	var center: Vector2 = definition["center"]
	var size: Vector2 = definition["size"]
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(8, roundi(size.x * 3.0))
	plane.subdivide_depth = maxi(8, roundi(size.y * 3.0))
	var surface := MeshInstance3D.new()
	surface.name = "FloodSurface_%s" % String(id)
	surface.mesh = plane
	surface.position = Vector3(center.x, 0.02, center.y)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.visibility_range_end = 28.0
	surface.visible = false
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.08, 0.42, 0.68, 0.0)
	material.metallic = 0.18
	material.roughness = 0.12
	material.emission_enabled = true
	material.emission = Color(0.04, 0.20, 0.32)
	material.emission_energy_multiplier = 0.18
	surface.material_override = material
	add_child(surface)
	_surfaces[id] = surface
	_zone_progress[id] = 0.0
