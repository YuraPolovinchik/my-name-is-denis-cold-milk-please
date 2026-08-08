extends CanvasLayer

const APARTMENT_MAP_SCRIPT := preload("res://scripts/apartment_map.gd")
const POURING_HUD_SCENE := preload("res://scenes/ui/components/pouring_hud.tscn")
const UI_FONT: FontFile = preload("res://assets/fonts/NotoSans-Variable.ttf")

var objective_label: Label
var timer_label: Label
var wake_bar: ProgressBar
var wake_label: Label
var call_label: Label
var economy_label: Label
var condition_label: Label
var intoxication_label: Label
var stamina_bar: ProgressBar
var intoxication_bar: ProgressBar
var appliance_panel: Panel
var appliance_label: Label
var appliance_bar: ProgressBar
var contamination_panel: Panel
var contamination_label: Label
var contamination_bar: ProgressBar
var task_panel: Panel
var task_label: Label
var task_progress_bar: ProgressBar
var task_skill_track: ColorRect
var task_green_zone: ColorRect
var task_marker: ColorRect
var task_hint: Label
var prompt_label: Label
var message_label: Label
var subtitle_label: Label
var coffee_label: Label
var coffee_route_title: Label
var coffee_next_label: Label
var coffee_progress_bar: ProgressBar
var alert_banner: Panel
var alert_label: Label
var urgent_label: Label
var dev_label: Label
var bottom_bar: Panel
var result_panel: Panel
var result_label: Label
var result_leaderboard_label: Label
var player_name_edit: LineEdit
var save_result_button: Button
var restart_button: Button
var save_status_label: Label
var leaderboard_overlay: Panel
var leaderboard_overlay_label: Label
var intro_panel: Panel
var apartment_map: Control
var pouring_hud: PouringHUD
var _message_tween: Tween
var _subtitle_tween: Tween
var _intro_tween: Tween
var _dev_visible := false
var _intro_elapsed := 0.0
var _intro_hidden := false
var _current_result: Dictionary = {}

const INK := Color(0.045, 0.055, 0.07, 0.90)
const INK_SOFT := Color(0.055, 0.075, 0.09, 0.82)
const GLASS := Color(0.04, 0.06, 0.08, 0.58)
const GLASS_STRONG := Color(0.025, 0.035, 0.045, 0.78)
const CREAM := Color("f2eee6")
const GOLD := Color("edbd68")
const BLUE := Color("76b7d7")
const CORAL := Color("ef8066")
const MUTED := Color("9aa8b2")

func _ready() -> void:
    layer = 20
    _build_ui()
    pouring_hud = POURING_HUD_SCENE.instantiate() as PouringHUD
    add_child(pouring_hud)
    call_deferred("_bind_pouring_hud")
    QuestManager.quest_updated.connect(_on_quest_updated)
    QuestManager.notification_requested.connect(show_message)
    RitaSleep.wake_changed.connect(_on_wake_changed)
    RitaSleep.subtitle_requested.connect(show_subtitle)
    RitaDemands.subtitle_requested.connect(show_subtitle)
    RitaDemands.demand_changed.connect(_on_demand_changed)
    CallManager.subtitle_requested.connect(show_subtitle)
    MilkDelivery.courier_spoke.connect(show_subtitle)
    RunStats.run_finished.connect(_on_run_finished)
    RunStats.economy_updated.connect(_on_economy_updated)
    RunStats.denis_spoke.connect(show_subtitle)
    _on_quest_updated(QuestManager.get_state())
    _on_wake_changed(RitaSleep.wake_level, RitaSleep.get_state_text())
    _on_economy_updated(RunStats.get_economy_state())

func _bind_pouring_hud() -> void:
    var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
    var mug := get_tree().get_first_node_in_group("mug")
    var mug_controller := mug.get_node_or_null("MugContentController") as MugContentController if mug != null else null
    if pouring_hud != null and player != null and mug_controller != null:
        pouring_hud.bind(player, mug_controller)

