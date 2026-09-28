extends RefCounted

const ASSETS := "res://assets/furniture/artpass/"
var cache: Dictionary = {}
var world: Node

func apply(root: Node, stats: Dictionary) -> void:
	world = root.find_child("Apartment", true, false)
	if world == null:
		return
	# Original decoration overlaps the new, physically attached upholstery.
	for name in ["SofaPillowWarm", "SofaPillowBlue", "ThrowBlanket", "BedPillowMain", "BedPillowAccent", "FoldedThrow", "HamperClothes"]:
		_hide(world.find_child(name, true, false))
	var bath := world.find_child("BathroomFurniture", true, false) as Node3D
	if bath != null:
		var vanity := _add(bath, "vanity", Vector3.ZERO)
		if vanity != null:
			_hide(bath.get_node_or_null("Vanity"))
			_hide(bath.get_node_or_null("VanityTop"))
		var toilet := _add(bath, "toilet", Vector3(1.10, 0.04, 4.50))
		if toilet != null:
			_hide(bath.get_node_or_null("ToiletBase"))
			_hide(bath.get_node_or_null("ToiletTank"))
	var sink := world.find_child("BathroomSink", true, false) as Node3D
	if sink != null and _add(sink, "faucet", Vector3.ZERO) != null:
		_hide(sink.get_node_or_null("Tap"))
	var washer := world.find_child("WashingMachine", true, false) as Node3D
	if washer != null:
		var cabinet := washer.get_node_or_null("Cabinet") as MeshInstance3D
		if cabinet != null:
			_fit(cabinet, "washer_cabinet")
	if _add(world as Node3D, "shower_hardware", Vector3.ZERO) != null:
		for name in ["ShowerRail", "ShowerHead", "ShowerHose"]:
			_hide(world.find_child(name, true, false))
	var bench := world.find_child("WardrobeBench", true, false) as Node3D
	if bench != null and _add(bench, "bench", Vector3.ZERO) != null:
		for child in bench.get_children():
			if child is MeshInstance3D:
				_hide(child)
	var bed := world.find_child("Bed", true, false) as Node3D
	if bed != null and _add(bed, "rita_portrait", Vector3(-0.82, 0.99, -0.28)) != null:
		_hide(bed.get_node_or_null("RitaHead"))
		_hide(bed.get_node_or_null("RitaHair"))
	_finish_surfaces()
	var meshes := world.find_children("*", "MeshInstance3D", true, false)
	var fitted := 0
	for item in meshes:
		var mi := item as MeshInstance3D
		var key := String(mi.name)
		var existing := mi.get_active_material(0) as StandardMaterial3D
		if existing != null:
			var hex := existing.albedo_color.to_html(false)
			if hex == "d9b86c":
				existing.albedo_color = Color("c1b59a")
			elif hex == "365b62":
				existing.albedo_color = Color("52625c")
		if (key.begins_with("HangingGarment_") or key.begins_with("Coat_")):
			# Sleeves need more width than the old flat placeholder, but stay inside the rack.
			var model := _fit(mi, "garment")
			if model != null:
				model.scale.z *= 1.6
				for part in model.find_children("*", "MeshInstance3D", true, false):
					var material: Material = part.get_active_material(0)
					if material != null and material.resource_name == "Atelier_Ink":
						part.material_override = mi.get_active_material(0)
				fitted += 1
		elif key in ["LaundryHamper", "BathroomHamper"]:
			if _fit(mi, "hamper") != null:
				fitted += 1
		elif key.begins_with("FoldedTowel_"):
			if _fit(mi, "folded_linen") != null:
				fitted += 1
	for node in world.find_children("FoldedClothes_*", "", true, false):
		for child in node.get_children():
			if child is MeshInstance3D and _fit(child, "folded_linen") != null:
				fitted += 1
	for node in world.find_children("WardrobeLaundryBasket", "", true, false):
		for child in node.get_children():
			if child is MeshInstance3D and _fit(child, "hamper") != null:
				fitted += 1
	_hide(world.find_child("BathroomHamperLid", true, false))
	# Bevel visible rigid objects without replacing their physics bodies or scripts.
	var rounded := 0
	for item in meshes:
		var mi := item as MeshInstance3D
		if not mi.is_visible_in_tree() or not mi.mesh is BoxMesh or mi.get_parent() == world:
			continue
		var size: Vector3 = (mi.mesh as BoxMesh).size
		if minf(size.x, minf(size.y, size.z)) < 0.015 or maxf(size.x, maxf(size.y, size.z)) > 4.0:
			continue
		var material := mi.get_active_material(0)
		if material is BaseMaterial3D and (material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL):
			continue
		mi.material_override = material
		mi.mesh = _rounded_box(size)
		mi.add_to_group("room_beveled")
		rounded += 1
	stats["room_models"] = world.get_tree().get_nodes_in_group("room_art").size()
	stats["beveled_objects"] = rounded

func _hide(node: Node) -> void:
	if node is Node3D:
		node.visible = false

