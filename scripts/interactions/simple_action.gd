extends "res://scripts/interactions/interactable.gd"

@export_enum("slippers", "felt_pads", "hinge_oil", "water", "kettle_base", "brew", "laptop", "milk_delivery", "coffee_delivery", "rita_bathroom_clean", "rita_kitchen_dishes", "towel", "coffee_pickup", "light_switch", "window", "inspect", "coffee_powder_pour", "water_pour", "milk_pour") var action_type := "slippers"

var _kettle_timer: Timer
var _kettle_ref: Node3D
var _kettle_tick = 0
var _kettle_elapsed := 0.0
var _kettle_powered := false
var _overboil_elapsed := 0.0
var _overboil_noise_tick := 0.0
var _cooling_elapsed := 0.0
var _overboil_warning_stage := 0
const KETTLE_HEAT_SECONDS := 8.0
const KETTLE_COOL_SECONDS := 28.0
const KETTLE_ROUTE_FILL_ML := 300.0
const BOIL_AWAY_DELAY_SECONDS := 7.0
const BOIL_AWAY_ML_PER_SECOND := 1.7
const FAUCET_FLOW_ML_S := 50.0
var water_on := false
var water_fill_progress := 0.0
var overflow_progress := 0.0
var kitchen_flooded := false
var _water_ref: Node3D
var _water_stream: Node3D
var _water_catch_area: Area3D
var _flood_visual: Node3D
var _apartment_flood_visual: ApartmentFloodVisual
var _water_audio_tick := 0.0
var _flood_elapsed := 0.0
var _flood_spawn_tick := 0.0
var _flood_damage_stage := 0
var _flood_path_cursor := 0
const FLOOD_PATH: Array[Vector3] = [
    Vector3(7.18, 0.02, -3.62),
    Vector3(6.15, 0.02, -2.55),
    Vector3(4.35, 0.02, -1.35),
    Vector3(2.20, 0.02, -1.68),
    Vector3(0.25, 0.02, -1.68),
    Vector3(-2.15, 0.02, -1.30),
    Vector3(-4.55, 0.02, -1.05),
    Vector3(0.10, 0.02, 1.15),
    Vector3(0.10, 0.02, 3.55),
    Vector3(2.35, 0.02, 3.92),
    Vector3(-2.35, 0.02, 3.92),
]
var _steam_nodes: Array[Node3D] = []
var _task_active := false
var _task_progress := 0.0
var _task_marker := 0.0
var _task_marker_direction := 1.0
var _task_green_center := 52.0
var _task_green_width := 22.0
var _task_skill_hits := 0
var _brew_active := false
var _brew_progress := 0.0
var _pour_stream: Node3D

func _ready() -> void:
    set_process(action_type in ["water", "kettle_base"])
    if action_type == "water":
        add_to_group("water_station")
        _water_stream = get_node_or_null("WaterStream") as Node3D
        _water_catch_area = get_node_or_null("WaterCatchArea") as Area3D
        _flood_visual = get_node_or_null("KitchenFlood") as Node3D
        _set_water_visual(false)
    if action_type == "kettle_base":
        add_to_group("kettle_station")
        _kettle_timer = Timer.new()
        _kettle_timer.wait_time = 1.0
        _kettle_timer.one_shot = false
        _kettle_timer.timeout.connect(_on_kettle_tick)
        add_child(_kettle_timer)
        for node_name in ["SteamA", "SteamB", "SteamC"]:
            var steam := get_node_or_null(node_name) as Node3D
            if steam != null:
                steam.visible = false
                _steam_nodes.append(steam)
    if action_type == "brew":
        add_to_group("timed_task_station")
        _pour_stream = get_node_or_null("PourStream") as Node3D
        if _pour_stream != null:
            _pour_stream.visible = false
    if action_type == "coffee_powder_pour":
        add_to_group("coffee_powder_station")
        _pour_stream = get_node_or_null("PourStream") as Node3D
        if _pour_stream != null:
            _pour_stream.visible = false
    if action_type == "water_pour":
        add_to_group("water_pour_station")
        _pour_stream = get_node_or_null("PourStream") as Node3D
        if _pour_stream != null:
            _pour_stream.visible = false
    if action_type == "milk_pour":
        add_to_group("milk_pour_station")
        _pour_stream = get_node_or_null("PourStream") as Node3D
        if _pour_stream != null:
            _pour_stream.visible = false
    if action_type in ["rita_bathroom_clean", "rita_kitchen_dishes"]:
        add_to_group("timed_task_station")
    if action_type == "milk_delivery":
        add_to_group("milk_delivery_pickup")
        call_deferred("set_delivery_available", bool(MilkDelivery.get_state().get("at_door", false)))
    if action_type == "coffee_delivery":
        add_to_group("coffee_delivery_pickup")
        call_deferred("set_delivery_available", bool(CoffeeDelivery.get_state().get("at_door", false)))

func _process(delta: float) -> void:
    if action_type == "water":
        _process_water(delta)
    elif action_type == "kettle_base":
        _process_kettle(delta)

func interact(actor, mode: int) -> String:
    var closing_running_water := action_type == "water" and water_on
    if RitaDemands.has_active_demand() and action_type in ["water", "kettle_base", "brew", "coffee_pickup", "coffee_powder_pour", "water_pour", "milk_pour"] and not closing_running_water:
        return "СНАЧАЛА ПОРУЧЕНИЕ РИТЫ: %s" % RitaDemands.get_objective()
    if action_type == "water":
        return _toggle_water()
    # §2 миссии: старые автоматические зоны ОТКЛЮЧЕНЫ — жидкость начисляется
    # только через физический PourController (никакого двойного учёта).
    if action_type == "brew":
        return "ВАРКА ОТКЛЮЧЕНА  •  НАЛИВАЙ ФИЗИЧЕСКИ: ВОЗЬМИ ЧАЙНИК И НАЖМИ ЛКМ НАД КРУЖКОЙ"
    if action_type == "coffee_powder_pour":
        # Физическое насыпание не входит в этот срез: сохраняем старую
        # компактную зону только для порошка.
        return await _coffee_powder_pour_interaction()
    if action_type == "water_pour":
        return "НАЛИВ ЧЕРЕЗ ЗОНУ ОТКЛЮЧЁН  •  ВОЗЬМИ ЧАЙНИК И НАЖМИ ЛКМ НАД КРУЖКОЙ"
    if action_type == "milk_pour":
        return "НАЛИВ ЧЕРЕЗ ЗОНУ ОТКЛЮЧЁН  •  ОТКРОЙ ПАКЕТ И НАЛЕЙ НАД КРУЖКОЙ (ЛКМ)"
    var demand_location := _demand_location()
    if demand_location == &"":
        return await super.interact(actor, mode)
    if busy:
        return "ПОДОЖДИ"
    if not RitaDemands.can_complete_at(demand_location):
        return RitaDemands.try_complete_at(demand_location)
    busy = true
    var duration := _duration_for(mode)
    var time_left := duration
    var noise_tick := 1.25
    var pulse_count := maxi(1, int(ceil(duration / 1.25)))
    var pulse_noise := _noise_for(mode) / float(pulse_count)
    _begin_task_minigame()
    QuestManager.notification_requested.emit("РАБОТА НАЧАТА  •  SPACE В ЗЕЛЁНОЙ ЗОНЕ УСКОРЯЕТ%s" % ("  •  ДЕРЖИ E" if mode == InteractionMode.QUIET else ""))
    while time_left > 0.0:
        await get_tree().process_frame
        if not RunStats.run_active:
            busy = false
            _end_task_minigame()
            return "ЗАБЕГ ЗАВЕРШЁН"
        var delta := get_process_delta_time()
        time_left -= delta
        _update_task_minigame(delta)
        if Input.is_action_just_pressed("ui_accept"):
            time_left = _apply_task_skill_input(duration, time_left)
        noise_tick -= delta
        _task_progress = clampf((1.0 - time_left / duration) * 100.0, 0.0, 100.0)
        if actor == null or not is_instance_valid(actor) or global_position.distance_to(actor.global_position) > 2.25:
            busy = false
            _end_task_minigame()
            return "РАБОТА СОРВАНА  •  ТЫ ОТОШЁЛ"
        if RitaSleep.is_angry:
            busy = false
            _end_task_minigame()
            return "РАБОТА СОРВАНА  •  РИТА СНОВА В ЯРОСТИ"
        if mode == InteractionMode.QUIET and not Input.is_action_pressed("interact"):
            busy = false
            _end_task_minigame()
            return "ТИХАЯ РАБОТА СОРВАНА  •  НУЖНО ДЕРЖАТЬ E"
        if noise_tick <= 0.0:
            noise_tick += 1.25
            NoiseManager.emit_noise(global_position, pulse_noise, noise_category, source_id)
            AudioManager.play_3d(&"clink", global_position, -15.0 if mode == InteractionMode.QUIET else -9.0, 0.78)
    busy = false
    _task_progress = 100.0
    _end_task_minigame()
    return perform_interaction(actor, mode)

