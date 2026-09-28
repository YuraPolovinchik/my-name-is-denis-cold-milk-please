extends Node

## TrimEnhancer — вставляет профессиональный архитектурный декор,
## сгенерированный в Blender 5.0 (tools/build_apartment_trim.py):
## потолочные карнизы с профилем, плинтусы с реальным сечением,
## дверные обналички, оконные откосы и подоконники, панельные
## радиаторы с трубами, потолочные розетки под светильники.
## Чисто визуальный слой: коллизий нет, геймплей не затронут.
## Материалы: штукатурные элементы клонируют СОВМЕСТНЫЙ материал стен
## из apartment_builder (уже с фото-текстурой от GraphicsEnhancer),
## поэтому карнизы фактурой совпадают со стенами один в один.

const WAIT_FRAMES := 320
const SETTLE_FRAMES := 20
const TRIM_SCENE := "res://assets/environment/apartment_trim.glb"

const HEX_WALL := "d8d2c8"
const HEX_TRIM := "eeeae2"

## Map: GLB floor material name → apartment_builder palette hex whose
## photo-textured material we clone, so new floors match the flat exactly.
const FLOOR_DONORS := {
	"FLOOR_OAK": "a87345",          # oak_light
	"FLOOR_OAK_ACCENT": "805331",   # oak
	"FLOOR_OAK_SEAM": "5d3823",     # oak_dark
	"FLOOR_TILE": "9fa3a1",         # tile
	"FLOOR_TILE_ACCENT": "777d7c",  # tile_dark
	"FLOOR_TILE_SEAM": "777d7c",    # tile_dark
}

## Old gappy plank/tile floors are replaced by the Blender layer.
const HIDE_PREFIXES := ["office_Plank", "bedroom_Plank", "wardrobe_Plank",
	"hall_Tile", "kitchen_Tile", "bath_Tile"]

var _done := false
## True, когда декор смонтирован (или монтаж невозможен) — снимки комнат
## в game.gd ждут этого флага, чтобы попасть в кадр вместе с декором.
var mounted := false

func _ready() -> void:
	get_tree().root.child_entered_tree.connect(_on_scene_root_entered)
	_run()

func _run() -> void:
	for _i in range(WAIT_FRAMES):
		await get_tree().process_frame
		if _find_world_env() != null:
			break
	if _done:
		return
	_done = true
	# Даём материал-пассу GraphicsEnhancer успеть покрасить стены,
	# чтобы клонировать материал стен уже с фото-текстурой.
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame

	var packed: PackedScene = load(TRIM_SCENE)
	if packed == null:
		print("TRIM_ENHANCED_OK skipped=no_scene")
		mounted = true
		return
	var trim := packed.instantiate() as Node3D
	if trim == null:
		print("TRIM_ENHANCED_OK skipped=not_node3d")
		mounted = true
		return
	trim.name = "ApartmentTrim"
	# Мусорный опорный куб из Blender-экспорта: 2x2x2 м, центр (0,0,0) —
	# торчит посреди коридора как белый короб. Прячем вместе с прочим хламом.
	for junk in trim.find_children("Cube", "", true, false):
		if junk is MeshInstance3D:
			(junk as MeshInstance3D).visible = false

	var donor_plaster := _find_shared_material(HEX_WALL)
	var donor_trim := _find_shared_material(HEX_TRIM)
	var mat_plaster := (donor_plaster.duplicate() if donor_plaster != null else _fallback(Color(HEX_WALL), 0.88))
	var mat_trim := (donor_trim.duplicate() if donor_trim != null else _fallback(Color(HEX_TRIM), 0.58))
	var mat_metal := _metal()
	for m in [mat_plaster, mat_trim, mat_metal]:
		m.set_meta("gfx_done", true)

	# New hole-free floors: clone the SAME photo-textured materials the builder
	# uses for oak/tile so seams and accents match the apartment palette.
	var floor_mats := {}
	for glb_name in FLOOR_DONORS:
		var donor_hex: String = FLOOR_DONORS[glb_name]
		var donor := _find_shared_material(donor_hex)
		floor_mats[glb_name] = (donor.duplicate() if donor != null else _fallback(Color(donor_hex), 0.62))
		floor_mats[glb_name].set_meta("gfx_done", true)
		if String(glb_name).begins_with("FLOOR_OAK"):
			floor_mats[glb_name].albedo_color = Color({"FLOOR_OAK": "947c62", "FLOOR_OAK_ACCENT": "856e57", "FLOOR_OAK_SEAM": "625545"}[glb_name])
			floor_mats[glb_name].normal_scale = 0.23
		elif String(glb_name).begins_with("FLOOR_TILE"):
			floor_mats[glb_name].albedo_texture = null
			floor_mats[glb_name].normal_enabled = false
			floor_mats[glb_name].albedo_color = Color({"FLOOR_TILE": "b4b1a5", "FLOOR_TILE_ACCENT": "aca99e", "FLOOR_TILE_SEAM": "77766e"}[glb_name])
			floor_mats[glb_name].roughness = 0.76

	var stats := {"meshes": 0, "plaster": 0, "trim": 0, "metal": 0, "floor": 0}
	_assign_materials(trim, mat_plaster, mat_trim, mat_metal, stats, floor_mats)
	_hide_old_floors()

	var builder := get_tree().get_first_node_in_group("world_root") as Node
	if builder == null:
		# Резервный поиск корня квартиры по имени, задаваемому game.gd.
		builder = get_tree().root.get_node_or_null("GameRoot/Apartment")
		if builder == null:
			builder = get_tree().root.find_child("Apartment", true, false)
	if builder != null:
		builder.add_child(trim)
	else:
		add_child(trim)
	mounted = true
	print("TRIM_ENHANCED_OK meshes=%d plaster=%d trim=%d metal=%d" % [
		stats["meshes"], stats["plaster"], stats["trim"], stats["metal"]])

