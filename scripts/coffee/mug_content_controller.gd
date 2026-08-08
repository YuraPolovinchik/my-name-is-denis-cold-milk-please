# MugContentController.gd
# Управляет содержимым кружки: объём жидкостей (мл), порошок (граммы),
# температура, перемешивание, перелив.
# Единицы: жидкости в мл, порошок в граммах (§3 миссии).
class_name MugContentController
extends Node

## Сигнал: содержимое изменилось (для UI/визуала)
signal content_changed(components: Dictionary)
signal mug_contents_changed(components: Dictionary)

## Сигнал: кофе готов к употреблению (все условия выполнены)
signal coffee_ready()

## Сигнал: кружка переполнена — излишек пролился
signal overflowed(amount_ml: float, position: Vector3)
signal mug_overflowed(amount_ml: float, position: Vector3)

## Сигнал: температура изменилась
signal temperature_changed(temp_c: float)


## Ёмкость кружки (мл)
@export var capacity_ml: float = 350.0

## Минимальные пороги готовности
const WATER_MIN_ML: float = 170.0
const WATER_REC_MIN_ML: float = 200.0
const WATER_REC_MAX_ML: float = 230.0
const POWDER_MIN_G: float = 2.0
const POWDER_REC_MIN_G: float = 3.0
const POWDER_REC_MAX_G: float = 5.0
const POWDER_MAX_G: float = 10.0
const MILK_MIN_ML: float = 25.0
const MILK_REC_MIN_ML: float = 40.0
const MILK_REC_MAX_ML: float = 70.0
## Минимальная температура для готового кофе (§5 миссии)
const TEMP_MIN_C: float = 70.0

## --- Состав (§3 миссии: жидкости в мл, порошок в граммах) ---
var water_ml: float = 0.0
var milk_ml: float = 0.0
var coffee_powder_g: float = 0.0  # ГРАММЫ, не мл

## Температура содержимого (°C)
var temperature_c: float = 20.0

## Перемешано ли ложкой (3+ оборота — §16 миссии)
var is_stirred: bool = false

## Был ли перелив (для статистики)
var was_overflowed: bool = false

## Флаг готовности
var is_ready: bool = false

## Остывание содержимого (°C/сек)
@export var cool_rate: float = 0.25


func _process(delta: float) -> void:
	# Плавное остывание
	if total_liquid_ml() > 0.0 and temperature_c > 20.0:
		temperature_c = maxf(20.0, temperature_c - cool_rate * delta)
		temperature_changed.emit(temperature_c)


## Общий объём жидкости (мл, порошок НЕ считается жидкостью).
func total_liquid_ml() -> float:
	return water_ml + milk_ml


## Добавить жидкость (мл). Возвращает реально принятый объём.
## Излишек → overflow с созданием пролива (§10 миссии).
func add_liquid(amount_ml: float, defn: LiquidDefinition, source_temp_c: float = 20.0) -> float:
	if amount_ml <= 0.0 or defn == null:
		return 0.0
	var space_left: float = capacity_ml - total_liquid_ml()
	var accepted: float = minf(amount_ml, maxf(space_left, 0.0))
	var overflow: float = amount_ml - accepted

	if accepted > 0.0:
		# Смешиваем температуру пропорционально объёмам
		var old_total := total_liquid_ml()
		var new_total := old_total + accepted
		if new_total > 0.0:
			temperature_c = (temperature_c * old_total + source_temp_c * accepted) / new_total
			temperature_changed.emit(temperature_c)
		match defn.id:
			"water":
				water_ml += accepted
			"milk":
				milk_ml += accepted
			"coffee_mix":
				# Горячая вода с растворённым кофе — пополам
				water_ml += accepted * 0.9
				coffee_powder_g += accepted * 0.1
			_:
				water_ml += accepted
		# Любое добавление жидкости сбрасывает перемешивание
		is_stirred = false

	if overflow > 0.0:
		was_overflowed = true
		var origin := Vector3.ZERO
		var parent_3d := get_parent() as Node3D
		if parent_3d:
			origin = parent_3d.global_position
		overflowed.emit(overflow, origin)
		mug_overflowed.emit(overflow, origin)
		# Создаём лужу перелива (coffee_mix)
		var sm := get_tree().get_first_node_in_group("spill_manager")
		if sm and sm.has_method("spawn_spill_typed"):
			sm.call("spawn_spill_typed", origin, "coffee_mix", overflow)

	_check_readiness()
	content_changed.emit(get_components())
	mug_contents_changed.emit(get_components())
	return accepted


