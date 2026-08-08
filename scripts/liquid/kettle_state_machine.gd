# KettleStateMachine.gd
# Управляет состояниями чайника: от пустого до кипения и розлива.
# Вешается на сцену чайника как Node-компонент.
class_name KettleStateMachine
extends Node

## Сигнал: состояние изменилось
signal state_changed(new_state: KettleState)

## Сигнал: вода закипела
signal water_boiled()

## Сигнал: чайник снят с базы
signal kettle_lifted()

## Сигнал: чайник поставлен на базу
signal kettle_placed()

## Сигнал: чайник заполнен водой
signal kettle_filled()

## Сигнал: начинается наливание (tilt_angle > pour_start_angle)
signal pouring_started()

## Сигнал: наливание закончено
signal pouring_stopped()


## Состояния чайника
enum KettleState {
	EMPTY,      # Пустой, на базе
	FILLING,    # Наполняется водой из крана
	FILLED,     # Полный, холодный, на базе
	ON_BASE,    # На базе, готов к включению
	HEATING,    # Нагревается
	BOILED,     # Вода закипела (100°C), на базе
	COOLING,    # Остывает после снятия с базы
	HELD,       # В руках у игрока
	POURING,    # Наклонён, льёт воду
	BOILING_AWAY,
	DRY,
}

## Текущее состояние
var state: KettleState = KettleState.EMPTY:
	set(value):
		if value != state:
			var old_state = state
			state = value
			state_changed.emit(value)
			_on_state_entered(value, old_state)

## Температура воды в градусах Цельсия
var temperature_c: float = 20.0

## Температура кипения
const BOIL_TEMP: float = 100.0

## Скорость нагрева (°C/сек)
@export var heat_rate: float = 1.8

## Скорость остывания (°C/сек) когда чайник не на базе
@export var cool_rate: float = 0.3

## Ссылка на ContainerVolume (должна быть назначена вручную или через поиск)
@export var container_volume: ContainerVolume = null

## Ссылка на AudioStreamPlayer3D для звука кипения
@export var boil_sound_player: AudioStreamPlayer3D = null

## Время (сек) с момента последнего перехода в HEATING
var heating_time: float = 0.0

## Флаг: был ли момент, когда чайник кипел и его сняли (для квеста)
var has_boiled_and_lifted: bool = false


func _ready():
	# Автоматически ищем ContainerVolume среди детей
	if not container_volume:
		container_volume = find_child("ContainerVolume", true, false) as ContainerVolume
	
	if container_volume:
		container_volume.filled.connect(_on_container_filled)
		container_volume.emptied.connect(_on_container_emptied)


func _process(delta: float):
	match state:
		KettleState.HEATING:
			heating_time += delta
			temperature_c += heat_rate * delta
			if temperature_c >= BOIL_TEMP:
				temperature_c = BOIL_TEMP
				transition_to(KettleState.BOILED)
				water_boiled.emit()
		
		KettleState.COOLING, KettleState.HELD:
			temperature_c -= cool_rate * delta
			if temperature_c < 20.0:
				temperature_c = 20.0
		
		KettleState.POURING:
			# Температура падает медленнее во время розлива
			temperature_c -= cool_rate * 0.5 * delta
			if temperature_c < 20.0:
				temperature_c = 20.0


## Переход в новое состояние с проверкой валидности.
func transition_to(new_state: KettleState) -> bool:
	match new_state:
		KettleState.EMPTY:
			if state in [KettleState.ON_BASE, KettleState.FILLED, KettleState.BOILED, KettleState.COOLING, KettleState.HELD, KettleState.POURING, KettleState.FILLING, KettleState.BOILING_AWAY, KettleState.DRY]:
				state = new_state
				return true
		
		KettleState.FILLING:
			if state in [KettleState.EMPTY, KettleState.HELD, KettleState.FILLED, KettleState.ON_BASE, KettleState.BOILED, KettleState.COOLING, KettleState.DRY]:
				state = new_state
				return true
		
		KettleState.FILLED:
			if state == KettleState.FILLING:
				state = new_state
				return true
		
		KettleState.ON_BASE:
			if state in [KettleState.FILLED, KettleState.COOLING, KettleState.HELD]:
				state = new_state
				# Если вода уже кипела, остаёмся в BOILED или остываем
				if temperature_c >= BOIL_TEMP * 0.95:
					state = KettleState.BOILED
					state_changed.emit(KettleState.BOILED)
				return true
		
		KettleState.HEATING:
			if state in [KettleState.ON_BASE, KettleState.FILLED] and temperature_c < BOIL_TEMP:
				state = new_state
				heating_time = 0.0
				return true
		
		KettleState.BOILED:
			if state == KettleState.HEATING:
				state = new_state
				return true

		KettleState.BOILING_AWAY:
			if state == KettleState.BOILED:
				state = new_state
				return true

		KettleState.DRY:
			if state in [KettleState.EMPTY, KettleState.HEATING, KettleState.BOILED, KettleState.BOILING_AWAY]:
				state = new_state
				return true
		
		KettleState.COOLING:
			if state in [KettleState.BOILED, KettleState.HELD]:
				state = new_state
				return true
		
		KettleState.HELD:
			if state in [KettleState.FILLED, KettleState.BOILED, KettleState.ON_BASE, KettleState.COOLING, KettleState.BOILING_AWAY]:
				if state == KettleState.BOILED:
					has_boiled_and_lifted = true
				state = new_state
				kettle_lifted.emit()
				return true
		
		KettleState.POURING:
			if state == KettleState.HELD:
				state = new_state
				pouring_started.emit()
				return true
	
	return false


## Остановить наливание (вернуться в HELD).
func stop_pouring() -> bool:
	if state == KettleState.POURING:
		state = KettleState.HELD
		pouring_stopped.emit()
		return true
	return false


## Можно ли наливать (достаточно ли наклонён чайник)?
func can_pour(tilt_angle_deg: float) -> bool:
	if state == KettleState.HELD and container_volume and not container_volume.is_empty():
		var liq_def: LiquidDefinition = container_volume.liquid
		if liq_def:
			return tilt_angle_deg >= liq_def.pour_start_angle
	return false


func _on_state_entered(new_state: KettleState, old_state: KettleState):
	match new_state:
		KettleState.FILLING:
			temperature_c = 20.0
			var kettle_owner := get_parent()
			if kettle_owner != null:
				kettle_owner.set_meta("filled", false)
		KettleState.FILLED:
			kettle_filled.emit()
		KettleState.ON_BASE:
			kettle_placed.emit()
		KettleState.EMPTY:
			temperature_c = 20.0


func _on_container_filled():
	if state == KettleState.FILLING:
		transition_to(KettleState.FILLED)


func _on_container_emptied():
	if state == KettleState.BOILING_AWAY:
		transition_to(KettleState.DRY)
	else:
		transition_to(KettleState.EMPTY)
	var kettle_owner := get_parent()
	if kettle_owner != null:
		kettle_owner.set_meta("fill_progress", 0.0)
		kettle_owner.set_meta("filled", false)