func _process(delta: float) -> void:
    timer_label.text = RunStats.format_time(RunStats.elapsed_time)
    var call := CallManager.get_state()
    _update_player_condition()
    _update_appliance_progress()
    _update_kitchen_contamination()
    _update_task_progress()
    if bool(call.get("paused_for_rita", false)):
        call_label.text = "СОЗВОН НА ПАУЗЕ"
        call_label.modulate = BLUE
    elif bool(call["question_active"]):
        if String(call.get("question_kind", "status")) == "payment":
            call_label.text = "THE ПЛАТЁЖ  %.0fс" % float(call["answer_time_left"])
            call_label.modulate = GOLD
        else:
            call_label.text = "ОТВЕТЬ  %.0fс" % float(call["answer_time_left"])
            call_label.modulate = CORAL
    else:
        call_label.text = "WONE IT  %s" % RunStats.format_time(float(call["time_to_question"]))
        call_label.modulate = MUTED

    if not _intro_hidden:
        _intro_elapsed += delta
        var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1
        if _intro_elapsed > 7.5 or moving or Input.is_action_just_pressed("interact"):
            _hide_intro()

    if Input.is_action_just_pressed("dev_overlay"):
        _dev_visible = not _dev_visible
        dev_label.visible = _dev_visible
        alert_banner.visible = not _dev_visible
    if Input.is_action_just_pressed("map"):
        apartment_map.visible = not apartment_map.visible
    if Input.is_action_just_pressed("leaderboard") and RunStats.run_active:
        leaderboard_overlay.visible = not leaderboard_overlay.visible
        apartment_map.visible = false
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if leaderboard_overlay.visible else Input.MOUSE_MODE_CAPTURED)
        if leaderboard_overlay.visible:
            _refresh_leaderboard()
    if _dev_visible:
        _update_dev_overlay(call)
    else:
        _update_urgent_panel(call)

func set_prompt(text: String) -> void:
    prompt_label.text = text

func show_message(text: String) -> void:
    message_label.text = text
    message_label.modulate.a = 1.0
    AudioManager.play_ui(&"ui", -14.0)
    if _message_tween != null:
        _message_tween.kill()
    _message_tween = create_tween()
    _message_tween.tween_interval(2.2)
    _message_tween.tween_property(message_label, "modulate:a", 0.0, 0.45)

func show_subtitle(text: String) -> void:
    subtitle_label.text = text
    subtitle_label.modulate.a = 1.0
    if _subtitle_tween != null:
        _subtitle_tween.kill()
    _subtitle_tween = create_tween()
    _subtitle_tween.tween_interval(VoiceManager.subtitle_hold_time(text))
    _subtitle_tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.6)

func _on_quest_updated(data: Dictionary) -> void:
    objective_label.text = String(data.get("objective", "СДЕЛАТЬ КОФЕ"))
    _update_coffee_route(data)

func _update_coffee_route(data: Dictionary) -> void:
    # A readable recipe navigator replaces the old anonymous row of dots.
    # It shows one concrete action now, the following milestone, and overall
    # progress without forcing a new player to memorise what each light means.
    var coffee_available := bool(data.get("has_coffee", false))
    if CoffeeDelivery.needs_coffee() and not bool(data.get("coffee_powder_poured", false)):
        coffee_available = false
    var stages: Array[Dictionary] = [
        {"done": bool(data.get("has_mug", false)), "name": "КРУЖКА", "action": "ВЗЯТЬ КРУЖКУ"},
        {"done": coffee_available, "name": "КОФЕ", "action": "ДОСТАТЬ ИЛИ ЗАКАЗАТЬ КОФЕ"},
        {"done": bool(data.get("coffee_powder_poured", false)), "name": "ПОРОШОК", "action": "НАСЫПАТЬ КОФЕ В КРУЖКУ"},
        {"done": bool(data.get("kettle_filled", false)), "name": "ВОДА", "action": "НАПОЛНИТЬ ЧАЙНИК ПОД КРАНОМ"},
        {"done": bool(data.get("water_boiled", false)), "name": "КИПЯТОК", "action": "ПОСТАВИТЬ НА БАЗУ И ВСКИПЯТИТЬ"},
        {"done": bool(data.get("water_poured", false)), "name": "НАЛИТЬ", "action": "НАЛИТЬ КИПЯТОК В КРУЖКУ"},
        {"done": bool(data.get("has_milk", false)), "name": "МОЛОКО", "action": "ЗАКАЗАТЬ И ЗАБРАТЬ МОЛОКО"},
        {"done": bool(data.get("milk_poured", false)), "name": "ДОБАВИТЬ", "action": "НАЛИТЬ МОЛОКО В КРУЖКУ"},
        {"done": bool(data.get("coffee_made", false)), "name": "РАЗМЕШАТЬ", "action": "ПЕРЕМЕШАТЬ ЛОЖКОЙ"},
        {"done": bool(data.get("coffee_drunk", false)), "name": "ГОТОВО", "action": "ВЫПИТЬ КОФЕ"},
    ]
    var completed := 0
    var active_index := stages.size() - 1
    for index in range(stages.size()):
        if bool(stages[index]["done"]):
            completed += 1
        elif active_index == stages.size() - 1:
            active_index = index
            break
    if completed >= stages.size():
        active_index = stages.size() - 1
    var active: Dictionary = stages[active_index]
    coffee_route_title.text = "МАРШРУТ КОФЕ  •  ЭТАП %d/%d  •  %s" % [mini(active_index + 1, stages.size()), stages.size(), String(active["name"])]
    coffee_label.text = "СЕЙЧАС: %s" % String(active["action"])
    coffee_label.modulate = Color("9be8c1") if completed >= stages.size() else GOLD
    if active_index + 1 < stages.size():
        coffee_next_label.text = "ПОТОМ: %s" % String(stages[active_index + 1]["name"])
    else:
        coffee_next_label.text = "МАРШРУТ ЗАВЕРШЁН"
    coffee_progress_bar.value = float(completed) / float(stages.size()) * 100.0

