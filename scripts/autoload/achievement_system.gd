extends Node

signal achievement_unlocked(achievement_id: String, title: String, description: String)

var _achievements: Dictionary = {}
var _unlocked: Array[String] = []
var _progress: Dictionary = {}
var _save_path: String = "user://achievements.json"

func _ready() -> void:
	_load_achievements()
	_define_achievements()

func _define_achievements() -> void:
	_register_achievement("silent_ninja", "Тихий Ниндзя", "Пройдите игру без громких действий", 0)
	_register_achievement("coffee_master", "Мастер Кофе", "Сделайте идеальный кофе за менее 120 секунд", 0)
	_register_achievement("rita_survivor", "Выживший", "Пройдите игру без пробуждения Риты", 0)
	_register_achievement("rich_denis", "Богатый Денис", "Накопите более 2000 рублей", 0)
	_register_achievement("football_fan", "Фанат Футбола", "Посмотрите 3 опасных момента", 0)
	_register_achievement("beer_lover", "Любитель Пива", "Выпейте 5 глотов пива", 0)
	_register_achievement("speed_runner", "Спидраннер", "Пройдите игру за менее 90 секунд", 0)
	_register_achievement("perfectionist", "Перфекционист", "Пройдите игру без долгов и пропущенных звонков", 0)
	_register_achievement("ghost", "Призрак", "Пройдите игру без единого шума", 0)
	_register_achievement("economist", "Экономист", "Соберите все спрятанные деньги", 0)
	# Новые достижения
	_register_achievement("first_coffee", "Первая Чашка", "Сделайте свой первый кофе", 0)
	_register_achievement("coffee_regular", "Кофейный Завсегдатай", "Сделайте 3 чашки кофе", 0)
	_register_achievement("ghost_runner", "Призрачный Бегун", "Пройдите игру не разбудив Риту", 0)
	_register_achievement("speed_demon", "Скоростной Демон", "Завершите забег меньше чем за 3 минуты", 0)
	_register_achievement("perfect_run", "Идеальный Забег", "Получите ранг S", 0)
	_register_achievement("money_bags", "Мешок Денег", "Найдите 2000+ рублей за забег", 0)
	_register_achievement("clumsy", "Неуклюжий", "Разбудите Риту 5 раз", 0)
	_register_achievement("butterfingers", "Руки-Крюки", "Уроните 10 предметов", 0)
	# Достижения, на которые уже ссылаются проверки забега (run_stats._check_achievements)
	_register_achievement("sniper_pour", "Снайпер Разлива", "Разлейте молоко и воду почти без потерь (точность 99.5%+)", 0)
	_register_achievement("zero_spill", "Ни Капли Мимо", "Идеальный забег: ни капли не пролито (точность 100%)", 0)

func _register_achievement(id: String, title: String, description: String, progress_needed: int) -> void:
	_achievements[id] = {
		"title": title,
		"description": description,
		"progress_needed": progress_needed,
		"unlocked": false
	}

func unlock_achievement(id: String) -> void:
	if not _achievements.has(id):
		return
	var achievement: Dictionary = _achievements[id]
	if achievement["unlocked"]:
		return
	achievement["unlocked"] = true
	_unlocked.append(id)
	achievement_unlocked.emit(id, achievement["title"], achievement["description"])
	_save_achievements()

func increment_progress(id: String, amount: int = 1) -> void:
	if not _progress.has(id):
		_progress[id] = 0
	_progress[id] = int(_progress[id]) + amount
	var achievement: Dictionary = _achievements.get(id, {})
	if achievement.is_empty():
		return
	if int(_progress[id]) >= int(achievement.get("progress_needed", 0)) and int(achievement.get("progress_needed", 0)) > 0:
		unlock_achievement(id)

## Вызывается при успешном приготовлении кофе
func on_coffee_made() -> void:
	increment_progress("coffee_made")
	if get_progress("coffee_made") >= 3:
		unlock_achievement("coffee_regular")
	unlock_achievement("first_coffee")

## Вызывается при пробуждении Риты
func on_rita_awakened(category: StringName) -> void:
	increment_progress("rita_awakened")
	if get_progress("rita_awakened") >= 5:
		unlock_achievement("clumsy")
	# Отслеживание для достижения "ghost" — если Рита проснулась, сбрасываем прогресс тихого прохождения
	if _progress.has("silent_run"):
		_progress.erase("silent_run")

## Вызывается при падении предмета
func on_item_dropped() -> void:
	increment_progress("items_dropped")
	if get_progress("items_dropped") >= 10:
		unlock_achievement("butterfingers")

## Вызывается при успешном завершении забега без пробуждения
func on_silent_run_completed() -> void:
	increment_progress("silent_run")
	if get_progress("silent_run") >= 3:
		unlock_achievement("ghost")

## Вызывается при просмотре футбола
func on_football_watched() -> void:
	increment_progress("football_watched")
	if get_progress("football_watched") >= 3:
		unlock_achievement("football_fan")

## Вызывается при выпивании пива
func on_beer_drank(amount: int = 1) -> void:
	increment_progress("beer_drank", amount)
	if get_progress("beer_drank") >= 5:
		unlock_achievement("beer_lover")

## Итоговые достижения забега — вызывается из RunStats.finish_run()
func evaluate_run_result(result: Dictionary) -> void:
	if result.get("rita_awake", true):
		return
	var run_time := float(result.get("time", INF))
	var balance := float(result.get("balance", -INF))
	# "Тихий Ниндзя" — без громких действий, пока Рита спит
	if int(result.get("loud_actions", 999)) == 0:
		unlock_achievement("silent_ninja")
	# "Выживший" — Рита ни разу не проснулась за забег
	unlock_achievement("rita_survivor")
	# "Мастер Кофе" — идеальный кофе быстрее 120 секунд
	if run_time <= 120.0:
		unlock_achievement("coffee_master")
	# "Богатый Денис" — баланс выше 2000 рублей на финише
	if balance >= 2000.0:
		unlock_achievement("rich_denis")
	# "Спидраннер" — забег быстрее 90 секунд
	if run_time <= 90.0:
		unlock_achievement("speed_runner")
	# "Экономист" — собраны все спрятанные тайники квартиры
	var stashes_total := int(result.get("cash_stashes_total", 0))
	var stashes_collected := int(result.get("cash_stashes_collected", 0))
	if stashes_total > 0 and stashes_collected >= stashes_total:
		unlock_achievement("economist")

func is_unlocked(id: String) -> bool:
	return _achievements.has(id) and bool(_achievements[id].get("unlocked", false))

func get_progress(id: String) -> int:
	return int(_progress.get(id, 0))

func get_all_achievements() -> Dictionary:
	return _achievements.duplicate(true)

func get_unlocked_count() -> int:
	return _unlocked.size()

func _save_achievements() -> void:
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"unlocked": _unlocked,
		"progress": _progress
	}
	file.store_string(JSON.stringify(data))
	file.close()

func _load_achievements() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var raw_unlocked: Array = data.get("unlocked", [])
		_unlocked = []
		for item in raw_unlocked:
			if item is String:
				_unlocked.append(item)
		_progress = data.get("progress", {})
