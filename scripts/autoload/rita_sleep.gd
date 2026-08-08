extends Node

signal wake_changed(value: float, state_text: String)
signal state_changed(state_index: int, state_text: String)
signal awakened(reason: StringName)
signal subtitle_requested(text: String)

var wake_level: float = 0.0
var peak_wake_level: float = 0.0
var last_noise_category: StringName = &"NONE"
var last_noise_source: StringName = &"NONE"
var awakened_once := false
var is_angry := false
var player_hidden := false
var calm_progress := 0.0
var _silence_time := 0.0
var _state_index := 0
var _curse_timer := 0.0
var _source_last_time: Dictionary = {}
var _source_streaks: Dictionary = {}
var _source_reaction_stage: Dictionary = {}
var _last_reaction_time := -100.0
var _post_demand_grace := 0.0

const DECAY_DELAY := 3.0
const DECAY_PER_SECOND := 4.5
const CALM_REQUIRED := 6.0
const SOURCE_CHAIN_RESET := 4.5
const REACTION_COOLDOWN := 2.0
const DEMAND_SLEEP_DECAY := 12.0
const POST_DEMAND_GRACE := 5.0

func _process(delta: float) -> void:
    if not RunStats.run_active:
        return
    if is_angry:
        _process_angry(delta)
        return
    if RitaDemands.has_active_demand():
        _process_demand_sleep(delta)
        return
    if _post_demand_grace > 0.0:
        _post_demand_grace = maxf(0.0, _post_demand_grace - delta)
        wake_level = 0.0
        wake_changed.emit(wake_level, get_state_text())
        return
    _silence_time += delta
    if _silence_time >= DECAY_DELAY and wake_level > 0.0:
        wake_level = maxf(0.0, wake_level - DECAY_PER_SECOND * delta)
        _update_state(false)

func _process_demand_sleep(delta: float) -> void:
    _silence_time += delta
    wake_level = maxf(0.0, wake_level - DEMAND_SLEEP_DECAY * delta)
    _state_index = 0
    wake_changed.emit(wake_level, get_state_text())

func on_demand_completed() -> void:
    wake_level = 0.0
    _silence_time = 0.0
    _state_index = 0
    _post_demand_grace = POST_DEMAND_GRACE
    wake_changed.emit(wake_level, get_state_text())

func _process_angry(delta: float) -> void:
    if player_hidden:
        calm_progress += delta * 1.65
        wake_level = clampf(100.0 * (1.0 - calm_progress / CALM_REQUIRED), 0.0, 100.0)
        wake_changed.emit(wake_level, get_state_text())
        if calm_progress >= CALM_REQUIRED:
            _finish_angry_state()
        return
    var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
    var moving := player != null and Vector2(player.velocity.x, player.velocity.z).length() > 0.08
    calm_progress = 0.0
    wake_level = 100.0
    _curse_timer -= delta
    if _curse_timer <= 0.0:
        _curse_timer = 2.25 if moving else 3.4
        subtitle_requested.emit(_movement_curse())
    wake_changed.emit(wake_level, get_state_text())

func _finish_angry_state() -> void:
    is_angry = false
    wake_level = 18.0
    _state_index = 0
    subtitle_requested.emit("Блядь... всё. Выходи. Разбудил — теперь сделаешь, что скажу.")
    QuestManager.clear_bonus_objective(&"escape")
    RitaDemands.assign_after_wake()
    QuestManager.notification_requested.emit("РИТА УСПОКОИЛАСЬ, НО ТЕПЕРЬ У НЕЁ ЕСТЬ ПОРУЧЕНИЕ")
    wake_changed.emit(wake_level, get_state_text())

func set_player_hidden(value: bool) -> void:
    if player_hidden == value:
        return
    player_hidden = value
    if player_hidden and is_angry:
        calm_progress = maxf(calm_progress, 0.4)
        subtitle_requested.emit("Денис?.. Куда ты, блядь, делся?..")
        QuestManager.set_bonus_objective(&"escape", "СИДИ В ГАРДЕРОБНОЙ, ПОКА РИТА НЕ УСПОКОИТСЯ")
    elif is_angry:
        subtitle_requested.emit("Я тебя всё равно найду. Беги в гардеробную!")
        QuestManager.set_bonus_objective(&"escape", "БЕГИ В ГАРДЕРОБНУЮ И СПРЯЧЬСЯ")