func _on_demand_changed(_data: Dictionary) -> void:
    _on_quest_updated(QuestManager.get_state())
    _update_task_progress()

func _on_wake_changed(value: float, state_text: String) -> void:
    wake_bar.value = value
    wake_label.text = "РИТА  %s  %d%%" % [state_text, int(value)]
    var fill_color := BLUE
    if value >= 75.0:
        fill_color = CORAL
    elif value >= 40.0:
        fill_color = GOLD
    var fill := wake_bar.get_theme_stylebox("fill") as StyleBoxFlat
    if fill != null:
        fill.bg_color = fill_color

func _on_economy_updated(data: Dictionary) -> void:
    if economy_label == null:
        return
    var balance := float(data.get("balance", 0.0))
    var debt := float(data.get("debt", 0.0))
    economy_label.modulate = CORAL if balance < 0.0 else Color("9be8c1")
    var debt_suffix := "  •  долг %.0f ₽" % debt if debt > 0.0 else ""
    economy_label.text = "%.0f ₽   −%.1f/с%s" % [
        balance,
        float(data.get("living_cost_rate", 0.0)),
        debt_suffix
    ]

func _on_run_finished(result: Dictionary) -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    _current_result = result.duplicate(true)
    result_panel.visible = true
    AudioManager.play_ui(&"success", -6.0)
    result_label.text = "КОФЕ ВЫПИТ — ЗАБЕГ ЗАВЕРШЁН\n\n%s\n\nВремя                %s\nБаланс               %+.0f ₽\nДолг                  %.0f ₽\nЧеллендж-очки         %d\n\nПик пробуждения      %d%%\nГромких действий     %d\nУронено предметов    %d\nОтветов на созвоне   %d\nПропущено вопросов   %d\nРита проснулась      %s\n\nПлатежей получено    %d\nПлатежей пропущено   %d\nНайдено наличных     %.0f ₽\nЗаказов молока       %d\nКурьеров упущено     %d\nВера в THE ПЛАТЕЖ    %s" % [
        String(result["rank"]), RunStats.format_time(float(result["time"])),
        float(result.get("balance", 0.0)),
        float(result.get("debt", 0.0)),
        int(result.get("challenge_score", 0)),
        int(result["peak_wake"]),
        int(result["loud_actions"]),
        int(result["dropped_items"]),
        int(result["answered_calls"]),
        int(result["missed_calls"]),
        "ДА" if bool(result["rita_awake"]) else "НЕТ",
        int(result.get("payments_received", 0)),
        int(result.get("missed_payments", 0)),
        float(result.get("cash_found", 0.0)),
        int(result.get("milk_orders", 0)),
        int(result.get("missed_couriers", 0)),
        "НЕПОКОЛЕБИМА" if int(result.get("payment_altar_bows", 0)) > 0 else "НЕ ПРОВЕРЕНА"
    ]
    save_status_label.text = "ВВЕДИ ИМЯ И СОХРАНИ РЕЗУЛЬТАТ"
    player_name_edit.text = ""
    save_result_button.disabled = false
    _refresh_leaderboard()
    player_name_edit.call_deferred("grab_focus")

