extends Node

signal demand_changed(data: Dictionary)
signal subtitle_requested(text: String)

const DEMAND_DEFINITIONS := {
    &"order_food": {
        "objective": "ЗАКАЗАТЬ РИТЕ ЕДУ НА НОУТБУКЕ",
        "location": &"laptop",
        "cost": 680.0,
        "line": "Разбудил меня — теперь закажи нормальную еду. И сам оплати.",
        "done": "ЕДА ЗАКАЗАНА  •  -680 ₽"
    },
    &"order_medicine": {
        "objective": "ЗАКАЗАТЬ РИТЕ ЛЕКАРСТВА НА НОУТБУКЕ",
        "location": &"laptop",
        "cost": 460.0,
        "line": "Раз уж не дал поспать — закажи мне лекарства. За свой счёт.",
        "done": "ЛЕКАРСТВА ЗАКАЗАНЫ  •  -460 ₽"
    },
    &"clean_bathroom": {
        "objective": "ОТМЫТЬ ВАННУЮ ПО ТРЕБОВАНИЮ РИТЫ",
        "location": &"bathroom_clean",
        "cost": 0.0,
        "line": "Иди ванную отмой. Хоть какая-то польза от того, что ты меня разбудил.",
        "done": "ВАННАЯ ОТМЫТА  •  РИТА ОТСТАЛА"
    },
    &"wash_dishes": {
        "objective": "ПЕРЕМЫТЬ ПОСУДУ НА КУХНЕ",
        "location": &"kitchen_dishes",
        "cost": 0.0,
        "line": "Раз не спишь — перемой посуду. И попробуй ещё раз меня разбудить.",
        "done": "ПОСУДА ПЕРЕМЫТА  •  РИТА ОТСТАЛА"
    },
    &"festival_cinema": {
        "objective": "ПРИНЕСТИ ТЕЛЕВИЗОР В КОМНАТУ РИТЫ И ВКЛЮЧИТЬ В РОЗЕТКУ",
        "location": &"rita_tv_watch",
        "cost": 0.0,
        "line": "Я хочу посмотреть японское фестивальное кино. Принеси телевизор, включи его и стой рядом, пока я не усну.",
        "done": "РИТА ДОСМОТРЕЛА ФЕСТИВАЛЬНОЕ КИНО И УСНУЛА"
    }
}

var active_type: StringName = &""
var queued_demands := 0
var demands_received := 0
var demands_completed := 0
var money_spent := 0.0
var _last_type: StringName = &""
var _nag_timer := 0.0
var _festival_stage: StringName = &"bring_tv"
var _festival_progress := 0.0

func _process(delta: float) -> void:
    if not RunStats.run_active or active_type == &"":
        return
    _nag_timer -= delta
    if _nag_timer <= 0.0:
        _nag_timer = 28.0
        subtitle_requested.emit(_nag_line(active_type))

func reset() -> void:
    active_type = &""
    queued_demands = 0
    demands_received = 0
    demands_completed = 0
    money_spent = 0.0
    _last_type = &""
    _nag_timer = 0.0
    _festival_stage = &"bring_tv"
    _festival_progress = 0.0
    demand_changed.emit(get_state())

func assign_after_wake(forced_type: StringName = &"") -> void:
    if not RunStats.run_active:
        return
    if active_type != &"":
        queued_demands = mini(queued_demands + 1, 2)
        QuestManager.notification_requested.emit("РИТА ДОБАВИЛА ЕЩЁ ОДНО ПОРУЧЕНИЕ  •  В ОЧЕРЕДИ: %d" % queued_demands)
        demand_changed.emit(get_state())
        return
    _activate_demand(forced_type)

func _activate_demand(forced_type: StringName = &"") -> void:
    if not RunStats.run_active:
        queued_demands = 0
        return
    var next_type := forced_type
    if not DEMAND_DEFINITIONS.has(next_type):
        var candidates: Array[StringName] = []
        for type_variant in DEMAND_DEFINITIONS.keys():
            var candidate := StringName(type_variant)
            if candidate != _last_type:
                candidates.append(candidate)
        next_type = candidates[randi() % candidates.size()]
    active_type = next_type
    _last_type = next_type
    demands_received += 1
    _nag_timer = 22.0
    _festival_stage = &"bring_tv"
    _festival_progress = 0.0
    RunStats.record_rita_demand_received()
    var definition: Dictionary = DEMAND_DEFINITIONS[active_type]
    subtitle_requested.emit(String(definition["line"]))
    QuestManager.notification_requested.emit("РИТА ОЗАДАЧИЛА ДЕНИСА  •  %s" % String(definition["objective"]))
    QuestManager.quest_updated.emit(QuestManager.get_state())
    demand_changed.emit(get_state())

