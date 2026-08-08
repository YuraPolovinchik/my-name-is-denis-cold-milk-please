extends Node

signal run_finished(result: Dictionary)
signal run_reset()
signal economy_updated(data: Dictionary)
signal denis_spoke(text: String)

var run_active = false
var elapsed_time = 0.0
var peak_wake_level = 0.0
var loud_actions = 0
var dropped_items = 0
var answered_calls = 0
var missed_calls = 0
var rita_awake = false
var camera_warning = false
var money_balance := 750.0
var living_cost_rate := 2.5
var payment_opportunities := 0
var payments_received := 0
var missed_payments := 0
var missed_payment_streak := 0
var cash_found := 0.0
var total_heard_noise := 0.0
var prevented_noise := 0.0
var rita_demands_received := 0
var rita_demands_completed := 0
var rita_demand_spending := 0.0
var football_moments_watched := 0
var football_moments_missed := 0
var beer_sips := 0
var peak_intoxication := 0.0
var kitchen_floods := 0
var payment_altar_bows := 0
# Pour stats (manual pouring system)
var pour_water_hit_ml := 0.0
var pour_water_spilled_ml := 0.0
var pour_milk_hit_ml := 0.0
var pour_milk_spilled_ml := 0.0
var cleaned_water_ml := 0.0
var cleaned_milk_ml := 0.0
var cleaned_coffee_mix_ml := 0.0

var milk_orders := 0
var missed_couriers := 0
var milk_spending := 0.0
var best_challenge_score := 0
var best_clean_time := INF
var seed_value = 0
var scenario = 0
var _finish_guard = false
var _economy_emit_timer := 0.0
var last_finished_result: Dictionary = {}

const LEADERBOARD_PATH := "user://coffee_leaderboard.json"
const LEADERBOARD_LIMIT := 50

func _process(delta: float) -> void:
    if run_active:
        elapsed_time += delta
        money_balance -= living_cost_rate * delta
        _economy_emit_timer -= delta
        if _economy_emit_timer <= 0.0:
            _economy_emit_timer = 0.25
            economy_updated.emit(get_economy_state())

func reset_run() -> void:
    run_active = true
    elapsed_time = 0.0
    peak_wake_level = 0.0
    loud_actions = 0
    dropped_items = 0
    answered_calls = 0
    missed_calls = 0
    rita_awake = false
    camera_warning = false
    money_balance = 750.0
    payment_opportunities = 0
    payments_received = 0
    missed_payments = 0
    missed_payment_streak = 0
    cash_found = 0.0
    total_heard_noise = 0.0
    prevented_noise = 0.0
    rita_demands_received = 0
    rita_demands_completed = 0
    rita_demand_spending = 0.0
    football_moments_watched = 0
    football_moments_missed = 0
    beer_sips = 0
    peak_intoxication = 0.0
    kitchen_floods = 0
    payment_altar_bows = 0
    pour_water_hit_ml = 0.0
    pour_water_spilled_ml = 0.0
    pour_milk_hit_ml = 0.0
    pour_milk_spilled_ml = 0.0
    cleaned_water_ml = 0.0
    cleaned_milk_ml = 0.0
    cleaned_coffee_mix_ml = 0.0
    milk_orders = 0
    missed_couriers = 0
    milk_spending = 0.0
    _economy_emit_timer = 0.0
    _finish_guard = false
    seed_value = int(Time.get_unix_time_from_system()) % 2147483647
    seed(seed_value)
    scenario = randi_range(0, 1)
    run_reset.emit()
    economy_updated.emit(get_economy_state())

func receive_payment(amount: float = 900.0) -> void:
    payment_opportunities += 1
    payments_received += 1
    missed_payment_streak = 0
    money_balance += amount
    economy_updated.emit(get_economy_state())

func miss_payment() -> float:
    payment_opportunities += 1
    missed_payments += 1
    missed_payment_streak += 1
    var loss := 450.0 + float(missed_payment_streak) * 225.0
    money_balance -= loss
    economy_updated.emit(get_economy_state())
    return loss

func collect_cash(amount: float) -> void:
    if amount <= 0.0:
        return
    cash_found += amount
    money_balance += amount
    economy_updated.emit(get_economy_state())

