extends Node

## FurnitureEnhancer — заменяет мебель авторскими Blender-моделями artpass
## и моделями Kenney Furniture Kit, добавляет декор помещений.
## Принцип: тело мебели (RigidBody3D) и его коллизии остаются нетронутыми —
## скрываются только дочерние меши, а на их место по AABB встаёт GLB-модель,
## смасштабированная под габариты оригинала. Перетаскивание, шумы, интеракции
## продолжают работать как раньше. Материалы моделей помечаются gfx_done,
## поэтому текстурный пасс GraphicsEnhancer их не перекрашивает.

const ROOM_ART := preload("res://scripts/room_art_pass.gd")
const WAIT_FRAMES := 300
const MODEL_DIR := "res://assets/furniture/"

# Корень мебели из apartment_builder -> [файл модели, поворот в градусах].
const REPLACEMENTS := {
	"Sofa": ["artpass/sofa.glb", 0.0],
	"CoffeeTable": ["artpass/coffee_table.glb", 0.0],
	"TVConsole": ["artpass/tv_console.glb", 0.0],
	"Bookshelf": ["artpass/bookshelf.glb", 0.0],
	"OfficeChair": ["artpass/office_chair.glb", 0.0],
	"WorkDesk": ["artpass/desk.glb", 0.0],
	"Nightstand": ["artpass/nightstand.glb", 0.0],
	"BedroomDresser": ["artpass/dresser.glb", 0.0],
	"DiningArea": ["artpass/dining_table.glb", 0.0],
	"DiningChair": ["artpass/dining_chair.glb", 0.0],
	"HallConsole": ["artpass/hall_console.glb", 0.0],
	"ShoeBench": ["artpass/shoe_bench.glb", 0.0],
	"ShoeLeft": ["artpass/sneaker.glb", 0.0],
	"ShoeRight": ["artpass/sneaker.glb", 0.0],
	"Toaster": ["toaster.glb", 0.0],
	"NotebookStack": ["books.glb", 0.0],
	"DeskLamp": ["lampSquareTable.glb", 0.0],
	"Plant": ["artpass/plant.glb", 0.0],
}

# Свободный декор: [имя, файл, позиция, yaw, масштаб].
const DECOR := [
	["DecorBooks", "books.glb", Vector3(-5.45, 0.46, 0.08), 14.0, 1.0],
	["DecorFloorLamp", "lampRoundFloor.glb", Vector3(-7.30, 0.0, 2.85), 0.0, 1.0],
	["DecorDoormat", "rugDoormat.glb", Vector3(0.35, 0.0, 6.02), 0.0, 1.0],
	["DecorBear", "bear.glb", Vector3(-6.30, 0.86, 4.38), 155.0, 1.0],
	["DecorPlantKitchen", "plantSmall2.glb", Vector3(7.52, 1.06, -5.72), 0.0, 1.0],
	["DecorPlantDesk", "plantSmall3.glb", Vector3(-6.35, 0.84, -5.28), 40.0, 1.0],
	["DecorRadio", "radio.glb", Vector3(-6.55, 1.96, 1.45), 90.0, 1.0],
	["DecorSpeaker", "speaker.glb", Vector3(-1.35, 0.71, -0.20), 90.0, 1.0],
	["DecorTrash", "trashcan.glb", Vector3(7.18, 0.0, -0.12), 0.0, 1.0],
	["DecorBox", "cardboardBoxOpen.glb", Vector3(-4.15, 0.0, 6.92), 25.0, 1.0],
	["DecorCoffeeMachine", "kitchenCoffeeMachine.glb", Vector3(5.60, 1.03, -5.90), 0.0, 1.0],
	["DecorBlender", "kitchenBlender.glb", Vector3(7.49, 1.03, -4.60), 90.0, 1.0],
	["DecorMicrowave", "kitchenMicrowave.glb", Vector3(6.20, 1.03, -6.00), 0.0, 1.0],
]

var _done := false

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
	var stats := {}
	_replace_furniture(stats)
	_add_decor(stats)
	_upgrade_bed(stats)
	ROOM_ART.new().apply(get_tree().root, stats)
	var summary := []
	for key in stats:
		summary.append("%s=%d" % [key, stats[key]])
	print("FURNITURE_ENHANCED_OK %s" % " ".join(summary))

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

# ---------- Обход и замена ----------

func _replace_furniture(stats: Dictionary) -> void:
	var stack: Array[Node] = []
	for child in get_tree().root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D:
			var root := node as Node3D
			var key := String(root.name)
			if REPLACEMENTS.has(key) and not root.has_meta("furn_done") and not root is Light3D:
				root.set_meta("furn_done", true)
				stats[key] = int(stats.get(key, 0)) + 1
				_replace_root(root, key, stats)
		for child in node.get_children():
			stack.append(child)