func _begin_task_minigame() -> void:
    _task_active = true
    _task_progress = 0.0
    _task_marker = randf_range(8.0, 38.0)
    _task_marker_direction = 1.0
    _task_green_center = randf_range(30.0, 70.0)
    _task_green_width = 22.0
    _task_skill_hits = 0

func _update_task_minigame(delta: float) -> void:
    _task_marker += _task_marker_direction * delta * (88.0 + float(_task_skill_hits) * 8.0)
    if _task_marker >= 100.0:
        _task_marker = 100.0
        _task_marker_direction = -1.0
    elif _task_marker <= 0.0:
        _task_marker = 0.0
        _task_marker_direction = 1.0

func _apply_task_skill_input(duration: float, time_left: float) -> float:
    if _task_marker >= _task_green_center - _task_green_width * 0.5 and _task_marker <= _task_green_center + _task_green_width * 0.5:
        _task_skill_hits += 1
        _task_green_center = randf_range(24.0, 76.0)
        _task_green_width = maxf(13.0, 22.0 - float(_task_skill_hits) * 1.8)
        AudioManager.play_ui(&"success", -12.0)
        QuestManager.notification_requested.emit("ТОЧНО В ЗОНУ  •  РАБОТА УСКОРЕНА")
        return maxf(0.0, time_left - duration * 0.18)
    AudioManager.play_ui(&"ui", -18.0)
    return time_left

func _end_task_minigame() -> void:
    _task_active = false

func get_task_state() -> Dictionary:
    if _brew_active:
        return {
            "active": true,
            "label": "НАЛИВАЕМ КИПЯТОК В КРУЖКУ",
            "progress": _brew_progress,
            "skill": false,
            "hint": "ЧАЙНИК НАКЛОНЁН  •  НЕ ОТХОДИ"
        }
    if not _task_active:
        return {"active": false}
    return {
        "active": true,
        "label": "УБОРКА ВАННОЙ" if action_type == "rita_bathroom_clean" else "МОЙКА ПОСУДЫ",
        "progress": _task_progress,
        "skill": true,
        "marker": _task_marker,
        "zone_start": _task_green_center - _task_green_width * 0.5,
        "zone_end": _task_green_center + _task_green_width * 0.5,
        "hits": _task_skill_hits,
        "hint": "SPACE — ПОПАДИ В ЗЕЛЁНУЮ ЗОНУ, ЧТОБЫ УСКОРИТЬСЯ"
    }

func _brew_interaction(actor: Node, mode: int) -> String:
    if busy or _brew_active:
        return "КИПЯТОК УЖЕ НАЛИВАЕТСЯ"
    if QuestManager.coffee_made:
        return "КОФЕ УЖЕ ГОТОВ  •  ВОЗЬМИ КРУЖКУ И НАЖМИ E"
    var mug := _nearest_item(&"mug", 1.15)
    if mug == null or bool(mug.get("held")):
        return "ПОСТАВЬ КРУЖКУ НА ЖЁЛТУЮ ПОДСТАВКУ"
    var kettle := _nearest_item(&"kettle", 1.55)
    if kettle == null:
        return "ПРИНЕСИ ГОРЯЧИЙ ЧАЙНИК К КРУЖКЕ"
    if bool(kettle.get("held")):
        return "ПОСТАВЬ ГОРЯЧИЙ ЧАЙНИК РЯДОМ С КРУЖКОЙ"
    if not QuestManager.has_coffee:
        return "СНАЧАЛА НАЙДИ РАСТВОРИМЫЙ КОФЕ"
    if not QuestManager.water_boiled or float(kettle.get_meta("heat", 0.0)) < 0.30:
        return "ВОДА В ЧАЙНИКЕ НЕ ГОРЯЧАЯ  •  ВСКИПЯТИ ЕЁ"
    busy = true
    _brew_active = true
    _brew_progress = 0.0
    var original_transform := kettle.global_transform
    var original_freeze := bool(kettle.get("freeze"))
    kettle.freeze = true
    kettle.linear_velocity = Vector3.ZERO
    kettle.angular_velocity = Vector3.ZERO
    var start_position := kettle.global_position
    var start_rotation := kettle.global_rotation
    var pour_position: Vector3 = mug.global_position + Vector3(-0.55, 0.64, 0.0)
    var duration := 2.5 if mode == InteractionMode.QUIET else (1.15 if mode == InteractionMode.FAST else 1.8)
    var elapsed := 0.0
    var pour_audio_tick := 0.0
    var cancelled := false
    while elapsed < duration:
        await get_tree().process_frame
        if not RunStats.run_active or actor == null or not is_instance_valid(actor):
            cancelled = true
            break
        if global_position.distance_to(actor.global_position) > 2.45 or RitaSleep.is_angry:
            cancelled = true
            break
        elapsed += get_process_delta_time()
        var progress := clampf(elapsed / duration, 0.0, 1.0)
        _brew_progress = progress * 100.0
        var lift := sin(progress * PI)
        kettle.global_position = start_position.lerp(pour_position, lift)
        kettle.global_rotation = Vector3(
            lerp_angle(start_rotation.x, start_rotation.x, lift),
            lerp_angle(start_rotation.y, start_rotation.y, lift),
            lerp_angle(start_rotation.z, start_rotation.z + deg_to_rad(-68.0), lift)
        )
        var pouring := progress >= 0.24 and progress <= 0.78
        if _pour_stream != null:
            _pour_stream.visible = pouring
            if pouring:
                _place_pour_stream(kettle, mug)
        pour_audio_tick -= get_process_delta_time()
        if pouring and pour_audio_tick <= 0.0:
            pour_audio_tick = 0.42
            AudioManager.play_3d(&"kettle", mug.global_position, -22.0 if mode == InteractionMode.QUIET else -17.0, 1.45)
    if _pour_stream != null:
        _pour_stream.visible = false
    kettle.global_transform = original_transform
    kettle.freeze = original_freeze
    kettle.linear_velocity = Vector3.ZERO
    kettle.angular_velocity = Vector3.ZERO
    _brew_active = false
    _brew_progress = 0.0
    busy = false
    if cancelled:
        return "НАЛИВАНИЕ ПРЕРВАНО  •  ПОДОЙДИ БЛИЖЕ"
    var result := QuestManager.brew_coffee()
    if not QuestManager.coffee_made:
        return result
    QuestManager.consume_kettle_water()
    kettle.set_meta("filled", false)
    kettle.set_meta("fill_progress", 0.0)
    kettle.set_meta("heat", 0.0)
    mug.set_meta("coffee_ready", true)
    _tint_mug(mug)
    var noise := _noise_for(mode)
    NoiseManager.emit_noise(mug.global_position, noise, &"DISHES", &"coffee_pour")
    AudioManager.play_ui(&"success", -8.0)
    return "КОФЕ ЗАВАРЕН  •  ВОЗЬМИ КРУЖКУ И НАЖМИ E, ЧТОБЫ ВЫПИТЬ"