func spend_money(amount: float) -> void:
    if amount <= 0.0:
        return
    money_balance -= amount
    economy_updated.emit(get_economy_state())

func record_rita_demand_received() -> void:
    rita_demands_received += 1

func record_rita_demand_completed(cost: float) -> void:
    rita_demands_completed += 1
    rita_demand_spending += maxf(cost, 0.0)

func record_noise_prevented(amount: float) -> void:
    prevented_noise += maxf(amount, 0.0)

func record_football_moment(watched: bool) -> void:
    if watched:
        football_moments_watched += 1
    else:
        football_moments_missed += 1

func record_beer_sip(current_intoxication: float) -> void:
    beer_sips += 1
    peak_intoxication = maxf(peak_intoxication, current_intoxication)

func record_kitchen_flood() -> void:
    kitchen_floods += 1

func record_pour_stats(hit_ml: float, spilled_ml: float, liquid_id: String) -> void:
    if liquid_id == "water":
        pour_water_hit_ml += maxf(hit_ml, 0.0)
        pour_water_spilled_ml += maxf(spilled_ml, 0.0)
    elif liquid_id == "milk":
        pour_milk_hit_ml += maxf(hit_ml, 0.0)
        pour_milk_spilled_ml += maxf(spilled_ml, 0.0)

func record_cleaned_liquid(amount_ml: float, liquid_id: String) -> void:
    var cleaned := maxf(amount_ml, 0.0)
    match liquid_id:
        "water":
            cleaned_water_ml += cleaned
        "milk":
            cleaned_milk_ml += cleaned
        "coffee_mix":
            cleaned_coffee_mix_ml += cleaned

func get_total_cleaned_ml() -> float:
    return cleaned_water_ml + cleaned_milk_ml + cleaned_coffee_mix_ml

func get_pour_accuracy(liquid_id: String) -> float:
    var hit := 0.0
    var spilled := 0.0
    if liquid_id == "water":
        hit = pour_water_hit_ml
        spilled = pour_water_spilled_ml
    elif liquid_id == "milk":
        hit = pour_milk_hit_ml
        spilled = pour_milk_spilled_ml
    else:
        hit = pour_water_hit_ml + pour_milk_hit_ml
        spilled = pour_water_spilled_ml + pour_milk_spilled_ml
    var total := hit + spilled
    if total <= 0.0:
        return 0.0
    return (hit / total) * 100.0

func get_pour_rank(accuracy: float) -> String:
    if accuracy >= 99.5:
        return "S — ИДЕАЛЬНАЯ МЕТКОСТЬ"
    elif accuracy >= 95.0:
        return "A — ОТЛИЧНАЯ МЕТКОСТЬ"
    elif accuracy >= 85.0:
        return "B — ХОРОШАЯ МЕТКОСТЬ"
    elif accuracy >= 70.0:
        return "C — СРЕДНЯЯ МЕТКОСТЬ"
    elif accuracy >= 50.0:
        return "D — НИЗКАЯ МЕТКОСТЬ"
    else:
        return "F — ВОДИТЕЛЬ-НЕУДАЧНИК"

func get_total_pour_accuracy() -> float:
    return get_pour_accuracy("")

func record_milk_order(cost: float) -> void:
    milk_orders += 1
    milk_spending += maxf(cost, 0.0)

func record_missed_courier() -> void:
    missed_couriers += 1

func get_economy_state() -> Dictionary:
    return {
        "balance": money_balance,
        "debt": maxf(-money_balance, 0.0),
        "living_cost_rate": living_cost_rate,
        "payment_opportunities": payment_opportunities,
        "payments_received": payments_received,
        "missed_payments": missed_payments,
        "missed_payment_streak": missed_payment_streak,
        "cash_found": cash_found
    }

func record_noise(raw_strength: float, heard_strength: float, _category: StringName) -> void:
    total_heard_noise += maxf(heard_strength, 0.0)
    if raw_strength >= 18.0:
        loud_actions += 1

func record_drop() -> void:
    dropped_items += 1

func record_payment_altar_bow() -> void:
    payment_altar_bows += 1

