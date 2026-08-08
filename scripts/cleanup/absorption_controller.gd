class_name AbsorptionController
extends Node

@export var absorption_capacity_ml := 400.0
var absorbed_ml := 0.0
var wetness := 0.0
var stain_color := Color("143d3b")

func remaining_capacity_ml() -> float:
	return maxf(0.0, absorption_capacity_ml - absorbed_ml)

func absorb(liquid_type: String, requested_ml: float) -> float:
	if requested_ml <= 0.0 or remaining_capacity_ml() <= 0.0:
		return 0.0
	var liquid_factor := 1.0
	if liquid_type == "milk":
		liquid_factor = 0.72
	elif liquid_type == "coffee_mix":
		liquid_factor = 0.82
	var saturation_factor := lerpf(1.0, 0.42, wetness)
	var actual := minf(requested_ml * liquid_factor * saturation_factor, remaining_capacity_ml())
	absorbed_ml += actual
	wetness = clampf(absorbed_ml / absorption_capacity_ml, 0.0, 1.0)
	var liquid_color := Color("779bc2")
	if liquid_type == "milk":
		liquid_color = Color("d8d4c9")
	elif liquid_type == "coffee_mix":
		liquid_color = Color("3b1d0f")
	stain_color = stain_color.lerp(liquid_color, clampf(actual / 90.0, 0.04, 0.35))
	RunStats.record_cleaned_liquid(actual, liquid_type)
	_update_visual()
	return actual

func get_state() -> Dictionary:
	return {
		"capacity_ml": absorption_capacity_ml,
		"absorbed_ml": absorbed_ml,
		"wetness": wetness,
	}

func _update_visual() -> void:
	var visual := get_parent().get_node_or_null("Visual") as MeshInstance3D
	if visual == null or visual.material_override == null:
		return
	var material := visual.material_override
	if not bool(visual.get_meta("absorption_material_owned", false)):
		material = material.duplicate()
		visual.material_override = material
		visual.set_meta("absorption_material_owned", true)
	if material is StandardMaterial3D:
		var wet := stain_color.darkened(0.38)
		(material as StandardMaterial3D).albedo_color = Color("143d3b").lerp(wet, wetness)