func _coffee_powder_pour_interaction() -> String:
    if busy or QuestManager.coffee_made or QuestManager.coffee_powder_poured:
        return "КОФЕ УЖЕ НАСЫПАН"
    var mug := _nearest_item(&"mug", 1.25)
    if mug == null or bool(mug.get("held")):
        return "ПОСТАВЬ КРУЖКУ НА ПЛОЩАДКУ"
    if not QuestManager.has_coffee:
        return "СНАЧАЛА НАЙДИ РАСТВОРИМЫЙ КОФЕ"
    busy = true
    _set_pour_stream_visible(true)
    if _pour_stream != null:
        _place_pour_stream_simple(mug, Vector3(0.0, 0.35, 0.0))
    AudioManager.play_3d(&"clink", global_position, -12.0, 1.0)
    NoiseManager.emit_noise(global_position, 2.0, &"DISHES", &"coffee_powder_pour")
    await get_tree().create_timer(0.6).timeout
    _set_pour_stream_visible(false)
    busy = false
    return QuestManager.pour_coffee_powder()

func _water_pour_interaction(mode: int) -> String:
    if busy or _brew_active:
        return "НАЛИВАНИЕ УЖЕ ИДЁТ"
    if QuestManager.coffee_made or QuestManager.water_poured:
        return "КИПЯТОК УЖЕ НАЛИТ"
    var mug := _nearest_item(&"mug", 1.25)
    if mug == null or bool(mug.get("held")):
        return "ПОСТАВЬ КРУЖКУ НА ПЛОЩАДКУ"
    var kettle := _nearest_item(&"kettle", 1.55)
    if kettle == null or bool(kettle.get("held")):
        return "ПРИНЕСИ ГОРЯЧИЙ ЧАЙНИК К КРУЖКЕ"
    if not QuestManager.coffee_powder_poured:
        return "СНАЧАЛА НАСЫПЬ КОФЕ В КРУЖКУ"
    if not QuestManager.water_boiled or float(kettle.get_meta("heat", 0.0)) < 0.30:
        return "ВОДА В ЧАЙНИКЕ НЕ ГОРЯЧАЯ  •  ВСКИПЯТИ ЕЁ"
    busy = true
    _brew_active = true
    _brew_progress = 0.0
    var original_transform := kettle.global_transform
    var original_freeze := bool(kettle.get("freeze"))
    kettle.freeze = true
    kettle.linear_velocity = Vector3.ZERO
    kettle.angular_velocity = Vector3.ZERO
    var start_position := kettle.global_position
    var start_rotation := kettle.global_rotation
    var pour_position: Vector3 = mug.global_position + Vector3(-0.55, 0.64, 0.0)
    var duration := 2.0 if mode == InteractionMode.QUIET else (0.9 if mode == InteractionMode.FAST else 1.4)
    var elapsed := 0.0
    var pour_audio_tick := 0.0
    var cancelled := false
    while elapsed < duration:
        await get_tree().process_frame
        if not RunStats.run_active or global_position.distance_to(mug.global_position) > 2.45 or RitaSleep.is_angry:
            cancelled = true
            break
        elapsed += get_process_delta_time()
        var progress := clampf(elapsed / duration, 0.0, 1.0)
        _brew_progress = progress * 100.0
        var lift := sin(progress * PI)
        kettle.global_position = start_position.lerp(pour_position, lift)
        kettle.global_rotation = Vector3(
            lerp_angle(start_rotation.x, start_rotation.x, lift),
            lerp_angle(start_rotation.y, start_rotation.y, lift),
            lerp_angle(start_rotation.z, start_rotation.z + deg_to_rad(-68.0), lift)
        )
        var pouring := progress >= 0.24 and progress <= 0.78
        if _pour_stream != null:
            _pour_stream.visible = pouring
            if pouring:
                _place_pour_stream_simple(mug, Vector3(0.0, 0.18, 0.0))
        pour_audio_tick -= get_process_delta_time()
        if pouring and pour_audio_tick <= 0.0:
            pour_audio_tick = 0.42
            AudioManager.play_3d(&"kettle", mug.global_position, -22.0 if mode == InteractionMode.QUIET else -17.0, 1.45)
    if _pour_stream != null:
        _pour_stream.visible = false
    kettle.global_transform = original_transform
    kettle.freeze = original_freeze
    kettle.linear_velocity = Vector3.ZERO
    kettle.angular_velocity = Vector3.ZERO
    _brew_active = false
    _brew_progress = 0.0
    busy = false
    if cancelled:
        return "НАЛИВАНИЕ ПРЕРВАНО  •  ПОДОЙДИ БЛИЖЕ"
    return QuestManager.pour_water_into_mug()

func _milk_pour_interaction(mode: int) -> String:
    if busy:
        return "НАЛИВАНИЕ УЖЕ ИДЁТ"
    if QuestManager.coffee_made or QuestManager.milk_poured:
        return "МОЛОКО УЖЕ НАЛИТО"
    var mug := _nearest_item(&"mug", 1.25)
    if mug == null or bool(mug.get("held")):
        return "ПОСТАВЬ КРУЖКУ НА ПЛОЩАДКУ"
    if not QuestManager.water_poured:
        return "СНАЧАЛА НАЛЕЙ КИПЯТОК В КРУЖКУ"
    if not QuestManager.has_milk:
        return "СНАЧАЛА ЗАБЕРИ МОЛОКО У КУРЬЕРА"
    busy = true
    _set_pour_stream_visible(true)
    if _pour_stream != null:
        _place_pour_stream_simple(mug, Vector3(0.0, 0.20, 0.0))
    AudioManager.play_3d(&"kettle", global_position, -18.0, 1.2)
    NoiseManager.emit_noise(global_position, 3.0, &"DISHES", &"milk_pour")
    await get_tree().create_timer(0.8).timeout
    _set_pour_stream_visible(false)
    _tint_mug(mug)
    mug.set_meta("coffee_ready", true)
    var noise := _noise_for(mode)
    NoiseManager.emit_noise(mug.global_position, noise, &"DISHES", &"milk_pour")
    AudioManager.play_ui(&"success", -8.0)
    busy = false
    return QuestManager.pour_milk_into_mug()

func _set_pour_stream_visible(value: bool) -> void:
    if _pour_stream == null:
        _pour_stream = get_node_or_null("PourStream") as Node3D
    if _pour_stream != null:
        _pour_stream.visible = value

