extends Node

signal quest_updated(data: Dictionary)
signal notification_requested(text: String)
signal coffee_finished()

## Ссылка на MugContentController (устанавливается через mug_content_controller_path)
var mug_content_controller: Node = null
var mug_content_controller_path: NodePath = NodePath()

var has_mug = false
var has_coffee = false
var has_milk = false
var kettle_filled = false
var kettle_boiling = false
var water_boiled = false
var coffee_powder_poured = false
var water_poured = false
var milk_poured = false
var coffee_made = false
var coffee_drunk = false
var returned_to_desk = false
var second_cup_required = false
var spill_cleanup_required := false
var spill_cleanup_state: Dictionary = {}
var _finish_guard = false
var _bonus_objectives: Dictionary = {}

func _ready() -> void:
    if mug_content_controller_path:
        var node = get_node(mug_content_controller_path)
        if node != null:
            mug_content_controller = node
            if mug_content_controller.has_signal("coffee_ready"):
                mug_content_controller.coffee_ready.connect(_on_mug_coffee_ready)

func reset() -> void:
    has_mug = false
    has_coffee = false
    has_milk = false
    kettle_filled = false
    kettle_boiling = false
    water_boiled = false
    coffee_powder_poured = false
    water_poured = false
    milk_poured = false
    coffee_made = false
    coffee_drunk = false
    returned_to_desk = false
    second_cup_required = false
    spill_cleanup_required = false
    spill_cleanup_state.clear()
    _finish_guard = false
    _bonus_objectives.clear()
    quest_updated.emit(get_state())

## Подключиться к MugContentController для ручного розлива
func register_mug_content_controller(ctrl: Node) -> void:
    if mug_content_controller != null and is_instance_valid(mug_content_controller):
        if mug_content_controller.has_signal("content_changed") and mug_content_controller.content_changed.is_connected(_on_mug_content_changed):
            mug_content_controller.content_changed.disconnect(_on_mug_content_changed)
        if mug_content_controller.has_signal("temperature_changed") and mug_content_controller.temperature_changed.is_connected(_on_mug_temperature_changed):
            mug_content_controller.temperature_changed.disconnect(_on_mug_temperature_changed)
    mug_content_controller = ctrl
    if ctrl.has_signal("coffee_ready"):
        if not ctrl.coffee_ready.is_connected(_on_mug_coffee_ready):
            ctrl.coffee_ready.connect(_on_mug_coffee_ready)
    if ctrl.has_signal("content_changed"):
        if not ctrl.content_changed.is_connected(_on_mug_content_changed):
            ctrl.content_changed.connect(_on_mug_content_changed)
    if ctrl.has_signal("temperature_changed"):
        if not ctrl.temperature_changed.is_connected(_on_mug_temperature_changed):
            ctrl.temperature_changed.connect(_on_mug_temperature_changed)
    sync_story_mug()

func _on_mug_content_changed(_components: Dictionary) -> void:
    sync_story_mug()

func _on_mug_temperature_changed(_temperature_c: float) -> void:
    sync_story_mug()

func sync_story_mug() -> void:
    if mug_content_controller == null or not is_instance_valid(mug_content_controller):
        return
    var components: Dictionary = mug_content_controller.call("get_components")
    var powder_now := float(components.get("coffee_powder_g", 0.0)) >= MugContentController.POWDER_MIN_G
    var water_now := (
        float(components.get("water_ml", 0.0)) >= MugContentController.WATER_MIN_ML
        and float(components.get("temperature_c", 0.0)) >= MugContentController.TEMP_MIN_C
    )
    var milk_now := float(components.get("milk_ml", 0.0)) >= MugContentController.MILK_MIN_ML
    var changed := (
        powder_now != coffee_powder_poured
        or water_now != water_poured
        or milk_now != milk_poured
    )
    coffee_powder_poured = powder_now
    water_poured = water_now
    milk_poured = milk_now
    if changed:
        quest_updated.emit(get_state())

## Срабатывает, когда MugContentController определяет, что кофе готов
func _on_mug_coffee_ready() -> void:
    if coffee_made:
        return
    milk_poured = true
    water_poured = true
    coffee_made = true
    notification_requested.emit("КОФЕ ГОТОВ  •  ВОЗЬМИ КРУЖКУ И ВЫПЕЙ")
    quest_updated.emit(get_state())
    coffee_finished.emit()
    AchievementSystem.on_coffee_made()

func register_mug() -> void:
    if has_mug:
        return
    has_mug = true
    notification_requested.emit("КРУЖКА НАЙДЕНА")
    quest_updated.emit(get_state())

