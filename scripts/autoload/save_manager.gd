extends Node

signal game_saved(path: String)
signal game_loaded(path: String)

const SAVE_PATH := "user://denis_quicksave.json"
const RESET_PATHS := [
	"user://denis_quicksave.json",
	"user://tutorial_completed.flag",
	"user://coffee_leaderboard.json",
	"user://achievements.json",
]

var cat: RitaCat
var _web_reset_callback: Variant

func _ready() -> void:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge = Engine.get_singleton("JavaScriptBridge")
	var window = bridge.get_interface("window")
	_web_reset_callback = bridge.create_callback(Callable(self, "_on_web_reset_requested"))
	window.addEventListener("denis-reset-save", _web_reset_callback)

func reset_all_local_progress() -> void:
	for path in RESET_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _on_web_reset_requested(_arguments: Array) -> void:
	reset_all_local_progress()
	var bridge = Engine.get_singleton("JavaScriptBridge")
	bridge.eval("window.dispatchEvent(new Event('denis-save-reset-complete'));", true)

func register_cat(next_cat: RitaCat) -> void:
	cat = next_cat

func save_game() -> bool:
	if not is_instance_valid(cat):
		return false
	var p := cat.global_position
	var payload := {
		"version": 1,
		"cat": cat.get_save_data(),
		"cat_position": [p.x, p.y, p.z],
		"cat_story_was_active": cat.story_director.active_story != null,
		"active_cat_story": String(cat.story_director.active_story.story_id) if cat.story_director.active_story != null else "",
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	game_saved.emit(SAVE_PATH)
	return true

func load_game() -> bool:
	if not is_instance_valid(cat) or not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	var payload := parsed as Dictionary
	# Story scripts own temporary locks and moved props, so loading always runs
	# their cleanup path before restoring persistent deck/relationship state.
	cat.story_director.abort_current(&"load_game")
	cat.load_save_data(payload.get("cat", {}))
	var cancelled_story := StringName(payload.get("active_cat_story", ""))
	if cancelled_story != &"":
		cat.story_director.deck.mark_completed(cancelled_story)
	var saved_position: Array = payload.get("cat_position", [])
	if saved_position.size() == 3:
		cat.global_position = Vector3(float(saved_position[0]), maxf(0.1, float(saved_position[1])), float(saved_position[2]))
	cat.velocity = Vector3.ZERO
	cat.wants_motion = false
	cat.route.clear()
	cat.set_body_state(CatBodyController.BodyState.SIT)
	game_loaded.emit(SAVE_PATH)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		if save_game():
			QuestManager.notification_requested.emit("ИГРА СОХРАНЕНА")
	elif event.keycode == KEY_F9:
		if load_game():
			QuestManager.notification_requested.emit("ИГРА ЗАГРУЖЕНА")