func finish_run() -> Dictionary:
    if _finish_guard:
        return {}
    _finish_guard = true
    run_active = false
    var challenge_score := calculate_challenge_score()
    best_challenge_score = maxi(best_challenge_score, challenge_score)
    if money_balance >= 0.0 and not rita_awake:
        best_clean_time = minf(best_clean_time, elapsed_time)
    var pour_accuracy := get_total_pour_accuracy()
    var result = {
        "time": elapsed_time,
        "peak_wake": peak_wake_level,
        "loud_actions": loud_actions,
        "dropped_items": dropped_items,
        "answered_calls": answered_calls,
        "missed_calls": missed_calls,
        "rita_awake": rita_awake,
        "camera_warning": camera_warning,
        "balance": money_balance,
        "debt": maxf(-money_balance, 0.0),
        "payments_received": payments_received,
        "missed_payments": missed_payments,
        "cash_found": cash_found,
        "total_heard_noise": total_heard_noise,
        "prevented_noise": prevented_noise,
        "rita_demands_received": rita_demands_received,
        "rita_demands_completed": rita_demands_completed,
        "rita_demand_spending": rita_demand_spending,
        "football_moments_watched": football_moments_watched,
        "football_moments_missed": football_moments_missed,
        "beer_sips": beer_sips,
        "peak_intoxication": peak_intoxication,
        "kitchen_floods": kitchen_floods,
        "payment_altar_bows": payment_altar_bows,
        "milk_orders": milk_orders,
        "missed_couriers": missed_couriers,
        "milk_spending": milk_spending,
        "pour_water_hit_ml": pour_water_hit_ml,
        "pour_water_spilled_ml": pour_water_spilled_ml,
        "pour_milk_hit_ml": pour_milk_hit_ml,
        "pour_milk_spilled_ml": pour_milk_spilled_ml,
        "cleaned_water_ml": cleaned_water_ml,
        "cleaned_milk_ml": cleaned_milk_ml,
        "cleaned_coffee_mix_ml": cleaned_coffee_mix_ml,
        "cleaned_ml": get_total_cleaned_ml(),
        "pour_accuracy": pour_accuracy,
        "pour_rank": get_pour_rank(pour_accuracy),
        "challenge_score": challenge_score,
        "best_challenge_score": best_challenge_score,
        "best_clean_time": best_clean_time,
        "seed": seed_value,
        "rank": calculate_rank()
    }
    last_finished_result = result.duplicate(true)
    # Проверка достижений
    _check_achievements(result)
    run_finished.emit(result)
    return result

func save_leaderboard_result(player_name: String, result: Dictionary = {}) -> Dictionary:
    var clean_name := player_name.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
    if clean_name.is_empty():
        clean_name = "ДЕНИС"
    clean_name = clean_name.substr(0, 18)
    var source := result if not result.is_empty() else last_finished_result
    if source.is_empty():
        return {"ok": false, "error": "НЕТ ЗАВЕРШЁННОГО ЗАБЕГА"}
    var entries := load_leaderboard()
    var replacement_index := -1
    for index in range(entries.size()):
        if String(entries[index].get("name", "")).to_lower() == clean_name.to_lower():
            replacement_index = index
            break
    var entry := {
        "name": clean_name,
        "time": float(source.get("time", 0.0)),
        "balance": float(source.get("balance", 0.0)),
        "debt": float(source.get("debt", 0.0)),
        "score": int(source.get("challenge_score", 0)),
        "rank": String(source.get("rank", "")),
        "saved_at": Time.get_datetime_string_from_system(false, true)
    }
    if replacement_index >= 0:
        entries[replacement_index] = entry
    else:
        entries.append(entry)
    entries = sort_leaderboard_entries(entries)
    if entries.size() > LEADERBOARD_LIMIT:
        entries.resize(LEADERBOARD_LIMIT)
    var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "error": "НЕ УДАЛОСЬ СОХРАНИТЬ ТАБЛИЦУ"}
    file.store_string(JSON.stringify(entries, "\t"))
    file.close()
    var place := entries.find(entry) + 1
    return {"ok": true, "place": place, "entry": entry, "entries": entries}

func load_leaderboard() -> Array:
    if not FileAccess.file_exists(LEADERBOARD_PATH):
        return []
    var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
    if file == null:
        return []
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Array:
        return []
    var entries: Array = []
    for candidate in parsed:
        if candidate is Dictionary:
            entries.append(candidate)
    return sort_leaderboard_entries(entries)

