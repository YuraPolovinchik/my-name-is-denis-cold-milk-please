# ContainerVolume.gd
# Node-компонент для отслеживания объёма жидкости в контейнере (чайник, кружка, пакет молока).
# Использует LiquidDefinition для определения свойств жидкости.
class_name ContainerVolume
extends Node

## Сигнал: объём изменился
signal volume_changed(current_ml: float, delta_ml: float)
signal container_volume_changed(current_ml: float, delta_ml: float)

## Сигнал: контейнер заполнен (current_ml >= capacity_ml * 0.95)
signal filled()

## Сигнал: контейнер пуст (current_ml <= 0)
signal emptied()

## Сигнал: жидкость добавилась (для обратной связи)
signal liquid_added(amount_ml: float, definition: LiquidDefinition)

## Сигнал: жидкость удалилась
signal liquid_removed(amount_ml: float, definition: LiquidDefinition)


## Тип контейнера (для идентификации в коде)
enum ContainerType {
	KETTLE,      # Электрочайник
	MUG,         # Кружка
	MILK_PACK,   # Пакет молока
	COFFEE_JAR,  # Банка кофе
}

## Тип контейнера
@export var container_type: ContainerType = ContainerType.MUG

## Максимальная вместимость в миллилитрах
@export var capacity_ml: float = 350.0

## Жидкость по умолчанию (задаётся в редакторе)
@export var default_liquid: LiquidDefinition = null

## Текущий объём жидкости (мл)
var current_ml: float = 0.0

## Текущая жидкость в контейнере (null если пусто)
var liquid: LiquidDefinition = null:
	set(value):
		# Не даём сменить жидкость, если контейнер не пуст и несовместимо
		if liquid != null and value != null and liquid.id != value.id and current_ml > 1.0:
			push_warning("ContainerVolume: попытка сменить жидкость с '%s' на '%s' в непустом контейнере!" % [liquid.id, value.id])
			return
		liquid = value

## Флаг: можно ли смешивать жидкости (только для кружки — кофе + вода + молоко)
@export var allow_mixing: bool = false


func _ready():
	if default_liquid and current_ml <= 0.0:
		liquid = default_liquid


## Добавить жидкость в контейнер.
## Возвращает реально добавленный объём (может быть меньше amount_ml, если контейнер почти полон).
func add_liquid(amount_ml: float, defn: LiquidDefinition) -> float:
	if amount_ml <= 0.0:
		return 0.0
	
	# Проверка совместимости жидкостей
	if current_ml > 0.0 and liquid != null and liquid.id != defn.id:
		if not allow_mixing:
			push_warning("ContainerVolume: нельзя смешивать '%s' и '%s'" % [liquid.id, defn.id])
			return 0.0
	
	# Если контейнер был пуст, устанавливаем жидкость
	if current_ml <= 0.0:
		liquid = defn
	elif liquid == null:
		liquid = defn
	
	var space_left: float = capacity_ml - current_ml
	if space_left <= 0.0:
		return 0.0
	
	var actual: float = minf(amount_ml, space_left)
	current_ml += actual
	
	volume_changed.emit(current_ml, actual)
	container_volume_changed.emit(current_ml, actual)
	liquid_added.emit(actual, defn)
	
	if current_ml >= capacity_ml * 0.95:
		filled.emit()
	
	return actual


## Удалить жидкость из контейнера.
## Возвращает реально удалённый объём.
func remove_liquid(amount_ml: float) -> float:
	if amount_ml <= 0.0 or current_ml <= 0.0:
		return 0.0
	
	var actual: float = minf(amount_ml, current_ml)
	var removed_defn: LiquidDefinition = liquid
	
	current_ml -= actual
	
	volume_changed.emit(current_ml, -actual)
	container_volume_changed.emit(current_ml, -actual)
	liquid_removed.emit(actual, removed_defn)
	
	if current_ml <= 0.0:
		current_ml = 0.0
		liquid = null
		emptied.emit()
	
	return actual


## Удалить жидкость целиком (вернуть в источник).
func drain():
	if current_ml > 0.0 and liquid:
		var removed_defn: LiquidDefinition = liquid
		liquid_removed.emit(current_ml, removed_defn)
	current_ml = 0.0
	liquid = null
	volume_changed.emit(current_ml, 0.0)
	container_volume_changed.emit(current_ml, 0.0)
	emptied.emit()


## Заполнить до capacity (начальная заливка).
func fill_completely(defn: LiquidDefinition):
	liquid = defn
	var added: float = capacity_ml - current_ml
	current_ml = capacity_ml
	volume_changed.emit(current_ml, added)
	container_volume_changed.emit(current_ml, added)
	liquid_added.emit(added, defn)
	filled.emit()


## Процент заполнения (0.0 — 1.0).
func fill_fraction() -> float:
	if capacity_ml <= 0.0:
		return 0.0
	return clampf(current_ml / capacity_ml, 0.0, 1.0)


## Пуст ли контейнер?
func is_empty() -> bool:
	return current_ml <= 0.0


## Полон ли контейнер?
func is_full() -> bool:
	return current_ml >= capacity_ml * 0.95
