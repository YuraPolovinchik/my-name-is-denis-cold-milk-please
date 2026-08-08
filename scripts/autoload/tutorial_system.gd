extends Node

signal tutorial_step_changed(step_id: String, text: String)
signal tutorial_completed()

var current_step: int = 0
var tutorial_active: bool = false
var _steps: Array[Dictionary] = []
var _completed_steps: Array[String] = []
var _tutorial_overlay: Control
var _skip_enabled: bool = true

func _ready() -> void:
	_define_tutorial_steps()

func _define_tutorial_steps() -> void:
	_steps = [
		{"id": "welcome", "text": "Добро пожаловать! Это игра 'Не Разбуди Риту'.\nНажмите любую клавишу для продолжения.", "key": "any"},
		{"id": "movement", "text": "WASD — движение\nShift — бег (громко)\nCtrl — присесть (тихо)\nAlt — на носочках", "key": "move"},
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
	_show_step(current_step)

func _show_step(index: int) -> void:
	if index >= _steps.size():
		_complete_tutorial()
		return
	var step: Dictionary = _steps[index]
	tutorial_step_changed.emit(step["id"], step["text"])

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
	tutorial_completed.emit()

func _complete_tutorial() -> void:
	tutorial_active = false
	tutorial_completed.emit()

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