func reset() -> void:
    wake_level = 0.0
    peak_wake_level = 0.0
    last_noise_category = &"NONE"
    last_noise_source = &"NONE"
    awakened_once = false
    is_angry = false
    player_hidden = false
    calm_progress = 0.0
    _silence_time = 0.0
    _state_index = 0
    _curse_timer = 0.0
    _source_last_time.clear()
    _source_streaks.clear()
    _source_reaction_stage.clear()
    _last_reaction_time = -100.0
    _post_demand_grace = 0.0
    wake_changed.emit(wake_level, get_state_text())

func add_noise(amount: float, category: StringName, source_id: StringName) -> void:
    if amount <= 0.01 or not RunStats.run_active:
        return
    if is_angry:
        return
    if RitaDemands.has_active_demand() or _post_demand_grace > 0.0:
        return
    var streak := _register_source_pulse(source_id)
    var effective_amount := _effective_noise_amount(amount, source_id, streak)
    if effective_amount < 0.35:
        return
    _silence_time = 0.0
    last_noise_category = category
    last_noise_source = source_id
    # Применяем модификатор сложности
    effective_amount *= DifficultyManager.get_rita_wake_speed()
    wake_level = clampf(wake_level + effective_amount, 0.0, 100.0)
    peak_wake_level = maxf(peak_wake_level, wake_level)
    RunStats.peak_wake_level = peak_wake_level
    var source_reacted := _maybe_source_reaction(source_id, streak)
    _update_state(not source_reacted)
    if wake_level >= 100.0 and not is_angry:
        awakened_once = true
        is_angry = true
        calm_progress = 0.0
        _curse_timer = 1.8
        RunStats.rita_awake = true
        awakened.emit(category)
        subtitle_requested.emit(_awake_line_for(category, source_id))
        QuestManager.on_rita_awakened(category)
        QuestManager.set_bonus_objective(&"escape", "НИЧЕГО НЕ ТРОГАЙ. БЕГИ В ГАРДЕРОБНУЮ И СПРЯЧЬСЯ")
        # Экранные эффекты при пробуждении
        ScreenEffects.chromatic_aberration_pulse(0.8, 0.4)
        ScreenEffects.vignette_pulse(0.6, 0.5)
        ScreenEffects.shake(0.5, 0.3)
        # Отслеживание достижений
        AchievementSystem.on_rita_awakened(category)

func _register_source_pulse(source_id: StringName) -> int:
    var now: float = float(RunStats.elapsed_time)
    var last_time := float(_source_last_time.get(source_id, -100.0))
    var streak := 1
    if now - last_time <= SOURCE_CHAIN_RESET:
        streak = int(_source_streaks.get(source_id, 0)) + 1
    else:
        _source_reaction_stage[source_id] = 0
    _source_last_time[source_id] = now
    _source_streaks[source_id] = streak
    return streak

func _effective_noise_amount(amount: float, source_id: StringName, streak: int) -> float:
    match source_id:
        &"phone":
            return amount * clampf(0.52 + float(streak - 1) * 0.018, 0.52, 0.70)
        &"vacuum":
            return amount * clampf(0.68 + float(streak - 1) * 0.018, 0.68, 0.88)
        &"washing_machine":
            return amount * clampf(0.38 + float(streak - 1) * 0.018, 0.38, 0.62)
        &"kettle_hum":
            return amount * clampf(0.52 + float(streak - 1) * 0.012, 0.52, 0.68)
        &"television":
            # A steady television is less startling than an impact, but becomes
            # increasingly aggravating when Denis leaves the sound running.
            return amount * clampf(0.58 + float(streak - 1) * 0.018, 0.58, 0.78)
        &"doorbell":
            return amount * clampf(0.88 + float(streak - 1) * 0.025, 0.88, 1.0)
    return amount