func register_coffee() -> void:
    if has_coffee:
        return
    has_coffee = true
    notification_requested.emit("РАСТВОРИМЫЙ КОФЕ НАЙДЕН")
    quest_updated.emit(get_state())

func register_milk() -> void:
    if has_milk:
        return
    has_milk = true
    notification_requested.emit("МОЛОКО ЗАБРАНО У КУРЬЕРА")
    quest_updated.emit(get_state())

func notify_delivery_changed() -> void:
    quest_updated.emit(get_state())

func set_spill_cleanup_required(required: bool, state: Dictionary = {}) -> void:
    var changed := spill_cleanup_required != required
    spill_cleanup_required = required
    spill_cleanup_state = state.duplicate(true)
    if changed:
        notification_requested.emit(
            "УБРАТЬ РАЗЛИТУЮ ЖИДКОСТЬ" if required
            else "КРУПНАЯ ЛУЖА УБРАНА"
        )
    quest_updated.emit(get_state())

func notify_water_insufficient() -> void:
    kettle_boiling = false
    kettle_filled = false
    water_boiled = false
    water_poured = false
    notification_requested.emit("ВОДЫ НЕ ХВАТИЛО")
    quest_updated.emit(get_state())
    _emit_refill_kettle_notification()

func _emit_refill_kettle_notification() -> void:
    await get_tree().create_timer(1.15).timeout
    notification_requested.emit("СНОВА НАПОЛНИТЬ ЧАЙНИК")

func fill_kettle() -> String:
    if RitaDemands.has_active_demand():
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if kettle_filled:
        return "ЧАЙНИК УЖЕ НАПОЛНЕН"
    kettle_filled = true
    notification_requested.emit("ВОДА НАБРАНА")
    quest_updated.emit(get_state())
    return "ЧАЙНИК НАПОЛНЕН"

func start_kettle() -> String:
    if RitaDemands.has_active_demand():
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if kettle_boiling:
        return "ЧАЙНИК УЖЕ РАБОТАЕТ"
    if water_boiled:
        return "ВОДА УЖЕ ЗАКИПЕЛА"
    if not kettle_filled:
        return "ЧАЙНИК ПУСТ"
    kettle_boiling = true
    notification_requested.emit("ЧАЙНИК ЗАКИПАЕТ")
    quest_updated.emit(get_state())
    return "ЧАЙНИК ВКЛЮЧЁН"

func finish_boiling() -> void:
    if water_boiled:
        return
    kettle_boiling = false
    water_boiled = true
    notification_requested.emit("ВОДА ЗАКИПЕЛА")
    quest_updated.emit(get_state())

func cool_kettle() -> void:
    if not water_boiled:
        return
    kettle_boiling = false
    water_boiled = false
    notification_requested.emit("ВОДА В ЧАЙНИКЕ ОСТЫЛА  •  НУЖНО КИПЯТИТЬ ЗАНОВО")
    quest_updated.emit(get_state())

func cancel_boiling() -> void:
    if not kettle_boiling:
        return
    kettle_boiling = false
    notification_requested.emit("ЧАЙНИК СНЯТ С ПОДСТАВКИ  •  КИПЯЧЕНИЕ ПРЕРВАНО")
    quest_updated.emit(get_state())

func pour_coffee_powder() -> String:
    if RitaDemands.has_active_demand():
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if coffee_made:
        return "КОФЕ УЖЕ ГОТОВ"
    if coffee_powder_poured:
        return "КОФЕ УЖЕ НАСЫПАН"
    if not has_mug:
        return "СНАЧАЛА НУЖНА КРУЖКА"
    if not has_coffee:
        return "БЕЗ КОФЕ ЭТО ПРОСТО КИПЯТОК"
    sync_story_mug()
    return "УДЕРЖИВАЙ E И ПОПАДИ СТРУЁЙ КОФЕ В ОТВЕРСТИЕ КРУЖКИ"

func pour_water_into_mug() -> String:
    return _pour_water_into_mug_impl(true)

## Ручной розлив воды (без проверки зоны — для нового PourController)
func manual_pour_water() -> String:
    return _pour_water_into_mug_impl(false)

func _pour_water_into_mug_impl(check_zone: bool) -> String:
    if RitaDemands.has_active_demand():
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if coffee_made:
        return "КОФЕ УЖЕ ГОТОВ"
    if water_poured:
        return "КИПЯТОК УЖЕ НАЛИТ"
    sync_story_mug()
    return "УДЕРЖИВАЙ E И ПОПАДИ СТРУЁЙ ВОДЫ В ОТВЕРСТИЕ КРУЖКИ"