func _place_pour_stream_simple(target: Node3D, offset: Vector3) -> void:
    if _pour_stream == null:
        return
    var stream_start := global_position + Vector3(0.0, 0.55, 0.0)
    var stream_finish := target.global_position + offset
    var direction := stream_finish - stream_start
    if direction.length() < 0.05:
        return
    _pour_stream.global_position = (stream_start + stream_finish) * 0.5
    _pour_stream.quaternion = Quaternion(Vector3.UP, direction.normalized())
    _pour_stream.scale = Vector3(1.0, direction.length() / 0.48, 1.0)

func _place_pour_stream(kettle: Node3D, mug: Node3D) -> void:
    if _pour_stream == null:
        return
    var stream_start := kettle.to_global(Vector3(0.43, 0.08, 0.0))
    var stream_finish := mug.global_position + Vector3(0.0, 0.18, 0.0)
    var direction := stream_finish - stream_start
    if direction.length() < 0.05:
        return
    _pour_stream.global_position = (stream_start + stream_finish) * 0.5
    _pour_stream.quaternion = Quaternion(Vector3.UP, direction.normalized())
    _pour_stream.scale = Vector3(1.0, direction.length() / 0.48, 1.0)

func perform_interaction(actor, _mode: int) -> String:
    if action_type == "laptop" and bool(get_meta("cat_blocked", false)):
        return "БАТОН ЛЁГ НА КЛАВИАТУРУ — СНАЧАЛА ТИХО ОТВЛЕКИ КОТА"
    match action_type:
        "coffee_powder_pour", "water_pour", "milk_pour":
            # §2 миссии: начисление жидкости через зоны запрещено
            return "АВТОНАЛИВ ОТКЛЮЧЁН  •  ИСПОЛЬЗУЙ ФИЗИЧЕСКИЙ РОЗЛИВ (ЛКМ)"
        "slippers":
            if actor.has_method("equip_slippers"):
                actor.equip_slippers()
            visible = false
            call_deferred("queue_free")
            AudioManager.play_3d(&"cloth_step", global_position, -8.0, 1.1)
            return "ТАПОЧКИ НАДЕТЫ"
        "felt_pads":
            if actor.has_method("equip_furniture_pads"):
                actor.call("equip_furniture_pads")
            visible = false
            call_deferred("queue_free")
            return "ВОЙЛОЧНЫЕ НАКЛАДКИ ВЗЯТЫ  •  ПЕРЕДВИГАЕМАЯ МЕБЕЛЬ СТАНЕТ ТИШЕ"
        "hinge_oil":
            if actor.has_method("equip_hinge_oil"):
                actor.call("equip_hinge_oil")
            visible = false
            call_deferred("queue_free")
            return "СМАЗКА ВЗЯТА  •  СЛЕДУЮЩЕЕ ОТКРЫТИЕ КАЖДОЙ ДВЕРИ СМАЖЕТ ПЕТЛИ"
        "water":
            return _toggle_water()
        "kettle_base":
            var kettle: Node3D = _nearest_item(&"kettle", 1.1)
            if kettle == null or bool(kettle.get("held")):
                return "ПОСТАВЬ ЧАЙНИК НА ПОДСТАВКУ"
            if not bool(kettle.get_meta("filled", false)):
                return "ЧАЙНИК ПУСТ"
            var result: String = QuestManager.start_kettle()
            if QuestManager.kettle_boiling and not bool(kettle.get_meta("boiling", false)):
                _start_kettle_cycle(kettle)
                AudioManager.play_3d(&"switch", global_position, -7.0, 0.85)
            return result
        "brew":
            var mug: Node3D = _nearest_item(&"mug", 1.25)
            if mug == null or bool(mug.get("held")):
                return "ПОСТАВЬ КРУЖКУ НА СТОЛЕШНИЦУ"
            var result: String = QuestManager.brew_coffee()
            if QuestManager.coffee_made:
                _tint_mug(mug)
                AudioManager.play_ui(&"success", -9.0)
            return result
        "laptop":
            if CallManager.question_active:
                return CallManager.answer_question()
            if RitaDemands.has_active_demand():
                return RitaDemands.try_complete_at(&"laptop")
            if CoffeeDelivery.needs_coffee():
                return CoffeeDelivery.order_coffee()
            if not QuestManager.has_milk:
                if not QuestManager.water_poured:
                    return "СНАЧАЛА ПРИГОТОВЬ КРУЖКУ И НАЛЕЙ КИПЯТОК"
                return MilkDelivery.order_milk()
            if QuestManager.coffee_made:
                return QuestManager.return_to_desk()
            return "СОЗВОН ИДЁТ. КАМЕРА ВЫКЛЮЧЕНА"
        "milk_delivery":
            return MilkDelivery.collect_milk()
        "coffee_delivery":
            return CoffeeDelivery.collect_coffee()
        "rita_bathroom_clean":
            return RitaDemands.try_complete_at(&"bathroom_clean")
        "rita_kitchen_dishes":
            return RitaDemands.try_complete_at(&"kitchen_dishes")
        "towel":
            return "ПОЛОТЕНЦЕ СМЯГЧАЕТ УДАРЫ"
        "coffee_pickup":
            QuestManager.register_coffee()
            return "РАСТВОРИМЫЙ КОФЕ НАЙДЕН"
        "light_switch":
            var target_group := String(get_meta("target_group", "kitchen_lights"))
            var lights := get_tree().get_nodes_in_group(target_group)
            var next_visible := true
            if not lights.is_empty() and lights[0] is Node3D:
                next_visible = not (lights[0] as Node3D).visible
            for light in lights:
                if light is Node3D:
                    (light as Node3D).visible = next_visible
            AudioManager.play_3d(&"switch", global_position, -10.0)
            return "СВЕТ %s" % ("ВКЛЮЧЁН" if next_visible else "ВЫКЛЮЧЕН")
        "window":
            if bool(get_meta("closed", false)):
                return "ОКНО УЖЕ ЗАКРЫТО"
            set_meta("closed", true)
            AudioManager.play_3d(&"door", global_position, -13.0, 1.15)
            return "ОКНО ЗАКРЫТО. С УЛИЦЫ СТАЛО ТИШЕ"
        "inspect":
            AudioManager.play_3d(&"ui", global_position, -16.0)
            return String(get_meta("interaction_message", display_name))
        _:
            return display_name

func set_delivery_available(value: bool) -> void:
    visible = value
    for descendant in find_children("*", "CollisionObject3D", true, false):
        var collision_object := descendant as CollisionObject3D
        if collision_object != null:
            collision_object.collision_layer = 1 if value else 0
            collision_object.collision_mask = 3 if value else 0

func _duration_for(mode: int) -> float:
    if action_type == "rita_bathroom_clean" and not RitaDemands.can_complete_at(&"bathroom_clean"):
        return 0.05
    if action_type == "rita_kitchen_dishes" and not RitaDemands.can_complete_at(&"kitchen_dishes"):
        return 0.05
    return super._duration_for(mode)

func _noise_for(mode: int) -> float:
    if action_type == "rita_bathroom_clean" and not RitaDemands.can_complete_at(&"bathroom_clean"):
        return 0.0
    if action_type == "rita_kitchen_dishes" and not RitaDemands.can_complete_at(&"kitchen_dishes"):
        return 0.0
    return super._noise_for(mode)

func _demand_location() -> StringName:
    if action_type == "rita_bathroom_clean":
        return &"bathroom_clean"
    if action_type == "rita_kitchen_dishes":
        return &"kitchen_dishes"
    return &""

