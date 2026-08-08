# LiquidDefinition.gd
# Ресурс, определяющий свойства жидкости (вода, молоко, кофе).
# Используется ContainerVolume, StreamRenderer и др. для настройки поведения.
class_name LiquidDefinition
extends Resource

## Уникальный идентификатор жидкости (например, "water", "milk", "coffee_mix")
@export var id: String = ""

## Отображаемое название (для UI/подсказок)
@export var display_name: String = ""

## Цвет жидкости (для струи и поверхности в кружке)
@export var color: Color = Color.WHITE

## Непрозрачность жидкости (0.0 — прозрачная, 1.0 — полностью непрозрачная)
@export var opacity: float = 0.85

## Плотность (г/мл) — влияет на звук и поведение струи
@export var density: float = 1.0

## Угол наклона (в градусах), при котором начинается выливание
@export var pour_start_angle: float = 35.0

## Минимальная скорость потока (мл/с) при pour_start_angle
@export var flow_rate_min: float = 40.0

## Максимальная скорость потока (мл/с) при максимальном наклоне (80°)
@export var flow_rate_max: float = 260.0

## Толщина струи в метрах при минимальном потоке
@export var stream_width_min: float = 0.008

## Толщина струи в метрах при максимальном потоке
@export var stream_width_max: float = 0.025

## Путь к звуку плеска при наливании (в assets/)
@export var pour_sound_path: String = ""

## Путь к звуку попадания в кружку
@export var hit_sound_path: String = ""

## Путь к звуку пролития мимо
@export var spill_sound_path: String = ""


## Возвращает скорость потока (мл/с) для заданного угла наклона (в градусах).
func get_flow_rate(tilt_angle_deg: float) -> float:
	if tilt_angle_deg < 30.0:
		return 0.0
	var viscosity_scale := clampf(flow_rate_max / 95.0, 0.70, 1.0)
	if tilt_angle_deg < 42.0:
		return lerpf(15.0, 25.0, (tilt_angle_deg - 30.0) / 12.0) * viscosity_scale
	if tilt_angle_deg < 58.0:
		return lerpf(30.0, 50.0, (tilt_angle_deg - 42.0) / 16.0) * viscosity_scale
	if tilt_angle_deg < 75.0:
		return lerpf(55.0, 80.0, (tilt_angle_deg - 58.0) / 17.0) * viscosity_scale
	return lerpf(88.0, 105.0, clampf((tilt_angle_deg - 75.0) / 5.0, 0.0, 1.0)) * viscosity_scale


## Возвращает толщину струи для заданной скорости потока.
func get_stream_width(flow_rate: float) -> float:
	var t: float = (flow_rate - flow_rate_min) / (flow_rate_max - flow_rate_min) if flow_rate_max > flow_rate_min else 0.0
	return lerpf(stream_width_min, stream_width_max, clampf(t, 0.0, 1.0))
