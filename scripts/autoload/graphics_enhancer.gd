extends Node

## GraphicsEnhancer — постобработка визуала квартиры после сборки.
## Не меняет геймплей: только материалы, свет и декор без коллизий.
## Текстуры: фото CC0 (ambientCG), переведённые в градации яркости и
## нормированные к средней светлоте проекта. Каждый материал из общей
## палитры apartment_builder сопоставляется ПО ТОЧНОМУ HEX-ЦВЕТУ, поэтому
## серая деталь умножается на родной цвет — палитра не искажается вообще,
## а полы/стены/столешницы получают реальную фактуру. Никаких пятен:
## контраст жёстко зажат нижней границей яркости для каждого типа.

# Светлота текстуры нормируется к этой средней; итоговый оттенок даёт albedo_color.
const AVG_TARGET := 0.93
const DEFAULT_CONTRAST := 0.5
const DETAIL_SIZE := 512
const CEIL_Y := 3.02

# Файлы res://assets/textures/{name}_color.jpg + {name}_normal.jpg (CC0 ambientCG).
const TEX_FILES := [
	"wood",        # Planks012 — дощатый пол, дверные рамы
	"wood003",     # Wood003 — тёмная мебель (brown)
	"plaster",     # Plaster003 — окрашенные стены
	"tile",        # Tiles053 — плиточный пол кухни/прихожей/ванной
	"marble",      # Marble013 — столешницы
	"fabric",      # Fabric030 — диван, спальные ткани
	"fabric003",   # Fabric003 — синяя/рыжая ткань, покрывала
	"carpet001",   # Carpet001 — светлый ковёр
	"carpet002",   # Carpet002 — основной ковёр гостиной
	"cardboard",   # Cardboard001 — коробки переезда
]

# Палитра apartment_builder._create_materials -> какая деталь куда идёт.
# t = файл, uv = масштаб world-triplanar, ns = сила normal-карты,
# lo = нижняя граница яркости (чем выше — тем ровнее поверхность),
# con = мягкость контраста (переопределяет DEFAULT_CONTRAST).
const PALETTE := {
	# Стены: ровная окраска с еле заметной фактурой штукатурки.
	"d8d2c8": {"t": "plaster", "uv": 0.35, "ns": 0.09, "lo": 0.90, "con": 0.48},
	"b9a998": {"t": "plaster", "uv": 0.35, "ns": 0.20, "lo": 0.90, "con": 0.48},
	# Дощатые полы и дверные пакеты: единое дерево на всю квартиру.
	"805331": {"t": "wood", "uv": 0.8, "ns": 0.55, "lo": 0.84},
	"a87345": {"t": "wood", "uv": 0.8, "ns": 0.55, "lo": 0.84},
	"5d3823": {"t": "wood", "uv": 0.8, "ns": 0.55, "lo": 0.84},
	# Плитка: крупноформатная, швы совпадают с шагом сетки пола.
	"9fa3a1": {"t": "tile", "uv": 1.0, "ns": 0.65, "lo": 0.87},
	"777d7c": {"t": "tile", "uv": 1.0, "ns": 0.65, "lo": 0.87},
	# Столешница и её торец: камень.
	"d4cec0": {"t": "marble", "uv": 0.55, "ns": 0.28, "lo": 0.88},
	"948c7d": {"t": "marble", "uv": 0.55, "ns": 0.28, "lo": 0.88},
	# Ткани мебели.
	"526353": {"t": "fabric", "uv": 2.4, "ns": 0.42, "lo": 0.85},
	"3f5c72": {"t": "fabric003", "uv": 2.4, "ns": 0.42, "lo": 0.85},
	"a5573e": {"t": "fabric", "uv": 2.4, "ns": 0.42, "lo": 0.85},
	"72525f": {"t": "fabric003", "uv": 2.4, "ns": 0.36, "lo": 0.86},
	"d7c8ae": {"t": "fabric003", "uv": 2.2, "ns": 0.34, "lo": 0.88},
	# Ковры — плотный ворс.
	"365b62": {"t": "carpet002", "uv": 1.4, "ns": 0.60, "lo": 0.86},
	"d9b86c": {"t": "carpet001", "uv": 1.4, "ns": 0.60, "lo": 0.86},
	# Тёмное дерево мебели.
	"4b2416": {"t": "wood003", "uv": 1.1, "ns": 0.45, "lo": 0.82},
	# Картонные коробки.
	"9a7047": {"t": "cardboard", "uv": 1.2, "ns": 0.50, "lo": 0.83},
}