func _nearest_item(group_name: StringName, radius: float) -> Node3D:
    var nearest: Node3D = null
    var nearest_distance = radius
    for node in get_tree().get_nodes_in_group(String(group_name)):
        if node is Node3D:
            var distance = global_position.distance_to(node.global_position)
            if distance <= nearest_distance:
                nearest = node
                nearest_distance = distance
    return nearest

func get_prompt(_actor) -> String:
    if action_type == "laptop" and bool(get_meta("cat_blocked", false)):
        return "E — ОТВЛЕЧЬ БАТОНА ОТ НОУТБУКА"
    if action_type == "milk_delivery":
        return MilkDelivery.get_pickup_prompt()
    if action_type == "coffee_delivery":
        return CoffeeDelivery.get_pickup_prompt()
    if action_type == "laptop" and not QuestManager.has_milk:
        var delivery := MilkDelivery.get_state()
        if bool(delivery.get("at_door", false)):
            return "КУРЬЕР У ДВЕРИ  •  БЕГИ ЗАБИРАТЬ МОЛОКО"
        if bool(delivery.get("on_the_way", false)):
            return "ПРОВЕРИТЬ ДОСТАВКУ МОЛОКА  •  %.0f СЕК" % float(delivery.get("eta", 0.0))
        return "ЗАКАЗАТЬ МОЛОКО  •  %.0f ₽" % float(delivery.get("next_price", 0.0))
    if action_type == "water":
        if kitchen_flooded and water_on:
            return "СРОЧНО ЗАКРЫТЬ КРАН  •  КУХНЯ ЗАТОПЛЕНА"
        if water_on:
            return "ЗАКРЫТЬ КРАН  •  %d%% / ПЕРЕЛИВ %d%%" % [int(water_fill_progress), int(overflow_progress)]
        if water_fill_progress > 0.0 and water_fill_progress < 100.0:
            return "ВКЛЮЧИТЬ КРАН  •  ЧАЙНИК %d%%" % int(water_fill_progress)
        if _kettle_under_faucet() != null:
            return "ВКЛЮЧИТЬ ВОДУ  •  ЧАЙНИК ПОД КРАНОМ"
        return "ПОДНЕСИ ИЛИ ПОСТАВЬ ЧАЙНИК ПОД СТРУЮ"
    if action_type == "kettle_base":
        if QuestManager.kettle_boiling:
            return "ЧАЙНИК КИПИТ  •  %d%%" % int(get_appliance_state().get("value", 0.0))
        if QuestManager.water_boiled and _kettle_powered:
            return "ЧАЙНИК ПЕРЕКИПАЕТ  •  СНИМИ ЕГО С ПОДСТАВКИ"
        if QuestManager.water_boiled and _cooling_elapsed > 0.0:
            return "ВОДА ОСТЫВАЕТ  •  УСПЕЙ ЗАВАРИТЬ КОФЕ"
    if action_type == "coffee_powder_pour":
        if QuestManager.coffee_made or QuestManager.coffee_powder_poured:
            return "КОФЕ УЖЕ НАСЫПАН"
        if _nearest_item(&"mug", 1.25) == null:
            return "ПОСТАВЬ КРУЖКУ В ЗОНУ ЗАСЫПКИ КОФЕ"
        return "E — НАСЫПАТЬ КОФЕ В КРУЖКУ"
    if action_type == "water_pour":
        if QuestManager.coffee_made or QuestManager.water_poured:
            return "КИПЯТОК УЖЕ НАЛИТ"
        if _nearest_item(&"mug", 1.25) == null:
            return "ПОСТАВЬ КРУЖКУ В ЗОНУ НАЛИВА"
        if not QuestManager.coffee_powder_poured:
            return "СНАЧАЛА НАСЫПЬ КОФЕ В КРУЖКУ"
        if not QuestManager.water_boiled:
            return "СНАЧАЛА ВСКИПЯТИ ЧАЙНИК"
        return "E — НАЛИТЬ КИПЯТОК В КРУЖКУ"
    if action_type == "milk_pour":
        if QuestManager.coffee_made or QuestManager.milk_poured:
            return "МОЛОКО УЖЕ НАЛИТО"
        if _nearest_item(&"mug", 1.25) == null:
            return "ПОСТАВЬ КРУЖКУ В ЗОНУ НАЛИВА МОЛОКА"
        if not QuestManager.water_poured:
            return "СНАЧАЛА НАЛЕЙ КИПЯТОК"
        if not QuestManager.has_milk:
            return "СНАЧАЛА ЗАБЕРИ МОЛОКО У КУРЬЕРА"
        return "E — НАЛИТЬ МОЛОКО В КРУЖКУ"
    return super.get_prompt(_actor)

func get_appliance_state() -> Dictionary:
    if action_type == "water":
        if kitchen_flooded:
            var manager := get_tree().get_first_node_in_group("spill_manager") as SpillManager
            var water_ml := manager.get_volume_by_type("water") if manager != null else 0.0
            return {"active": true, "label": "%s • %d МЛ • ШВАБРА В ВАННОЙ" % [_flood_stage_label(), roundi(water_ml)], "value": clampf(water_ml / 3000.0 * 100.0, 0.0, 100.0), "danger": true}
        if water_on and water_fill_progress < 100.0 and _water_ref != null:
            return {"active": true, "label": "ЧАЙНИК • %d / %d МЛ" % [roundi(water_fill_progress * KETTLE_ROUTE_FILL_ML / 100.0), roundi(KETTLE_ROUTE_FILL_ML)], "value": water_fill_progress, "danger": false}
        if water_on:
            return {"active": true, "label": "КРАН ОСТАВЛЕН — ПЕРЕЛИВ", "value": overflow_progress, "danger": true}
        if water_fill_progress > 0.0 and water_fill_progress < 100.0:
            return {"active": true, "label": "ЧАЙНИК • %d / %d МЛ • КРАН ЗАКРЫТ" % [roundi(water_fill_progress * KETTLE_ROUTE_FILL_ML / 100.0), roundi(KETTLE_ROUTE_FILL_ML)], "value": water_fill_progress, "danger": false}
    elif action_type == "kettle_base":
        if QuestManager.kettle_boiling:
            return {"active": true, "label": "ЧАЙНИК КИПИТ", "value": clampf(_kettle_elapsed / KETTLE_HEAT_SECONDS * 100.0, 0.0, 100.0), "danger": false}
        if QuestManager.water_boiled and _kettle_powered:
            var boiling_volume := _kettle_ref.get_node_or_null("ContainerVolume") as ContainerVolume if _kettle_ref != null else null
            var remaining_ml := boiling_volume.current_ml if boiling_volume != null else 0.0
            var delay_left := maxf(0.0, BOIL_AWAY_DELAY_SECONDS - _overboil_elapsed)
            var boil_label := "ВЫКИПАНИЕ ЧЕРЕЗ %.0f С • %d / %d МЛ" % [ceilf(delay_left), roundi(remaining_ml), roundi(KETTLE_ROUTE_FILL_ML)] if delay_left > 0.0 else "ВОДА ВЫКИПАЕТ • %d / %d МЛ" % [roundi(remaining_ml), roundi(KETTLE_ROUTE_FILL_ML)]
            return {"active": true, "label": boil_label, "value": clampf(remaining_ml / KETTLE_ROUTE_FILL_ML * 100.0, 0.0, 100.0), "danger": true}
        if QuestManager.water_boiled and _cooling_elapsed > 0.0:
            return {"active": true, "label": "ВОДА ОСТЫВАЕТ", "value": clampf((1.0 - _cooling_elapsed / KETTLE_COOL_SECONDS) * 100.0, 0.0, 100.0), "danger": _cooling_elapsed > KETTLE_COOL_SECONDS * 0.72}
    return {"active": false}