func _assign_materials(root: Node, mat_plaster: Material, mat_trim: Material, mat_metal: Material, stats: Dictionary, floor_mats: Dictionary = {}) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var kind := "trim"
			var src := _first_material_name(mi)
			if src.find("PLASTER") >= 0:
				kind = "plaster"
			elif src.find("METAL") >= 0:
				kind = "metal"
			elif src.begins_with("FLOOR_"):
				kind = "floor"
			mi.material_override = {
				"plaster": mat_plaster, "trim": mat_trim, "metal": mat_metal,
				"floor": floor_mats.get(src, mat_trim)
			}[kind]
			stats["meshes"] = int(stats["meshes"]) + 1
			stats[kind] = int(stats[kind]) + 1
		for child in node.get_children():
			stack.append(child)

## Builder's plank/tile floors are full of see-through gaps; the Blender
## replacement floors cover them, so the old boards are simply hidden.
func _hide_old_floors() -> void:
	var builder := get_tree().get_first_node_in_group("world_root") as Node
	if builder == null:
		builder = get_tree().root.get_node_or_null("GameRoot/Apartment")
	if builder == null:
		# Последний резерв: рекурсивный поиск корня квартиры по имени из game.gd.
		builder = get_tree().root.find_child("Apartment", true, false)
	if builder == null:
		print("TRIM_FLOORS_REPLACED skipped=no_builder")
		return
	var hidden := 0
	var prefixes_lower: Array[String] = []
	for prefix in HIDE_PREFIXES:
		prefixes_lower.append(String(prefix).to_lower())
	var stack: Array[Node] = [builder]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var lname := String(node.name).to_lower()
			for prefix in prefixes_lower:
				if lname.begins_with(prefix):
					(node as MeshInstance3D).visible = false
					hidden += 1
					break
		for child in node.get_children():
			stack.append(child)
	print("TRIM_FLOORS_REPLACED hidden=%d" % hidden)

func _first_material_name(mi: MeshInstance3D) -> String:
	if mi.mesh == null:
		return ""
	for s in range(mi.mesh.get_surface_count()):
		var m := mi.mesh.surface_get_material(s)
		if m != null:
			return String(m.resource_name)
	return ""

func _find_shared_material(hex_lower: String) -> StandardMaterial3D:
	var stack: Array[Node] = []
	for child in get_tree().root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var m := mi.material_override as StandardMaterial3D
				if m.albedo_color.to_html(false).to_lower() == hex_lower:
					return m
		for child in node.get_children():
			stack.append(child)
	return null

func _fallback(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("c4c9c8")
	m.roughness = 0.30
	m.metallic = 0.55
	return m

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

func _on_scene_root_entered(node: Node) -> void:
	if node.scene_file_path != "res://scenes/game.tscn" or not _done:
		return
	_done = false
	mounted = false
	for child in get_children():
		child.queue_free()
	_run()
