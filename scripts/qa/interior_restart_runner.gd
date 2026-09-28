extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	for frame in range(100):
		await process_frame
	var first := _inspect()
	if first.is_empty():
		quit(1)
		return
	reload_current_scene()
	for frame in range(100):
		await process_frame
	var second := _inspect()
	if first != second:
		push_error("Art pass changed across restart: %s / %s" % [first, second])
		quit(2)
		return
	print("INTERIOR_RESTART_TEST_OK %s" % second)
	quit(0)

func _inspect() -> Dictionary:
	var game := current_scene
	var sofa := game.find_child("Sofa", true, false) if game != null else null
	if sofa == null or sofa.get_node_or_null("ModelReplacement") == null:
		push_error("Missing upgraded sofa")
		return {}
	var bed := game.find_child("Bed", true, false)
	if bed == null or bed.get_node_or_null("ArtpassBed") == null:
		push_error("Missing upgraded bed")
		return {}
	if bed.get_node_or_null("RoomArt_rita_portrait") == null or bed.get_node("RitaHead").visible:
		push_error("Rita portrait replacement was not mounted")
		return {}
	var trim := game.find_child("ApartmentTrim", true, false)
	if trim == null:
		push_error("Missing Blender architectural trim")
		return {}
	for required in ["RoomArt_toilet", "RoomArt_vanity", "RoomArt_shower_hardware", "RoomArt_bench", "RoomArt_faucet", "RoomArt_washer_cabinet"]:
		if game.find_child(required, true, false) == null:
			push_error("Missing room detail: " + required)
			return {}
	if get_nodes_in_group("room_art").size() < 34 or get_nodes_in_group("room_beveled").size() < 250:
		push_error("Room art pass did not finish")
		return {}
	return {"room_models": get_nodes_in_group("room_art").size(), "beveled": get_nodes_in_group("room_beveled").size(), "collision_shapes": game.find_children("*", "CollisionShape3D", true, false).size(), "graphics_children": root.get_node("GraphicsEnhancer").get_child_count(), "furniture_children": root.get_node("FurnitureEnhancer").get_child_count(), "sofa_shapes": sofa.find_children("*", "CollisionShape3D", true, false).size()}
