extends Node

signal delivery_updated(data: Dictionary)

enum DeliveryState { NOT_ORDERED, ON_THE_WAY, AT_DOOR, MISSED, COLLECTED }

const BASE_PRICE := 220.0
const MIN_ETA := 14.0
const MAX_ETA := 22.0
const PICKUP_WINDOW := 25.0
const RING_INTERVAL := 4.5
const ENTRY_POSITION := Vector3(0.45, 1.15, 6.08)

var state := DeliveryState.NOT_ORDERED
var eta := 0.0
var pickup_time_left := 0.0
var ring_timer := 0.0
var ring_count := 0
var order_attempts := 0
var _rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
	if not RunStats.run_active:
		return
	if state == DeliveryState.ON_THE_WAY:
		if RitaSleep.is_angry or RitaDemands.has_active_demand():
			return
		eta = maxf(0.0, eta - delta)
		if eta <= 0.0:
			_arrive()
		else:
			delivery_updated.emit(get_state())
	elif state == DeliveryState.AT_DOOR:
		pickup_time_left = maxf(0.0, pickup_time_left - delta)
		ring_timer -= delta
		if ring_timer <= 0.0:
			_ring_doorbell()
			ring_timer += RING_INTERVAL
		if pickup_time_left <= 0.0:
			_miss_delivery()
		else:
			delivery_updated.emit(get_state())

func reset() -> void:
	state = DeliveryState.NOT_ORDERED
	eta = 0.0
	pickup_time_left = 0.0
	ring_timer = 0.0
	ring_count = 0
	order_attempts = 0
	_rng.seed = int(RunStats.seed_value) + 9473
	_set_pickup_available(false)
	delivery_updated.emit(get_state())

func needs_coffee() -> bool:
	var jar := get_tree().get_first_node_in_group("coffee_jar")
	if jar == null:
		return false
	var emitter := jar.get_node_or_null("CoffeePowderEmitter") as CoffeePowderEmitter
	return emitter != null and emitter.is_empty()

func on_coffee_empty() -> void:
	if state == DeliveryState.COLLECTED:
		state = DeliveryState.NOT_ORDERED
	QuestManager.set_bonus_objective(&"coffee_delivery", "КОФЕ ЗАКОНЧИЛСЯ — ЗАКАЗАТЬ НА НОУТБУКЕ")
	QuestManager.notification_requested.emit("КОФЕ ЗАКОНЧИЛСЯ • ЗАКАЖИ НОВУЮ БАНКУ НА НОУТБУКЕ")
	delivery_updated.emit(get_state())

func order_coffee() -> String:
	if not needs_coffee():
		return "В БАНКЕ ЕЩЁ ЕСТЬ КОФЕ"
	if state == DeliveryState.ON_THE_WAY:
		return "КУРЬЕР С КОФЕ УЖЕ ЕДЕТ • ПРИМЕРНО %.0f СЕК" % ceilf(eta)
	if state == DeliveryState.AT_DOOR:
		return "КОФЕ УЖЕ У ДВЕРИ • ЗАБЕРИ КОРОБКУ"
	order_attempts += 1
	RunStats.spend_money(BASE_PRICE)
	state = DeliveryState.ON_THE_WAY
	eta = _rng.randf_range(MIN_ETA, MAX_ETA)
	pickup_time_left = 0.0
	ring_count = 0
	_set_pickup_available(false)
	QuestManager.set_bonus_objective(&"coffee_delivery", "КУРЬЕР ВЕЗЁТ КОФЕ")
	QuestManager.notify_delivery_changed()
	delivery_updated.emit(get_state())
	return "КОФЕ ЗАКАЗАН ЗА %.0f ₽ • КУРЬЕР БУДЕТ ЧЕРЕЗ %d–%d СЕК" % [BASE_PRICE, int(MIN_ETA), int(MAX_ETA)]

