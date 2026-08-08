class_name CatDebugPanel
extends Node

var label: Label

func _ready() -> void:
	if "--cat-debug" not in OS.get_cmdline_user_args():
		set_process(false)
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	label = Label.new()
	label.position = Vector2(18, 300)
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.94, 0.88, 0.58)
	layer.add_child(label)

func _process(_delta: float) -> void:
	var cat := get_parent() as RitaCat
	if label == null or cat == null:
		return
	var state := cat.get_debug_state()
	var story: Dictionary = state.get("story", {})
	label.text = "CAT %s / %s\nDECK %s\nDONE %s\nSTORY %s PHASE %s\nCHAOS %s: %s\nCALM %.1fs\nTRUST %.0f  WARINESS %.0f" % [
		state.get("body", ""), state.get("intention", ""),
		story.get("deck", []), story.get("completed", []),
		story.get("active_story", ""), story.get("phase", 0),
		story.get("chaos", 0), cat.story_director.chaos.reasons,
		float(story.get("calm_left", 0.0)),
		float(state.get("relationship", {}).get("trust", 0.0)),
		float(state.get("relationship", {}).get("wariness", 0.0)),
	]