func _build_ui() -> void:
    var root := Control.new()
    root.name = "Interface"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var ui_theme := Theme.new()
    ui_theme.default_font = UI_FONT
    root.theme = ui_theme
    add_child(root)

    var top_bar := _glass_panel(root, Vector2(16, 14), Vector2(1248, 68), GLASS)
    var objective_chip := _glass_panel(top_bar, Vector2(10, 8), Vector2(500, 52), GLASS_STRONG)
    objective_label = _label(objective_chip, Vector2(14, 6), Vector2(472, 40), 16, CREAM)
    objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var coffee_chip := _glass_panel(top_bar, Vector2(520, 8), Vector2(390, 52), GLASS_STRONG)
    coffee_route_title = _label(coffee_chip, Vector2(10, 3), Vector2(370, 14), 10, MUTED)
    coffee_label = _label(coffee_chip, Vector2(10, 17), Vector2(258, 22), 12, GOLD)
    coffee_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    coffee_next_label = _label(coffee_chip, Vector2(270, 17), Vector2(110, 22), 10, MUTED)
    coffee_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    coffee_next_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    coffee_progress_bar = _status_bar(coffee_chip, Vector2(10, 43), Vector2(370, 4), GOLD)
    timer_label = _label(top_bar, Vector2(920, 21), Vector2(90, 26), 17, CREAM)
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    economy_label = _label(top_bar, Vector2(1015, 21), Vector2(215, 26), 15, Color("9be8c1"))
    economy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    alert_banner = _glass_panel(root, Vector2(16, 90), Vector2(1248, 34), Color(CORAL.r, CORAL.g, CORAL.b, 0.22))
    alert_banner.visible = false
    alert_label = _label(alert_banner, Vector2(16, 6), Vector2(1216, 22), 14, CREAM)
    alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    urgent_label = alert_label
    dev_label = _label(root, Vector2(16, 90), Vector2(1248, 220), 13, Color("9be8c1"))
    dev_label.visible = false

    bottom_bar = _glass_panel(root, Vector2(16, 652), Vector2(1248, 54), GLASS)
    wake_label = _label(bottom_bar, Vector2(12, 6), Vector2(210, 16), 12, CREAM)
    wake_bar = ProgressBar.new()
    wake_bar.position = Vector2(12, 24)
    wake_bar.size = Vector2(210, 8)
    wake_bar.min_value = 0.0
    wake_bar.max_value = 100.0
    wake_bar.show_percentage = false
    wake_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var wake_bg := StyleBoxFlat.new()
    wake_bg.bg_color = Color(1, 1, 1, 0.08)
    wake_bg.corner_radius_top_left = 4
    wake_bg.corner_radius_top_right = 4
    wake_bg.corner_radius_bottom_left = 4
    wake_bg.corner_radius_bottom_right = 4
    var wake_fill := StyleBoxFlat.new()
    wake_fill.bg_color = BLUE
    wake_fill.corner_radius_top_left = 4
    wake_fill.corner_radius_top_right = 4
    wake_fill.corner_radius_bottom_left = 4
    wake_fill.corner_radius_bottom_right = 4
    wake_bar.add_theme_stylebox_override("background", wake_bg)
    wake_bar.add_theme_stylebox_override("fill", wake_fill)
    bottom_bar.add_child(wake_bar)

    call_label = _label(bottom_bar, Vector2(250, 16), Vector2(180, 22), 14, MUTED)
    condition_label = _label(bottom_bar, Vector2(450, 16), Vector2(150, 22), 13, CREAM)
    stamina_bar = _status_bar(bottom_bar, Vector2(450, 36), Vector2(150, 6), Color("76b7d7"))
    intoxication_label = _label(bottom_bar, Vector2(620, 16), Vector2(170, 22), 13, CREAM)
    intoxication_bar = _status_bar(bottom_bar, Vector2(620, 36), Vector2(170, 6), Color("edbd68"))

    var prompt_chip := _glass_panel(bottom_bar, Vector2(820, 8), Vector2(418, 38), GLASS_STRONG)
    prompt_label = _label(prompt_chip, Vector2(12, 8), Vector2(394, 22), 15, CREAM)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    message_label = _label(root, Vector2(330, 120), Vector2(620, 42), 20, GOLD)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label = _label(root, Vector2(210, 598), Vector2(860, 44), 22, CREAM)
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    appliance_panel = _glass_panel(root, Vector2(430, 560), Vector2(420, 46), GLASS_STRONG)
    appliance_label = _label(appliance_panel, Vector2(12, 6), Vector2(396, 18), 13, CREAM)
    appliance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    appliance_bar = _status_bar(appliance_panel, Vector2(12, 28), Vector2(396, 8), BLUE)
    appliance_panel.visible = false

    contamination_panel = _glass_panel(root, Vector2(16, 118), Vector2(360, 48), GLASS_STRONG)
    contamination_label = _label(contamination_panel, Vector2(12, 5), Vector2(336, 20), 13, CREAM)
    contamination_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    contamination_bar = _status_bar(contamination_panel, Vector2(12, 29), Vector2(336, 9), CORAL)
    contamination_panel.visible = false

    task_panel = _glass_panel(root, Vector2(380, 500), Vector2(520, 96), GLASS_STRONG)
    task_label = _label(task_panel, Vector2(14, 6), Vector2(492, 20), 14, CREAM)
    task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    task_progress_bar = _status_bar(task_panel, Vector2(16, 28), Vector2(488, 8), BLUE)
    task_skill_track = ColorRect.new()
    task_skill_track.position = Vector2(16, 44)
    task_skill_track.size = Vector2(488, 14)
    task_skill_track.color = Color(1, 1, 1, 0.10)
    task_skill_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    task_panel.add_child(task_skill_track)
    task_green_zone = ColorRect.new()
    task_green_zone.position = Vector2(16, 44)
    task_green_zone.size = Vector2(96, 14)
    task_green_zone.color = Color("54d889")
    task_green_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    task_panel.add_child(task_green_zone)
    task_marker = ColorRect.new()
    task_marker.position = Vector2(16, 42)
    task_marker.size = Vector2(3, 18)
    task_marker.color = Color.WHITE
    task_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    task_panel.add_child(task_marker)
    task_hint = _label(task_panel, Vector2(14, 64), Vector2(492, 22), 11, MUTED)
    task_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    task_panel.visible = false

    var crosshair := _label(root, Vector2(623, 337), Vector2(34, 34), 20, Color(1, 1, 1, 0.42))
    crosshair.text = "+"
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    intro_panel = _panel(root, Vector2(365, 274), Vector2(550, 132), Color(0.035, 0.048, 0.06, 0.94))
    var title := _label(intro_panel, Vector2(20, 24), Vector2(510, 84), 34, GOLD)
    title.text = "ДЕНИС НАЛЕЙ КОФЕ."
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    apartment_map = APARTMENT_MAP_SCRIPT.new()
    apartment_map.name = "ApartmentMap"
    apartment_map.position = Vector2(230, 92)
    apartment_map.size = Vector2(820, 520)
    apartment_map.visible = false
    root.add_child(apartment_map)

    result_panel = _panel(root, Vector2(0, 0), Vector2(1280, 720), Color(0.025, 0.035, 0.045, 0.98))
    result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    result_panel.visible = false
    result_label = _label(result_panel, Vector2(55, 30), Vector2(535, 485), 16, CREAM)
    var board_card := _panel(result_panel, Vector2(625, 30), Vector2(600, 610), INK_SOFT)
    var board_title := _label(board_card, Vector2(25, 18), Vector2(550, 40), 27, GOLD)
    board_title.text = "ТАБЛИЦА ЛИДЕРОВ"
    board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_leaderboard_label = _label(board_card, Vector2(25, 72), Vector2(550, 500), 17, CREAM)
    save_status_label = _label(result_panel, Vector2(55, 525), Vector2(535, 26), 14, GOLD)
    player_name_edit = LineEdit.new()
    player_name_edit.position = Vector2(55, 557)
    player_name_edit.size = Vector2(250, 42)
    player_name_edit.placeholder_text = "Имя игрока"
    player_name_edit.max_length = 18
    player_name_edit.add_theme_font_size_override("font_size", 18)
    result_panel.add_child(player_name_edit)
    save_result_button = _button(result_panel, Vector2(317, 557), Vector2(273, 42), "СОХРАНИТЬ / ПЕРЕЗАПИСАТЬ")
    save_result_button.pressed.connect(_save_current_result)
    player_name_edit.text_submitted.connect(func(_text: String) -> void: _save_current_result())
    restart_button = _button(result_panel, Vector2(55, 622), Vector2(535, 46), "НОВЫЙ ЗАБЕГ  •  R")
    restart_button.pressed.connect(func() -> void: get_tree().reload_current_scene())

    leaderboard_overlay = _panel(root, Vector2(115, 55), Vector2(1050, 610), Color(0.025, 0.035, 0.045, 0.985))
    leaderboard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    var overlay_title := _label(leaderboard_overlay, Vector2(35, 24), Vector2(980, 45), 30, GOLD)
    overlay_title.text = "ТАБЛИЦА ЛИДЕРОВ"
    overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    leaderboard_overlay_label = _label(leaderboard_overlay, Vector2(110, 90), Vector2(830, 440), 20, CREAM)
    var overlay_hint := _label(leaderboard_overlay, Vector2(35, 552), Vector2(980, 30), 16, BLUE)
    overlay_hint.text = "L — закрыть таблицу"
    overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    leaderboard_overlay.visible = false