## Добавить порошок (ГРАММЫ — §3/§15 миссии).
func add_powder(amount_g: float) -> float:
	if amount_g <= 0.0:
		return 0.0
	var accepted := minf(amount_g, maxf(POWDER_MAX_G - coffee_powder_g, 0.0))
	coffee_powder_g += accepted
	# Порошок не считается жидкостью, не вызывает перелив
	_check_readiness()
	content_changed.emit(get_components())
	mug_contents_changed.emit(get_components())
	return accepted


## Отметить перемешивание (вызывается StirController после 3+ оборотов).
func set_stirred() -> void:
	if is_stirred:
		return
	is_stirred = true
	_check_readiness()
	content_changed.emit(get_components())
	mug_contents_changed.emit(get_components())


## Словарь компонентов (для сигнала/UI).
func get_components() -> Dictionary:
	return {
		"water_ml": water_ml,
		"milk_ml": milk_ml,
		"coffee_powder_g": coffee_powder_g,
		"total_liquid_ml": total_liquid_ml(),
		"temperature_c": temperature_c,
		"is_stirred": is_stirred,
		"is_ready": is_ready,
		"was_overflowed": was_overflowed,
		"capacity_ml": capacity_ml,
	}


## Цвет поверхности в зависимости от состава (§10 миссии).
func get_surface_color() -> Color:
	if total_liquid_ml() <= 0.0 and coffee_powder_g <= 0.0:
		return Color(0, 0, 0, 0)
	# Только порошок — тёмно-коричневый
	if total_liquid_ml() <= 0.0:
		return Color(0.23, 0.13, 0.06, 0.95)
	# Кофе с водой — коричневый; молоко осветляет
	var milk_frac: float = milk_ml / maxf(total_liquid_ml(), 1.0)
	var base := Color(0.20, 0.10, 0.04, 0.92)
	var milk_col := Color(0.55, 0.42, 0.28, 0.95)
	return base.lerp(milk_col, clampf(milk_frac * 2.2, 0.0, 1.0))


## Проверка готовности кофе (все условия §3/§5/§16).
func _check_readiness() -> void:
	var ready: bool = (
		water_ml >= WATER_MIN_ML
		and coffee_powder_g >= POWDER_MIN_G
		and milk_ml >= MILK_MIN_ML
		and temperature_c >= TEMP_MIN_C
		and is_stirred
	)
	if ready and not is_ready:
		is_ready = true
		if get_parent() != null:
			get_parent().set_meta("coffee_ready", true)
		coffee_ready.emit()
	elif not ready:
		is_ready = false
		if get_parent() != null:
			get_parent().set_meta("coffee_ready", false)


## Выпить глоток (мл). Возвращает реально выпитое.
func drink_sip(amount_ml: float) -> float:
	var total := total_liquid_ml()
	if total <= 0.0:
		return 0.0
	var sip: float = minf(amount_ml, total)
	var frac: float = sip / total
	water_ml -= water_ml * frac
	milk_ml -= milk_ml * frac
	_check_readiness()
	content_changed.emit(get_components())
	mug_contents_changed.emit(get_components())
	return sip


## Полностью опустошить кружку.
func empty() -> void:
	water_ml = 0.0
	milk_ml = 0.0
	coffee_powder_g = 0.0
	temperature_c = 20.0
	is_stirred = false
	is_ready = false
	if get_parent() != null:
		get_parent().set_meta("coffee_ready", false)
	content_changed.emit(get_components())
	mug_contents_changed.emit(get_components())