func _toggle_water() -> String:
    if water_on:
        water_on = false
        _set_water_visual(false)
        if _water_ref != null and is_instance_valid(_water_ref):
            var stopped_state := _water_ref.get_node_or_null("KettleStateMachine") as KettleStateMachine
            if stopped_state != null and stopped_state.state == KettleStateMachine.KettleState.FILLING:
                stopped_state.transition_to(KettleStateMachine.KettleState.FILLED)
        AudioManager.play_3d(&"switch", global_position, -10.0, 1.1)
        return "КРАН ЗАКРЫТ  •  ЧАЙНИК %d%%" % int(water_fill_progress)
    water_on = true
    _water_audio_tick = 0.0
    _set_water_visual(true)
    AudioManager.play_3d(&"switch", global_position, -10.0, 0.95)
    return "ВОДА ОТКРЫТА  •  ПОСТАВЬ ОТВЕРСТИЕ ЧАЙНИКА ПОД СТРУЮ"

func _process_water(delta: float) -> void:
    if kitchen_flooded:
        var spill_manager := get_tree().get_first_node_in_group("spill_manager") as SpillManager
        if spill_manager != null:
            if water_on:
                _advance_apartment_flood(delta, spill_manager)
            var remaining_water := spill_manager.get_volume_by_type("water")
            overflow_progress = clampf(remaining_water / 1200.0 * 100.0, 0.0, 100.0)
            _update_flood_visual()
            _sync_apartment_flood_visual(remaining_water)
            if remaining_water <= 1.0 and not water_on:
                kitchen_flooded = false
                overflow_progress = 0.0
                _flood_elapsed = 0.0
                _flood_damage_stage = 0
                _update_flood_visual()
                _sync_apartment_flood_visual(0.0)
                QuestManager.clear_bonus_objective(&"apartment_flood")
                QuestManager.notification_requested.emit("КУХНЯ ВЫТЕРТА НАСУХО • ЧИСТО")
    if not water_on or not RunStats.run_active:
        return
    _water_audio_tick -= delta
    if _water_audio_tick <= 0.0:
        _water_audio_tick = 0.72
        AudioManager.play_3d(&"kettle", global_position, -20.0 if not kitchen_flooded else -12.0, 1.35)
        NoiseManager.emit_noise(global_position, 2.2 if not kitchen_flooded else 7.5, &"APPLIANCE", &"running_water")
    var kettle := _kettle_under_faucet()
    var kettle_catches_water := kettle != null
    if kettle_catches_water:
        var detected_volume := kettle.get_node_or_null("ContainerVolume") as ContainerVolume
        water_fill_progress = clampf(detected_volume.current_ml / KETTLE_ROUTE_FILL_ML * 100.0, 0.0, 100.0) if detected_volume != null else 0.0
        kettle.set_meta("fill_progress", water_fill_progress)
        kettle.set_meta("filled", water_fill_progress >= 100.0)
        _water_ref = kettle
    elif _water_ref != null:
        if is_instance_valid(_water_ref):
            var stopped_state := _water_ref.get_node_or_null("KettleStateMachine") as KettleStateMachine
            if stopped_state != null and stopped_state.state == KettleStateMachine.KettleState.FILLING:
                stopped_state.transition_to(KettleStateMachine.KettleState.FILLED)
        _water_ref = null
    if _water_ref != null and water_fill_progress < 100.0:
        var kettle_volume := _water_ref.get_node_or_null("ContainerVolume") as ContainerVolume
        var kettle_state := _water_ref.get_node_or_null("KettleStateMachine") as KettleStateMachine
        if kettle_volume == null:
            _water_ref = null
            return
        if kettle_state != null and kettle_state.state != KettleStateMachine.KettleState.FILLING:
            kettle_state.transition_to(KettleStateMachine.KettleState.FILLING)
        kettle_volume.add_liquid(
            minf(FAUCET_FLOW_ML_S * delta, KETTLE_ROUTE_FILL_ML - kettle_volume.current_ml),
            load("res://resources/liquids/water.tres")
        )
        water_fill_progress = clampf(kettle_volume.current_ml / KETTLE_ROUTE_FILL_ML * 100.0, 0.0, 100.0)
        _water_ref.set_meta("fill_progress", water_fill_progress)
        if water_fill_progress >= 100.0:
            _water_ref.set_meta("filled", true)
            if kettle_state != null and kettle_state.state == KettleStateMachine.KettleState.FILLING:
                kettle_state.transition_to(KettleStateMachine.KettleState.FILLED)
            QuestManager.fill_kettle()
            QuestManager.notification_requested.emit("ЧАЙНИК ПОЛОН  •  КРАН ВСЁ ЕЩЁ ОТКРЫТ")
    else:
        overflow_progress = minf(100.0, overflow_progress + delta * (9.0 if water_fill_progress >= 100.0 else 5.0))
        _update_flood_visual()
        if overflow_progress >= 100.0 and not kitchen_flooded:
            _trigger_kitchen_flood()

func _trigger_kitchen_flood() -> void:
    kitchen_flooded = true
    _flood_elapsed = 0.0
    _flood_spawn_tick = 0.0
    _flood_damage_stage = 0
    _flood_path_cursor = 0
    _update_flood_visual()
    RunStats.spend_money(650.0)
    RunStats.record_kitchen_flood()
    NoiseManager.emit_noise(global_position, 62.0, &"APPLIANCE", &"kitchen_flood")
    var spill_manager := get_tree().get_first_node_in_group("spill_manager") as SpillManager
    if spill_manager != null:
        spill_manager.spawn_spill_typed(Vector3(global_position.x - 0.45, 0.02, global_position.z + 0.25), "water", 95.0)
        spill_manager.spawn_spill_typed(Vector3(global_position.x + 0.10, 0.02, global_position.z + 0.58), "water", 95.0)
        spill_manager.spawn_spill_typed(Vector3(global_position.x + 0.55, 0.02, global_position.z + 0.10), "water", 95.0)
    QuestManager.set_bonus_objective(&"apartment_flood", "ЗАКРОЙ КРАН • ВОЗЬМИ ШВАБРУ В ВАННОЙ • СОБЕРИ ВСЮ ВОДУ")
    QuestManager.notification_requested.emit("КУХНЮ ЗАТОПИЛО • РЕМОНТ −650 ₽ • ЗАКРОЙ КРАН И БЕГИ ЗА ШВАБРОЙ!")

func _advance_apartment_flood(delta: float, spill_manager: SpillManager) -> void:
    _flood_elapsed += delta
    _flood_spawn_tick -= delta
    var stage := 0
    if _flood_elapsed >= 65.0:
        stage = 3
    elif _flood_elapsed >= 35.0:
        stage = 2
    elif _flood_elapsed >= 15.0:
        stage = 1
    if stage > _flood_damage_stage:
        _flood_damage_stage = stage
        _apply_flood_damage_stage(stage)
    if _flood_spawn_tick > 0.0:
        return
    _flood_spawn_tick = maxf(0.72, 1.25 - _flood_elapsed * 0.004)
    var reachable_points: int = int([3, 5, 8, FLOOD_PATH.size()][stage])
    var point_index := _flood_path_cursor % reachable_points
    _flood_path_cursor += 1
    var amount := minf(95.0, 24.0 + _flood_elapsed * 0.72)
    var flood_point := FLOOD_PATH[point_index]
    spill_manager.spawn_spill_typed(flood_point, "water", amount)
    if stage >= 2:
        _push_flood_current(flood_point, stage)