func has_active_demand() -> bool:
    return active_type != &""

func get_objective() -> String:
    if active_type == &"":
        return ""
    if active_type == &"festival_cinema" and _festival_stage == &"watching":
        return "СТОЯТЬ РЯДОМ, ПОКА РИТА СМОТРИТ КИНО И ЗАСЫПАЕТ  •  %d%%" % int(_festival_progress)
    return String(DEMAND_DEFINITIONS[active_type]["objective"])

func begin_festival_movie() -> bool:
    if active_type != &"festival_cinema":
        return false
    if _festival_stage != &"watching":
        _festival_stage = &"watching"
        _festival_progress = 0.0
        subtitle_requested.emit("Вот. Не переключай и стой здесь, пока я смотрю.")
        QuestManager.notification_requested.emit("РИТА СМОТРИТ ЯПОНСКОЕ КИНО  •  НЕ ОТХОДИ ОТ ТЕЛЕВИЗОРА")
        QuestManager.quest_updated.emit(QuestManager.get_state())
        demand_changed.emit(get_state())
    return true

func set_festival_progress(value: float) -> void:
    if active_type != &"festival_cinema" or _festival_stage != &"watching":
        return
    var next_progress := clampf(value, 0.0, 100.0)
    if absf(next_progress - _festival_progress) < 0.05:
        return
    _festival_progress = next_progress
    demand_changed.emit(get_state())

func is_festival_movie_watching() -> bool:
    return active_type == &"festival_cinema" and _festival_stage == &"watching"

func get_festival_progress() -> float:
    return _festival_progress

func get_location() -> StringName:
    if active_type == &"":
        return &""
    return StringName(DEMAND_DEFINITIONS[active_type]["location"])

func can_complete_at(location: StringName) -> bool:
    if active_type == &"":
        return false
    return StringName(DEMAND_DEFINITIONS[active_type]["location"]) == location

func try_complete_at(location: StringName) -> String:
    if not RunStats.run_active:
        return "ЗАБЕГ ЗАВЕРШЁН"
    if active_type == &"":
        return "РИТА ПОКА НИЧЕГО НЕ ТРЕБУЕТ"
    var definition: Dictionary = DEMAND_DEFINITIONS[active_type]
    if StringName(definition["location"]) != location:
        return "СНАЧАЛА: %s" % String(definition["objective"])
    if active_type == &"festival_cinema" and _festival_progress < 99.9:
        return "РИТА ЕЩЁ СМОТРИТ  •  СТОЙ РЯДОМ С ТЕЛЕВИЗОРОМ"
    var cost := float(definition["cost"])
    if cost > 0.0:
        RunStats.spend_money(cost)
        money_spent += cost
    demands_completed += 1
    RunStats.record_rita_demand_completed(cost)
    var result := String(definition["done"])
    active_type = &""
    _festival_stage = &"bring_tv"
    _festival_progress = 0.0
    RitaSleep.on_demand_completed()
    if queued_demands > 0 and RunStats.run_active:
        queued_demands -= 1
        call_deferred("_activate_demand")
    QuestManager.quest_updated.emit(QuestManager.get_state())
    demand_changed.emit(get_state())
    return result

func get_state() -> Dictionary:
    return {
        "active": active_type != &"",
        "type": active_type,
        "objective": get_objective(),
        "queued": queued_demands,
        "received": demands_received,
        "completed": demands_completed,
        "money_spent": money_spent,
        "festival_stage": _festival_stage,
        "festival_progress": _festival_progress
    }

func _nag_line(demand_type: StringName) -> String:
    match demand_type:
        &"order_food": return "Денис, еда сама себя не закажет. Я жду."
        &"order_medicine": return "Где лекарства, Денис? Я не забыла."
        &"clean_bathroom": return "Ванная всё ещё грязная. Не беси меня второй раз."
        &"wash_dishes": return "Я слышу, что посуда всё ещё в раковине."
        &"festival_cinema":
            if _festival_stage == &"watching":
                return "Денис, не уходи. Я ещё не уснула."
            return "Где телевизор? Я хочу своё японское фестивальное кино."
    return "Денис, выполни то, что я попросила."
