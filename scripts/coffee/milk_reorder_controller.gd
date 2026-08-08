# MilkReorderController.gd
# Управление повторным заказом молока.
# Если молоко закончилось или игрок пролил всё, можно заказать ещё (249₽).
class_name MilkReorderController
extends Node

## Сигнал: молоко перезаказано
signal milk_reordered()

## Цена повторного заказа
@export var reorder_price: float = 249.0

## Флаг: можно ли заказать
var can_reorder: bool = false

## Количество заказов
var order_count: int = 0


## Запросить повторный заказ.
func request_reorder() -> bool:
	if not can_reorder:
		return false
	
	if RunStats.money_balance < reorder_price:
		return false
	
	# Списываем деньги
	RunStats.spend_money(reorder_price)
	order_count += 1
	RunStats.record_milk_order(reorder_price)
	
	milk_reordered.emit()
	return true


## Активировать возможность повторного заказа.
func enable_reorder():
	can_reorder = true


## Деактивировать.
func disable_reorder():
	can_reorder = false