func _apply_flood_damage_stage(stage: int) -> void:
    match stage:
        1:
            RunStats.spend_money(450.0)
            NoiseManager.emit_noise(Vector3(5.6, 0.5, -2.4), 32.0, &"WATER_DAMAGE", &"cabinet_swelling")
            QuestManager.notification_requested.emit("ВОДА ПОЛЗЁТ ПОД ГАРНИТУР • ФАСАДЫ РАЗБУХЛИ • −450 ₽")
        2:
            RunStats.spend_money(1200.0)
            NoiseManager.emit_noise(Vector3(0.0, 0.1, -1.7), 48.0, &"WATER_DAMAGE", &"hallway_flood")
            _release_flood_clutter(3)
            ScreenEffects.shake(0.22, 0.35)
            QuestManager.notification_requested.emit("ВОДА УЖЕ В КОРИДОРЕ И ГОСТИНОЙ • ВЕЩИ ПОПЛЫЛИ • −1200 ₽")
        3:
            RunStats.spend_money(2600.0)
            NoiseManager.emit_noise(Vector3(0.0, 0.1, 2.4), 66.0, &"WATER_DAMAGE", &"apartment_flood")
            _release_flood_clutter(7)
            ScreenEffects.shake(0.38, 0.55)
            QuestManager.notification_requested.emit("ВОДА ПО КОЛЕНО ВО ВСЕЙ КВАРТИРЕ • ДЕНИС ЕЛЕ ИДЁТ • −2600 ₽")

func _release_flood_clutter(limit: int) -> void:
    var released := 0
    var allowed_tokens := ["shoe", "book_loose", "magazine", "remote", "backpack", "parcel", "clothes", "laundry_basket"]
    for node in get_tree().get_nodes_in_group("carryable"):
        if released >= limit or not node is RigidBody3D:
            break
        var body := node as RigidBody3D
        if bool(body.get_meta("flood_released", false)):
            continue
        var id := String(body.get("item_id"))
        var allowed := false
        for token in allowed_tokens:
            if id.contains(token):
                allowed = true
                break
        if not allowed:
            continue
        body.set_meta("flood_released", true)
        body.freeze = false
        body.sleeping = false
        var away := body.global_position - Vector3(0.0, body.global_position.y, -1.4)
        away.y = 0.0
        body.apply_central_impulse(away.normalized() * 0.22 + Vector3.UP * 0.04)
        released += 1

func _push_flood_current(origin: Vector3, stage: int) -> void:
    var allowed_tokens := ["shoe", "book_loose", "magazine", "remote", "backpack", "parcel", "clothes", "laundry_basket"]
    var phase := _flood_elapsed * 0.73
    var current := Vector3(sin(phase), 0.0, cos(phase * 0.81)).normalized()
    for node in get_tree().get_nodes_in_group("carryable"):
        if not node is RigidBody3D:
            continue
        var body := node as RigidBody3D
        if body.global_position.distance_to(origin) > 3.2:
            continue
        var id := String(body.get("item_id"))
        var allowed := false
        for token in allowed_tokens:
            if id.contains(token):
                allowed = true
                break
        if not allowed:
            continue
        body.freeze = false
        body.sleeping = false
        var lift := 0.055 if stage == 2 else 0.10
        body.apply_central_impulse(current * (0.06 + float(stage) * 0.025) + Vector3.UP * lift)
        body.apply_torque_impulse(Vector3(0.0, randf_range(-0.035, 0.035), 0.0))

func _flood_stage_label() -> String:
    if _flood_damage_stage >= 3:
        return "ВОДА ПО КОЛЕНО • ДЕНИС ЗАМЕДЛЕН"
    if _flood_damage_stage == 2:
        return "ВОДА ПО ЩИКОЛОТКУ • КОРИДОР ЗАЛИТ"
    if _flood_damage_stage == 1:
        return "ВОДА ПОД ГАРНИТУРОМ"
    return "КУХНЯ ЗАТОПЛЕНА — ЗАКРОЙ КРАН"

func _kettle_under_faucet() -> Node3D:
    _cache_water_visuals()
    if _water_catch_area == null:
        return null
    for area in _water_catch_area.get_overlapping_areas():
        if area.name != &"KettleOpeningArea":
            continue
        var candidate := area.get_parent()
        while candidate != null and candidate is Node3D:
            if candidate.is_in_group("kettle"):
                return candidate as Node3D
            candidate = candidate.get_parent()
    return null

func _set_water_visual(value: bool) -> void:
    _cache_water_visuals()
    if _water_stream != null:
        _water_stream.visible = value

func _update_flood_visual() -> void:
    _cache_water_visuals()
    if _flood_visual == null:
        return
    _flood_visual.visible = overflow_progress > 0.5
    var scale_value := lerpf(0.10, 2.8, clampf(overflow_progress / 100.0, 0.0, 1.0))
    _flood_visual.scale = Vector3(scale_value, 1.0, scale_value * 0.72)

func _sync_apartment_flood_visual(volume_ml: float) -> void:
    if _apartment_flood_visual == null or not is_instance_valid(_apartment_flood_visual):
        _apartment_flood_visual = get_tree().get_first_node_in_group("apartment_flood_visual") as ApartmentFloodVisual
    if _apartment_flood_visual != null:
        _apartment_flood_visual.set_flood_state(
            kitchen_flooded,
            _flood_damage_stage,
            _flood_elapsed,
            volume_ml,
            water_on
        )

func _cache_water_visuals() -> void:
    if _water_stream == null:
        _water_stream = get_node_or_null("WaterStream") as Node3D
    if _water_catch_area == null:
        _water_catch_area = get_node_or_null("WaterCatchArea") as Area3D
    if _flood_visual == null:
        _flood_visual = get_node_or_null("KitchenFlood") as Node3D

func _start_kettle_cycle(kettle: Node3D) -> void:
    _kettle_ref = kettle
    _kettle_tick = 0
    _kettle_elapsed = 0.0
    _kettle_powered = true
    _overboil_elapsed = 0.0
    _overboil_noise_tick = 0.0
    _cooling_elapsed = 0.0
    _overboil_warning_stage = 0
    kettle.set_meta("boiling", true)
    kettle.set_meta("heat", 0.0)
    var kettle_state := kettle.get_node_or_null("KettleStateMachine") as KettleStateMachine
    if kettle_state != null:
        if kettle_state.state == KettleStateMachine.KettleState.HELD:
            kettle_state.transition_to(KettleStateMachine.KettleState.ON_BASE)
        kettle_state.transition_to(KettleStateMachine.KettleState.HEATING)
    _set_steam_visible(true)
    _kettle_timer.start()