var _tex: Dictionary = {}
var _counts: Dictionary = {}
var _done := false

func _ready() -> void:
	get_tree().root.child_entered_tree.connect(_on_scene_root_entered)
	_run()

func _run() -> void:
	for _i in range(240):
		await get_tree().process_frame
		if _find_world_env() != null:
			break
	if _done or _find_world_env() == null:
		print("GRAPHICS_ENHANCED_OK applied=none")
		return
	_done = true
	_load_photo_details()
	var stats := {}
	_apply_material_pass(stats)
	_upgrade_environment(_find_world_env())
	_upgrade_lights()
	_add_window_atmosphere(Vector3(-4.65, 0.0, -6.5), Color("a5573e"))
	_add_window_atmosphere(Vector3(4.65, 0.0, -6.5), Color("5c6b73"))
	_add_poster(Vector3(-7.86, 1.62, -0.35), 90.0, 1.05, 0.78, 0)
	_add_poster(Vector3(1.505, 1.58, 0.35), -90.0, 0.72, 0.95, 1)
	_add_poster(Vector3(-6.30, 1.60, 6.40), 180.0, 0.95, 0.70, 2)
	var summary := []
	for key in stats:
		summary.append("%s=%d" % [key, stats[key]])
	print("GRAPHICS_ENHANCED_OK %s" % " ".join(summary))

func _find_world_env() -> WorldEnvironment:
	var stack: Array[Node] = []
	for child in get_tree().root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is WorldEnvironment:
			return node as WorldEnvironment
		for child in node.get_children():
			stack.append(child)
	return null

# ---------- Фото-текстуры (CC0 ambientCG) ----------

func _load_photo_details() -> void:
	for name_value in TEX_FILES:
		var albedo := _detail_albedo(
			"res://assets/textures/%s_color.jpg" % name_value,
			_default_lo(name_value))
		var normal := _detail_normal("res://assets/textures/%s_normal.jpg" % name_value)
		if albedo != null:
			_tex[name_value] = {"albedo": albedo, "normal": normal}

func _default_lo(file_name: String) -> float:
	match file_name:
		"plaster":
			return 0.90
		"cardboard":
			return 0.83
	return 0.85