func _add(parent: Node3D, asset: String, pos: Vector3) -> Node3D:
	var packed := load(ASSETS + asset + ".glb") as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	model.name = "RoomArt_" + asset
	parent.add_child(model)
	model.add_to_group("room_art")
	model.position = pos
	return model

func _fit(source: MeshInstance3D, asset: String) -> Node3D:
	var model := _add(source.get_parent() as Node3D, asset, Vector3.ZERO)
	if model == null:
		return null
	var bounds := AABB()
	var has_bounds := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(box) if has_bounds else box
		has_bounds = true
	if not has_bounds:
		model.queue_free()
		return null
	var target := source.get_aabb()
	var ratio := target.size / bounds.size.max(Vector3.ONE * 0.001)
	var local := Transform3D(Basis.from_scale(ratio), target.get_center() - bounds.get_center() * ratio)
	model.transform = source.transform * local
	source.hide()
	return model

func _rounded_box(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if cache.has(key):
		return cache[key]
	var radius := minf(0.024, minf(size.x, minf(size.y, size.z)) * 0.18)
	var half := size * 0.5
	var core := half - Vector3.ONE * radius
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in range(3):
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var us := [-half[u_axis], -core[u_axis], core[u_axis], half[u_axis]]
		var vs := [-half[v_axis], -core[v_axis], core[v_axis], half[v_axis]]
		for side in [-1.0, 1.0]:
			for i in range(3):
				for j in range(3):
					var points: Array[Vector3] = []
					for uv in [Vector2(i,j), Vector2(i+1,j), Vector2(i+1,j+1), Vector2(i,j+1)]:
						var p := Vector3.ZERO
						p[axis] = side * half[axis]
						p[u_axis] = us[int(uv.x)]
						p[v_axis] = vs[int(uv.y)]
						points.append(p)
					var indices := [0,2,1,0,3,2] if side > 0 else [0,1,2,0,2,3]
					for index in indices:
						var p: Vector3 = points[index]
						var inner := p.clamp(-core, core)
						var normal := (p - inner).normalized()
						surface.set_normal(normal)
						surface.set_uv(Vector2(p[u_axis] / size[u_axis] + 0.5, p[v_axis] / size[v_axis] + 0.5))
						surface.add_vertex(inner + normal * radius)
	surface.generate_tangents()
	var result := surface.commit()
	cache[key] = result
	return result

func _finish_surfaces() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 t=vec2(wp.x+wp.z,wp.y)/vec2(0.30,0.15);t.x+=mod(floor(t.y),2.0)*0.5;vec2 f=fract(t);vec2 e=min(f,1.0-f);float d=min(e.x*0.30,e.y*0.15);float aa=max(fwidth(d),0.0001);float grout=1.0-smoothstep(0.0012-aa,0.0012+aa,d);float variation=fract(sin(dot(floor(t),vec2(12.9,78.2)))*437.1)*0.025;ALBEDO=mix(vec3(0.62,0.66,0.61)+variation,vec3(0.46,0.47,0.44),grout);ROUGHNESS=0.43;}"
	var tile := ShaderMaterial.new()
	tile.shader = shader
	_panel("BathSouthWainscot", Vector3(4.8,.78,6.375),Vector3(6.05,1.45,.024),tile)
	_panel("BathEastWainscot", Vector3(7.875,.78,4.25),Vector3(.024,1.45,4.15),tile)
	_panel("KitchenNorthSplash", Vector3(5.32,1.34,-6.365),Vector3(3.4,.55,.024),tile)
	_panel("KitchenEastSplash", Vector3(7.875,1.35,-3.55),Vector3(.024,.57,2.0),tile)
	var silver := StandardMaterial3D.new()
	# Compatibility has no planar reflections. A light silver surface reads as
	# glass under room lights without turning into an opaque black rectangle.
	silver.albedo_color = Color(.48,.54,.55)
	silver.metallic = .08
	silver.roughness = .18
	for mirror_name in ["Mirror", "OutsideMirror"]:
		for mirror in world.find_children(mirror_name, "MeshInstance3D", true, false):
			mirror.material_override = silver
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(.27,.21,.15)
	bronze.metallic = .42
	bronze.roughness = .35
	for frame in [
		["BathMirrorTop", Vector3(7.86,2.29,3.10),Vector3(.055,.035,.99)],
		["BathMirrorBottom", Vector3(7.86,1.11,3.10),Vector3(.055,.035,.99)],
		["BathMirrorLeft", Vector3(7.86,1.70,2.62),Vector3(.055,1.19,.035)],
		["BathMirrorRight", Vector3(7.86,1.70,3.58),Vector3(.055,1.19,.035)],
		["HallMirrorTop", Vector3(-1.43,2.375,2.62),Vector3(.055,.035,.80)],
		["HallMirrorBottom", Vector3(-1.43,1.065,2.62),Vector3(.055,.035,.80)],
		["HallMirrorLeft", Vector3(-1.43,1.72,2.24),Vector3(.055,1.30,.035)],
		["HallMirrorRight", Vector3(-1.43,1.72,3.00),Vector3(.055,1.30,.035)],
	]:
		_panel(frame[0],frame[1],frame[2],bronze)

func _panel(name: String, position: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	world.add_child(node)
