# PourStats.gd
# Статистика меткости наливания.
# Отслеживает, сколько жидкости попало в кружку, сколько пролито мимо.
class_name PourStats
extends Resource

## Общий объём налитой воды (мл)
var water_total_ml: float = 0.0

## Воды попало в кружку (мл)
var water_hit_ml: float = 0.0

## Воды пролито мимо (мл)
var water_spilled_ml: float = 0.0

## Общий объём налитого молока (мл)
var milk_total_ml: float = 0.0

## Молока попало в кружку (мл)
var milk_hit_ml: float = 0.0

## Молока пролито мимо (мл)
var milk_spilled_ml: float = 0.0

## Точность наливания воды (%)
func get_water_accuracy() -> float:
	if water_total_ml <= 0.0:
		return 100.0
	return (water_hit_ml / water_total_ml) * 100.0

## Точность наливания молока (%)
func get_milk_accuracy() -> float:
	if milk_total_ml <= 0.0:
		return 100.0
	return (milk_hit_ml / milk_total_ml) * 100.0

## Общая точность (%)
func get_total_accuracy() -> float:
	var total_poured: float = water_total_ml + milk_total_ml
	var total_hit: float = water_hit_ml + milk_hit_ml
	if total_poured <= 0.0:
		return 100.0
	return (total_hit / total_poured) * 100.0

## Записать результат наливания воды.
func record_water_pour(hit_ml: float, spilled_ml: float):
	water_hit_ml += hit_ml
	water_spilled_ml += spilled_ml
	water_total_ml += hit_ml + spilled_ml

## Записать результат наливания молока.
func record_milk_pour(hit_ml: float, spilled_ml: float):
	milk_hit_ml += hit_ml
	milk_spilled_ml += spilled_ml
	milk_total_ml += hit_ml + spilled_ml

## Оценка за меткость (S/A/B/C/D/F)
func get_accuracy_rank() -> String:
	var acc: float = get_total_accuracy()
	if acc >= 99.5:
		return "S"
	elif acc >= 95.0:
		return "A"
	elif acc >= 85.0:
		return "B"
	elif acc >= 70.0:
		return "C"
	elif acc >= 50.0:
		return "D"
	else:
		return "F"
