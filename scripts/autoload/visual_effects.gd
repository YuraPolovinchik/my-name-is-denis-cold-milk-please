extends Node

var _particles: Dictionary = {}
var _tweens: Array[Tween] = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for tween in _tweens:
			if tween != null and tween.is_valid():
				tween.kill()
		_tweens.clear()

func create_dust_burst(position: Vector3, count: int = 8) -> void:
	var parent := _get_effects_parent()
	if parent == null:
		return
	for i in range(count):
		var dust := _create_dust_particle(position, parent)
		if dust == null:
			continue
		var tween := parent.create_tween()
		_tweens.append(tween)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.3, 1.0), randf_range(-1.0, 1.0)).normalized()
		var end_pos := position + dir * randf_range(0.15, 0.45)
		tween.tween_property(dust, "global_position", end_pos, randf_range(0.4, 0.8))
		tween.parallel().tween_property(dust, "scale", Vector3.ZERO, randf_range(0.4, 0.8))
		tween.tween_callback(dust.queue_free)
		tween.finished.connect(func() -> void: _tweens.erase(tween))

func create_spark_burst(position: Vector3, count: int = 6) -> void:
	var parent := _get_effects_parent()
	if parent == null:
		return
	for i in range(count):
		var spark := _create_spark_particle(position, parent)
		if spark == null:
			continue
		var tween := parent.create_tween()
		_tweens.append(tween)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.0), randf_range(-1.0, 1.0)).normalized()
		var end_pos := position + dir * randf_range(0.2, 0.6)
		tween.tween_property(spark, "global_position", end_pos, randf_range(0.15, 0.35))
		tween.parallel().tween_property(spark, "scale", Vector3.ZERO, randf_range(0.15, 0.35))
		tween.tween_callback(spark.queue_free)
		tween.finished.connect(func() -> void: _tweens.erase(tween))

## Удобная обёртка: вызывает create_dust_burst (совместимость с вызовами из player_controller.gd)
func spawn_dust(position: Vector3, _intensity: float = 1.0) -> void:
	create_dust_burst(position, int(_intensity * 8.0))

## Удобная обёртка: вызывает create_spark_burst (совместимость с вызовами из physical_item.gd)
func spawn_impact_sparks(position: Vector3, count: int = 6) -> void:
	create_spark_burst(position, count)

## Удобная обёртка: тряска без конкретной позиции (для бросков предметов)
func spawn_impact_shake(intensity: float = 0.15) -> void:
	var camera := _get_player_camera()
	if camera == null:
		return
	create_impact_shake(camera.global_position, intensity)

func create_impact_shake(position: Vector3, intensity: float = 1.0) -> void:
	var camera := _get_player_camera()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(position)
	if distance > 12.0:
		return
	var strength := clampf(intensity / (1.0 + distance * 0.3), 0.0, 1.0)
	if strength < 0.05:
		return
	var tween := camera.create_tween()
	_tweens.append(tween)
	var original_pos := camera.position
	var shake_count := int(strength * 6.0) + 1
	for i in range(shake_count):
		var offset := Vector3(
			randf_range(-0.02, 0.02) * strength,
			randf_range(-0.015, 0.015) * strength,
			randf_range(-0.02, 0.02) * strength
		)
		tween.tween_property(camera, "position", original_pos + offset, 0.03)
	tween.tween_property(camera, "position", original_pos, 0.05)
	tween.finished.connect(func() -> void: _tweens.erase(tween))

func create_breath_mist(position: Vector3, direction: Vector3) -> void:
	var parent := _get_effects_parent()
	if parent == null:
		return
	var mist := _create_mist_particle(position, parent)
	if mist == null:
		return
	var tween := parent.create_tween()
	_tweens.append(tween)
	var end_pos := position + direction * 0.3 + Vector3.UP * 0.1
	tween.tween_property(mist, "global_position", end_pos, 1.5)
	tween.parallel().tween_property(mist, "scale", Vector3.ZERO, 1.5)
	tween.tween_callback(mist.queue_free)
	tween.finished.connect(func() -> void: _tweens.erase(tween))

func create_kettle_steam(position: Vector3, intensity: float = 1.0) -> void:
	var parent := _get_effects_parent()
	if parent == null:
		return
	var steam := _create_steam_particle(position, parent)
	if steam == null:
		return
	steam.scale = Vector3.ONE * randf_range(0.6, 1.0) * intensity
	var tween := parent.create_tween()
	_tweens.append(tween)
	var end_pos := position + Vector3.UP * randf_range(0.3, 0.6) + Vector3(randf_range(-0.1, 0.1), 0.0, randf_range(-0.1, 0.1))
	tween.tween_property(steam, "global_position", end_pos, randf_range(1.0, 2.0))
	tween.parallel().tween_property(steam, "scale", Vector3.ZERO, randf_range(1.0, 2.0))
	tween.tween_callback(steam.queue_free)
	tween.finished.connect(func() -> void: _tweens.erase(tween))

func create_light_flicker(light: Light3D, duration: float = 0.5) -> void:
	if light == null:
		return
	var tween := light.create_tween()
	_tweens.append(tween)
	var original_energy := light.light_energy
	tween.tween_property(light, "light_energy", original_energy * 0.3, 0.05)
	tween.tween_property(light, "light_energy", original_energy * 1.2, 0.05)
	tween.tween_property(light, "light_energy", original_energy * 0.1, 0.03)
	tween.tween_property(light, "light_energy", original_energy, 0.1)
	tween.finished.connect(func() -> void:
		light.light_energy = original_energy
		_tweens.erase(tween)
	)

func create_float_up_text(position: Vector3, text: String, color: Color = Color.WHITE) -> void:
	var parent := _get_effects_parent()
	if parent == null:
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position
	parent.add_child(label)
	var tween := parent.create_tween()
	_tweens.append(tween)
	tween.tween_property(label, "position:y", position.y + 0.8, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(label.queue_free)
	tween.finished.connect(func() -> void: _tweens.erase(tween))

func _get_effects_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("effects_parent") as Node

func _get_player_camera() -> Camera3D:
	var tree := get_tree()
	if tree == null:
		return null
	var player := tree.get_first_node_in_group("player") as Node3D
	if player == null:
		return null
	return player.get_node_or_null("Camera") as Camera3D

func _create_dust_particle(position: Vector3, parent: Node) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	(mesh.mesh as SphereMesh).radius = 0.015
	(mesh.mesh as SphereMesh).height = 0.03
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.82, 0.78, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
	return mesh

func _create_spark_particle(position: Vector3, parent: Node) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	(mesh.mesh as SphereMesh).radius = 0.008
	(mesh.mesh as SphereMesh).height = 0.016
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.4, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.2)
	material.emission_energy_multiplier = 2.0
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
	return mesh

func _create_mist_particle(position: Vector3, parent: Node) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	(mesh.mesh as SphereMesh).radius = 0.04
	(mesh.mesh as SphereMesh).height = 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 1.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
	return mesh

func _create_steam_particle(position: Vector3, parent: Node) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	(mesh.mesh as SphereMesh).radius = 0.03
	(mesh.mesh as SphereMesh).height = 0.06
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.9, 0.95, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
	return mesh
