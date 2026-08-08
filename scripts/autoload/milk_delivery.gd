extends Node

signal delivery_updated(data: Dictionary)
signal courier_spoke(text: String)

enum DeliveryState { NOT_ORDERED, ON_THE_WAY, AT_DOOR, MISSED, COLLECTED }

const BASE_PRICE := 165.0
const REORDER_SURCHARGE := 70.0
const MIN_ETA := 12.0
const MAX_ETA := 20.0
const PICKUP_WINDOW := 20.0
const RING_INTERVAL := 3.0
const ENTRY_POSITION := Vector3(0.0, 1.15, 6.08)
const COURIER_LINES := [
    "Доставка! Молоко привёз!",
    "Доставка! Откройте дверь!",
    "Денис! Заказ с молоком, забирайте!",
    "Я долго ждать не буду!"
]

var state := DeliveryState.NOT_ORDERED
var eta := 0.0
var pickup_time_left := 0.0
var ring_timer := 0.0
var ring_count := 0
var order_attempts := 0
var missed_deliveries := 0
var last_price := 0.0
var _rng := RandomNumberGenerator.new()

func _process(delta: float) -> void:
    if not RunStats.run_active:
        return
    if state == DeliveryState.ON_THE_WAY:
        # Do not let a courier materialise while the player is locked inside
        # Rita's rage/demand sequence. The delivery resumes when normal play does.
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
    missed_deliveries = 0
    last_price = 0.0
    _rng.seed = int(RunStats.seed_value) + 7319
    _set_pickup_available(false)
    delivery_updated.emit(get_state())

func order_milk() -> String:
    if state == DeliveryState.COLLECTED:
        return "МОЛОКО УЖЕ ЗАБРАНО"
    if state == DeliveryState.ON_THE_WAY:
        return "КУРЬЕР УЖЕ ЕДЕТ  •  ПРИМЕРНО %.0f СЕК" % ceil(eta)
    if state == DeliveryState.AT_DOOR:
        return "КУРЬЕР УЖЕ У ДВЕРИ  •  БЕГИ ЗАБИРАТЬ МОЛОКО"
    order_attempts += 1
    last_price = BASE_PRICE + float(missed_deliveries) * REORDER_SURCHARGE
    RunStats.spend_money(last_price)
    RunStats.record_milk_order(last_price)
    state = DeliveryState.ON_THE_WAY
    eta = _rng.randf_range(MIN_ETA, MAX_ETA)
    pickup_time_left = 0.0
    ring_count = 0
    _set_pickup_available(false)
    QuestManager.notify_delivery_changed()
    delivery_updated.emit(get_state())
    return "МОЛОКО ЗАКАЗАНО ЗА %.0f ₽  •  КУРЬЕР БУДЕТ ЧЕРЕЗ %d–%d СЕК" % [last_price, int(MIN_ETA), int(MAX_ETA)]

func collect_milk() -> String:
    if state == DeliveryState.COLLECTED:
        return "МОЛОКО УЖЕ У ДЕНИСА"
    if state == DeliveryState.ON_THE_WAY:
        return "КУРЬЕР ЕЩЁ ЕДЕТ  •  ОСТАЛОСЬ ПРИМЕРНО %.0f СЕК" % ceil(eta)
    if state != DeliveryState.AT_DOOR:
        return "СНАЧАЛА ЗАКАЖИ МОЛОКО НА НОУТБУКЕ"
    state = DeliveryState.COLLECTED
    pickup_time_left = 0.0
    ring_timer = 0.0
    _set_pickup_available(false)
    # Reveal the physical milk carton so the player can carry it to the coffee zone.
    # QuestManager.register_milk() is called by physical_item.gd.on_picked_up() when picked up.
    QuestManager.clear_bonus_objective(&"milk_delivery")
    _reveal_milk_carton()
    delivery_updated.emit(get_state())
    AudioManager.play_ui(&"success", -7.0)
    return "МОЛОКО ЗАБРАНО  •  ПАКЕТ У ДВЕРИ  •  ЗАНЕСИ ЕГО К КОФЕ"

