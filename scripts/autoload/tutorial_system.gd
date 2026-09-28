extends CanvasLayer

signal tutorial_step_changed(step_id: String, text: String)
signal tutorial_completed()

const UI_FONT: FontFile = preload("res://assets/fonts/NotoSans-Variable.ttf")

var current_step: int = 0
var tutorial_active: bool = false
var _steps: Array[Dictionary] = []
var _completed_steps: Array[String] = []
var _skip_enabled: bool = true
var _root: Control
var _panel: Panel
var _title_label: Label
var _text_label: Label
var _hint_label: Label
var _any_key_pending := false

func _ready() -> void:
	_define_tutorial_steps()
	layer = 25

func _define_tutorial_steps() -> void:
	_steps = [
		{"id": "welcome", "text": "Добро пожаловать! Это игра 'Не Разбуди Риту'.\nНажмите любую клавишу для продолжения.", "key": "any"},
		{"id": "movement", "text": "WASD — движение\nShift — бег (громко)\nC — присесть (тихо)\nAlt — на носочках", "key": "move"},
		{"id": "interaction", "text": "E — обычное взаимодействие\nУдерживать E — тихое\nShift+E — быстрое (громко)", "key": "interact"},
		{"id": "pickup", "text": "ЛКМ — взять предмет\nПКМ — аккуратно поставить\nR — повернуть предмет", "key": "pickup"},
		{"id": "noise", "text": "Следите за индикатором шума Риты!\nКрасный = она просыпается", "key": "any"},
		{"id": "economy", "text": "Следите за балансом!\nПропущенные платежи = долг", "key": "any"},
		{"id": "hide", "text": "Если Рита проснулась — бегите в гардеробную!\nСидите тихо, пока она не успокоится", "key": "any"},
		{"id": "complete", "text": "Обучение завершено!\nУдачи, Денис!", "key": "any"}
	]

func start_tutorial() -> void:
	if tutorial_active:
		return
	tutorial_active = true
	current_step = 0
	_ensure_overlay()
	_show_step(current_step)

func _show_step(index: int) -> void:
	if index >= _steps.size():
		_complete_tutorial()
		return
	var step: Dictionary = _steps[index]
	tutorial_step_changed.emit(step["id"], step["text"])
	_update_overlay(step)

func advance_tutorial() -> void:
	if not tutorial_active:
		return
	_completed_steps.append(_steps[current_step]["id"])
	current_step += 1
	if current_step >= _steps.size():
		_complete_tutorial()
	else:
		_show_step(current_step)

func skip_tutorial() -> void:
	if not _skip_enabled:
		return
	tutorial_active = false
	_hide_overlay()
	tutorial_completed.emit()

func _complete_tutorial() -> void:
	tutorial_active = false
	_hide_overlay()
	tutorial_completed.emit()

## Количество шагов обучения (для отображения прогресса в HUD)
func get_step_count() -> int:
	return _steps.size()

## Идентификатор текущего шага (для привязки к вводу в HUD)
func get_current_step_id() -> String:
	if current_step < _steps.size():
		return String(_steps[current_step]["id"])
	return ""

## Проверить, нужно ли показывать обучение (первый запуск)
func should_show_tutorial() -> bool:
	# Проверяем, прошел ли игрок обучение ранее
	var save_path := "user://tutorial_completed.flag"
	return not FileAccess.file_exists(save_path)

## Отметить обучение как пройденное
func mark_tutorial_completed() -> void:
	var save_path := "user://tutorial_completed.flag"
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string("completed")
		file.close()

func is_tutorial_completed() -> bool:
	return _completed_steps.size() >= _steps.size()

func get_current_step_text() -> String:
	if current_step < _steps.size():
		return String(_steps[current_step]["text"])
	return ""

# ------------------------------------------------------------------
# Оверлей обучения. Строится лениво при старте, чтобы не трогать HUD.
# Стиль повторяет панели HUD (тёмное стекло + золотой заголовок).
# ------------------------------------------------------------------

func _ensure_overlay() -> void:
	if _root != null and is_instance_valid(_root):
		return
	var root := Control.new()
	root.name = "TutorialOverlay"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_root = root
	_panel = Panel.new()
	_panel.position = Vector2(880, 436)
	_panel.size = Vector2(384, 204)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.048, 0.06, 0.94)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.10)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	_title_label = _make_label(_panel, Vector2(18, 14), Vector2(348, 24), 15, Color("edbd68"))
	_title_label.text = "ОБУЧЕНИЕ"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label = _make_label(_panel, Vector2(18, 48), Vector2(348, 108), 14, Color("f2eee6"))
	_hint_label = _make_label(_panel, Vector2(18, 168), Vector2(348, 24), 12, Color("76b7d7"))
	_hint_label.text = "ESC — пропустить"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.visible = false

func _make_label(parent: Node, pos: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _update_overlay(step: Dictionary) -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var total := get_step_count()
	_title_label.text = "ОБУЧЕНИЕ  %d/%d" % [mini(current_step + 1, total), total]
	_text_label.text = String(step.get("text", ""))
	_hint_label.text = _hint_for(String(step.get("id", "")))
	_panel.visible = true

func _hide_overlay() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false
	if _root != null and is_instance_valid(_root):
		_root.visible = false

func _hint_for(step_id: String) -> String:
	match step_id:
		"movement":
			return "W / A / S / D — продолжить"
		"interaction":
			return "E — продолжить"
		"pickup":
			return "ЛКМ (взять предмет) — продолжить"
		_:
			return "Любая клавиша — далее   ESC — пропустить"

func _input(event: InputEvent) -> void:
	if not tutorial_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			skip_tutorial()
		else:
			_any_key_pending = true
	elif event is InputEventMouseButton and event.pressed:
		_any_key_pending = true

func _process(_delta: float) -> void:
	if not tutorial_active:
		return
	var any_key := _any_key_pending
	_any_key_pending = false
	match get_current_step_id():
		"movement":
			for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
				if Input.is_action_just_pressed(action):
					advance_tutorial()
					break
		"interact", "interaction":
			if Input.is_action_just_pressed(&"interact"):
				advance_tutorial()
		"pickup":
			if Input.is_action_just_pressed(&"pickup"):
				advance_tutorial()
		_:
			if any_key:
				advance_tutorial()