func _process_kettle(delta: float) -> void:
    if not RunStats.run_active:
        return
    if _kettle_ref == null or not is_instance_valid(_kettle_ref):
        _kettle_ref = get_tree().get_first_node_in_group("kettle") as Node3D
    if QuestManager.kettle_boiling:
        _kettle_elapsed = minf(KETTLE_HEAT_SECONDS, _kettle_elapsed + delta)
        if _kettle_ref != null:
            _kettle_ref.set_meta("heat", clampf(_kettle_elapsed / KETTLE_HEAT_SECONDS, 0.0, 1.0))
        _animate_steam()
        return
    if not QuestManager.water_boiled or _kettle_ref == null:
        _set_steam_visible(false)
        return
    var on_base := not bool(_kettle_ref.get("held")) and global_position.distance_to(_kettle_ref.global_position) <= 1.1
    if _kettle_powered and on_base:
        var previous_overboil_elapsed := _overboil_elapsed
        _overboil_elapsed += delta
        _overboil_noise_tick -= delta
        _kettle_ref.set_meta("heat", 1.0)
        _set_steam_visible(true)
        _animate_steam()
        if _overboil_noise_tick <= 0.0:
            _overboil_noise_tick = 1.20
            var overboil_noise := minf(18.0, 9.0 + _overboil_elapsed * 0.05)
            NoiseManager.emit_noise(_kettle_ref.global_position, overboil_noise, &"KETTLE", &"kettle_overboil")
            AudioManager.play_3d(&"kettle", _kettle_ref.global_position, -15.0, 1.12)
        var kettle_volume := _kettle_ref.get_node_or_null("ContainerVolume") as ContainerVolume
        var kettle_state := _kettle_ref.get_node_or_null("KettleStateMachine") as KettleStateMachine
        if _overboil_elapsed >= BOIL_AWAY_DELAY_SECONDS and kettle_volume != null:
            if kettle_state != null and kettle_state.state == KettleStateMachine.KettleState.BOILED:
                kettle_state.transition_to(KettleStateMachine.KettleState.BOILING_AWAY)
            var active_before := maxf(0.0, previous_overboil_elapsed - BOIL_AWAY_DELAY_SECONDS)
            var active_after := maxf(0.0, _overboil_elapsed - BOIL_AWAY_DELAY_SECONDS)
            kettle_volume.remove_liquid(BOIL_AWAY_ML_PER_SECOND * (active_after - active_before))
            _kettle_ref.set_meta("fill_progress", clampf(kettle_volume.current_ml / KETTLE_ROUTE_FILL_ML * 100.0, 0.0, 100.0))
            _kettle_ref.set_meta("filled", kettle_volume.current_ml > 0.01)
        var remaining_ml := kettle_volume.current_ml if kettle_volume != null else 0.0
        if remaining_ml < 100.0 and remaining_ml >= 30.0 and _overboil_warning_stage == 0:
            _overboil_warning_stage = 1
            QuestManager.notification_requested.emit("ВОДА ВЫКИПАЕТ • ОСТАЛОСЬ МЕНЬШЕ 100 МЛ")
        elif remaining_ml < 30.0 and remaining_ml > 0.01 and _overboil_warning_stage < 2:
            _overboil_warning_stage = 2
            QuestManager.notification_requested.emit("ЧАЙНИК ПОЧТИ ПУСТ")
        if kettle_volume != null and kettle_volume.current_ml <= 0.01:
            _kettle_powered = false
            _kettle_timer.stop()
            _kettle_ref.set_meta("heat", 0.0)
            _kettle_ref.set_meta("boiling", false)
            _set_steam_visible(false)
            if kettle_state != null and kettle_state.state != KettleStateMachine.KettleState.DRY:
                kettle_state.transition_to(KettleStateMachine.KettleState.DRY)
            QuestManager.notification_requested.emit("ВОДА ВЫКИПЕЛА • ЧАЙНИК ОТКЛЮЧИЛСЯ")
            QuestManager.notify_water_insufficient()
        return
    if _kettle_powered:
        _kettle_powered = false
        _cooling_elapsed = 0.01
        QuestManager.notification_requested.emit("ЧАЙНИК СНЯТ  •  ГОРЯЧАЯ ВОДА НАЧАЛА ОСТЫВАТЬ")
    _cooling_elapsed += delta
    var heat := clampf(1.0 - _cooling_elapsed / KETTLE_COOL_SECONDS, 0.0, 1.0)
    _kettle_ref.set_meta("heat", heat)
    _set_steam_visible(heat > 0.38)
    if heat > 0.38:
        _animate_steam()
    if _cooling_elapsed >= KETTLE_COOL_SECONDS:
        _cooling_elapsed = KETTLE_COOL_SECONDS
        _kettle_ref.set_meta("heat", 0.0)
        _set_steam_visible(false)
        QuestManager.cool_kettle()

func _on_kettle_tick() -> void:
    if _kettle_ref == null or not is_instance_valid(_kettle_ref):
        _kettle_timer.stop()
        _set_steam_visible(false)
        return
    if bool(_kettle_ref.get("held")) or global_position.distance_to(_kettle_ref.global_position) > 1.1:
        _kettle_timer.stop()
        _kettle_powered = false
        _kettle_ref.set_meta("boiling", false)
        _kettle_elapsed = 0.0
        _set_steam_visible(false)
        QuestManager.cancel_boiling()
        return
    _kettle_tick += 1
    AudioManager.play_3d(&"kettle", _kettle_ref.global_position, -19.0 + float(_kettle_tick) * 0.35, 0.86 + float(_kettle_tick) * 0.025)
    NoiseManager.emit_noise(_kettle_ref.global_position, 4.0 + float(_kettle_tick) * 0.35, &"KETTLE", &"kettle_hum")
    if _kettle_tick < 8:
        return
    _kettle_timer.stop()
    QuestManager.finish_boiling()
    NoiseManager.emit_noise(_kettle_ref.global_position, 24.0, &"KETTLE", &"kettle_click")
    AudioManager.play_3d(&"switch", _kettle_ref.global_position, -4.0, 0.72)
    _kettle_ref.set_meta("boiling", false)
    _kettle_ref.set_meta("heat", 1.0)
    var kettle_state := _kettle_ref.get_node_or_null("KettleStateMachine") as KettleStateMachine
    if kettle_state != null:
        kettle_state.temperature_c = KettleStateMachine.BOIL_TEMP
        if kettle_state.state == KettleStateMachine.KettleState.HEATING:
            kettle_state.transition_to(KettleStateMachine.KettleState.BOILED)
    _kettle_elapsed = KETTLE_HEAT_SECONDS
    _overboil_elapsed = 0.0
    _overboil_noise_tick = 0.0
    _set_steam_visible(true)

func _set_steam_visible(value: bool) -> void:
    _cache_steam_nodes()
    for steam in _steam_nodes:
        steam.visible = value

func _animate_steam() -> void:
    _cache_steam_nodes()
    var time_value := Time.get_ticks_msec() * 0.001
    for index in range(_steam_nodes.size()):
        var steam := _steam_nodes[index]
        var density := 1.0 + clampf((_overboil_elapsed - BOIL_AWAY_DELAY_SECONDS) / 90.0, 0.0, 0.65)
        steam.scale = Vector3(density, density, density)
        steam.position.y = 0.34 + fmod(time_value * (0.18 + float(index) * 0.035) + float(index) * 0.15, 0.42)
        steam.position.x = sin(time_value * 1.7 + float(index) * 2.1) * 0.07

func _cache_steam_nodes() -> void:
    if not _steam_nodes.is_empty():
        return
    for node_name in ["SteamA", "SteamB", "SteamC"]:
        var steam := get_node_or_null(node_name) as Node3D
        if steam != null:
            _steam_nodes.append(steam)

func _tint_mug(mug: Node3D) -> void:
    var coffee_surface := mug.get_node_or_null("CoffeeSurface") as Node3D
    if coffee_surface != null:
        coffee_surface.visible = true
        return
    var mesh = mug.get_node_or_null("Mesh") as MeshInstance3D
    if mesh == null:
        return
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.18, 0.07, 0.025)
    material.metallic = 0.0
    material.roughness = 0.5
    mesh.material_override = material
