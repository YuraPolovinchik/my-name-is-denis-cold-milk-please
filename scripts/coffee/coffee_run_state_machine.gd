# CoffeeRunStateMachine.gd
# Расширенная стейт-машина для кофейного квеста.
# Управляет последовательностью шагов от начала до финиша.
class_name CoffeeRunStateMachine
extends Node

## Сигнал: шаг квеста изменился
signal step_changed(step: int, description: String)

## Сигнал: квест завершён
signal run_completed(result: Dictionary)

## Шаги квеста
enum QuestStep {
	# Шаг 0: Начало
	START = 0,
	
	# Шаг 1-2: Предметы
	FIND_MUG,          # 1. Взять кружку
	FIND_COFFEE,       # 2. Взять банку кофе
	
	# Шаг 3: Кофе в кружку
	POUR_COFFEE_POWDER, # 3. Насыпать кофе в кружку
	
	# Шаг 4-7: Вода
	FILL_KETTLE,       # 4. Наполнить чайник
	BOIL_WATER,        # 5. Вскипятить чайник
	LIFT_KETTLE,       # 6. Снять чайник с базы
	POUR_WATER,        # 7. Налить воду в кружку (ручной розлив)
	
	# Шаг 8-10: Молоко
	ORDER_MILK,        # 8. Заказать молоко
	COLLECT_MILK,      # 9. Забрать у курьера
	POUR_MILK,         # 10. Налить молоко (ручной розлив)
	
	# Шаг 11: Финал
	DRINK_COFFEE,      # 11. Выпить кофе за рабочим столом
	FINISHED,          # 12. Забег завершён
}

## Текущий шаг
var current_step: QuestStep = QuestStep.START

## Прогресс (0.0-1.0)
var progress: float = 0.0


func _ready():
	add_to_group("coffee_run_state_machine")
	_emit_step()


## Перейти к следующему шагу, если текущий шаг соответствует.
func advance_to(step: QuestStep) -> bool:
	if int(step) <= int(current_step):
		return false  # уже прошли этот шаг
	
	current_step = step
	progress = float(step) / float(QuestStep.FINISHED)
	_emit_step()
	
	if step == QuestStep.FINISHED:
		run_completed.emit(_build_result())
	
	return true


## Получить описание текущего шага.
func get_step_description() -> String:
	match current_step:
		QuestStep.START:
			return "Найди кружку и свари идеальный кофе"
		QuestStep.FIND_MUG:
			return "Найди кружку на кухне и возьми её"
		QuestStep.FIND_COFFEE:
			return "Найди банку кофе в шкафчике"
		QuestStep.POUR_COFFEE_POWDER:
			return "Подойди к кружке с кофе и насыпь его внутрь"
		QuestStep.FILL_KETTLE:
			return "Наполни чайник водой из крана"
		QuestStep.BOIL_WATER:
			return "Включи чайник и дождись кипения (100°C)"
		QuestStep.LIFT_KETTLE:
			return "Сними чайник с подставки"
		QuestStep.POUR_WATER:
			return "Налей кипяток в кружку (ЛКМ + целься носиком)"
		QuestStep.ORDER_MILK:
			return "Закажи молоко через приложение (телефон)"
		QuestStep.COLLECT_MILK:
			return "Забери молоко у курьера"
		QuestStep.POUR_MILK:
			return "Налей молоко в кружку (ЛКМ + целься носиком)"
		QuestStep.DRINK_COFFEE:
			return "Отнеси кружку на рабочий стол и выпей (E)"
		QuestStep.FINISHED:
			return "Забег завершён!"
		_:
			return ""


func _emit_step():
	step_changed.emit(int(current_step), get_step_description())
	QuestManager.set_quest_progress(int(current_step), progress)


func _build_result() -> Dictionary:
	return {
		"completed": true,
		"steps": int(current_step),
		"total_steps": int(QuestStep.FINISHED),
	}