func _maybe_source_reaction(source_id: StringName, streak: int) -> bool:
    var desired_stage := 0
    match source_id:
        &"phone":
            desired_stage = 3 if streak >= 9 else (2 if streak >= 5 else (1 if streak >= 2 else 0))
        &"vacuum":
            desired_stage = 3 if streak >= 9 else (2 if streak >= 5 else (1 if streak >= 2 else 0))
        &"washing_machine":
            desired_stage = 3 if streak >= 9 else (2 if streak >= 5 else (1 if streak >= 2 else 0))
        &"kettle_hum":
            desired_stage = 2 if streak >= 7 else (1 if streak >= 3 else 0)
        &"television":
            desired_stage = 3 if streak >= 9 else (2 if streak >= 5 else (1 if streak >= 2 else 0))
        &"doorbell":
            desired_stage = 3 if streak >= 5 else (2 if streak >= 3 else 1)
    var current_stage := int(_source_reaction_stage.get(source_id, 0))
    if desired_stage <= current_stage or RunStats.elapsed_time - _last_reaction_time < REACTION_COOLDOWN:
        return false
    var line := _source_reaction_line(source_id, desired_stage)
    if line.is_empty():
        return false
    _source_reaction_stage[source_id] = desired_stage
    _last_reaction_time = RunStats.elapsed_time
    subtitle_requested.emit(line)
    return true

func _source_reaction_line(source_id: StringName, stage: int) -> String:
    match source_id:
        &"phone":
            if stage == 1: return "Денис... телефон вибрирует. Убери звук, пожалуйста."
            if stage == 2: return "Денис, выключи уже вибрацию, я пытаюсь спать."
            if stage == 3: return "ДА ЗАТКНИ ТЫ ЭТОТ ЕБУЧИЙ ТЕЛЕФОН, ДЕНИС!"
        &"vacuum":
            if stage == 1: return "М-м... пылесос сам включился. Останови его."
            if stage == 2: return "Денис, этот пылесос уже заебал. Выключи."
            if stage == 3: return "ТЫ СОВСЕМ ЕБАНУЛСЯ? КАКОЙ НАХУЙ ПЫЛЕСОС С УТРА?!"
        &"washing_machine":
            if stage == 1: return "Денис... стиралка опять скачет. Поймай её, пожалуйста."
            if stage == 2: return "Денис, она сейчас из ванной уедет. Выключи отжим."
            if stage == 3: return "ДЕНИС, БЛЯДЬ, УТИХОМИРЬ ЭТУ СТИРАЛКУ!"
        &"kettle_hum":
            if stage == 1: return "Денис... чайник шумит."
            if stage == 2: return "Сними уже чайник, он заебал гудеть."
        &"television":
            if stage == 1: return "Денис... телевизор слишком громко. Выключи звук, пожалуйста."
            if stage == 2: return "Денис, выключи уже звук у телека. Я из-за него не сплю."
            if stage == 3: return "ДА ЗАТКНИ ТЫ ЭТОТ ЕБУЧИЙ ТЕЛЕК, ДЕНИС! ОН НА ВСЮ КВАРТИРУ ОРЁТ!"
        &"doorbell":
            if stage == 1: return "Денис... кто там звонит? Забери уже заказ."
            if stage == 2: return "ДЕНИС, БЛЯДЬ, У ТЕБЯ КУРЬЕР В ДВЕРЬ ДОЛБИТСЯ!"
            if stage == 3: return "ДА ЗАБЕРИ ТЫ УЖЕ ЭТО МОЛОКО! ОН МЕНЯ СЕЙЧАС РАЗБУДИТ!"
    return ""

func get_state_text() -> String:
    if is_angry:
        if player_hidden:
            return "ИЩЕТ ДЕНИСА — УКРЫТИЕ %d%%" % int(clampf(calm_progress / CALM_REQUIRED * 100.0, 0.0, 100.0))
        return "В ЯРОСТИ — БЕГИ В ГАРДЕРОБНУЮ"
    if RitaDemands.has_active_demand():
        return "ЗАСЫПАЕТ — ШУМ НЕ КОПИТСЯ"
    if _post_demand_grace > 0.0:
        return "УСНУЛА ПОСЛЕ ПОРУЧЕНИЯ"
    if wake_level < 25.0: return "СПИТ КРЕПКО"
    if wake_level < 50.0: return "ВОРОЧАЕТСЯ"
    if wake_level < 75.0: return "ПРИСЛУШИВАЕТСЯ"
    if wake_level < 100.0: return "ПОЧТИ ПРОСНУЛАСЬ"
    return "ПРОСНУЛАСЬ"