func get_state() -> Dictionary:
    return {
        "state": state,
        "state_name": _state_name(),
        "ordered": state in [DeliveryState.ON_THE_WAY, DeliveryState.AT_DOOR, DeliveryState.COLLECTED],
        "on_the_way": state == DeliveryState.ON_THE_WAY,
        "at_door": state == DeliveryState.AT_DOOR,
        "collected": state == DeliveryState.COLLECTED,
        "missed": state == DeliveryState.MISSED,
        "eta": eta,
        "pickup_time_left": pickup_time_left,
        "ring_count": ring_count,
        "order_attempts": order_attempts,
        "missed_deliveries": missed_deliveries,
        "next_price": BASE_PRICE + float(missed_deliveries) * REORDER_SURCHARGE,
        "last_price": last_price
    }

func get_pickup_prompt() -> String:
    match state:
        DeliveryState.AT_DOOR:
            return "ЗАБРАТЬ МОЛОКО У КУРЬЕРА  •  ОСТАЛОСЬ %.0f СЕК" % ceil(pickup_time_left)
        DeliveryState.ON_THE_WAY:
            return "КУРЬЕР ЕЩЁ ЕДЕТ  •  %.0f СЕК" % ceil(eta)
        DeliveryState.COLLECTED:
            return "МОЛОКО УЖЕ ЗАБРАНО"
        DeliveryState.MISSED:
            return "КУРЬЕР УШЁЛ  •  ЗАКАЖИ МОЛОКО ЗАНОВО"
        _:
            return "ЗАКАЖИ МОЛОКО НА НОУТБУКЕ"

func force_arrival_for_test() -> void:
    if state == DeliveryState.ON_THE_WAY:
        _arrive()

func force_ring_for_test() -> void:
    if state == DeliveryState.AT_DOOR:
        _ring_doorbell()

func _arrive() -> void:
    state = DeliveryState.AT_DOOR
    eta = 0.0
    pickup_time_left = PICKUP_WINDOW
    ring_timer = 0.10
    ring_count = 0
    _set_pickup_available(true)
    QuestManager.set_bonus_objective(&"milk_delivery", "КУРЬЕР У ДВЕРИ — ЗАБРАТЬ МОЛОКО")
    QuestManager.notify_delivery_changed()
    delivery_updated.emit(get_state())

func _ring_doorbell() -> void:
    ring_count += 1
    var line: String = COURIER_LINES[(ring_count - 1) % COURIER_LINES.size()]
    courier_spoke.emit(line)
    AudioManager.play_3d(&"buzz", ENTRY_POSITION, -2.0, 1.30 + minf(float(ring_count), 5.0) * 0.035)
    var strength := minf(66.0, 28.0 + float(ring_count) * 6.0)
    NoiseManager.emit_noise(ENTRY_POSITION, strength, &"DOORBELL", &"doorbell")
    QuestManager.notification_requested.emit("ДЗЫНЬ-ДЗЫНЬ  •  КУРЬЕР С МОЛОКОМ У ДВЕРИ  •  %.0f СЕК" % ceil(pickup_time_left))

func _miss_delivery() -> void:
    state = DeliveryState.MISSED
    missed_deliveries += 1
    pickup_time_left = 0.0
    ring_timer = 0.0
    _set_pickup_available(false)
    RunStats.record_missed_courier()
    QuestManager.clear_bonus_objective(&"milk_delivery")
    QuestManager.notify_delivery_changed()
    delivery_updated.emit(get_state())
    QuestManager.notification_requested.emit("КУРЬЕР УШЁЛ С МОЛОКОМ  •  ДЕНЬГИ НЕ ВЕРНУЛИ  •  ЗАКАЖИ ЗАНОВО")

func _reveal_milk_carton() -> void:
    var carton := get_tree().get_first_node_in_group("milk_carton")
    if carton == null:
        push_error("MilkCarton not found in scene tree — physical milk cannot be revealed")
        return
    carton.visible = true
    carton.freeze = false
    carton.sleeping = false
    carton.collision_layer = 2
    carton.collision_mask = 3

func _set_pickup_available(value: bool) -> void:
    for pickup in get_tree().get_nodes_in_group("milk_delivery_pickup"):
        if pickup.has_method("set_delivery_available"):
            pickup.call("set_delivery_available", value)

func _state_name() -> String:
    match state:
        DeliveryState.ON_THE_WAY: return "КУРЬЕР ЕДЕТ"
        DeliveryState.AT_DOOR: return "КУРЬЕР У ДВЕРИ"
        DeliveryState.MISSED: return "КУРЬЕР УШЁЛ"
        DeliveryState.COLLECTED: return "МОЛОКО ЗАБРАНО"
        _: return "НЕ ЗАКАЗАНО"
