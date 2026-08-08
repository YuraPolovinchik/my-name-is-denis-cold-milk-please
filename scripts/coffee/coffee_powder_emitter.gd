class_name CoffeePowderEmitter
extends Node

signal powder_changed(remaining_g: float, delta_g: float)

@export var capacity_g: float = 80.0
@export var remaining_g: float = 80.0
@export var flow_g_s: float = 4.8

func is_empty() -> bool:
	return remaining_g <= 0.001

func remove_powder(amount_g: float) -> float:
	var removed := minf(maxf(amount_g, 0.0), remaining_g)
	if removed <= 0.0:
		return 0.0
	remaining_g -= removed
	powder_changed.emit(remaining_g, -removed)
	if is_empty():
		CoffeeDelivery.on_coffee_empty()
	return removed

func refill(amount_g: float = -1.0) -> void:
	var target := capacity_g if amount_g < 0.0 else clampf(amount_g, 0.0, capacity_g)
	var added := target - remaining_g
	remaining_g = target
	powder_changed.emit(remaining_g, added)

func get_flow_rate(tilt_degrees: float) -> float:
	if tilt_degrees < 36.0:
		return 0.0
	return flow_g_s * clampf((tilt_degrees - 36.0) / 32.0, 0.12, 1.0)