func pour_milk_into_mug() -> String:
    return _pour_milk_into_mug_impl(true)

## Ручной розлив молока (без проверки зоны — для нового PourController)
func manual_pour_milk() -> String:
    return _pour_milk_into_mug_impl(false)

func _pour_milk_into_mug_impl(check_zone: bool) -> String:
    if RitaDemands.has_active_demand():
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if coffee_made:
        return "КОФЕ УЖЕ ГОТОВ"
    if milk_poured:
        return "МОЛОКО УЖЕ НАЛИТО"
    sync_story_mug()
    return "УДЕРЖИВАЙ E И ПОПАДИ СТРУЁЙ МОЛОКА В ОТВЕРСТИЕ КРУЖКИ"

func brew_coffee() -> String:
    if RitaDemands.has_active_demand():
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if coffee_made:
        return "КОФЕ УЖЕ ГОТОВ"
    if not has_mug:
        return "СНАЧАЛА НУЖНА КРУЖКА"
    if not has_coffee:
        return "БЕЗ КОФЕ ЭТО ПРОСТО КИПЯТОК"
    if not has_milk:
        return "БЕЗ МОЛОКА КОФЕ НЕ ГОТОВ  •  ЗАКАЖИ И ЗАБЕРИ ДОСТАВКУ"
    if not water_boiled:
        return "ВОДА ЕЩЁ НЕ ЗАКИПЕЛА"
    if not coffee_powder_poured:
        return pour_coffee_powder()
    if not water_poured:
        return "ПОДНЕСИ ЧАЙНИК К КРУЖКЕ И УДЕРЖИВАЙ E"
    if not milk_poured:
        return "ПОДНЕСИ МОЛОКО К КРУЖКЕ И УДЕРЖИВАЙ E"
    coffee_made = true
    notification_requested.emit("КОФЕ ГОТОВ  •  ВОЗЬМИ КРУЖКУ И ВЫПЕЙ")
    quest_updated.emit(get_state())
    coffee_finished.emit()
    AchievementSystem.on_coffee_made()
    return "КОФЕ ГОТОВ"

func consume_kettle_water() -> void:
    kettle_boiling = false
    water_boiled = false
    kettle_filled = false
    quest_updated.emit(get_state())

func drink_coffee() -> String:
    if coffee_drunk:
        return "КОФЕ УЖЕ ВЫПИТ"
    if not coffee_made:
        return "В КРУЖКЕ ЕЩЁ НЕТ КОФЕ"
    if spill_cleanup_required:
        return "СНАЧАЛА УБЕРИ КРУПНУЮ ЛУЖУ НА КУХНЕ"
    coffee_drunk = true
    returned_to_desk = true
    quest_updated.emit(get_state())
    if not _finish_guard:
        _finish_guard = true
        RunStats.finish_run()
    return "КОФЕ ВЫПИТ  •  ЗАБЕГ ЗАВЕРШЁН"

func return_to_desk() -> String:
    if coffee_drunk:
        return "ЗАБЕГ УЖЕ ЗАВЕРШЁН"
    if not coffee_made:
        return "СНАЧАЛА НУЖЕН КОФЕ"
    if spill_cleanup_required:
        return "СНАЧАЛА УБЕРИ КРУПНУЮ ЛУЖУ НА КУХНЕ"
    return "КОФЕ НЕ НАДО НЕСТИ К НОУТБУКУ  •  ВОЗЬМИ КРУЖКУ И ВЫПЕЙ"

func on_rita_awakened(_reason: StringName) -> void:
    second_cup_required = true
    notification_requested.emit("РИТА ПРОСНУЛАСЬ. ИДЕАЛЬНЫЙ РАНГ ПОТЕРЯН")
    quest_updated.emit(get_state())

func set_bonus_objective(objective_id: StringName, text: String) -> void:
    _bonus_objectives[objective_id] = text
    quest_updated.emit(get_state())

func clear_bonus_objective(objective_id: StringName) -> void:
    if not _bonus_objectives.has(objective_id):
        return
    _bonus_objectives.erase(objective_id)
    quest_updated.emit(get_state())

func has_bonus_objective(objective_id: StringName) -> bool:
    return _bonus_objectives.has(objective_id)

func get_bonus_objective(objective_id: StringName) -> String:
    return String(_bonus_objectives.get(objective_id, ""))