func _detail_albedo(path: String, lo: float) -> ImageTexture:
	var source := load(path) as Texture2D
	var img := source.get_image() if source != null else null
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.resize(DETAIL_SIZE, DETAIL_SIZE, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	# Средняя светота по прореженной сетке (в 16 раз быстрее полного обхода).
	var sum := 0.0
	var samples := 0
	for y in range(0, DETAIL_SIZE, 4):
		for x in range(0, DETAIL_SIZE, 4):
			sum += img.get_pixel(x, y).get_luminance()
			samples += 1
	var avg := maxf(sum / float(maxi(samples, 1)), 0.02)
	var k := AVG_TARGET / avg
	for y in range(DETAIL_SIZE):
		for x in range(DETAIL_SIZE):
			var lum := img.get_pixel(x, y).get_luminance()
			# Обесцвечивание + мягкий контраст вокруг единицы, с жёсткой
			# нижней границей: ни один пиксель не делает грязных провалов.
			var v := lerpf(1.0, lum * k, DEFAULT_CONTRAST)
			v = clampf(v, lo, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _detail_normal(path: String) -> ImageTexture:
	var source := load(path) as Texture2D
	var img := source.get_image() if source != null else null
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.resize(DETAIL_SIZE, DETAIL_SIZE, Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _apply_material_pass(stats: Dictionary) -> void:
	var stack: Array[Node] = []
	for child in get_tree().root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and not _has_player_ancestor(node):
			var mi := node as MeshInstance3D
			var m := mi.material_override as StandardMaterial3D
			if m != null and not m.has_meta("gfx_done"):
				m.set_meta("gfx_done", true)
				if m.emission_enabled and m.emission_energy_multiplier >= 0.8:
					m.emission_energy_multiplier = minf(m.emission_energy_multiplier * 1.2, 2.4)
					stats["emissive"] = int(stats.get("emissive", 0)) + 1
				else:
					_apply_palette_texture(m, stats)
		for child in node.get_children():
			stack.append(child)

func _apply_palette_texture(m: StandardMaterial3D, stats: Dictionary) -> void:
	if m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		return
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	if m.albedo_texture != null:
		return
	if m.emission_enabled:
		return
	if m.metallic >= 0.4:
		return
	var hex_key := m.albedo_color.to_html(false).to_lower()
	var cfg: Dictionary = PALETTE.get(hex_key, {})
	if cfg.is_empty():
		stats["untouched"] = int(stats.get("untouched", 0)) + 1
		return
	var tex_name: String = cfg["t"]
	if not _tex.has(tex_name):
		stats["missing_tex"] = int(stats.get("missing_tex", 0)) + 1
		return
	var t: Dictionary = _tex[tex_name]
	m.albedo_texture = t["albedo"]
	if t["normal"] != null:
		m.normal_enabled = true
		m.normal_texture = t["normal"]
		m.normal_scale = float(cfg["ns"])
	var s := float(cfg["uv"])
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(s, s, s)
	stats[tex_name] = int(stats.get(tex_name, 0)) + 1

func _has_player_ancestor(node: Node) -> bool:
	var cur := node
	while cur != null:
		if cur is Node and (cur as Node).is_in_group("player"):
			return true
		cur = cur.get_parent()
	return false

# ---------- Свет и окружение ----------

func _upgrade_environment(world: WorldEnvironment) -> void:
	var env := world.environment
	if env == null:
		return
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 0.45
		env.ssao_intensity = 1.25
		env.ssil_enabled = true
		env.ssil_intensity = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.94
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.10
	env.glow_hdr_threshold = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.96
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.06, 0.10)
	env.fog_density = 0.003
	env.fog_sky_affect = 0.0
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.035, 0.09)
	sky_mat.sky_horizon_color = Color(0.46, 0.27, 0.19)
	sky_mat.ground_bottom_color = Color(0.02, 0.025, 0.04)
	sky_mat.ground_horizon_color = Color(0.30, 0.19, 0.14)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky

func _upgrade_lights() -> void:
	var stack: Array[Node] = []
	for child in get_tree().root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is OmniLight3D:
			var light := node as OmniLight3D
			light.light_specular = 0.45
			if light.name in ["OfficeFill", "KitchenMain", "HallLight"]:
				light.light_energy *= 0.72
				light.shadow_enabled = true
			if light.name == "DeskLamp":
				light.shadow_enabled = true
			if light.name in ["OfficeFill", "KitchenMain", "HallLight"]:
				_add_pendant(light)
			elif light.name.ends_with("CeilingLight"):
				_add_flush_dome(light)
		elif node is DirectionalLight3D:
			var moon := node as DirectionalLight3D
			moon.light_specular = 0.55
			moon.shadow_blur = 1.3
		for child in node.get_children():
			stack.append(child)

func _add_pendant(light: OmniLight3D) -> void:
	var holder := Node3D.new()
	holder.name = "Pendant_%s" % light.name
	add_child(holder)
	var cord := MeshInstance3D.new()
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.008
	cord_mesh.bottom_radius = 0.008
	cord_mesh.height = CEIL_Y - light.position.y + 0.12
	cord.mesh = cord_mesh
	cord.position = Vector3(light.position.x, (CEIL_Y + light.position.y + 0.12) * 0.5, light.position.z)
	cord.material_override = _flat_material(Color("14161a"), 0.6)
	holder.add_child(cord)
	var shade := MeshInstance3D.new()
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius = 0.045
	shade_mesh.bottom_radius = 0.185
	shade_mesh.height = 0.16
	shade.mesh = shade_mesh
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shade.position = Vector3(light.position.x, light.position.y + 0.14, light.position.z)
	shade.material_override = _flat_material(Color("2f4a40"), 0.42)
	holder.add_child(shade)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.042
	bulb_mesh.height = 0.084
	bulb.mesh = bulb_mesh
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.position = light.position + Vector3(0.0, 0.03, 0.0)
	bulb.material_override = _glow_material(Color("ffd9a0"), 2.2)
	holder.add_child(bulb)

func _add_flush_dome(light: OmniLight3D) -> void:
	var dome := MeshInstance3D.new()
	dome.name = "Dome_%s" % light.name
	var mesh := SphereMesh.new()
	mesh.radius = 0.155
	mesh.height = 0.09
	mesh.radial_segments = 20
	mesh.rings = 10
	dome.mesh = mesh
	dome.position = light.position + Vector3(0.0, 0.10, 0.0)
	dome.material_override = _glow_material(Color("ffe9c8"), 1.5)
	add_child(dome)

# ---------- Атмосфера у окон ----------

func _add_window_atmosphere(window_center: Vector3, curtain_color: Color) -> void:
	var inner_z := window_center.z + 0.55
	var spot := SpotLight3D.new()
	spot.name = "MoonShaft_%s" % window_center.x
	add_child(spot)
	spot.position = Vector3(window_center.x, 2.55, window_center.z - 0.45)
	spot.look_at(Vector3(window_center.x + signf(window_center.x) * 0.35, 0.15, inner_z + 1.4), Vector3.UP)
	spot.light_color = Color("8ca9d9")
	spot.light_energy = 2.1
	spot.spot_range = 10.5
	spot.spot_angle = 31.0
	spot.spot_angle_attenuation = 0.85
	spot.shadow_enabled = false
	var dust := GPUParticles3D.new()
	dust.name = "Dust_%s" % window_center.x
	add_child(dust)
	dust.amount = 42
	dust.lifetime = 10.0
	dust.preprocess = 9.0
	dust.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(1.5, 1.3, 1.1)
	proc.direction = Vector3(0, 0, 1)
	proc.spread = 180.0
	proc.initial_velocity_min = 0.015
	proc.initial_velocity_max = 0.05
	proc.gravity = Vector3.ZERO
	proc.scale_min = 0.5
	proc.scale_max = 1.5
	proc.angle_min = 0.0
	proc.angle_max = 360.0
	proc.color = Color(1.0, 0.93, 0.75, 0.16)
	dust.process_material = proc
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.vertex_color_use_as_albedo = true
	quad.material = pm
	dust.draw_pass_1 = quad
	dust.position = Vector3(window_center.x, 1.45, inner_z)
	_add_curtains(window_center, curtain_color)

func _add_curtains(center: Vector3, color: Color) -> void:
	var rod := MeshInstance3D.new()
	rod.name = "CurtainRod_%s" % center.x
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.018
	rod_mesh.bottom_radius = 0.018
	rod_mesh.height = 3.5
	rod.mesh = rod_mesh
	rod.rotation_degrees = Vector3(0, 0, 90)
	rod.position = Vector3(center.x, 2.74, center.z + 0.16)
	rod.material_override = _flat_material(Color("3a2a1c"), 0.35)
	add_child(rod)
	var fabric := _flat_material(color, 1.0)
	if _tex.has("fabric"):
		fabric.albedo_texture = (_tex["fabric"] as Dictionary)["albedo"]
		fabric.uv1_triplanar = true
		fabric.uv1_world_triplanar = true
		fabric.uv1_scale = Vector3(2.2, 2.2, 2.2)
	var cloth_scene := load("res://assets/furniture/artpass/curtains.glb") as PackedScene
	if cloth_scene != null:
		var cloth := cloth_scene.instantiate() as Node3D
		cloth.position = center
		add_child(cloth)
	for side in ([] if cloth_scene != null else [-1.0, 1.0]):
		var panel := MeshInstance3D.new()
		panel.name = "Curtain_%s_%d" % [center.x, int(side)]
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(0.46, 2.42, 0.06)
		panel.mesh = panel_mesh
		panel.position = Vector3(center.x + side * 1.42, 1.47, center.z + 0.16)
		panel.material_override = fabric
		add_child(panel)
	var sheer := MeshInstance3D.new()
	sheer.name = "Sheer_%s" % center.x
	var sheer_mesh := BoxMesh.new()
	sheer_mesh.size = Vector3(2.1, 2.30, 0.025)
	sheer.mesh = sheer_mesh
	sheer.position = Vector3(center.x, 1.53, center.z + 0.10)
	var sheer_mat := StandardMaterial3D.new()
	sheer_mat.albedo_color = Color(1.0, 0.97, 0.9, 0.28)
	sheer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheer_mat.roughness = 1.0
	sheer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheer.material_override = sheer_mat
	add_child(sheer)

# ---------- Картины ----------

func _add_poster(pos: Vector3, yaw_deg: float, w: float, h: float, style: int) -> void:
	var holder := Node3D.new()
	holder.name = "Poster_%d" % style
	add_child(holder)
	holder.position = pos
	holder.rotation_degrees = Vector3(0, yaw_deg, 0)
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(w + 0.09, h + 0.09, 0.045)
	frame.mesh = frame_mesh
	frame.material_override = _flat_material(Color("4b2f1c"), 0.5)
	holder.add_child(frame)
	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	canvas.mesh = quad
	canvas.position = Vector3(0, 0, 0.026)
	canvas.material_override = _poster_material(style)
	holder.add_child(canvas)

func _poster_material(style: int) -> StandardMaterial3D:
	var img := Image.create(224, 168, false, Image.FORMAT_RGB8)
	var palettes := [
		{"top": Color(0.95, 0.72, 0.42), "bot": Color(0.28, 0.16, 0.22), "cols": [Color(0.86, 0.38, 0.25), Color(0.93, 0.78, 0.45), Color(0.22, 0.30, 0.42)]},
		{"top": Color(0.20, 0.30, 0.38), "bot": Color(0.09, 0.12, 0.17), "cols": [Color(0.85, 0.62, 0.30), Color(0.35, 0.55, 0.52), Color(0.75, 0.80, 0.78)]},
		{"top": Color(0.83, 0.80, 0.72), "bot": Color(0.45, 0.42, 0.36), "cols": [Color(0.35, 0.48, 0.32), Color(0.62, 0.35, 0.28), Color(0.25, 0.28, 0.34)]}
	]
	var pal: Dictionary = palettes[style % palettes.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717 + style * 131
	for y in range(168):
		for x in range(224):
			var t := float(y) / 167.0
			img.set_pixel(x, y, (pal["top"] as Color).lerp(pal["bot"] as Color, t))
	for i in range(7):
		var blob_col: Color = pal["cols"][i % 3]
		blob_col.a = rng.randf_range(0.25, 0.5)
		var cx := rng.randf_range(30.0, 194.0)
		var cy := rng.randf_range(24.0, 144.0)
		var rr := rng.randf_range(14.0, 46.0)
		for y in range(maxi(0, int(cy - rr)), mini(168, int(cy + rr))):
			for x in range(maxi(0, int(cx - rr)), mini(224, int(cx + rr))):
				var dd := Vector2(x - cx, y - cy).length() / rr
				if dd <= 1.0:
					var src := img.get_pixel(x, y)
					var k := (1.0 - dd) * blob_col.a
					img.set_pixel(x, y, src.lerp(Color(blob_col.r, blob_col.g, blob_col.b), k))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.9
	return mat

# ---------- Вспомогательные материалы ----------

func _flat_material(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := _flat_material(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _on_scene_root_entered(node: Node) -> void:
	if node.scene_file_path != "res://scenes/game.tscn" or not _done:
		return
	_done = false
	for child in get_children():
		child.queue_free()
	_run()