func _save_current_result() -> void:
    if _current_result.is_empty():
        save_status_label.text = "НЕТ ЗАВЕРШЁННОГО ЗАБЕГА"
        return
    var saved: Dictionary = RunStats.save_leaderboard_result(player_name_edit.text, _current_result)
    if not bool(saved.get("ok", false)):
        save_status_label.text = String(saved.get("error", "ОШИБКА СОХРАНЕНИЯ"))
        return
    player_name_edit.text = String((saved.get("entry", {}) as Dictionary).get("name", "ДЕНИС"))
    save_status_label.text = "РЕЗУЛЬТАТ СОХРАНЁН  •  МЕСТО №%d" % int(saved.get("place", 0))
    AudioManager.play_ui(&"success", -8.0)
    _refresh_leaderboard()

func _refresh_leaderboard() -> void:
    var text := _format_leaderboard(RunStats.load_leaderboard())
    if result_leaderboard_label != null:
        result_leaderboard_label.text = text
    if leaderboard_overlay_label != null:
        leaderboard_overlay_label.text = text

func _format_leaderboard(entries: Array) -> String:
    if entries.is_empty():
        return "ПОКА НЕТ РЕЗУЛЬТАТОВ\n\nВЫПЕЙ ПЕРВУЮ КРУЖКУ И ЗАДАЙ ТЕМП."
    var lines: PackedStringArray = [
        " №   ИМЯ                 ВРЕМЯ     БАЛАНС      ОЧКИ",
        "────────────────────────────────────────────────"
    ]
    var visible_count := mini(entries.size(), 10)
    for index in range(visible_count):
        var entry: Dictionary = entries[index]
        var name := String(entry.get("name", "ДЕНИС")).substr(0, 18).rpad(18)
        var balance := float(entry.get("balance", 0.0))
        var balance_text := "+%.0f ₽" % balance if balance >= 0.0 else "−%.0f ₽" % absf(balance)
        lines.append("%2d.  %s  %s    %10s   %6d" % [
            index + 1,
            name,
            RunStats.format_time(float(entry.get("time", 0.0))),
            balance_text,
            int(entry.get("score", 0))
        ])
    lines.append("\nСОРТИРОВКА: ВРЕМЯ → БАЛАНС → ОЧКИ")
    return "\n".join(lines)