func sort_leaderboard_entries(entries: Array) -> Array:
    var sorted := entries.duplicate(true)
    sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var time_a := float(a.get("time", INF))
        var time_b := float(b.get("time", INF))
        if not is_equal_approx(time_a, time_b):
            return time_a < time_b
        var balance_a := float(a.get("balance", -INF))
        var balance_b := float(b.get("balance", -INF))
        if not is_equal_approx(balance_a, balance_b):
            return balance_a > balance_b
        return int(a.get("score", 0)) > int(b.get("score", 0))
    )
    return sorted

func calculate_challenge_score() -> int:
    var score := 10000.0
    score -= elapsed_time * 10.0
    score -= total_heard_noise * 18.0
    score -= float(missed_calls) * 250.0
    score -= float(missed_payments) * 700.0
    score += prevented_noise * 6.0
    score += float(payments_received) * 200.0
    score -= float(rita_demands_received) * 350.0
    score -= rita_demand_spending * 0.5
    score += float(football_moments_watched) * 120.0
    score -= float(football_moments_missed) * 220.0
    score -= maxf(0.0, peak_intoxication - 55.0) * 3.0
    score -= float(kitchen_floods) * 1500.0
    score -= float(missed_couriers) * 650.0
    # Bonus for pour accuracy
    var pour_acc := get_total_pour_accuracy()
    if pour_acc >= 99.5:
        score += 5000
    elif pour_acc >= 95.0:
        score += 3000
    elif pour_acc >= 85.0:
        score += 2000
    elif pour_acc >= 70.0:
        score += 1000
    elif pour_acc >= 50.0:
        score += 500
    # Penalty for very bad pouring
    if pour_acc < 30.0 and (pour_water_spilled_ml + pour_milk_spilled_ml) > 50.0:
        score -= 2000
    return maxi(0, int(round(score)))

func calculate_rank() -> String:
    if money_balance < 0.0:
        return "D — ДОЛГ %.0f ₽" % absf(money_balance)
    if camera_warning:
        return "D — КАМЕРА БЫЛА ВКЛЮЧЕНА"
    if rita_awake:
        return "C — РИТА ВСЁ СЛЫШАЛА"
    if peak_wake_level < 35.0 and missed_calls == 0 and elapsed_time <= 360.0:
        return "S — ТИХИЙ УДАЛЁНЩИК"
    if peak_wake_level < 70.0 and missed_calls <= 1:
        return "A — МЕНЕДЖЕР НА НОСОЧКАХ"
    return "B — КОФЕ ПОЛУЧЕН"

func format_time(seconds: float) -> String:
    var total = int(seconds)
    return "%02d:%02d" % [total / 60, total % 60]

func _check_achievements(result: Dictionary) -> void:
    # Достижение за бесшумное прохождение
    if not result.get("rita_awake", true) and result.get("peak_wake", 100.0) < 50.0:
        AchievementSystem.unlock_achievement("ghost_runner")
        AchievementSystem.on_silent_run_completed()
    
    # Достижение за скорость
    if result.get("time", 999.0) < 180.0:
        AchievementSystem.unlock_achievement("speed_demon")
    
    # Достижение за идеальный забег
    if result.get("rank", "") == "S — ТИХИЙ УДАЛЁНЩИК":
        AchievementSystem.unlock_achievement("perfect_run")
    
    # Достижение за коллекционирование денег
    if result.get("cash_found", 0) >= 2000.0:
        AchievementSystem.unlock_achievement("money_bags")
    
    # Достижение за пиво
    if result.get("beer_sips", 0) >= 3:
        AchievementSystem.on_beer_drank(result.get("beer_sips", 0))
    
    # Достижение за футбол
    if result.get("football_moments_watched", 0) >= 3:
        AchievementSystem.unlock_achievement("football_fan")
    
    # Достижение за экономию (без долгов)
    if result.get("debt", 0.0) <= 0.0 and result.get("missed_payments", 0) == 0:
        AchievementSystem.unlock_achievement("perfectionist")
    
    # Достижение за меткость S-ранг
    var pour_acc: float = result.get("pour_accuracy", 0.0)
    if pour_acc >= 99.5:
        AchievementSystem.unlock_achievement("sniper_pour")
    
    # Достижение за ноль пролитого
    if pour_acc >= 100.0:
        AchievementSystem.unlock_achievement("zero_spill")