func _update_state(with_reaction: bool) -> void:
    var next_state := 0
    if wake_level >= 100.0: next_state = 4
    elif wake_level >= 75.0: next_state = 3
    elif wake_level >= 50.0: next_state = 2
    elif wake_level >= 25.0: next_state = 1
    if next_state != _state_index:
        _state_index = next_state
        state_changed.emit(_state_index, get_state_text())
        if with_reaction and RunStats.elapsed_time - _last_reaction_time >= REACTION_COOLDOWN:
            var line := _stage_reaction(_state_index)
            if not line.is_empty():
                _last_reaction_time = RunStats.elapsed_time
                subtitle_requested.emit(line)
    wake_changed.emit(wake_level, get_state_text())

func _movement_curse() -> String:
    var lines := [
        "Блядь, Денис, я иду! Прячься, пока я тебя не нашла!",
        "БЕГИ В ГАРДЕРОБНУЮ, СУКА, И НЕ ПОПАДАЙСЯ МНЕ!",
        "Я ТЕБЕ СЕЙЧАС ЭТОТ ЧАЙНИК В ЖОПУ ЗАСУНУ!",
        "КАКОГО ХУЯ ТЫ ЕЩЁ НЕ СПРЯТАЛСЯ?!"
    ]
    return lines[randi() % lines.size()]

func _stage_reaction(stage: int) -> String:
    match stage:
        1:
            return "М-м?.. Денис, потише, пожалуйста."
        2:
            return "Денис... я всё слышу. Разберись с этим шумом."
        3:
            return "Какого хрена ты там делаешь? Ещё звук — и я встану."
    return ""

func _awake_line_for(category: StringName, source_id: StringName) -> String:
    if source_id == &"phone":
        return "ДЕНИС, БЛЯДЬ! Я ТЕБЕ СЕЙЧАС ЭТОТ ТЕЛЕФОН РАЗЪЕБУ!"
    if source_id == &"vacuum":
        return "ЕБАТЬ, ТЫ РЕАЛЬНО НЕ ВЫКЛЮЧИЛ ПЫЛЕСОС?! БЕГИ, СУКА!"
    if source_id == &"washing_machine":
        return "КАКОГО ХУЯ СТИРАЛКА ЕДЕТ ПО КОРИДОРУ?! БЕГИ ПРЯТАТЬСЯ!"
    if source_id == &"television":
        return "КАКОГО ХУЯ ТЕЛЕК ОРЁТ НА ВСЮ КВАРТИРУ?! ЗАТКНИ ЕГО И БЕГИ В ГАРДЕРОБНУЮ!"
    if source_id == &"doorbell":
        return "ДЕНИС, СУКА! КУРЬЕР МЕНЯ РАЗБУДИЛ! БЕГИ В ГАРДЕРОБНУЮ, ПОКА Я ТЕБЯ НЕ УВИДЕЛА!"
    match category:
        &"KETTLE": return "ДЕНИС, БЛЯДЬ! КАКОГО ХУЯ ЧАЙНИК ОРЁТ?! БЕГИ ПРЯТАТЬСЯ!"
        &"DISHES", &"OBJECT_IMPACT": return "ЕБАТЬ, ТЫ ТАМ КУХНЮ РАЗЪЁБЫВАЕШЬ?! БЕГИ, ПОКА Я НЕ ВЫШЛА!"
        &"VOICE_CALL": return "ДЕНИС, СУКА, ЗАТКНИ СОЗВОН И ПРЯЧЬСЯ, Я ВСЁ СЛЫШУ!"
        _: return "КАКОГО ХУЯ, ДЕНИС?! БЕГИ В ГАРДЕРОБНУЮ, БЛЯДЬ!"