func _hide_intro() -> void:
    if _intro_hidden:
        return
    _intro_hidden = true
    if _intro_tween != null:
        _intro_tween.kill()
    _intro_tween = create_tween()
    _intro_tween.tween_property(intro_panel, "modulate:a", 0.0, 0.35)
    _intro_tween.tween_callback(intro_panel.hide)

func _update_urgent_panel(call: Dictionary) -> void:
    var tasks: Array[String] = []
    var critical := false
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if RitaSleep.is_angry:
        critical = true
        if player != null and bool(player.get("is_hidden")):
            tasks.append("НЕ ВЫХОДИ ИЗ ГАРДЕРОБНОЙ — Рита успокаивается %d%%" % int(clampf(RitaSleep.calm_progress / RitaSleep.CALM_REQUIRED * 100.0, 0.0, 100.0)))
        else:
            tasks.append("БЕГИ В ГАРДЕРОБНУЮ И ПРЯЧЬСЯ")
    var delivery := MilkDelivery.get_state()
    if bool(delivery.get("at_door", false)):
        critical = true
        tasks.append("КУРЬЕР У ДВЕРИ %.0fс — забери молоко" % float(delivery.get("pickup_time_left", 0.0)))
    elif bool(delivery.get("on_the_way", false)):
        tasks.append("Курьер едет — ~%.0f сек" % float(delivery.get("eta", 0.0)))
    var coffee_delivery := CoffeeDelivery.get_state()
    if bool(coffee_delivery.get("at_door", false)):
        critical = true
        tasks.append("КУРЬЕР С КОФЕ У ДВЕРИ %.0fс" % float(coffee_delivery.get("pickup_time_left", 0.0)))
    elif bool(coffee_delivery.get("on_the_way", false)):
        tasks.append("Кофе едет — ~%.0f сек" % float(coffee_delivery.get("eta", 0.0)))
    if bool(call.get("question_active", false)):
        critical = true
        var seconds := float(call.get("answer_time_left", 0.0))
        if bool(call.get("paused_for_rita", false)):
            tasks.append("Созвон на паузе — сначала пережди ярость Риты")
        elif String(call.get("question_kind", "status")) == "payment":
            tasks.append("THE ПЛАТЁЖ %.0fс — бегом к ноутбуку" % seconds)
        else:
            tasks.append("Ответь на созвон %.0fс — бегом к ноутбуку" % seconds)
    var phone := get_tree().get_first_node_in_group("phone_locator") as Node3D
    if phone != null and bool(phone.get("active")):
        critical = true
        tasks.append("Заглуши телефон — %s" % _urgent_room_title(NoiseManager.room_for_position(phone.global_position)))
    if RitaDemands.has_active_demand():
        tasks.append("Рита: %s" % RitaDemands.get_objective())
    if QuestManager.spill_cleanup_required:
        critical = true
        tasks.append("ПОТОП • закрой кран • швабра в ванной")
    if QuestManager.has_bonus_objective(&"football"):
        tasks.append("Футбол: %s" % QuestManager.get_bonus_objective(&"football"))
    if player != null and player.has_method("get_condition_state"):
        var condition: Dictionary = player.call("get_condition_state")
        if float(condition.get("stamina", 100.0)) < 22.0:
            tasks.append("Денис выдохся — подгляди футбол и выпей пива")
    if tasks.is_empty():
        alert_banner.visible = false
        return
    alert_banner.visible = true
    alert_label.modulate = CORAL if critical else CREAM
    alert_label.text = "  •  ".join(PackedStringArray(tasks.slice(0, 2)))