func get_state() -> Dictionary:
    return {
        "has_mug": has_mug,
        "has_coffee": has_coffee,
        "has_milk": has_milk,
        "milk_delivery": MilkDelivery.get_state(),
        "coffee_delivery": CoffeeDelivery.get_state(),
        "kettle_filled": kettle_filled,
        "kettle_boiling": kettle_boiling,
        "water_boiled": water_boiled,
        "coffee_powder_poured": coffee_powder_poured,
        "water_poured": water_poured,
        "milk_poured": milk_poured,
        "coffee_made": coffee_made,
        "coffee_drunk": coffee_drunk,
        "returned_to_desk": returned_to_desk,
        "second_cup_required": second_cup_required,
        "spill_cleanup_required": spill_cleanup_required,
        "spill_cleanup": spill_cleanup_state,
        "objective": get_objective()
    }

func get_objective() -> String:
    if _bonus_objectives.has(&"escape"):
        return String(_bonus_objectives[&"escape"])
    if RitaDemands.has_active_demand():
        return RitaDemands.get_objective()
    if spill_cleanup_required:
        return "УБРАТЬ РАЗЛИТУЮ ЖИДКОСТЬ"
    if not has_mug:
        return "НАЙТИ КРУЖКУ"
    if not has_coffee:
        return "НАЙТИ РАСТВОРИМЫЙ КОФЕ"
    if not coffee_powder_poured and CoffeeDelivery.needs_coffee():
        var coffee_delivery := CoffeeDelivery.get_state()
        if bool(coffee_delivery.get("at_door", false)):
            return "ЗАБРАТЬ КОФЕ У КУРЬЕРА • %.0f СЕК" % float(coffee_delivery.get("pickup_time_left", 0.0))
        if bool(coffee_delivery.get("on_the_way", false)):
            return "ДОЖДАТЬСЯ КУРЬЕРА С КОФЕ • %.0f СЕК" % float(coffee_delivery.get("eta", 0.0))
        return "ЗАКАЗАТЬ КОФЕ НА НОУТБУКЕ • %.0f ₽" % float(coffee_delivery.get("next_price", 0.0))
    if not coffee_powder_poured:
        return "ПОДНЕСТИ КОФЕ К КРУЖКЕ  •  УДЕРЖИВАТЬ E — НАСЫПАТЬ"
    if not water_poured:
        if not kettle_filled:
            return "НАПОЛНИТЬ ЧАЙНИК"
        if not water_boiled:
            if kettle_filled and not kettle_boiling and not _item_near_node(&"kettle", "KettleBase", 1.1):
                return "ПОСТАВИТЬ НАПОЛНЕННЫЙ ЧАЙНИК НА ПОДСТАВКУ"
            if kettle_boiling:
                return "ДОЖДАТЬСЯ, ПОКА ЧАЙНИК ВСКИПИТ"
            return "ВСКИПЯТИТЬ ВОДУ"
    if not coffee_made:
        if not water_poured:
            return "ПОДНЕСТИ ЧАЙНИК К КРУЖКЕ  •  УДЕРЖИВАТЬ E — НАЛИВАТЬ"
        var delivery := MilkDelivery.get_state()
        if not has_milk and (not bool(delivery.get("ordered", false)) or bool(delivery.get("missed", false))):
            return "ЗАКАЗАТЬ МОЛОКО НА НОУТБУКЕ  •  %.0f ₽" % float(delivery.get("next_price", 0.0))
        if not has_milk and bool(delivery.get("at_door", false)):
            return "ЗАБРАТЬ МОЛОКО У КУРЬЕРА  •  %.0f СЕК" % float(delivery.get("pickup_time_left", 0.0))
        if not has_milk:
            return "ДОЖДАТЬСЯ КУРЬЕРА С МОЛОКОМ  •  %.0f СЕК" % float(delivery.get("eta", 0.0))
        if not milk_poured:
            return "ПОДНЕСТИ МОЛОКО К КРУЖКЕ  •  УДЕРЖИВАТЬ E — НАЛИВАТЬ"
        if mug_content_controller != null and not bool(mug_content_controller.get("is_stirred")):
            return "НАЙТИ ЛОЖКУ И ПЕРЕМЕШАТЬ КОФЕ"
    if not coffee_drunk:
        return "ВЗЯТЬ КРУЖКУ И ВЫПИТЬ КОФЕ"
    return "КОФЕ ВЫПИТ"

func _item_near_node(item_group: StringName, target_name: String, radius: float) -> bool:
    var item := get_tree().get_first_node_in_group(String(item_group)) as Node3D
    var scene := get_tree().current_scene
    var target := scene.find_child(target_name, true, false) as Node3D if scene != null else null
    if item == null or target == null or bool(item.get("held")):
        return false
    return item.global_position.distance_to(target.global_position) <= radius