func _replace_root(root: Node3D, key: String, stats: Dictionary) -> void:
	var cfg: Array = REPLACEMENTS[key]
	var target := _local_aabb(root)
	if not bool(target["ok"]):
		stats["skip_no_mesh"] = int(stats.get("skip_no_mesh", 0)) + 1
		return
	var packed: PackedScene = load(MODEL_DIR + String(cfg[0]))
	if packed == null:
		stats["missing_model"] = int(stats.get("missing_model", 0)) + 1
		return
	var inst := packed.instantiate() as Node3D
	if inst == null:
		stats["missing_model"] = int(stats.get("missing_model", 0)) + 1
		return
	var tgt: AABB = target["aabb"]
	var ma := _local_aabb(inst)
	if not bool(ma["ok"]):
		stats["missing_model"] = int(stats.get("missing_model", 0)) + 1
		inst.queue_free()
		return
	var model_aabb: AABB = ma["aabb"]
	var yaw: float = float(cfg[1])
	inst.scale = Vector3(
		tgt.size.x / maxf(model_aabb.size.x, 0.001),
		tgt.size.y / maxf(model_aabb.size.y, 0.001),
		tgt.size.z / maxf(model_aabb.size.z, 0.001))
	inst.rotation_degrees.y = yaw
	# Совмещаем: низ модели на низ оригинала, центры XZ совпадают.
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var b0 := basis * (model_aabb.position * inst.scale)
	var b1 := basis * ((model_aabb.position + model_aabb.size) * inst.scale)
	var tmin := Vector3(minf(b0.x, b1.x), minf(b0.y, b1.y), minf(b0.z, b1.z))
	var tmax := Vector3(maxf(b0.x, b1.x), maxf(b0.y, b1.y), maxf(b0.z, b1.z))
	inst.position = Vector3(
		(tgt.position.x + tgt.size.x * 0.5) - (tmin.x + tmax.x) * 0.5,
		tgt.position.y - tmin.y,
		(tgt.position.z + tgt.size.z * 0.5) - (tmin.z + tmax.z) * 0.5)
	inst.name = "ModelReplacement"
	_mark_materials(inst)
	_hide_source_meshes(root)
	root.add_child(inst)
	stats["replaced"] = int(stats.get("replaced", 0)) + 1

func _hide_source_meshes(root: Node3D) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false
		for child in node.get_children():
			stack.append(child)

func _mark_materials(root: Node) -> void:
	# Помечаем материалы модели, чтобы текстурный пасс GraphicsEnhancer
	# не перекрашивал авторские цвета Kenney.
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var m := mi.material_override
			if m != null:
				m.set_meta("gfx_done", true)
			if mi.mesh != null:
				for i in range(mi.mesh.get_surface_count()):
					var sm := mi.mesh.surface_get_material(i)
					if sm != null:
						sm.set_meta("gfx_done", true)
			var am := mi.get_active_material(0)
			if am != null:
				am.set_meta("gfx_done", true)
		for child in node.get_children():
			stack.append(child)

# Объединённый AABB всех мешей в локальной системе root.
func _local_aabb(root: Node3D) -> Dictionary:
	var has := false
	var total := AABB()
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xform: Transform3D = pair[1]
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var box: AABB = xform * mi.get_aabb()
			if has:
				total = total.merge(box)
			else:
				total = box
				has = true
		for child in node.get_children():
			var next_x := xform
			if child is Node3D:
				next_x = xform * (child as Node3D).transform
			stack.append([child, next_x])
	return {"ok": has, "aabb": total}

# ---------- Свободный декор ----------

func _add_decor(stats: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "FurnitureDecor"
	add_child(holder)
	for entry in DECOR:
		var packed: PackedScene = load(MODEL_DIR + String(entry[1]))
		if packed == null:
			stats["missing_model"] = int(stats.get("missing_model", 0)) + 1
			continue
		var inst := packed.instantiate() as Node3D
		if inst == null:
			stats["missing_model"] = int(stats.get("missing_model", 0)) + 1
			continue
		inst.name = String(entry[0])
		inst.position = entry[2]
		inst.rotation_degrees.y = float(entry[3])
		inst.scale = Vector3.ONE * float(entry[4])
		_mark_materials(inst)
		holder.add_child(inst)
		stats["decor"] = int(stats.get("decor", 0)) + 1

func _upgrade_bed(stats: Dictionary) -> void:
	var bed := get_tree().root.find_child("Bed", true, false) as Node3D
	var packed := load(MODEL_DIR + "artpass/bed.glb") as PackedScene
	if bed == null or packed == null:
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	for child in bed.get_children():
		if child is MeshInstance3D and child.name in ["BedBase", "Headboard", "Mattress", "Duvet", "RitaBody"]:
			child.visible = false
	model.name = "ArtpassBed"
	bed.add_child(model)
	stats["bed"] = 1

func _on_scene_root_entered(node: Node) -> void:
	if node.scene_file_path != "res://scenes/game.tscn" or not _done:
		return
	_done = false
	for child in get_children():
		child.queue_free()
	_run()