func _urgent_room_title(room_id: StringName) -> String:
    match room_id:
        &"office": return "ГОСТИНАЯ / КАБИНЕТ"
        &"kitchen": return "КУХНЯ"
        &"corridor": return "КОРИДОР"
        &"bedroom": return "СПАЛЬНЯ РИТЫ"
        &"bathroom": return "ВАННАЯ"
        &"wardrobe": return "ГАРДЕРОБНАЯ"
    return "КВАРТИРА"

func _update_player_condition() -> void:
    if condition_label == null or stamina_bar == null or intoxication_bar == null:
        return
    var player := get_tree().get_first_node_in_group("player")
    if player == null or not player.has_method("get_condition_state"):
        return
    var state: Dictionary = player.call("get_condition_state")
    var stamina := float(state.get("stamina", 100.0))
    var intoxication := float(state.get("intoxication", 0.0))
    var movement_inverted := bool(state.get("movement_inverted", false))
    var mouse_inverted := bool(state.get("mouse_inverted", false))
    stamina_bar.value = stamina
    intoxication_bar.value = intoxication
    condition_label.text = "СИЛЫ %d%%" % int(stamina)
    if intoxication < 18.0:
        intoxication_label.text = "РУКИ точные"
    elif movement_inverted and mouse_inverted:
        intoxication_label.text = "ПЬЯН %d%% • ИНВЕРСИЯ" % int(intoxication)
    elif movement_inverted:
        intoxication_label.text = "ПЬЯН %d%% • WASD↕" % int(intoxication)
    elif mouse_inverted:
        intoxication_label.text = "ПЬЯН %d%% • МЫШЬ↔" % int(intoxication)
    elif intoxication < 48.0:
        intoxication_label.text = "КАЧАЕТ %d%%" % int(intoxication)
    else:
        intoxication_label.text = "ПЬЯН %d%%" % int(intoxication)
    var intox_fill := intoxication_bar.get_theme_stylebox("fill") as StyleBoxFlat
    if intox_fill != null:
        intox_fill.bg_color = CORAL if intoxication >= 48.0 else GOLD

func _update_appliance_progress() -> void:
    if appliance_panel == null:
        return
    var state: Dictionary = {"active": false}
    var water_station := get_tree().get_first_node_in_group("water_station")
    if water_station != null and water_station.has_method("get_appliance_state"):
        state = water_station.call("get_appliance_state")
    if not bool(state.get("active", false)):
        var kettle_station := get_tree().get_first_node_in_group("kettle_station")
        if kettle_station != null and kettle_station.has_method("get_appliance_state"):
            state = kettle_station.call("get_appliance_state")
    appliance_panel.visible = bool(state.get("active", false))
    if not appliance_panel.visible:
        return
    appliance_label.text = String(state.get("label", "ПРОЦЕСС"))
    appliance_bar.value = float(state.get("value", 0.0))
    var fill := appliance_bar.get_theme_stylebox("fill") as StyleBoxFlat
    if fill != null:
        fill.bg_color = CORAL if bool(state.get("danger", false)) else BLUE

func _update_kitchen_contamination() -> void:
    if contamination_panel == null:
        return
    var manager := get_tree().get_first_node_in_group("spill_manager") as SpillManager
    if manager == null:
        contamination_panel.visible = false
        return
    var state := manager.get_required_cleanup_state()
    var total_ml := float(state.get("total_ml", 0.0))
    var percent := float(state.get("contamination_percent", 0.0))
    var cleanliness := float(state.get("cleanliness_percent", 100.0))
    contamination_panel.visible = total_ml > 0.5
    if not contamination_panel.visible:
        return
    contamination_bar.value = percent
    contamination_label.text = "ЧИСТОТА КВАРТИРЫ • %d%% • ОСТАЛОСЬ %d МЛ • НУЖНА ШВАБРА" % [roundi(cleanliness), roundi(total_ml)]
    var fill := contamination_bar.get_theme_stylebox("fill") as StyleBoxFlat
    if fill != null:
        fill.bg_color = Color("72d49b") if cleanliness >= 75.0 else (GOLD if cleanliness >= 45.0 else CORAL)