func collect_coffee() -> String:
	if state == DeliveryState.ON_THE_WAY:
		return "КУРЬЕР ЕЩЁ ЕДЕТ • %.0f СЕК" % ceilf(eta)
	if state != DeliveryState.AT_DOOR:
		return "СНАЧАЛА ЗАКАЖИ КОФЕ НА НОУТБУКЕ"
	var jar := get_tree().get_first_node_in_group("coffee_jar") as RigidBody3D
	if jar == null:
		return "БАНКА КОФЕ ПОТЕРЯЛАСЬ"
	var emitter := jar.get_node_or_null("CoffeePowderEmitter") as CoffeePowderEmitter
	if emitter == null:
		return "В БАНКЕ НЕТ КОФЕЙНОГО КОМПОНЕНТА"
	emitter.refill()
	jar.held = false
	jar.freeze = true
	jar.visible = true
	jar.global_position = Vector3(0.45, 0.34, 5.86)
	jar.global_rotation = Vector3.ZERO
	jar.collision_layer = 2
	jar.collision_mask = 3
	state = DeliveryState.COLLECTED
	pickup_time_left = 0.0
	_set_pickup_available(false)
	QuestManager.register_coffee()
	QuestManager.clear_bonus_objective(&"coffee_delivery")
	delivery_updated.emit(get_state())
	AudioManager.play_ui(&"success", -7.0)
	return "НОВАЯ БАНКА КОФЕ У ДВЕРИ • ВОЗЬМИ ЕЁ"

func force_arrival_for_test() -> void:
	if state == DeliveryState.ON_THE_WAY:
		_arrive()

func get_state() -> Dictionary:
	return {
		"state": state,
		"ordered": state in [DeliveryState.ON_THE_WAY, DeliveryState.AT_DOOR],
		"on_the_way": state == DeliveryState.ON_THE_WAY,
		"at_door": state == DeliveryState.AT_DOOR,
		"collected": state == DeliveryState.COLLECTED,
		"missed": state == DeliveryState.MISSED,
		"eta": eta,
		"pickup_time_left": pickup_time_left,
		"order_attempts": order_attempts,
		"next_price": BASE_PRICE,
	}

func get_pickup_prompt() -> String:
	if state == DeliveryState.AT_DOOR:
		return "ЗАБРАТЬ КОФЕ У КУРЬЕРА • %.0f СЕК" % ceilf(pickup_time_left)
	if state == DeliveryState.ON_THE_WAY:
		return "КУРЬЕР С КОФЕ ЕДЕТ • %.0f СЕК" % ceilf(eta)
	return "ЗАКАЖИ КОФЕ НА НОУТБУКЕ"

func _arrive() -> void:
	state = DeliveryState.AT_DOOR
	eta = 0.0
	pickup_time_left = PICKUP_WINDOW
	ring_timer = 0.1
	_set_pickup_available(true)
	QuestManager.set_bonus_objective(&"coffee_delivery", "КУРЬЕР У ДВЕРИ — ЗАБРАТЬ КОФЕ")
	QuestManager.notify_delivery_changed()
	delivery_updated.emit(get_state())

func _ring_doorbell() -> void:
	ring_count += 1
	AudioManager.play_3d(&"buzz", ENTRY_POSITION, -3.0, 1.22)
	NoiseManager.emit_noise(ENTRY_POSITION, minf(55.0, 26.0 + ring_count * 5.0), &"DOORBELL", &"coffee_courier")
	QuestManager.notification_requested.emit("ДЗЫНЬ-ДЗЫНЬ • КУРЬЕР С КОФЕ У ДВЕРИ • %.0f СЕК" % ceilf(pickup_time_left))

func _miss_delivery() -> void:
	state = DeliveryState.MISSED
	pickup_time_left = 0.0
	_set_pickup_available(false)
	QuestManager.set_bonus_objective(&"coffee_delivery", "КУРЬЕР УШЁЛ — ЗАКАЗАТЬ КОФЕ ЗАНОВО")
	delivery_updated.emit(get_state())
	QuestManager.notification_requested.emit("КУРЬЕР УШЁЛ С КОФЕ • ЗАКАЖИ ЗАНОВО")

func _set_pickup_available(value: bool) -> void:
	for pickup in get_tree().get_nodes_in_group("coffee_delivery_pickup"):
		if pickup.has_method("set_delivery_available"):
			pickup.call("set_delivery_available", value)