func _update_task_progress() -> void:
    if task_panel == null:
        return
    var state: Dictionary = {"active": false}
    if RitaDemands.is_festival_movie_watching():
        state = {
            "active": true,
            "label": "РИТА СМОТРИТ ЯПОНСКОЕ КИНО",
            "progress": RitaDemands.get_festival_progress(),
            "skill": false,
            "hint": "СТОЙ РЯДОМ  •  РИТА ПОСТЕПЕННО ЗАСЫПАЕТ"
        }
    else:
        for station in get_tree().get_nodes_in_group("timed_task_station"):
            if station.has_method("get_task_state"):
                var candidate: Dictionary = station.call("get_task_state")
                if bool(candidate.get("active", false)):
                    state = candidate
                    break
    if not bool(state.get("active", false)):
        for television in get_tree().get_nodes_in_group("festival_tv_task"):
            if television.has_method("get_task_state"):
                var movie_state: Dictionary = television.call("get_task_state")
                if bool(movie_state.get("active", false)):
                    state = movie_state
                    break
    task_panel.visible = bool(state.get("active", false))
    if not task_panel.visible:
        return
    if appliance_panel != null:
        appliance_panel.visible = false
    var progress := float(state.get("progress", 0.0))
    task_label.text = "%s  •  %d%%" % [String(state.get("label", "ЗАДАНИЕ")), int(progress)]
    task_progress_bar.value = progress
    var has_skill := bool(state.get("skill", false))
    task_panel.position = Vector2(380, 500) if has_skill else Vector2(380, 520)
    task_panel.size = Vector2(520, 96) if has_skill else Vector2(520, 52)
    task_skill_track.visible = has_skill
    task_green_zone.visible = has_skill
    task_marker.visible = has_skill
    task_hint.visible = has_skill
    if has_skill:
        var track_width := 488.0
        var zone_start := clampf(float(state.get("zone_start", 35.0)), 0.0, 100.0)
        var zone_end := clampf(float(state.get("zone_end", 60.0)), zone_start, 100.0)
        task_green_zone.position.x = 16.0 + track_width * zone_start / 100.0
        task_green_zone.size.x = maxf(3.0, track_width * (zone_end - zone_start) / 100.0)
        task_marker.position.x = 16.0 + track_width * clampf(float(state.get("marker", 0.0)), 0.0, 100.0) / 100.0
    task_hint.text = String(state.get("hint", "НЕ ОТХОДИ, ПОКА ЗАДАНИЕ НЕ ЗАВЕРШЕНО"))

func _update_dev_overlay(call: Dictionary) -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    var room := NoiseManager.room_for_position(player.global_position) if player != null else &"—"
    var noise := NoiseManager.last_noise
    dev_label.text = "F3  •  ДИАГНОСТИКА\n\nКОМНАТА: %s\nШУМ: %s  %.1f → %.1f\nИСТОЧНИК: %s\nДВЕРЬ КУХНИ: %s\nРИТА: %.1f  (%s)\nКВЕСТ: %s\nПОДОЗРЕНИЕ WONE IT: %d" % [
        String(room), String(noise["category"]), float(noise["raw_strength"]), float(noise["heard_strength"]),
        String(noise["source_id"]), "ОТКРЫТА" if NoiseManager.is_door_open(&"kitchen_door") else "ЗАКРЫТА",
        RitaSleep.wake_level, RitaSleep.get_state_text(), QuestManager.get_objective(), int(call["suspicion"])
    ]

func _glass_panel(parent: Node, pos: Vector2, size_value: Vector2, color: Color) -> Panel:
    var panel := Panel.new()
    panel.position = pos
    panel.size = size_value
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(1, 1, 1, 0.14)
    style.shadow_color = Color(0, 0, 0, 0.28)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0, 2)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel

func _panel(parent: Node, pos: Vector2, size_value: Vector2, color: Color) -> Panel:
    var panel := Panel.new()
    panel.position = pos
    panel.size = size_value
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(1, 1, 1, 0.10)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel

func _label(parent: Node, pos: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _button(parent: Node, pos: Vector2, size_value: Vector2, text_value: String) -> Button:
    var button := Button.new()
    button.position = pos
    button.size = size_value
    button.text = text_value
    button.add_theme_font_size_override("font_size", 16)
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    parent.add_child(button)
    return button

func _status_bar(parent: Node, pos: Vector2, size_value: Vector2, fill_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = pos
    bar.size = size_value
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var background := StyleBoxFlat.new()
    background.bg_color = Color(1, 1, 1, 0.10)
    background.corner_radius_top_left = 4
    background.corner_radius_top_right = 4
    background.corner_radius_bottom_left = 4
    background.corner_radius_bottom_right = 4
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.corner_radius_top_left = 4
    fill.corner_radius_top_right = 4
    fill.corner_radius_bottom_left = 4
    fill.corner_radius_bottom_right = 4
    bar.add_theme_stylebox_override("background", background)
    bar.add_theme_stylebox_override("fill", fill)
    parent.add_child(bar)
    return bar

func _check(value: bool) -> String:
    return "●" if value else "○"
