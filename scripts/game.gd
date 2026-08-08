extends Node3D

const APARTMENT_BUILDER_SCRIPT := preload("res://scripts/apartment_builder.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const WATER_DEF := preload("res://resources/liquids/water.tres")
const MILK_DEF := preload("res://resources/liquids/milk.tres")
const CAT_BALANCE_RUNNER_SCRIPT := preload("res://scripts/qa/cat_balance_runner.gd")

var builder = null
var hud = null
var player = null
var _web_paused_for_focus := false

func _notification(what: int) -> void:
    if not OS.has_feature("web") or not is_inside_tree():
        return
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        if not get_tree().paused:
            get_tree().paused = true
            _web_paused_for_focus = true
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _web_paused_for_focus:
        get_tree().paused = false
        _web_paused_for_focus = false

func _ready() -> void:
    _ensure_input_actions()
    _reset_systems()
    builder = APARTMENT_BUILDER_SCRIPT.new()
    builder.name = "Apartment"
    add_child(builder)
    var objects: Dictionary = builder.build_world()
    player = objects.get("player") as Node
    if player == null:
        push_error("ApartmentBuilder did not create Player")
        get_tree().quit(2)
        return

    hud = HUD_SCRIPT.new()
    hud.name = "HUD"
    add_child(hud)
    if player.has_signal("prompt_changed"):
        player.connect("prompt_changed", Callable(hud, "set_prompt"))
    else:
        push_error("Player has no prompt_changed signal")
    if player.has_signal("message_requested"):
        player.connect("message_requested", Callable(hud, "show_message"))
    else:
        push_error("Player has no message_requested signal")

    QuestManager.notification_requested.emit("06:20. РИТА СПИТ. СОЗВОН УЖЕ ИДЁТ. ДЕНИСУ НУЖЕН КОФЕ.")
    CallManager.reset()
    
    # Инициализация новых систем
    _init_new_systems()

    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--cat-balance="):
            var balance_runner := CAT_BALANCE_RUNNER_SCRIPT.new() as CatBalanceRunner
            balance_runner.name = "CatBalanceRunner"
            add_child(balance_runner)
            balance_runner.setup(self, objects, argument.get_slice("=", 1))
    
    _run_optional_tests()
    _capture_layout_if_requested()
    _capture_room_if_requested()
    _benchmark_environment_if_requested()

func _init_new_systems() -> void:
    # Инициализация фоторежима
    PhotoMode.set_camera(player.get_node_or_null("Camera"))
    PhotoMode.set_ui_root(hud)
    
    # Запуск обучения для новых игроков
    if TutorialSystem.should_show_tutorial():
        TutorialSystem.start_tutorial()
    
    # Установка случайной погоды
    WeatherSystem.randomize_weather()

func _capture_layout_if_requested() -> void:
    if "--capture-layout" not in OS.get_cmdline_user_args():
        return
    await get_tree().process_frame
    await get_tree().process_frame
    if player == null or not is_instance_valid(player):
        get_tree().quit(3)
        return
    player.set_physics_process(false)
    var camera := player.get_node_or_null("Camera") as Camera3D
    if camera == null:
        get_tree().quit(4)
        return
    hud.visible = false
    player.call("set_view_hands_visible", false)
    var ceiling := builder.get_node_or_null("Ceiling") as MeshInstance3D
    if ceiling != null:
        ceiling.visible = false
    var wardrobe_ceiling := builder.get_node_or_null("WardrobeCeiling") as MeshInstance3D
    if wardrobe_ceiling != null:
        wardrobe_ceiling.visible = false
    camera.current = false
    var capture_camera := Camera3D.new()
    capture_camera.name = "LayoutCaptureCamera"
    add_child(capture_camera)
    capture_camera.current = true
    capture_camera.global_position = Vector3(0.0, 15.0, 1.5)
    capture_camera.look_at(Vector3(0.0, 0.0, 1.5), Vector3(0.0, 0.0, -1.0))
    capture_camera.fov = 68.0
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var path := ProjectSettings.globalize_path("res://docs/evidence/environment/apartment_top_view.png")
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var result := image.save_png(path)
    print("LAYOUT_CAPTURE_SAVED: %s (%s)" % [path, error_string(result)])
    get_tree().quit(0 if result == OK else 5)

func _capture_room_if_requested() -> void:
    var args := OS.get_cmdline_user_args()
    var camera_position := Vector3.ZERO
    var camera_target := Vector3.ZERO
    var file_name := ""
    var show_held_item := false
    var show_hud := false
    var show_economy := false
    var show_map := false
    var show_urgent := false
    var show_water := false
    var show_beer := false
    var show_task := false
    var show_fridge := false
    var show_football_video := false
    var show_vacuum := false
    var show_washing_machine := false
    var show_washing_machine_movable := false
    var show_movie := false
    var show_overboil := false
    var show_coffee_result := false
    var show_coffee_pour := false
    var show_delivery := false
    var show_coffee_delivery := false
    var show_aaa_new_game := false
    var show_aaa_kettle_hands := false
    var show_aaa_kettle_pour := false
    var show_aaa_wall_art := false
    var show_aaa_kitchen_open := false
    var show_environment_capture := false
    var show_intro_minimal := false
    var show_mug_print := false
    var payment_capture := ""
    var usability_capture := ""
    var coffee_anywhere_capture := ""
    var cat_capture := ""
    if "--capture-cat-idle" in args:
        camera_position = Vector3(-4.05, 0.98, 0.20)
        camera_target = Vector3(-5.55, 0.30, 1.48)
        file_name = "docs/evidence/rita_cat/cat_idle_home.png"
        cat_capture = "idle"
    elif "--capture-cat-spoon" in args:
        camera_position = Vector3(3.62, 1.48, -3.15)
        camera_target = Vector3(5.65, 1.08, -5.55)
        file_name = "docs/evidence/rita_cat/spoon_story_telegraph.png"
        cat_capture = "spoon"
    elif "--capture-cat-laptop" in args:
        camera_position = Vector3(-3.75, 1.62, -3.62)
        camera_target = Vector3(-5.55, 0.92, -5.25)
        file_name = "docs/evidence/rita_cat/laptop_story_development.png"
        cat_capture = "laptop"
    elif "--capture-cat-flood" in args:
        camera_position = Vector3(5.15, 1.65, 6.15)
        camera_target = Vector3(2.78, 0.62, 5.58)
        file_name = "docs/evidence/rita_cat/flood_mop_interference.png"
        cat_capture = "flood"
        show_hud = true
    elif "--capture-intro-minimal" in args:
        camera_position = Vector3(1.95, 1.62, -0.10)
        camera_target = Vector3(4.80, 1.05, -4.20)
        file_name = "docs/evidence/usability/intro_minimal.png"
        show_hud = true
        show_intro_minimal = true
    elif "--capture-denis-mug-print" in args:
        camera_position = Vector3(5.85, 1.35, -4.82)
        camera_target = Vector3(5.85, 1.22, -5.75)
        file_name = "docs/evidence/environment/denis_mug_lisa_print.png"
        show_mug_print = true
    elif "--capture-aaa-new-game" in args:
        camera_position = Vector3(1.95, 1.62, -0.10)
        camera_target = Vector3(4.80, 1.05, -4.20)
        file_name = "docs/evidence/aaa_polish/new_game_correct_state.png"
        show_hud = true
        show_aaa_new_game = true
    elif "--capture-aaa-kettle-hands" in args:
        camera_position = Vector3(3.05, 1.62, -2.75)
        camera_target = Vector3(5.20, 1.10, -4.70)
        file_name = "docs/evidence/aaa_polish/kettle_correct_in_hands.png"
        show_held_item = true
        show_aaa_kettle_hands = true
    elif "--capture-aaa-kettle-pour" in args:
        camera_position = Vector3(3.05, 1.62, -2.75)
        camera_target = Vector3(5.20, 1.10, -4.70)
        file_name = "docs/evidence/aaa_polish/kettle_pouring_with_e.png"
        show_held_item = true
        show_hud = true
        show_aaa_kettle_pour = true
    elif "--capture-aaa-wall-art" in args:
        camera_position = Vector3(-5.65, 1.70, -1.15)
        camera_target = Vector3(-7.85, 1.68, -1.15)
        file_name = "docs/evidence/aaa_polish/wall_art_correct.png"
        show_aaa_wall_art = true
    elif "--capture-aaa-kitchen-open" in args:
        camera_position = Vector3(1.95, 1.75, -0.10)
        camera_target = Vector3(5.20, 1.10, -4.75)
        file_name = "docs/evidence/aaa_polish/kitchen_all_open.png"
        show_aaa_kitchen_open = true
    elif "--capture-kettle-base-audit" in args:
        camera_position = Vector3(3.42, 1.48, -4.48)
        camera_target = Vector3(4.45, 1.26, -5.99)
        file_name = "docs/evidence/environment/kettle_on_base_audit.png"
        show_environment_capture = true
    elif "--capture-env-corridor" in args:
        camera_position = Vector3(0.0, 1.66, 5.82)
        camera_target = Vector3(0.0, 1.05, -2.60)
        file_name = "docs/evidence/environment/corridor_finished.png"
        show_environment_capture = true
    elif "--capture-env-kitchen" in args:
        camera_position = Vector3(2.55, 2.28, -1.32)
        camera_target = Vector3(5.30, 0.98, -5.12)
        file_name = "docs/evidence/environment/kitchen_finished.png"
        show_environment_capture = true
    elif "--capture-env-living" in args:
        camera_position = Vector3(-2.15, 1.82, -3.28)
        camera_target = Vector3(-5.65, 0.92, -0.10)
        file_name = "docs/evidence/environment/living_room_finished.png"
        show_environment_capture = true
    elif "--capture-env-bedroom" in args:
        camera_position = Vector3(-2.08, 1.68, 3.20)
        camera_target = Vector3(-5.72, 0.92, 4.88)
        file_name = "docs/evidence/environment/bedroom_finished.png"
        show_environment_capture = true
    elif "--capture-env-workspace" in args:
        camera_position = Vector3(-3.62, 1.76, -3.48)
        camera_target = Vector3(-5.65, 1.02, -5.25)
        file_name = "docs/evidence/environment/workspace_finished.png"
        show_environment_capture = true
    elif "--capture-env-bathroom" in args:
        camera_position = Vector3(2.18, 1.68, 3.08)
        camera_target = Vector3(5.52, 0.92, 4.48)
        file_name = "docs/evidence/environment/bathroom_finished.png"
        show_environment_capture = true
    elif "--capture-washing-machine" in args:
        camera_position = Vector3(0.34, 1.40, 2.36)
        camera_target = Vector3(2.08, 0.62, 3.06)
        file_name = "docs/evidence/environment/washing_machine_escape.png"
        show_hud = true
        show_washing_machine = true
    elif "--capture-washing-machine-movable" in args:
        camera_position = Vector3(0.05, 1.38, 4.42)
        camera_target = Vector3(1.25, 0.62, 4.72)
        file_name = "docs/evidence/environment/washing_machine_movable.png"
        show_hud = true
        show_washing_machine_movable = true
    elif "--capture-payment-entrance-closed" in args:
        camera_position = Vector3(-3.20, 1.58, 8.18)
        camera_target = Vector3(-3.20, 1.30, 9.50)
        file_name = "docs/evidence/payment_altar/entrance_closed.png"
        show_environment_capture = true
        payment_capture = "closed"
    elif "--capture-payment-entrance-open" in args:
        camera_position = Vector3(-3.20, 1.58, 8.18)
        camera_target = Vector3(-3.20, 1.30, 10.92)
        file_name = "docs/evidence/payment_altar/entrance_open.png"
        show_environment_capture = true
        payment_capture = "open"
    elif "--capture-payment-wide" in args:
        camera_position = Vector3(-3.20, 1.58, 8.88)
        camera_target = Vector3(-3.20, 0.90, 11.28)
        file_name = "docs/evidence/payment_altar/altar_wide.png"
        show_environment_capture = true
        payment_capture = "wide"
    elif "--capture-payment-investigation" in args:
        camera_position = Vector3(-3.08, 1.62, 10.04)
        camera_target = Vector3(-4.55, 1.55, 10.82)
        file_name = "docs/evidence/payment_altar/investigation_wall.png"
        show_environment_capture = true
        payment_capture = "investigation"
    elif "--capture-payment-relic" in args:
        camera_position = Vector3(-3.20, 1.42, 10.28)
        camera_target = Vector3(-3.20, 1.28, 11.42)
        file_name = "docs/evidence/payment_altar/central_relic.png"
        show_environment_capture = true
        payment_capture = "relic"
    elif "--capture-usability-phone" in args:
        camera_position = Vector3(-3.62, 1.48, -3.98)
        camera_target = Vector3(-4.82, 0.84, -5.23)
        file_name = "docs/evidence/usability/phone_random_desk.png"
        usability_capture = "phone"
    elif "--capture-usability-spill" in args:
        camera_position = Vector3(4.10, 1.58, -2.05)
        camera_target = Vector3(5.10, 0.08, -3.35)
        file_name = "docs/evidence/usability/spill_cleanup.png"
        show_held_item = true
        show_hud = true
        usability_capture = "spill"
    elif "--capture-apartment-flood" in args:
        camera_position = Vector3(3.05, 1.46, -1.18)
        camera_target = Vector3(5.20, 0.03, -2.58)
        file_name = "docs/evidence/usability/apartment_flood_mop.png"
        show_held_item = true
        show_hud = true
        usability_capture = "flood"
    elif "--capture-usability-water-hud" in args:
        camera_position = Vector3(3.25, 1.62, -2.70)
        camera_target = Vector3(5.05, 1.05, -4.65)
        file_name = "docs/evidence/usability/pouring_water_hud.png"
        show_held_item = true
        show_hud = true
        usability_capture = "water_hud"
    elif "--capture-usability-milk-hud" in args:
        camera_position = Vector3(3.25, 1.62, -2.70)
        camera_target = Vector3(5.05, 1.05, -4.65)
        file_name = "docs/evidence/usability/pouring_milk_hud.png"
        show_held_item = true
        show_hud = true
        usability_capture = "milk_hud"
    elif "--capture-usability-vacuum" in args:
        camera_position = Vector3(0.0, 1.34, -2.72)
        camera_target = Vector3(0.84, 0.26, -5.18)
        file_name = "docs/evidence/usability/vacuum_exit.png"
        usability_capture = "vacuum"
    elif "--capture-usability-vacuum-blocked" in args:
        camera_position = Vector3(0.0, 1.34, -2.72)
        camera_target = Vector3(0.84, 0.26, -5.18)
        file_name = "docs/evidence/usability/vacuum_blocked.png"
        show_hud = true
        usability_capture = "vacuum_blocked"
    elif "--capture-coffee-kitchen" in args:
        camera_position = Vector3(3.95, 1.72, -3.72)
        camera_target = Vector3(5.10, 1.18, -5.10)
        file_name = "docs/evidence/coffee_anywhere/kitchen_counter.png"
        show_hud = true
        coffee_anywhere_capture = "kitchen"
    elif "--capture-coffee-dining" in args:
        camera_position = Vector3(7.35, 1.48, 1.26)
        camera_target = Vector3(5.35, 0.96, 1.26)
        file_name = "docs/evidence/coffee_anywhere/dining_table.png"
        show_hud = true
        coffee_anywhere_capture = "dining"
    elif "--capture-coffee-desk" in args:
        camera_position = Vector3(-3.62, 1.55, -3.65)
        camera_target = Vector3(-5.20, 0.98, -5.10)
        file_name = "docs/evidence/coffee_anywhere/work_desk.png"
        show_hud = true
        coffee_anywhere_capture = "desk"
    elif "--capture-coffee-hall" in args:
        camera_position = Vector3(0.00, 1.48, 5.05)
        camera_target = Vector3(-1.30, 1.10, 5.05)
        file_name = "docs/evidence/coffee_anywhere/hall_console.png"
        show_hud = true
        coffee_anywhere_capture = "hall"
    elif "--capture-coffee-floor" in args:
        camera_position = Vector3(-3.80, 0.82, 0.05)
        camera_target = Vector3(-3.80, 0.18, 1.25)
        file_name = "docs/evidence/coffee_anywhere/living_floor.png"
        show_hud = true
        coffee_anywhere_capture = "floor"
    elif "--capture-rita" in args:
        camera_position = Vector3(-2.05, 1.62, 3.72)
        camera_target = Vector3(-5.45, 0.92, 4.72)
        file_name = "room_capture_rita.png"
    elif "--capture-living" in args:
        camera_position = Vector3(-3.15, 1.62, -3.65)
        camera_target = Vector3(-5.55, 0.90, -0.15)
        file_name = "room_capture_living.png"
    elif "--capture-corridor" in args:
        camera_position = Vector3(0.0, 1.62, -4.65)
        camera_target = Vector3(0.0, 1.05, 4.85)
        file_name = "room_capture_corridor.png"
    elif "--capture-delivery" in args:
        camera_position = Vector3(0.0, 1.62, 3.65)
        camera_target = Vector3(0.0, 0.72, 5.98)
        file_name = "milk_delivery_capture.png"
        show_hud = true
        show_delivery = true
    elif "--capture-coffee-delivery" in args:
        camera_position = Vector3(0.0, 1.62, 3.65)
        camera_target = Vector3(0.48, 0.55, 5.91)
        file_name = "docs/evidence/usability/coffee_delivery.png"
        show_hud = true
        show_coffee_delivery = true
    elif "--capture-wardrobe" in args:
        camera_position = Vector3(-4.65, 1.62, 6.92)
        camera_target = Vector3(-4.65, 1.20, 9.20)
        file_name = "room_capture_wardrobe.png"
    elif "--capture-kitchen" in args:
        camera_position = Vector3(2.05, 1.62, 0.55)
        camera_target = Vector3(5.25, 0.95, -3.85)
        file_name = "room_capture_kitchen_demand.png"
    elif "--capture-bathroom" in args:
        camera_position = Vector3(2.00, 1.62, 2.55)
        camera_target = Vector3(5.30, 0.90, 4.55)
        file_name = "room_capture_bathroom_demand.png"
    elif "--capture-hands" in args:
        camera_position = Vector3(-4.20, 1.62, -3.05)
        camera_target = Vector3(-5.20, 1.15, -0.30)
        file_name = "hands_capture.png"
        show_held_item = true
    elif "--capture-economy" in args:
        camera_position = Vector3(-3.15, 1.62, -3.65)
        camera_target = Vector3(-5.55, 0.90, -0.15)
        file_name = "economy_capture.png"
        show_hud = true
        show_economy = true
    elif "--capture-map" in args:
        camera_position = Vector3(0.0, 1.62, -4.65)
        camera_target = Vector3(0.0, 1.05, 4.85)
        file_name = "map_capture.png"
        show_hud = true
        show_map = true
    elif "--capture-urgent" in args:
        camera_position = Vector3(-3.15, 1.62, -3.65)
        camera_target = Vector3(-5.55, 0.90, -0.15)
        file_name = "urgent_tasks_capture.png"
        show_hud = true
        show_urgent = true
    elif "--capture-water" in args:
        camera_position = Vector3(5.52, 1.88, -2.72)
        camera_target = Vector3(7.35, 1.40, -4.28)
        file_name = "docs/evidence/environment/kitchen_sink_audit.png"
        show_hud = true
        show_water = true
    elif "--capture-beer" in args:
        camera_position = Vector3(-3.15, 1.62, -3.65)
        camera_target = Vector3(-5.55, 1.12, -0.15)
        file_name = "beer_drink_capture.png"
        show_beer = true
    elif "--capture-task" in args:
        camera_position = Vector3(3.35, 1.70, -0.30)
        camera_target = Vector3(6.05, 1.05, -2.86)
        file_name = "task_minigame_capture.png"
        show_hud = true
        show_task = true
    elif "--capture-fridge" in args:
        camera_position = Vector3(4.65, 1.55, -4.18)
        camera_target = Vector3(6.92, 1.02, -4.80)
        file_name = "fridge_beer_capture.png"
        show_fridge = true
    elif "--capture-football-video" in args:
        camera_position = Vector3(-5.20, 1.50, -0.20)
        camera_target = Vector3(-2.65, 1.15, -0.20)
        file_name = "football_video_capture.png"
        show_football_video = true
    elif "--capture-vacuum" in args:
        camera_position = Vector3(3.0, 1.25, 0.15)
        camera_target = Vector3(4.2, 0.12, -1.0)
        file_name = "vacuum_capture.png"
        show_vacuum = true
    elif "--capture-movie" in args:
        camera_position = Vector3(-2.10, 1.68, 3.55)
        camera_target = Vector3(-3.20, 1.15, 5.45)
        file_name = "rita_movie_capture.png"
        show_hud = true
        show_movie = true
    elif "--capture-overboil" in args:
        camera_position = Vector3(3.55, 1.66, -3.45)
        camera_target = Vector3(3.55, 1.38, -5.39)
        file_name = "kettle_overboil_capture.png"
        show_hud = true
        show_overboil = true
    elif "--capture-coffee-result" in args:
        camera_position = Vector3(2.05, 1.62, 0.55)
        camera_target = Vector3(5.25, 0.95, -3.85)
        file_name = "coffee_result_capture.png"
        show_hud = true
        show_coffee_result = true
    elif "--capture-coffee-pour" in args:
        camera_position = Vector3(3.90, 1.58, -4.32)
        camera_target = Vector3(5.10, 1.28, -5.37)
        file_name = "coffee_pour_capture.png"
        show_hud = true
        show_coffee_pour = true
    else:
        return
    await get_tree().process_frame
    await get_tree().process_frame
    player.set_physics_process(false)
    hud.visible = show_hud
    var camera := player.get_node_or_null("Camera") as Camera3D
    if camera == null:
        get_tree().quit(6)
        return
    if not coffee_anywhere_capture.is_empty() or not cat_capture.is_empty() or show_washing_machine or show_washing_machine_movable or show_mug_print:
        camera.current = false
        var coffee_capture_camera := Camera3D.new()
        coffee_capture_camera.name = "CoffeeAnywhereCaptureCamera"
        add_child(coffee_capture_camera)
        coffee_capture_camera.current = true
        camera = coffee_capture_camera
    camera.global_position = camera_position
    camera.look_at(camera_target, Vector3.UP)
    camera.fov = 76.0
    player.call("set_view_hands_visible", show_held_item or show_beer)
    if show_hud and not show_intro_minimal:
        var intro := hud.get("intro_panel") as Control
        if intro != null:
            intro.hide()
    if show_mug_print:
        var printed_mug := builder._objects.get("mug") as RigidBody3D
        if printed_mug != null:
            printed_mug.reparent(self, true)
            printed_mug.freeze = true
            printed_mug.sleeping = true
            printed_mug.global_position = Vector3(5.85, 1.22, -5.75)
            printed_mug.global_rotation = Vector3.ZERO
            camera.global_position = camera_position
            camera.look_at(camera_target, Vector3.UP)
            camera.fov = 42.0
    if show_economy:
        RunStats.money_balance = -820.0
        RunStats.missed_payments = 2
        RunStats.missed_payment_streak = 2
        RunStats.economy_updated.emit(RunStats.get_economy_state())
        CallManager.question_active = true
        CallManager.question_kind = &"payment"
        CallManager.answer_time_left = 7.4
    if show_delivery:
        QuestManager.register_mug()
        QuestManager.register_coffee()
        MilkDelivery.order_milk()
        MilkDelivery.force_arrival_for_test()
        MilkDelivery.pickup_time_left = 14.6
        hud.call("_update_urgent_panel", CallManager.get_state())
    if show_coffee_delivery:
        QuestManager.register_mug()
        QuestManager.register_coffee()
        var capture_coffee_jar := builder._objects.get("coffee") as RigidBody3D
        var capture_coffee_emitter := capture_coffee_jar.get_node("CoffeePowderEmitter") as CoffeePowderEmitter
        capture_coffee_emitter.remove_powder(capture_coffee_emitter.remaining_g)
        CoffeeDelivery.order_coffee()
        CoffeeDelivery.force_arrival_for_test()
        CoffeeDelivery.pickup_time_left = 18.0
        var capture_coffee_box := builder._objects.get("coffee_delivery") as Node3D
        capture_coffee_box.reparent(camera, true)
        capture_coffee_box.position = Vector3(0.0, -0.28, -1.45)
        capture_coffee_box.rotation = Vector3.ZERO
        hud.call("_on_quest_updated", QuestManager.get_state())
        hud.call("_update_urgent_panel", CallManager.get_state())
    if show_map:
        var phone := get_tree().get_first_node_in_group("phone_locator")
        if phone != null:
            phone.set("active", true)
        var map_panel := hud.get("apartment_map") as Control
        if map_panel != null:
            map_panel.show()
    if show_urgent:
        var urgent_phone := get_tree().get_first_node_in_group("phone_locator")
        if urgent_phone != null:
            urgent_phone.set("active", true)
        CallManager.question_active = true
        CallManager.question_kind = &"payment"
        CallManager.answer_time_left = 7.4
        RitaDemands.assign_after_wake(&"clean_bathroom")
    if show_water:
        var capture_water := builder._objects.get("water") as Node3D
        var capture_kettle := builder._objects.get("kettle") as RigidBody3D
        if capture_water != null and capture_kettle != null:
            capture_kettle.held = false
            capture_kettle.freeze = true
            var capture_catch := capture_water.get_node("WaterCatchArea") as Area3D
            capture_kettle.global_position = capture_catch.global_position - Vector3(0.0, 0.29, 0.0)
            capture_kettle.global_rotation = Vector3.ZERO
            await get_tree().physics_frame
            await get_tree().physics_frame
            capture_water.call("_toggle_water")
            capture_water.call("_process_water", 4.2)
            hud.call("_update_appliance_progress")
            camera.global_position = camera_position
            camera.look_at(camera_target, Vector3.UP)
            camera.fov = 76.0
    if show_beer:
        var capture_beer := builder._objects.get("match_beer") as RigidBody3D
        if capture_beer != null:
            player.call("begin_drink_match_beer", capture_beer, 18.0, 13.0)
            player.call("_update_drink_animation", 0.825)
            player.call("_update_view_hands", 1.0)
    if show_task:
        var capture_task := builder._objects.get("rita_kitchen_dishes") as Node
        RitaDemands.assign_after_wake(&"wash_dishes")
        if capture_task != null:
            capture_task.call("_begin_task_minigame")
            capture_task.set("_task_progress", 46.0)
            capture_task.set("_task_marker", 57.0)
            capture_task.set("_task_green_center", 61.0)
            hud.call("_update_task_progress")
    if show_fridge:
        var capture_fridge_door := builder._objects.get("fridge_door") as Node
        if capture_fridge_door != null and not bool(capture_fridge_door.get("is_open")):
            capture_fridge_door.call("perform_interaction", player, 0)
            capture_fridge_door.set("rotation", Vector3(0.0, deg_to_rad(float(capture_fridge_door.get("open_angle_degrees"))), 0.0))
    if show_football_video:
        var capture_football_tv := builder._objects.get("television") as RigidBody3D
        if capture_football_tv != null:
            var capture_outlet := capture_football_tv.call("_nearest_outlet", 2.8) as Node3D
            capture_football_tv.call("connect_to_outlet", capture_outlet)
            capture_football_tv.call("_update_screen")
            camera.fov = 62.0
            for video_frame in range(18):
                await get_tree().process_frame
            var capture_video_player := capture_football_tv.find_child("FootballVideoPlayer", true, false) as VideoStreamPlayer
            if capture_video_player != null:
                print("FOOTBALL_VIDEO_STATE: playing=%s position=%.3f texture=%s" % [str(capture_video_player.is_playing()), capture_video_player.stream_position, str(capture_video_player.get_video_texture() != null)])
    if show_vacuum:
        var capture_vacuum := builder._objects.get("vacuum") as Node3D
        if capture_vacuum != null:
            capture_vacuum.global_position = Vector3(4.20, 0.12, -1.00)
            capture_vacuum.set("armed", true)
            capture_vacuum.set("active", true)
            capture_vacuum.call("_set_indicator", true)
            capture_vacuum.call("_cache_collision_exclusions")
            capture_vacuum.call("_start_vacuum_motion")
            await get_tree().create_timer(0.30).timeout
            var capture_vacuum_start := capture_vacuum.global_position
            for capture_step in range(14):
                capture_vacuum.call("_physics_process", 0.25)
            camera.global_position = capture_vacuum.global_position + Vector3(0.0, 0.95, 1.35)
            camera.look_at(capture_vacuum.global_position, Vector3.UP)
            print("VACUUM_CAPTURE_DISTANCE: %.2f" % capture_vacuum.global_position.distance_to(capture_vacuum_start))
            print("VACUUM_CAPTURE_POSITION: %s" % str(capture_vacuum.global_position))
    if show_washing_machine:
        var capture_washer := builder._objects.get("washing_machine") as Node3D
        if capture_washer != null:
            capture_washer.call("force_start_cycle")
            for washer_capture_step in range(28):
                capture_washer.call("_process", 0.25)
            camera.global_position = camera_position
            camera.look_at(capture_washer.global_position + Vector3(0.0, 0.12, 0.0), Vector3.UP)
            camera.fov = 68.0
            print("WASHING_MACHINE_CAPTURE active=%s position=%s" % [
                str(bool(capture_washer.get("active"))),
                str(capture_washer.global_position)
            ])
    if show_washing_machine_movable:
        var movable_washer := builder._objects.get("washing_machine") as RigidBody3D
        if movable_washer != null:
            movable_washer.call("force_start_cycle")
            movable_washer.call("calm_machine")
            movable_washer.set("_settling_clear_of_door", false)
            movable_washer.global_position = Vector3(1.25, 0.61, 4.72)
            movable_washer.freeze = true
            hud.call("set_prompt", movable_washer.call("get_prompt", player))
            camera.global_position = camera_position
            camera.look_at(camera_target, Vector3.UP)
            camera.fov = 68.0
    if show_movie:
        var capture_tv := builder._objects.get("television") as RigidBody3D
        RitaDemands.assign_after_wake(&"festival_cinema")
        if capture_tv != null:
            capture_tv.held = false
            capture_tv.freeze = true
            capture_tv.global_position = Vector3(-3.20, 1.15, 5.45)
            var movie_outlet := capture_tv.call("_nearest_outlet", 2.8) as Node3D
            capture_tv.call("connect_to_outlet", movie_outlet)
            RitaDemands.begin_festival_movie()
            capture_tv.set_meta("freeze_movie_progress", true)
            capture_tv.set("_movie_progress", 52.0)
            RitaDemands.set_festival_progress(52.0)
            capture_tv.call("_update_screen")
            hud.call("_update_task_progress")
            RunStats.run_active = false
    if not payment_capture.is_empty():
        var payment_room := builder._objects.get("payment_altar_room") as Node
        if payment_room != null and payment_capture != "closed":
            payment_room.call("force_revealed_for_capture")
        if payment_capture == "relic":
            var payment_interaction := builder._objects.get("payment_altar_interaction") as Node
            if payment_interaction != null:
                payment_interaction.call("perform_interaction", player, 0)
    if usability_capture == "phone":
        var usability_phone := builder._objects.get("phone") as HallwayPhone
        if usability_phone != null:
            usability_phone.place_at_anchor_index(1)
            usability_phone.activate_phone()
            usability_phone.call("_process", 0.25)
            hud.call("_update_urgent_panel", CallManager.get_state())
            print("PHONE_CAPTURE active=%s anchor=%s noise=%s" % [
                str(usability_phone.active),
                usability_phone.placement_anchor.name,
                String(NoiseManager.last_noise.get("source_id", ""))
            ])
    elif usability_capture == "spill":
        var spill_manager := builder._objects.get("spill_manager") as SpillManager
        var cleanup_mop := builder._objects.get("mop") as RigidBody3D
        var spill_position := Vector3(5.10, 0.02, -3.35)
        if spill_manager != null and cleanup_mop != null:
            spill_manager.spawn_spill_typed(spill_position, "water", 130.0)
            cleanup_mop.call("on_picked_up")
            player.set("held_item", cleanup_mop)
            for mop_pose_frame in range(12):
                player.call("_update_held_item", 1.0 / 60.0)
                player.call("_update_view_hands", 1.0 / 60.0)
            var cleanup_controller := player.get("spill_cleanup_controller") as SpillCleanupController
            cleanup_controller.call("_physics_process", 0.0)
            cleanup_controller.start_cleaning()
            for cleanup_capture_step in range(2):
                cleanup_controller.call("_physics_process", 0.25)
                player.call("_update_held_item", 0.25)
                player.call("_update_view_hands", 0.25)
            hud.call("set_prompt", cleanup_controller.get_prompt())
            hud.call("_on_quest_updated", QuestManager.get_state())
            hud.call("_update_kitchen_contamination")
            var cleanup_state := spill_manager.get_required_cleanup_state()
            print("SPILL_CLEANUP_CAPTURE remaining=%.1f cleaned=%.1f required=%s" % [
                float(cleanup_state.get("water_ml", 0.0)),
                RunStats.cleaned_water_ml,
                str(bool(cleanup_state.get("required", false)))
            ])
    elif usability_capture == "flood":
        var flood_manager := builder._objects.get("spill_manager") as SpillManager
        var flood_station := builder._objects.get("water") as Node3D
        var flood_mop := builder._objects.get("mop") as RigidBody3D
        if flood_manager != null and flood_station != null and flood_mop != null:
            flood_station.call("_trigger_kitchen_flood")
            for flood_capture_second in range(70):
                flood_station.call("_advance_apartment_flood", 1.0, flood_manager)
            flood_station.call("_sync_apartment_flood_visual", flood_manager.get_volume_by_type("water"))
            var apartment_water := builder._objects.get("apartment_flood_visual") as ApartmentFloodVisual
            if apartment_water != null:
                for flood_visual_step in range(36):
                    apartment_water.call("_process", 0.25)
            flood_mop.call("on_picked_up")
            player.set("held_item", flood_mop)
            for flood_pose_frame in range(18):
                player.call("_update_held_item", 1.0 / 60.0)
                player.call("_update_view_hands", 1.0 / 60.0)
            hud.call("_on_quest_updated", QuestManager.get_state())
            hud.call("_update_kitchen_contamination")
            print("APARTMENT_FLOOD_CAPTURE stage=%d water=%.1f" % [
                int(flood_station.get("_flood_damage_stage")),
                flood_manager.get_volume_by_type("water")
            ])
    elif usability_capture == "water_hud":
        var water_hud_mug := builder._objects.get("mug") as RigidBody3D
        var water_hud_kettle := builder._objects.get("kettle") as RigidBody3D
        var water_hud_contents := water_hud_mug.get_node("MugContentController") as MugContentController
        var water_hud_volume := water_hud_kettle.get_node("ContainerVolume") as ContainerVolume
        water_hud_contents.add_liquid(165.0, WATER_DEF, 95.0)
        water_hud_volume.add_liquid(300.0, WATER_DEF)
        water_hud_kettle.call("on_picked_up")
        player.set("held_item", water_hud_kettle)
        water_hud_mug.freeze = true
        water_hud_mug.global_position = camera.to_global(Vector3(-0.34, -0.62, -1.62))
        for water_pose_frame in range(18):
            player.call("_update_held_item", 1.0 / 60.0)
            player.call("_update_view_hands", 1.0 / 60.0)
        player.call("_enter_pour_mode")
        var water_hud_controller := player.get("pour_controller") as PourController
        water_hud_controller.tilt_angle = 52.0
        water_hud_controller.target_tilt = 52.0
        water_hud_controller.call("_set_feedback", "in_mug", 12.0)
        water_hud_controller.set_process(false)
        player.call("_update_held_item", 0.12)
        player.call("_update_view_hands", 0.12)
        water_hud_controller._stream.update_stream(
            water_hud_kettle.call("get_pour_origin_global_position"),
            water_hud_kettle.call("get_pour_direction_global"),
            12.0,
            0.016,
            1.0
        )
        hud.call("set_prompt", "E — НАЛИВАТЬ  •  ПКМ — СТАБИЛИЗИРОВАТЬ  •  ЛКМ — ПОСТАВИТЬ")
    elif usability_capture == "milk_hud":
        var milk_hud_mug := builder._objects.get("mug") as RigidBody3D
        var milk_hud_carton := builder._objects.get("milk_carton") as RigidBody3D
        var milk_hud_contents := milk_hud_mug.get_node("MugContentController") as MugContentController
        var milk_hud_volume := milk_hud_carton.get_node("ContainerVolume") as ContainerVolume
        milk_hud_contents.add_liquid(190.0, WATER_DEF, 92.0)
        milk_hud_contents.add_liquid(25.0, MILK_DEF, 8.0)
        milk_hud_volume.drain()
        milk_hud_volume.add_liquid(430.0, MILK_DEF)
        milk_hud_carton.visible = true
        milk_hud_carton.collision_layer = 2
        milk_hud_carton.collision_mask = 3
        milk_hud_carton.call("on_picked_up")
        player.set("held_item", milk_hud_carton)
        milk_hud_mug.freeze = true
        milk_hud_mug.global_position = camera.to_global(Vector3(-0.34, -0.62, -1.62))
        for milk_pose_frame in range(18):
            player.call("_update_held_item", 1.0 / 60.0)
            player.call("_update_view_hands", 1.0 / 60.0)
        player.call("_enter_pour_mode")
        var milk_hud_controller := player.get("pour_controller") as PourController
        milk_hud_controller.tilt_angle = 50.0
        milk_hud_controller.target_tilt = 50.0
        milk_hud_controller.spilled_ml = 8.0
        milk_hud_controller.call("_set_feedback", "miss", 9.0)
        milk_hud_controller.set_process(false)
        player.call("_update_held_item", 0.12)
        player.call("_update_view_hands", 0.12)
        milk_hud_controller._stream.update_stream(
            milk_hud_carton.call("get_pour_origin_global_position"),
            milk_hud_carton.call("get_pour_direction_global"),
            9.0,
            0.018,
            1.0
        )
        hud.call("set_prompt", "E — НАЛИВАТЬ  •  ПКМ — СТАБИЛИЗИРОВАТЬ  •  ЛКМ — ПОСТАВИТЬ")
    elif usability_capture == "vacuum":
        var usability_vacuum := builder._objects.get("vacuum") as Node3D
        var usability_anchor := (builder._objects.get("vacuum_station") as Node3D).get_node("VacuumSpawnAnchor") as Node3D
        if usability_vacuum != null and usability_anchor != null:
            usability_vacuum.global_position = usability_anchor.global_position
            usability_vacuum.set("active", true)
            usability_vacuum.set("armed", true)
            usability_vacuum.call("_cache_collision_exclusions")
            var vacuum_exit_start := usability_vacuum.global_position
            usability_vacuum.call("_start_vacuum_motion")
            for vacuum_exit_frame in range(4):
                usability_vacuum.call("_physics_process", 0.25)
            print("VACUUM_STATION_CAPTURE distance=%.2f blocked=%s" % [
                usability_vacuum.global_position.distance_to(vacuum_exit_start),
                str(bool(usability_vacuum.get("_station_blocked")))
            ])
    elif usability_capture == "vacuum_blocked":
        var blocked_vacuum := builder._objects.get("vacuum") as Node3D
        var blocked_anchor := (builder._objects.get("vacuum_station") as Node3D).get_node("VacuumSpawnAnchor") as Node3D
        if blocked_vacuum != null and blocked_anchor != null:
            var exit_blocker := builder.call(
                "_loose_box",
                "VacuumExitBlocker",
                "КОРОБКА ПЕРЕД ПЫЛЕСОСОМ",
                blocked_anchor.global_position + Vector3.BACK * 0.42,
                Vector3(0.38, 0.32, 0.48),
                "fabric_rust",
                2.4
            ) as RigidBody3D
            exit_blocker.freeze = true
            await get_tree().physics_frame
            blocked_vacuum.global_position = blocked_anchor.global_position
            blocked_vacuum.set("armed", true)
            blocked_vacuum.set("active", true)
            blocked_vacuum.call("_cache_collision_exclusions")
            blocked_vacuum.call("_start_vacuum_motion")
            for forced_exit_frame in range(4):
                blocked_vacuum.call("_physics_process", 0.25)
            hud.call("show_message", "РОБОТ-ПЫЛЕСОС ПРОТАРАНИЛ ВЫЕЗД И УЕХАЛ")
            print("VACUUM_BLOCKED_CAPTURE active=%s blocked=%s" % [
                str(bool(blocked_vacuum.get("active"))),
                str(bool(blocked_vacuum.get("_station_blocked")))
            ])
    if show_overboil:
        var capture_kettle := builder._objects.get("kettle") as RigidBody3D
        var capture_base := builder._objects.get("kettle_base") as Node3D
        if capture_kettle != null and capture_base != null:
            capture_kettle.held = false
            capture_kettle.freeze = true
            capture_kettle.global_position = capture_base.global_position + Vector3(0.0, 0.31, 0.0)
            capture_kettle.set_meta("filled", true)
            capture_kettle.set_meta("heat", 1.0)
            var capture_boil_volume := capture_kettle.get_node("ContainerVolume") as ContainerVolume
            var capture_boil_state := capture_kettle.get_node("KettleStateMachine") as KettleStateMachine
            capture_boil_volume.add_liquid(300.0, WATER_DEF)
            capture_boil_state.state = KettleStateMachine.KettleState.BOILED
            capture_boil_state.temperature_c = 100.0
            QuestManager.kettle_filled = true
            QuestManager.water_boiled = true
            capture_base.set("_kettle_ref", capture_kettle)
            capture_base.set("_kettle_powered", true)
            capture_base.set("_overboil_elapsed", 7.0)
            capture_base.call("_process_kettle", 37.0)
            capture_base.call("_set_steam_visible", true)
            capture_base.call("_animate_steam")
            hud.call("_update_appliance_progress")
            capture_base.reparent(camera, true)
            capture_kettle.reparent(camera, true)
            capture_base.position = Vector3(0.0, -0.48, -1.55)
            capture_base.rotation = Vector3.ZERO
            capture_kettle.position = Vector3(0.0, -0.14, -1.55)
            capture_kettle.rotation = Vector3.ZERO
            camera.fov = 66.0
    if show_coffee_result:
        var preview_result := {
            "rank": "A — МЕНЕДЖЕР НА НОСОЧКАХ",
            "time": 184.7,
            "balance": 1280.0,
            "debt": 0.0,
            "challenge_score": 7420,
            "peak_wake": 48.0,
            "loud_actions": 3,
            "dropped_items": 1,
            "answered_calls": 4,
            "missed_calls": 0,
            "rita_awake": false,
            "payments_received": 2,
            "missed_payments": 0,
            "cash_found": 310.0,
            "prevented_noise": 46.0,
            "total_heard_noise": 31.0
        }
        hud.call("_on_run_finished", preview_result)
        var preview_board := [
            {"name": "ТИХИЙ ДЕНИС", "time": 152.4, "balance": 1640.0, "score": 8240},
            {"name": "КОФЕМАН", "time": 184.7, "balance": 1280.0, "score": 7420},
            {"name": "НЕ РАЗБУДИЛ", "time": 213.2, "balance": 430.0, "score": 6810},
            {"name": "THE ПЛАТЁЖ", "time": 248.9, "balance": -720.0, "score": 4920}
        ]
        hud.get("result_leaderboard_label").text = hud.call("_format_leaderboard", preview_board)
        hud.get("player_name_edit").text = "ДЕНИС"
    if show_coffee_pour:
        var pour_mug := builder._objects.get("mug") as RigidBody3D
        var pour_kettle := builder._objects.get("kettle") as RigidBody3D
        var pour_action := builder._objects.get("water_pour_zone") as Node3D
        if pour_mug != null and pour_kettle != null and pour_action != null:
            QuestManager.register_mug()
            QuestManager.register_coffee()
            QuestManager.register_milk()
            QuestManager.kettle_filled = true
            QuestManager.water_boiled = true
            pour_mug.held = false
            pour_mug.freeze = true
            pour_mug.global_position = pour_action.global_position + Vector3(0.0, 0.18, 0.0)
            pour_kettle.held = false
            pour_kettle.freeze = true
            pour_kettle.global_position = pour_mug.global_position + Vector3(-0.55, 0.64, 0.0)
            pour_kettle.global_rotation.z = deg_to_rad(-68.0)
            var visible_stream := pour_action.get_node_or_null("PourStream") as Node3D
            if visible_stream != null:
                visible_stream.visible = true
                pour_action.call("_place_pour_stream", pour_kettle, pour_mug)
            pour_action.set("_brew_active", true)
            pour_action.set("_brew_progress", 58.0)
            hud.call("_on_quest_updated", QuestManager.get_state())
            hud.call("_update_task_progress")
    if show_aaa_new_game:
        hud.call("_on_quest_updated", QuestManager.get_state())
        assert(QuestManager.get_objective() == "НАЙТИ КРУЖКУ")
        var new_game_kettle := builder._objects.get("kettle") as RigidBody3D
        var new_game_volume := new_game_kettle.get_node("ContainerVolume") as ContainerVolume
        var new_game_state := new_game_kettle.get_node("KettleStateMachine") as KettleStateMachine
        assert(new_game_volume.is_empty() and new_game_state.state == KettleStateMachine.KettleState.EMPTY)
    if show_aaa_kettle_hands or show_aaa_kettle_pour:
        var held_kettle := builder._objects.get("kettle") as RigidBody3D
        var held_volume := held_kettle.get_node("ContainerVolume") as ContainerVolume
        var held_state := held_kettle.get_node("KettleStateMachine") as KettleStateMachine
        if show_aaa_kettle_pour:
            held_volume.add_liquid(300.0, load("res://resources/liquids/water.tres"))
            held_state.state = KettleStateMachine.KettleState.HELD
            held_state.temperature_c = 95.0
        held_kettle.call("on_picked_up")
        player.set("held_item", held_kettle)
        for pose_frame in range(24):
            player.call("_update_held_item", 1.0 / 60.0)
            player.call("_update_view_hands", 1.0 / 60.0)
        if show_aaa_kettle_pour:
            var capture_mug := builder._objects.get("mug") as RigidBody3D
            capture_mug.freeze = true
            capture_mug.global_position = camera.to_global(Vector3(0.42, -0.62, -1.55))
            player.call("_enter_pour_mode")
            hud.call("set_prompt", "E — НАЛИВАТЬ  •  ПКМ — СТАБИЛИЗИРОВАТЬ  •  ЛКМ — ПОСТАВИТЬ")
            var capture_controller := player.get("pour_controller") as PourController
            capture_controller.tilt_angle = 50.0
            capture_controller.target_tilt = 50.0
            for pour_frame in range(18):
                player.call("_update_held_item", 1.0 / 60.0)
                player.call("_update_view_hands", 1.0 / 60.0)
            var capture_origin: Vector3 = held_kettle.call("get_pour_origin_global_position")
            capture_mug.reparent(camera, true)
            capture_mug.position = Vector3(0.02, -0.43, -1.42)
            capture_mug.rotation = Vector3.ZERO
            var capture_receiver := capture_mug.find_child("OpeningReceiverArea", true, false) as Node3D
            var capture_target := capture_receiver.global_position
            var capture_direction: Vector3 = capture_controller.call("_ballistic_direction_to", capture_origin, capture_target, 1.0)
            capture_controller.set_process(false)
            capture_controller._stream.update_stream(
                capture_origin,
                capture_direction,
                48.0,
                0.018,
                1.0
            )
            capture_controller.call("_update_prediction")
    if show_aaa_kitchen_open:
        var moving_keys := [
            "lower_door_right_a", "lower_door_right_b",
            "sink_door_left", "sink_door_right", "upper_left_door",
            "mug_cabinet", "drawer", "fridge_lower_door",
            "fridge_upper_door", "dishwasher_door"
        ]
        for moving_key in moving_keys:
            var moving_part := builder._objects.get(moving_key) as Node
            if moving_part != null and moving_part.has_method("perform_interaction"):
                moving_part.call("perform_interaction", player, 0)
        for open_frame in range(40):
            await get_tree().process_frame
        # Door noises can briefly drive the shared camera-shake service, so
        # stage the evidence view only after all moving parts have settled.
        camera.global_position = Vector3(2.55, 2.28, -1.32)
        camera.look_at(Vector3(5.30, 0.98, -5.12), Vector3.UP)
        camera.fov = 78.0
    if show_held_item and not show_aaa_kettle_hands and not show_aaa_kettle_pour:
        var mug := builder._objects.get("mug") as RigidBody3D
        if mug != null:
            mug.call("on_picked_up")
            player.set("held_item", mug)
            player.call("_update_held_item", 1.0)
            player.call("_update_view_hands", 1.0)
    if show_water:
        camera.global_position = camera_position
        camera.look_at(camera_target, Vector3.UP)
        camera.fov = 76.0
    if not coffee_anywhere_capture.is_empty():
        var anywhere_mug := builder._objects.get("mug") as RigidBody3D
        var anywhere_jar := builder._objects.get("coffee") as RigidBody3D
        var anywhere_content := anywhere_mug.get_node("MugContentController") as MugContentController
        var anywhere_positions := {
            "kitchen": Vector3(5.10, 1.20, -5.10),
            "dining": Vector3(5.35, 0.95, 1.26),
            "desk": Vector3(-5.20, 0.92, -5.10),
            "hall": Vector3(-1.30, 1.12, 5.05),
            "floor": Vector3(-3.80, 0.18, 1.25),
        }
        anywhere_mug.reparent(self, true)
        anywhere_mug.freeze = true
        anywhere_mug.global_position = anywhere_positions[coffee_anywhere_capture]
        anywhere_mug.global_rotation = Vector3.ZERO
        anywhere_content.empty()
        anywhere_content.add_powder(3.5)
        anywhere_content.add_liquid(200.0, WATER_DEF, 95.0)
        anywhere_jar.reparent(self, true)
        anywhere_jar.freeze = true
        var jar_offset := Vector3(0.35, 0.18, 0.05)
        if coffee_anywhere_capture == "hall":
            jar_offset = Vector3(0.0, 0.18, 0.38)
        elif coffee_anywhere_capture == "dining":
            jar_offset = Vector3(0.0, 0.18, -0.38)
        anywhere_jar.global_position = anywhere_mug.global_position + jar_offset
        anywhere_jar.global_rotation_degrees = Vector3(0.0, 0.0, -18.0)
        QuestManager.register_mug()
        QuestManager.register_coffee()
        anywhere_jar.call("on_picked_up")
        player.set("held_item", anywhere_jar)
        player.call("_enter_pour_mode")
        var anywhere_pour := player.get("pour_controller") as PourController
        if anywhere_pour != null:
            anywhere_pour.set_process(false)
            anywhere_pour.last_feedback_state = "in_mug"
            anywhere_pour.current_flow_rate_ml_s = 4.2
        hud.call("_on_quest_updated", QuestManager.get_state())
    if not cat_capture.is_empty():
        var capture_cat := builder._objects.get("rita_cat") as RitaCat
        if capture_cat != null:
            capture_cat.set_physics_process(false)
            if cat_capture == "idle":
                capture_cat.global_position = Vector3(-5.62, 0.12, 1.52)
                capture_cat.set_intention(CatIntentionController.Intention.REST)
                capture_cat.set_body_state(CatBodyController.BodyState.SIT)
                capture_cat.face_world_point(camera_position)
            elif cat_capture == "spoon":
                var capture_spoon := builder._objects.get("spoon") as RigidBody3D
                capture_spoon.freeze = true
                capture_spoon.global_position = Vector3(5.62, 1.16, -5.68)
                capture_cat.global_position = Vector3(5.15, 1.16, -5.55)
                capture_cat.story_director.force_story(&"SPOON_STORY")
                capture_cat.story_director.active_story.advance(12.1)
            elif cat_capture == "laptop":
                var capture_laptop := builder._objects.get("laptop") as Node3D
                capture_cat.global_position = capture_laptop.global_position + Vector3(0.32, 0.0, 0.20)
                capture_cat.story_director.force_story(&"LAPTOP_STORY")
                capture_cat.story_director.active_story.advance(12.1)
                capture_cat.story_director.active_story.advance(4.2)
                await get_tree().create_timer(0.72).timeout
            elif cat_capture == "flood":
                var cat_flood_manager := builder._objects.get("spill_manager") as SpillManager
                var cat_flood_station := builder._objects.get("water") as Node3D
                var cat_flood_mop := builder._objects.get("mop") as RigidBody3D
                var cat_flood_visual := builder._objects.get("apartment_flood_visual") as ApartmentFloodVisual
                if cat_flood_manager != null and cat_flood_station != null and cat_flood_mop != null and cat_flood_visual != null:
                    cat_flood_station.call("_trigger_kitchen_flood")
                    for cat_flood_second in range(70):
                        cat_flood_station.call("_advance_apartment_flood", 1.0, cat_flood_manager)
                    cat_flood_station.call("_sync_apartment_flood_visual", cat_flood_manager.get_volume_by_type("water"))
                    for cat_flood_visual_step in range(36):
                        cat_flood_visual.call("_process", 0.25)
                    cat_flood_mop.freeze = true
                    capture_cat.global_position = Vector3(2.92, cat_flood_visual.current_depth + 0.08, 5.55)
                    capture_cat.story_director.force_story(&"FLOOD_ESCAPE_STORY")
                    if capture_cat.story_director.active_story != null:
                        capture_cat.story_director.active_story.advance(12.1)
                    capture_cat.face_world_point(cat_flood_mop.global_position)
                    hud.call("_on_quest_updated", QuestManager.get_state())
                    hud.call("_update_kitchen_contamination")
            camera.global_position = camera_position
            camera.look_at(camera_target, Vector3.UP)
            camera.fov = 58.0
    if not show_aaa_kettle_pour:
        await get_tree().process_frame
    if show_environment_capture:
        camera.global_position = camera_position
        camera.look_at(camera_target, Vector3.UP)
        camera.fov = 76.0
    if not usability_capture.is_empty():
        camera.global_position = camera_position
        camera.look_at(camera_target, Vector3.UP)
        camera.fov = 72.0
        for usability_frame in range(3):
            await get_tree().process_frame
    if show_vacuum:
        var final_vacuum := builder._objects.get("vacuum") as Node3D
        if final_vacuum != null:
            camera.global_position = final_vacuum.global_position + Vector3(0.0, 0.72, 1.10)
            camera.look_at(final_vacuum.global_position + Vector3(0.0, 0.04, 0.0), Vector3.UP)
            camera.fov = 70.0
    if show_movie:
        for movie_render_frame in range(2):
            await get_tree().process_frame
            _stage_movie_capture_progress()
            await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var path := ProjectSettings.globalize_path("res://" + file_name)
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var result := image.save_png(path)
    print("ROOM_CAPTURE_SAVED: %s (%s)" % [path, error_string(result)])
    get_tree().quit(0 if result == OK else 7)

func _stage_movie_capture_progress() -> void:
    var capture_tv := builder._objects.get("television") as Node
    if capture_tv == null:
        return
    capture_tv.set("_movie_progress", 52.0)
    RitaDemands.set_festival_progress(52.0)
    capture_tv.call("_update_screen")
    hud.call("_update_task_progress")
    print("MOVIE_CAPTURE_PROGRESS: demand=%.1f hud=%.1f" % [RitaDemands.get_festival_progress(), float(hud.get("task_progress_bar").value)])

func _benchmark_environment_if_requested() -> void:
    if "--benchmark-environment" not in OS.get_cmdline_user_args():
        return
    hud.visible = true
    for warmup_frame in range(90):
        await get_tree().process_frame
    var sample_frames := 300
    var started_us := Time.get_ticks_usec()
    var previous_us := started_us
    var longest_frame_us := 0
    for sample_frame in range(sample_frames):
        await get_tree().process_frame
        var current_us := Time.get_ticks_usec()
        longest_frame_us = maxi(longest_frame_us, current_us - previous_us)
        previous_us = current_us
    var elapsed_seconds := float(Time.get_ticks_usec() - started_us) / 1000000.0
    var average_fps := float(sample_frames) / maxf(elapsed_seconds, 0.001)
    print(
        "ENVIRONMENT_BENCHMARK average_fps=%.2f longest_frame_ms=%.2f imported_props=%d environment_details=%d" % [
            average_fps,
            float(longest_frame_us) / 1000.0,
            get_tree().get_nodes_in_group("environment_imported_prop").size(),
            get_tree().get_nodes_in_group("environment_detail").size()
        ]
    )
    get_tree().quit(0)

func _ensure_input_actions() -> void:
    _ensure_key_action(&"move_forward", KEY_W)
    _ensure_key_action(&"move_back", KEY_S)
    _ensure_key_action(&"move_left", KEY_A)
    _ensure_key_action(&"move_right", KEY_D)
    _ensure_key_action(&"sprint", KEY_SHIFT)
    _ensure_key_action(&"crouch", KEY_CTRL)
    _ensure_key_action(&"tiptoe", KEY_ALT)
    _ensure_key_action(&"interact", KEY_E)
    _ensure_key_action(&"dev_overlay", KEY_F3)
    _ensure_key_action(&"map", KEY_M)
    _ensure_key_action(&"leaderboard", KEY_L)
    _ensure_key_action(&"restart_run", KEY_R)
    _ensure_key_action(&"rotate_item", KEY_R)
    _ensure_mouse_action(&"pickup", MOUSE_BUTTON_LEFT)
    _ensure_mouse_action(&"place", MOUSE_BUTTON_RIGHT)
    _ensure_key_action(&"pour_action", KEY_E)
    # Фоторежим
    _ensure_key_action(&"photo_mode_toggle", KEY_P)
    _ensure_key_action(&"photo_mode_exit", KEY_ESCAPE)
    _ensure_key_action(&"photo_mode_screenshot", KEY_ENTER)
    _ensure_key_action(&"photo_mode_up", KEY_SPACE)
    _ensure_key_action(&"photo_mode_down", KEY_C)
    _ensure_key_action(&"photo_mode_speed_up", KEY_SHIFT)
    _ensure_key_action(&"photo_mode_speed_down", KEY_CTRL)

func _ensure_key_action(action: StringName, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for existing in InputMap.action_get_events(action):
        if existing is InputEventKey and existing.physical_keycode == keycode:
            return
    var event = InputEventKey.new()
    event.physical_keycode = keycode
    InputMap.action_add_event(action, event)

func _ensure_mouse_action(action: StringName, button: MouseButton) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for existing in InputMap.action_get_events(action):
        if existing is InputEventMouseButton and existing.button_index == button:
            return
    var event = InputEventMouseButton.new()
    event.button_index = button
    InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart_run") and not RunStats.run_active:
        get_tree().reload_current_scene()
    
    # Обработка фоторежима
    if event.is_action_pressed("photo_mode_toggle"):
        if PhotoMode.active:
            PhotoMode.exit_photo_mode()
        else:
            PhotoMode.enter_photo_mode()
    
    # Скриншот в фоторежиме
    if PhotoMode.active and event.is_action_pressed("photo_mode_screenshot"):
        PhotoMode.take_screenshot()

func _reset_systems() -> void:
    NoiseManager.reset()
    RunStats.reset_run()
    RitaSleep.reset()
    RitaDemands.reset()
    MilkDelivery.reset()
    CoffeeDelivery.reset()
    QuestManager.reset()

func _run_optional_tests() -> void:
    if "--run-foundation-tests" not in OS.get_cmdline_user_args():
        return
    await get_tree().process_frame
    var required_groups: Array[StringName] = [&"mug", &"coffee_jar", &"kettle", &"towel", &"mop"]
    for group_name in required_groups:
        assert(not get_tree().get_nodes_in_group(String(group_name)).is_empty(), "Missing required group: %s" % String(group_name))
    assert(get_tree().get_first_node_in_group("player") != null, "Player missing")
    var payment_room := builder._objects.get("payment_altar_room") as Node3D
    var payment_door := builder._objects.get("payment_altar_door") as Node
    var payment_altar := builder._objects.get("payment_altar") as Node3D
    var payment_interaction := builder._objects.get("payment_altar_interaction") as Node
    assert(payment_room != null and payment_room.scene_file_path.ends_with("payment_altar_room.tscn"), "Payment altar is not an instanced room scene")
    assert(payment_door != null and payment_door.has_method("perform_interaction"), "Payment altar secret door is missing")
    assert(payment_altar != null and payment_altar.find_children("Candle*", "MeshInstance3D", true, false).size() >= 13, "Payment altar has no layered candle composition")
    assert(payment_room.find_child("InvestigationWall", true, false) != null, "Payment altar investigation wall is missing")
    assert(payment_room.find_child("WaitingCalendar", true, false) != null, "Payment altar waiting calendar is missing")
    assert(payment_room.find_child("PaymentWaitingCircle", true, false) != null, "Payment altar floor symbol is missing")
    assert(payment_room.find_child("PaymentAltarAudioZone", true, false) != null, "Payment altar audio zone is missing")
    payment_door.call("perform_interaction", player, 0)
    assert(bool(payment_door.get("is_open")), "Payment altar secret door does not open")
    payment_door.call("perform_interaction", player, 0)
    assert(not bool(payment_door.get("is_open")), "Payment altar secret door does not close")
    var altar_bows_before := int(RunStats.get("payment_altar_bows"))
    var altar_result := String(payment_interaction.call("perform_interaction", player, 0))
    assert(not altar_result.is_empty() and int(RunStats.get("payment_altar_bows")) == altar_bows_before + 1, "Payment altar interaction does not fire")
    RunStats.set("payment_altar_bows", altar_bows_before)
    var route_kettle := builder._objects.get("kettle") as RigidBody3D
    var route_kettle_base := builder._objects.get("kettle_base") as Node3D
    var route_base_ring := route_kettle_base.get_node("Ring") as MeshInstance3D
    var route_base_ring_mesh := route_base_ring.mesh as CylinderMesh
    var kettle_collision_bottom := route_kettle.global_position.y - 0.26
    var base_ring_top := route_base_ring.global_position.y + route_base_ring_mesh.height * 0.5
    assert(absf(kettle_collision_bottom - base_ring_top) < 0.005, "Kettle starts floating above or sunk into its base")
    assert(route_kettle.get_node_or_null("KettleFoot") is MeshInstance3D, "Kettle has no flat visual contact foot")
    var route_title := hud.get("coffee_route_title") as Label
    var route_action := hud.get("coffee_label") as Label
    var route_progress := hud.get("coffee_progress_bar") as ProgressBar
    var start_intro := hud.get("intro_panel") as Panel
    var start_intro_labels := start_intro.find_children("*", "Label", true, false) if start_intro != null else []
    assert(start_intro != null and start_intro.size.y <= 140.0, "Start prompt regressed into a full-screen instruction sheet")
    assert(start_intro_labels.size() == 1 and (start_intro_labels[0] as Label).text == "ДЕНИС НАЛЕЙ КОФЕ.", "Start prompt must contain only the requested coffee instruction")
    assert(route_title != null and route_title.text.contains("ЭТАП") and route_title.text.contains("КРУЖКА"), "Coffee route HUD does not name the current stage")
    assert(route_action != null and route_action.text.contains("СЕЙЧАС:") and route_action.text.contains("КРУЖКУ"), "Coffee route HUD does not explain the current action")
    assert(route_progress != null and route_progress.value == 0.0, "Coffee route HUD starts with false progress")
    QuestManager.register_mug()
    assert(route_title.text.contains("ЭТАП 2/10") and route_title.text.contains("КОФЕ"), "Coffee route HUD does not advance to the next named stage")
    assert(route_action.text.contains("ЗАКАЗАТЬ КОФЕ") and absf(route_progress.value - 10.0) < 0.1, "Coffee route HUD does not explain or measure stage two")
    QuestManager.reset()
    var route_kettle_volume := route_kettle.get_node("ContainerVolume") as ContainerVolume
    var route_kettle_state := route_kettle.get_node("KettleStateMachine") as KettleStateMachine
    assert(route_kettle_volume.is_empty() and absf(route_kettle_state.temperature_c - 20.0) < 0.01 and route_kettle_state.state == KettleStateMachine.KettleState.EMPTY, "New game kettle must be empty at room temperature")
    assert(not QuestManager.kettle_filled and not QuestManager.water_boiled, "New game starts with a pre-filled or boiled kettle")
    assert(route_kettle.get_node_or_null("KettleOpeningArea") is Area3D, "Kettle faucet opening is missing")
    var route_water := builder._objects.get("water") as Node3D
    var route_water_catch := route_water.get_node_or_null("WaterCatchArea") as Area3D
    assert(route_water_catch != null and route_water_catch.collision_mask == 16, "Faucet has no physical kettle-opening overlap volume")
    var route_opening := route_kettle.get_node("KettleOpeningArea") as Area3D
    var kettle_start_transform := route_kettle.global_transform
    var kettle_was_frozen := route_kettle.freeze
    route_kettle.freeze = true
    route_water.call("_toggle_water")
    assert(bool(route_water.get("water_on")), "Faucet refuses to run without the player aiming at a kettle")
    await get_tree().physics_frame
    route_water.call("_process_water", 0.25)
    assert(route_kettle_volume.is_empty(), "Faucet fills a kettle without a physical stream overlap")
    route_kettle.global_position = route_water_catch.global_position - Vector3(0.0, 0.29, 0.0)
    route_kettle.global_rotation = Vector3.ZERO
    await get_tree().physics_frame
    await get_tree().physics_frame
    assert(route_water_catch.get_overlapping_areas().has(route_opening), "Kettle opening does not physically enter the faucet stream")
    route_water.call("_process_water", 0.5)
    assert(route_kettle_volume.current_ml > 20.0, "Physical faucet overlap does not fill the kettle")
    route_kettle.global_position += Vector3(0.8, 0.0, 0.0)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var volume_after_leaving_stream := route_kettle_volume.current_ml
    route_water.call("_process_water", 0.5)
    assert(is_equal_approx(route_kettle_volume.current_ml, volume_after_leaving_stream), "Kettle keeps filling after leaving the physical stream")
    route_water.call("_toggle_water")
    route_kettle_volume.drain()
    route_kettle_state.state = KettleStateMachine.KettleState.EMPTY
    route_kettle.global_transform = kettle_start_transform
    route_kettle.freeze = kettle_was_frozen
    assert(InputMap.has_action("pour_action"), "Dedicated E pour action is missing")
    assert(route_kettle.get_node_or_null("GripPoint") != null and route_kettle.get_node_or_null("PourGripPoint") != null and route_kettle.get_node_or_null("Spout/PourOrigin") != null and route_kettle.get_node_or_null("Spout/PourDirection") != null, "Kettle pour anchors are incomplete")
    var coffee_route_mug := builder._objects.get("mug") as RigidBody3D
    assert(coffee_route_mug.get_node_or_null("MugOpening/OpeningReceiverArea") is LiquidReceiver and coffee_route_mug.get_node_or_null("MugOpening/OpeningMarker") != null and coffee_route_mug.get_node_or_null("MugOpening/OpeningNormal") != null and coffee_route_mug.get_node_or_null("MugContentController") is MugContentController and coffee_route_mug.get_node_or_null("LiquidSurface") is LiquidSurface, "Runtime mug liquid nodes are incomplete")
    var denis_mug_print := coffee_route_mug.get_node_or_null("DenisMugLisaPrint") as MeshInstance3D
    var denis_print_mesh := denis_mug_print.mesh as QuadMesh if denis_mug_print != null else null
    var denis_print_material := denis_print_mesh.material as StandardMaterial3D if denis_print_mesh != null else null
    assert(denis_print_material != null and denis_print_material.albedo_texture != null, "Denis mug has no Lisa print texture")
    var route_milk := builder._objects.get("milk_carton") as RigidBody3D
    assert(route_milk.get_node_or_null("ContainerVolume") is ContainerVolume and route_milk.get_node_or_null("PourOrigin") != null and route_milk.get_node_or_null("PourDirection") != null and route_milk.get_node_or_null("PourGripPoint") != null, "Milk does not reuse the physical pour anchors")
    var route_spoon := builder._objects.get("spoon") as RigidBody3D
    assert(route_spoon != null and route_spoon.get_node_or_null("SpoonTip") != null and route_spoon.get_node_or_null("StirController") is StirController, "Physical teaspoon is incomplete")
    var cleanup_mop := builder._objects.get("mop") as RigidBody3D
    var cleanup_absorption := cleanup_mop.get_node_or_null("AbsorptionController") as AbsorptionController
    assert(cleanup_mop != null and cleanup_mop.scene_file_path.ends_with("bathroom_mop.tscn"), "Bathroom mop is not an instanced physical prop")
    assert(cleanup_absorption != null and cleanup_absorption.absorption_capacity_ml >= 50000.0, "Bathroom mop can saturate and softlock a long flood")
    var cleanup_manager := builder._objects.get("spill_manager") as SpillManager
    var spilled_stat_before_cleanup := RunStats.pour_water_spilled_ml
    var cleaned_stat_before := RunStats.cleaned_water_ml
    cleanup_manager.spawn_spill_typed(Vector3(5.05, 0.02, -3.10), "water", 110.0)
    var cleanup_cluster := get_tree().get_nodes_in_group("spills").back() as SpillCluster
    var cleanup_radius_before := cleanup_cluster.radius
    var contamination_before := float(cleanup_manager.get_required_cleanup_state().get("contamination_percent", 0.0))
    assert(cleanup_manager.has_required_cleanup() and QuestManager.spill_cleanup_required, "A 110 ml water spill does not create the mandatory cleanup objective")
    var kitchen_towel := builder._objects.get("towel") as RigidBody3D
    var towel_cleanup_probe := player.get("spill_cleanup_controller") as SpillCleanupController
    player.set("held_item", kitchen_towel)
    towel_cleanup_probe.target = cleanup_cluster
    towel_cleanup_probe.start_cleaning()
    assert(not towel_cleanup_probe.cleaning, "Kitchen towel still cleans the flood; the bathroom mop is not required")
    player.set("held_item", null)
    hud.call("_update_kitchen_contamination")
    assert(bool((hud.get("contamination_panel") as Panel).visible) and contamination_before > 30.0, "Kitchen contamination gauge is not visible for a water spill")
    var mop_absorbed := cleanup_absorption.absorb("water", 35.0)
    cleanup_manager.absorb_cluster(cleanup_cluster, mop_absorbed)
    assert(cleanup_cluster.volume_ml > 70.0 and cleanup_cluster.volume_ml < 110.0 and cleanup_cluster.radius < cleanup_radius_before, "Spill does not shrink gradually while wiping")
    var contamination_after := float(cleanup_manager.get_required_cleanup_state().get("contamination_percent", 0.0))
    assert(contamination_after < contamination_before, "Kitchen contamination gauge does not decrease while wiping")
    assert(is_equal_approx(RunStats.pour_water_spilled_ml, spilled_stat_before_cleanup) and RunStats.cleaned_water_ml > cleaned_stat_before, "Cleanup corrupts spilled statistics or does not record cleaned_ml")
    var mop_absorbed_rest := cleanup_absorption.absorb("water", cleanup_cluster.volume_ml + 1.0)
    cleanup_manager.absorb_cluster(cleanup_cluster, mop_absorbed_rest)
    if is_instance_valid(cleanup_cluster) and not cleanup_cluster.is_empty():
        cleanup_manager.absorb_cluster(cleanup_cluster, cleanup_cluster.volume_ml)
    assert(not cleanup_manager.has_required_cleanup() and not QuestManager.spill_cleanup_required, "Cleanup objective remains after the large water spill is removed")
    cleanup_manager.spawn_spill_typed(Vector3(5.20, 0.02, -3.10), "milk", 35.0)
    var milk_cleanup_cluster := get_tree().get_nodes_in_group("spills").back() as SpillCluster
    assert(cleanup_manager.has_required_cleanup(), "A 35 ml milk spill does not use the lower mandatory threshold")
    cleanup_manager.absorb_cluster(milk_cleanup_cluster, milk_cleanup_cluster.volume_ml)
    assert(not cleanup_manager.has_required_cleanup(), "Milk spill cannot be cleaned")
    var flood_station := builder._objects.get("water") as Node3D
    flood_station.call("_trigger_kitchen_flood")
    assert(bool(flood_station.get("kitchen_flooded")) and cleanup_manager.get_volume_by_type("water") >= 284.0, "Kitchen flood is still only a decorative overlay")
    cleanup_absorption.absorbed_ml = 0.0
    cleanup_absorption.wetness = 0.0
    cleanup_mop.call("on_picked_up")
    player.set("held_item", cleanup_mop)
    var flood_cleanup := player.get("spill_cleanup_controller") as SpillCleanupController
    var first_flood_spill := cleanup_manager.find_nearest_cleanable(flood_station.global_position, 3.0)
    player.global_position = Vector3(first_flood_spill.global_position.x, 0.08, first_flood_spill.global_position.z + 0.55)
    flood_cleanup.call("_physics_process", 0.0)
    flood_cleanup.start_cleaning()
    var mop_moved_to_floor := false
    for _wipe_step in range(60):
        flood_cleanup.call("_physics_process", 0.25)
        player.call("_update_held_item", 0.25)
        if cleanup_mop.global_position.y < 0.20:
            mop_moved_to_floor = true
    flood_station.call("_process_water", 0.0)
    assert(mop_moved_to_floor, "Held mop never makes visible floor contact while scrubbing")
    assert(cleanup_manager.get_volume_by_type("water") <= 1.0 and not bool(flood_station.get("kitchen_flooded")), "Physical wiping does not clear the kitchen flood")
    assert(not cleanup_manager.has_required_cleanup() and not QuestManager.spill_cleanup_required, "Kitchen is declared clean before all visible flood residue is removed")
    flood_cleanup.stop_cleaning()
    player.set("held_item", null)
    var flood_visual := builder._objects.get("apartment_flood_visual") as ApartmentFloodVisual
    assert(flood_visual != null, "Apartment-wide flood surface is missing")
    flood_visual.set_flood_state(true, 3, 70.0, 4000.0, true)
    for _flood_visual_step in range(24):
        flood_visual.call("_process", 0.25)
    assert(flood_visual.get_water_depth_at(Vector3(4.8, 0.0, -2.0)) >= 0.62, "Final kitchen flood is not knee-deep")
    assert(flood_visual.get_water_depth_at(Vector3(-4.8, 0.0, 4.2)) >= 0.62, "Final flood does not cover the bedroom")
    assert(flood_visual.get_water_depth_at(Vector3(0.0, 0.0, 3.8)) >= 0.62, "Final flood does not cover the corridor")
    flood_visual.set_flood_state(false, 0, 0.0, 0.0, false)
    for _flood_drain_step in range(24):
        flood_visual.call("_process", 0.25)
    assert(hud.get("pouring_hud") is PouringHUD, "Compact PouringHUD component is not present in the real HUD")
    route_kettle_volume.add_liquid(300.0, load("res://resources/liquids/water.tres"))
    route_kettle_state.state = KettleStateMachine.KettleState.HELD
    route_kettle_state.temperature_c = 95.0
    var trajectory_probe := PourController.new()
    add_child(trajectory_probe)
    assert(trajectory_probe.start_pouring(route_kettle), "Ready kettle cannot enter pour mode")
    trajectory_probe._stream.update_stream(route_kettle.call("get_pour_origin_global_position"), route_kettle.call("get_pour_direction_global"), 120.0, 0.015, 1.0)
    assert(trajectory_probe._stream.last_trajectory.size() == 15, "Visual and physical stream do not share the required 14-segment trajectory")
    trajectory_probe.stop_pouring()
    trajectory_probe.queue_free()
    route_kettle_volume.drain()
    route_kettle_state.state = KettleStateMachine.KettleState.EMPTY
    route_kettle_state.temperature_c = 20.0
    var powder_jar := builder._objects.get("coffee") as RigidBody3D
    var powder_emitter := powder_jar.get_node("CoffeePowderEmitter") as CoffeePowderEmitter
    var powder_mug_content := coffee_route_mug.get_node("MugContentController") as MugContentController
    var powder_jar_parent := powder_jar.get_parent()
    var powder_jar_transform := powder_jar.global_transform
    powder_jar.reparent(builder, true)
    powder_jar.freeze = true
    coffee_route_mug.freeze = true
    coffee_route_mug.global_position = Vector3(-3.4, 1.0, -1.2)
    coffee_route_mug.global_rotation = Vector3.ZERO
    powder_mug_content.empty()
    powder_jar.global_position = coffee_route_mug.global_position + Vector3(0.0, 0.64, 0.0)
    powder_jar.global_rotation_degrees = Vector3(0.0, 0.0, 180.0)
    await get_tree().physics_frame
    await get_tree().physics_frame
    var powder_hit_probe := PourController.new()
    add_child(powder_hit_probe)
    assert(powder_hit_probe.start_pouring(powder_jar), "Coffee jar cannot enter the physical pour mode")
    powder_hit_probe.tilt_angle = 80.0
    var powder_before_hit := powder_emitter.remaining_g
    powder_hit_probe.call("_process_powder", 0.25)
    var powder_source_loss := powder_before_hit - powder_emitter.remaining_g
    assert(powder_hit_probe.hit_ml > 0.0 and powder_mug_content.coffee_powder_g > 0.0, "Physical powder trajectory does not hit OpeningReceiverArea")
    assert(absf(powder_source_loss - powder_hit_probe.hit_ml - powder_hit_probe.spilled_ml) < 0.01, "Powder mass is not conserved on a hit")
    powder_hit_probe.stop_pouring()
    powder_hit_probe.queue_free()
    var powder_after_hit := powder_mug_content.coffee_powder_g
    powder_jar.global_position += Vector3(0.55, 0.0, 0.0)
    await get_tree().physics_frame
    var powder_miss_probe := PourController.new()
    add_child(powder_miss_probe)
    assert(powder_miss_probe.start_pouring(powder_jar), "Coffee jar cannot restart pouring for a miss")
    powder_miss_probe.tilt_angle = 80.0
    var powder_before_miss := powder_emitter.remaining_g
    powder_miss_probe.call("_process_powder", 0.25)
    var powder_miss_loss := powder_before_miss - powder_emitter.remaining_g
    assert(powder_miss_probe.spilled_ml > 0.0 and is_equal_approx(powder_mug_content.coffee_powder_g, powder_after_hit), "Powder miss adds coffee to the mug or creates no spill")
    assert(absf(powder_miss_loss - powder_miss_probe.spilled_ml) < 0.01, "Powder mass is not conserved on a miss")
    powder_miss_probe.stop_pouring()
    powder_miss_probe.queue_free()
    powder_mug_content.empty()
    powder_jar.reparent(powder_jar_parent, true)
    powder_jar.global_transform = powder_jar_transform
    assert(get_tree().get_first_node_in_group("milk_delivery_pickup") != null, "Milk courier pickup is missing at the entrance")
    var player_camera := player.get_node_or_null("Camera") as Camera3D
    assert(player_camera != null, "First-person camera is missing")
    assert(player_camera.find_child("Hand1", true, false) != null or player_camera.find_child("LeftHand", true, false) != null, "Left first-person hand is missing")
    assert(player_camera.find_child("Hand2", true, false) != null or player_camera.find_child("RightHand", true, false) != null, "Right first-person hand is missing")
    var saved_test_intoxication := float(player.get("intoxication"))
    player.set("intoxication", 100.0)
    player.set("_drunk_movement_inverted", true)
    player.set("_drunk_mouse_inverted", true)
    var inverted_forward := player.call("_apply_drunk_movement_input", Vector2(0.0, -1.0)) as Vector2
    assert(inverted_forward.y > 0.90, "Maximum intoxication does not invert W into backward movement")
    assert(float(player.call("_drunk_mouse_multiplier")) < -1.0, "Maximum intoxication does not invert mouse input")
    assert(float(player.call("_drunk_fumble_chance")) >= 0.75 and float(player.call("_drunk_throw_strength")) >= 10.0, "Intoxication does not create strong accidental throws")
    route_spoon.call("arm_forced_impact_noise", 24.0)
    assert(float(route_spoon.get("_next_impact_noise_bonus")) >= 24.0, "Drunk fumble cannot arm a loud physical impact")
    route_spoon.set("_next_impact_noise_bonus", 0.0)
    player.set("intoxication", 0.0)
    player.call("_update_drunk_controls", 0.1)
    assert(not bool(player.get("_drunk_movement_inverted")) and not bool(player.get("_drunk_mouse_inverted")), "Sober controls remain inverted")
    assert(is_equal_approx(float(player.call("_drunk_fumble_chance")), 0.0), "Sober item placement can trigger a drunk throw")
    player.set("intoxication", saved_test_intoxication)
    assert(NoiseManager.room_for_position(Vector3(3.4, 1.0, -1.0)) == &"kitchen", "Kitchen room lookup failed")
    assert(NoiseManager.room_for_position(Vector3(-4.65, 1.0, 8.0)) == &"wardrobe", "Wardrobe room lookup failed")
    assert(get_tree().get_nodes_in_group("furniture").size() >= 14, "Detailed furniture set is incomplete")
    assert(get_tree().get_nodes_in_group("household_hazards").size() == 3, "Household activity nodes are missing")
    assert(get_tree().get_nodes_in_group("power_outlet").size() >= 5, "Power outlets are missing, including Rita bedroom outlet")
    assert(get_tree().get_first_node_in_group("television") != null, "Portable football television is missing")
    assert(InputMap.has_action("map"), "Apartment map input is missing")
    assert(InputMap.has_action("leaderboard"), "Leaderboard input is missing")
    assert(InputMap.has_action("rotate_item"), "Held-item rotation input is missing")
    assert(hud.get("apartment_map") != null, "Apartment map panel is missing")
    hud.call("_update_urgent_panel", CallManager.get_state())
    assert(hud.get("urgent_label") != null, "Right-side urgent task panel is missing in HUD")
    assert(RunStats.denis_spoke.is_connected(Callable(hud, "show_subtitle")), "Denis cash disclaimer is not connected to the HUD")
    assert(RitaSleep.subtitle_requested.is_connected(Callable(VoiceManager, "speak_rita")), "Rita subtitles are not connected to her generated voice")
    assert(RitaDemands.subtitle_requested.is_connected(Callable(VoiceManager, "speak_rita")), "Rita demands are silent")
    assert(CallManager.subtitle_requested.is_connected(Callable(VoiceManager, "speak_call_dialogue")), "Remote call dialogue is silent")
    assert(MilkDelivery.courier_spoke.is_connected(Callable(VoiceManager, "speak_courier")), "Courier dialogue is silent")
    assert(RunStats.denis_spoke.is_connected(Callable(VoiceManager, "speak_denis")), "Denis spoken lines are silent")
    var rita_voice_path := VoiceManager.voice_path_for("Денис... телевизор слишком громко. Выключи звук, пожалуйста.", &"rita")
    assert(not rita_voice_path.is_empty() and ResourceLoader.exists(rita_voice_path), "Generated Rita voice bank is missing")
    var rita_voice_stream := load(rita_voice_path) as AudioStream
    assert(rita_voice_stream != null and rita_voice_stream.get_length() > 1.0, "Generated Rita voice clip is invalid")
    assert(VoiceManager.subtitle_hold_time("Денис... телевизор слишком громко. Выключи звук, пожалуйста.") > 2.8, "Subtitle disappears before Rita finishes speaking")
    assert(not VoiceManager.voice_path_for("БЫЛ THE ПЛАТЁЖ, ТЫ НЕ УСПЕЛ. −900 ₽. ЖДИ СЛЕДУЮЩИЙ.", &"call").is_empty(), "Dynamic missed-payment speech has no voiced fallback")
    assert(not VoiceManager.voice_path_for("Доставка! Молоко привёз!", &"courier").is_empty(), "Generated courier voice bank is missing")
    assert(get_tree().get_first_node_in_group("phone_locator") != null, "Phone cannot be located by the map")
    assert(get_tree().get_nodes_in_group("soft_surface").size() >= 3, "Quiet carpet routes are missing")
    assert(builder._objects.has("felt_pads") and builder._objects.has("hinge_oil"), "Noise-control preparation tools are missing")
    assert(builder._objects.has("bedroom_door") and builder._objects.has("bathroom_door"), "Private room doors are missing")
    assert(builder._objects.has("wardrobe_door"), "Walk-in wardrobe door is missing")
    assert(get_tree().get_nodes_in_group("wall_hole_patch").size() >= 3, "Wall and window gaps are not fully sealed")
    var corridor_north_cap := builder.get_node_or_null("CorridorNorthCap") as MeshInstance3D
    assert(corridor_north_cap != null and corridor_north_cap.mesh is BoxMesh and (corridor_north_cap.mesh as BoxMesh).size.x >= 3.70, "Widened corridor still has visible holes at the north wall")
    var bedroom_door_visual := builder._objects["bedroom_door"].get_node_or_null("Panel") as MeshInstance3D
    var bedroom_door_handle := builder._objects["bedroom_door"].get_node_or_null("HandleHallSide") as Node3D
    assert(bedroom_door_visual != null and bedroom_door_visual.mesh is BoxMesh, "Bedroom doorway has no proper door leaf")
    var bedroom_door_size := (bedroom_door_visual.mesh as BoxMesh).size
    assert(bedroom_door_size.x <= 0.06 and bedroom_door_size.y <= 2.21 and bedroom_door_size.z <= 1.29, "Room door is still an oversized slab")
    assert(bedroom_door_handle != null and bedroom_door_handle.position.z > 0.95, "Room door handle is mounted beside the hinge")
    assert(absf(builder.get_node("HallConsole").global_position.x) >= 1.30 and absf(builder.get_node("ShoeBench").global_position.x) >= 1.30, "Entry furniture is still piled in the corridor centre")
    assert(builder.get_node("DiningArea").global_position.z >= 1.20, "Dining furniture is still occupying the kitchen centre")
    assert(builder.get_node("TVConsole").global_position.x >= -2.05, "Television console is not placed against the corridor wall")
    var corridor_runner := builder.get_node_or_null("CorridorShell/Runner") as MeshInstance3D
    assert(corridor_runner != null and corridor_runner.mesh is BoxMesh and (corridor_runner.mesh as BoxMesh).size.x >= 1.34, "Corridor was not widened to a comfortable clean route")
    assert(get_tree().get_nodes_in_group("environment_imported_prop").size() >= 12, "Curated apartment asset set is incomplete")
    for required_environment_prop in ["EntryDoormat", "ExternalMonitor", "RitaTableLamp", "BathroomWallCabinet", "KitchenTrashcan"]:
        assert(builder.get_node_or_null(required_environment_prop) != null, "Missing curated environment prop: %s" % required_environment_prop)
    var corridor_clearance_shape := BoxShape3D.new()
    corridor_clearance_shape.size = Vector3(0.76, 1.35, 0.76)
    var corridor_clearance_query := PhysicsShapeQueryParameters3D.new()
    corridor_clearance_query.shape = corridor_clearance_shape
    corridor_clearance_query.collision_mask = 1
    corridor_clearance_query.collide_with_areas = false
    corridor_clearance_query.collide_with_bodies = true
    for corridor_z in [-5.55, -4.20, -2.80, -1.20, 0.40, 1.80, 3.20, 4.65]:
        corridor_clearance_query.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.86, corridor_z))
        assert(get_world_3d().direct_space_state.intersect_shape(corridor_clearance_query, 8).is_empty(), "Central corridor clearance is physically blocked near z=%.2f" % corridor_z)
    var desk := builder.get_node_or_null("WorkDesk") as Node3D
    var chair := builder.get_node_or_null("OfficeChair") as Node3D
    var sofa := builder.get_node_or_null("Sofa") as Node3D
    var tv := builder._objects.get("television") as Node3D
    assert(desk != null and chair != null and desk.global_position.distance_to(chair.global_position) > 1.0, "Desk chair overlaps the desk")
    assert(absf(chair.rotation_degrees.y) < 15.0, "Desk chair faces away from the computer")
    assert(sofa != null and tv != null and sofa.global_position.distance_to(tv.global_position) > 3.5, "Sofa and TV zone overlaps")
    assert(absf(tv.rotation_degrees.y - 90.0) < 15.0, "Television screen faces the wall")
    assert(builder._objects["mug"].global_position.distance_to(builder._objects["coffee"].global_position) > 1.0, "Kitchen items overlap")
    assert(get_tree().get_nodes_in_group("movable_furniture").size() >= 14, "Not enough independent movable furniture")
    assert(get_tree().get_nodes_in_group("carryable").size() >= 28, "Loose apartment props are missing")
    assert(get_tree().get_nodes_in_group("door_lintel").size() >= 5, "Door openings have no proper lintels")
    var fridge := builder.get_node_or_null("Fridge") as Node3D
    var upper_cabinet_edge := builder.get_node_or_null("KitchenFurniture/EastUpperCabinet/UpperSideR") as Node3D
    var sink_cabinet := builder.get_node_or_null("KitchenFurniture/SinkBack") as Node3D
    assert(fridge != null and upper_cabinet_edge != null and fridge.global_position.distance_to(upper_cabinet_edge.global_position) > 2.0, "Refrigerator still overlaps the upper cabinet")
    assert(sink_cabinet != null and fridge.global_position.z - sink_cabinet.global_position.z > 1.70, "Refrigerator blocks the sink work zone")
    assert(fridge.global_position.x > 7.0 and fridge.global_position.z > -1.5, "Refrigerator is not on the east side wall")
    var north_counter := builder.get_node("KitchenFurniture/CounterTop") as MeshInstance3D
    var return_counter := builder.get_node("KitchenFurniture/SinkCounter") as MeshInstance3D
    var north_counter_mesh := north_counter.mesh as BoxMesh
    var return_counter_mesh := return_counter.mesh as BoxMesh
    assert(north_counter.global_position.z - north_counter_mesh.size.z * 0.5 <= -6.38, "North kitchen run is not tight to the wall")
    assert(return_counter.global_position.x + return_counter_mesh.size.x * 0.5 >= 7.88, "East kitchen return is not tight to the wall")
    var east_upper_cabinet := builder.get_node("KitchenFurniture/EastUpperCabinet") as Node3D
    assert(east_upper_cabinet.global_position.x > 7.55, "Upper cabinets still obscure the north window")
    var faucet_drop := builder.get_node("KitchenFurniture/FaucetDrop") as Node3D
    var sink_basin := builder.get_node("KitchenFurniture/SinkBasin") as MeshInstance3D
    var sink_basin_mesh := sink_basin.mesh as BoxMesh
    var upper_south_edge := east_upper_cabinet.global_position.z + 0.86
    assert(upper_south_edge < faucet_drop.global_position.z - 0.35, "Upper cabinet intersects the faucet work zone")
    assert(faucet_drop.global_position.x > sink_basin.global_position.x - sink_basin_mesh.size.x * 0.5 and faucet_drop.global_position.x < sink_basin.global_position.x + sink_basin_mesh.size.x * 0.5, "Faucet outlet misses the sink basin")
    assert(absf(faucet_drop.global_position.z - sink_basin.global_position.z) < sink_basin_mesh.size.z * 0.5, "Faucet outlet is not over the sink basin")
    var faucet_water := builder._objects.get("water") as Node3D
    var faucet_stream := faucet_water.get_node("WaterStream") as Node3D
    var faucet_catch := faucet_water.get_node("WaterCatchArea") as Area3D
    assert(faucet_stream.global_position.distance_to(faucet_catch.global_position) < 0.01, "Visible faucet stream and physical catch volume disagree")
    assert(absf(faucet_stream.global_position.x - faucet_drop.global_position.x) < 0.02, "Faucet stream is detached from the outlet")
    assert(builder.get_node_or_null("KitchenDecor/WallClock") == null, "Cross-shaped kitchen clock is still present")
    for obsolete_kitchen_decor in ["CoffeeMachine", "CoffeeMachineTop", "CoffeeCarafe", "BreadBox", "BreadLoaf", "SinkMat", "SpiceRack", "WindowPlantSill"]:
        assert(builder.get_node_or_null("KitchenDecor/%s" % obsolete_kitchen_decor) == null, "Obsolete kitchen prop still intersects the rebuilt layout: %s" % obsolete_kitchen_decor)
    for stable_kitchen_item_key in ["mug", "kettle", "spoon"]:
        var stable_kitchen_item := builder._objects.get(stable_kitchen_item_key) as RigidBody3D
        assert(stable_kitchen_item != null and stable_kitchen_item.freeze and stable_kitchen_item.linear_velocity.length() < 0.01, "Kitchen item starts airborne: %s" % stable_kitchen_item_key)
    for parked_clutter_name in ["CerealBox", "TeaBox", "CuttingBoard", "DishTowel", "Sponge", "SoapBottle"]:
        var parked_clutter := builder.get_node_or_null(parked_clutter_name) as RigidBody3D
        assert(parked_clutter != null and parked_clutter.freeze and parked_clutter.linear_velocity.length() < 0.01, "Countertop clutter starts airborne: %s" % parked_clutter_name)
    assert(builder.get_node_or_null("KitchenWindowSeam") != null, "Bright seam remains beside the kitchen window")
    var north_front_z := north_counter.global_position.z + north_counter_mesh.size.z * 0.5
    var return_north_z := return_counter.global_position.z - return_counter_mesh.size.z * 0.5
    assert(return_north_z <= north_front_z + 0.02, "L-shaped kitchen worktop still has a visible gap")
    var fridge_door := builder._objects.get("fridge_door") as Node
    assert(fridge_door != null and fridge_door.is_in_group("door"), "Refrigerator has no interactive door")
    assert(absf(float(fridge_door.get("open_angle_degrees"))) > 90.0, "Refrigerator door does not open far enough")
    assert(fridge_door.get_node_or_null("InteractionArea") is Area3D, "Refrigerator door has no moving interaction target")
    var fridge_approach := Vector3(6.35, 1.15, -0.85)
    assert(fridge.global_position.distance_to(fridge_approach) < 1.6, "Refrigerator cannot be approached from the kitchen aisle")
    var fridge_door_area := fridge_door.get_node("InteractionArea") as Area3D
    var fridge_ray := PhysicsRayQueryParameters3D.create(fridge_approach, fridge.global_position)
    fridge_ray.collision_mask = 3
    fridge_ray.collide_with_areas = true
    fridge_ray.collide_with_bodies = true
    var fridge_hit := get_world_3d().direct_space_state.intersect_ray(fridge_ray)
    var fridge_hit_node := fridge_hit.get("collider") as Node
    assert(not fridge_hit.is_empty() and fridge_hit_node != null and (fridge_hit_node == fridge_door_area or fridge_door.is_ancestor_of(fridge_hit_node)), "Player's E ray cannot target the refrigerator door")
    fridge_door.call("perform_interaction", player, 0)
    assert(bool(fridge_door.get("is_open")), "Refrigerator door cannot be opened")
    var refrigerated_beers := get_tree().get_nodes_in_group("match_beer")
    assert(refrigerated_beers.size() >= 3, "The refrigerator does not contain a physical beer stock")
    for refrigerated_beer in refrigerated_beers:
        assert(refrigerated_beer is Node3D and (refrigerated_beer as Node3D).global_position.distance_to(fridge.global_position) < 1.5, "A beer bottle starts outside the refrigerator")
    var kitchen_part_keys := [
        "lower_door_right_a", "lower_door_right_b",
        "sink_door_left", "sink_door_right",
        "upper_left_door", "mug_cabinet", "drawer",
        "fridge_lower_door", "fridge_upper_door", "dishwasher_door"
    ]
    var coffee_drawer := builder._objects.get("drawer") as Node3D
    var drawer_coffee := builder._objects.get("coffee") as Node3D
    assert(coffee_drawer != null and drawer_coffee != null and coffee_drawer.is_ancestor_of(drawer_coffee), "Coffee does not travel with its drawer")
    var coffee_closed_position := drawer_coffee.global_position
    for kitchen_part_key in kitchen_part_keys:
        var kitchen_part := builder._objects.get(kitchen_part_key) as Node
        assert(kitchen_part != null and "is_open" in kitchen_part, "Missing kitchen moving part: %s" % kitchen_part_key)
        if not bool(kitchen_part.get("is_open")):
            kitchen_part.call("perform_interaction", player, 0)
    await get_tree().create_timer(0.9).timeout
    for kitchen_part_key in kitchen_part_keys:
        assert(bool(builder._objects[kitchen_part_key].get("is_open")), "Kitchen part did not open: %s" % kitchen_part_key)
    assert(drawer_coffee.global_position.distance_to(coffee_closed_position) > 0.30, "Drawer contents do not move with the drawer")
    for kitchen_part_key in kitchen_part_keys:
        builder._objects[kitchen_part_key].call("perform_interaction", player, 0)
    await get_tree().create_timer(0.9).timeout
    for kitchen_part_key in kitchen_part_keys:
        assert(not bool(builder._objects[kitchen_part_key].get("is_open")), "Kitchen part did not close: %s" % kitchen_part_key)
    assert(drawer_coffee.global_position.distance_to(coffee_closed_position) < 0.03, "Drawer contents do not return with the drawer")
    var outlet := get_tree().get_first_node_in_group("power_outlet") as Node3D
    assert(outlet != null and tv.call("connect_to_outlet", outlet) != "", "Television outlet connection failed")
    assert(bool(tv.get("powered")), "Television did not power on near an outlet")
    var football_video_player := tv.find_child("FootballVideoPlayer", true, false) as VideoStreamPlayer
    var football_video_viewport := tv.get_node_or_null("FootballVideoViewport") as SubViewport
    var television_screen := tv.get_node_or_null("Screen") as MeshInstance3D
    var procedural_pitch := tv.get_node_or_null("Pitch") as MeshInstance3D
    assert(bool(tv.get("_using_real_video")) and football_video_player != null and football_video_player.stream != null and football_video_viewport != null, "Local football video is not connected to the television")
    tv.call("_update_screen")
    assert(television_screen != null and television_screen.material_override is ShaderMaterial and (television_screen.material_override as ShaderMaterial).get_shader_parameter("video_texture") != null, "Football video texture is not assigned to the 3D screen")
    var television_quad := television_screen.mesh as QuadMesh
    var television_video_shader := (television_screen.material_override as ShaderMaterial).shader.code
    assert(television_quad != null, "Television video is mapped to a box and crops the frame")
    assert(absf(television_quad.size.x / television_quad.size.y - 854.0 / 480.0) < 0.02, "Television screen is not 16:9")
    assert(television_video_shader.contains("texture(video_texture, UV)") and not television_video_shader.contains("1.0 - UV.y"), "Television video is vertically flipped")
    assert(procedural_pitch != null and not procedural_pitch.visible, "Procedural football placeholder covers the real video")
    assert(football_video_player.get_parent() == football_video_viewport, "Football player leaks into the main game canvas instead of the 3D television")
    var tv_wake_before_sound_test := RitaSleep.wake_level
    tv.set("_tv_noise_timer", 0.0)
    tv.call("_process_tv_noise", 0.1)
    assert(RitaSleep.wake_level > tv_wake_before_sound_test, "Audible television cannot wake Rita")
    assert(String(tv.call("interact", player, 1)).contains("ЗВУК ВЫКЛЮЧЕН") and bool(tv.get("muted")), "Holding E cannot mute the television")
    assert(String(tv.call("get_prompt", player)).contains("ЗВУК ВКЛЮЧИТЬ"), "Muted state is missing from the television prompt")
    assert(not String(tv.call("get_prompt", player)).begins_with("E —"), "Television prompt duplicates the E key label")
    var tv_wake_after_mute := RitaSleep.wake_level
    tv.set("_tv_noise_timer", 0.0)
    tv.call("_process_tv_noise", 2.1)
    assert(absf(RitaSleep.wake_level - tv_wake_after_mute) < 0.001, "Muted television still wakes Rita")
    RitaSleep.wake_level = tv_wake_before_sound_test
    var match_beer := builder._objects.get("match_beer") as RigidBody3D
    assert(match_beer != null and match_beer.is_in_group("carryable") and match_beer.is_in_group("match_beer"), "Match beer is not a physical carryable object")
    var beer_sips_before := int(match_beer.get("sips_remaining"))
    player.set("stamina", 34.0)
    player.set("intoxication", 0.0)
    tv.set("_watch_required", true)
    var watched_before := RunStats.football_moments_watched
    var watch_result := String(tv.call("complete_watch_with_beer", player, match_beer))
    assert(watch_result.contains("ПОДНОСИТ БУТЫЛКУ"), "Watching the match does not start the physical drinking animation")
    assert(bool(player.call("is_drinking_beer")) and player.get("held_item") == match_beer, "Beer bottle is not placed in Denis' hand while drinking")
    player.call("_update_drink_animation", 0.825)
    assert(match_beer.global_position.distance_to(player.camera.global_position) < 0.65, "Beer bottle does not reach Denis' mouth")
    player.call("_update_drink_animation", 0.825)
    assert(not bool(player.call("is_drinking_beer")) and player.get("held_item") == null, "Temporary beer bottle is not returned after drinking")
    assert(float(player.get("stamina")) > 34.0 and float(player.get("intoxication")) > 0.0, "Beer does not restore stamina and reduce hand control")
    assert(int(match_beer.get("sips_remaining")) == beer_sips_before - 1, "Beer bottle does not lose a sip")
    assert(RunStats.football_moments_watched == watched_before + 1, "Watched football moment is not recorded")
    player.set("stamina", 80.0)
    tv.set("_watch_required", true)
    var missed_football_before := RunStats.football_moments_missed
    tv.call("_miss_active_moment", "TEST")
    assert(float(player.get("stamina")) <= 64.1 and RunStats.football_moments_missed == missed_football_before + 1, "Missing the match has no stamina consequence")
    player.set("stamina", 100.0)
    player.set("intoxication", 0.0)
    assert(float(sofa.get("mass")) >= 50.0, "Sofa has unrealistic weight")
    assert(float(tv.get("mass")) < float(sofa.get("mass")), "Heavy furniture lifts like electronics")
    assert((tv as RigidBody3D).collision_mask & 2 != 0, "Television does not collide with its console")
    assert((tv as RigidBody3D).freeze, "Television falls before the player touches it")
    var television_safe_transform: Transform3D = tv.global_transform
    tv.set("last_safe_transform", television_safe_transform)
    tv.global_position.y = -5.0
    tv.call("_physics_process", 0.1)
    assert(tv.global_position.y > -1.0, "Non-critical television is lost forever after falling out of the apartment")
    (tv as RigidBody3D).freeze = true
    assert(float(fridge.get("mass")) >= 75.0, "Refrigerator has unrealistic weight")
    assert(int((sofa as RigidBody3D).collision_mask) & 2 != 0, "Movable furniture does not collide with other objects")
    var player_script := player.get_script() as GDScript
    assert(player_script != null and player_script.source_code.contains("_update_movement(delta)\n    _update_pushing(delta)"), "Heavy-object pushing is not wired into the physics loop")
    var bed := builder.get_node_or_null("Bed") as Node3D
    var nightstand := builder.get_node_or_null("Nightstand") as Node3D
    var dresser := builder.get_node_or_null("BedroomDresser") as Node3D
    var wardrobe := builder.get_node_or_null("Wardrobe") as Node3D
    assert(builder.get_node_or_null("RitaBedroomDecor") != null, "Rita bedroom decor is missing")
    assert(bed != null and nightstand != null and dresser != null and wardrobe != null, "Rita bedroom furniture is incomplete")
    assert(bed.global_position.distance_to(dresser.global_position) > 3.0, "Rita bedroom dresser overlaps the bed")
    assert(bed.global_position.distance_to(wardrobe.global_position) > 1.45, "Rita bedroom wardrobe overlaps the bed")
    assert(nightstand.global_position.distance_to(dresser.global_position) > 1.2, "Rita bedroom furniture is stacked together")
    assert(builder.get_node_or_null("WalkInWardrobe") != null, "Walk-in wardrobe room is missing")
    assert(get_tree().get_nodes_in_group("wardrobe_clothes").size() >= 10, "Wardrobe has too few searchable clothes and shoe boxes")
    assert(get_tree().get_nodes_in_group("rita_demand_station").size() == 2, "Rita demand interaction stations are missing")
    assert(get_tree().get_nodes_in_group("cash_stash").size() == 8, "Apartment cash stashes are incomplete")
    var dynamic_cash_before := get_tree().get_nodes_in_group("dynamic_cash").size()
    builder.call("_spawn_dynamic_cash")
    assert(get_tree().get_nodes_in_group("dynamic_cash").size() == dynamic_cash_before + 1, "Money does not appear dynamically during a run")
    var phone_locator := get_tree().get_first_node_in_group("phone_locator")
    var phone_station := builder._objects.get("phone_station") as Node3D
    assert(phone_station != null and phone_station.name == "HallwayPhoneStation", "Phone fallback station is missing")
    assert(phone_station.get_node_or_null("PhonePlacementAnchor") != null and phone_station.get_node_or_null("PhoneChargingPad") != null, "Hallway phone station structure is incomplete")
    assert((phone_locator.get("placement_anchors") as Array).size() >= 5, "Phone does not have enough safe random furniture locations")
    var random_phone_anchor := phone_locator.get("placement_anchor") as Node3D
    assert(random_phone_anchor != null and phone_locator.global_position.distance_to(random_phone_anchor.global_position) < 0.02, "Phone did not spawn on a random placement anchor")
    phone_locator.call("place_randomly")
    assert(phone_locator.get("placement_anchor") != random_phone_anchor, "Phone repeats the same location instead of choosing another random furniture spot")
    phone_locator.call("activate_phone")
    assert(bool(phone_locator.get("active")), "Phone locator never becomes active")
    var silenced_phone_anchor := phone_locator.get("placement_anchor") as Node3D
    phone_locator.call("on_picked_up")
    assert(not bool(phone_locator.get("armed")), "Silenced phone never enters cooldown")
    phone_locator.call("on_released")
    phone_locator.set("_rearm_left", 0.0)
    phone_locator.call("_process", 0.1)
    assert(
        bool(phone_locator.get("armed")) and not bool(phone_locator.get("active"))
        and phone_locator.get("placement_anchor") != silenced_phone_anchor,
        "Silenced phone does not rearm at a different random location"
    )
    phone_locator.set("_next_activation_delay", 0.0)
    phone_locator.call("_process", 0.1)
    assert(bool(phone_locator.get("active")), "Rearmed phone never rings again")
    phone_locator.set("_pulse_elapsed", float(phone_locator.get("pulse_interval")))
    phone_locator.call("_process", 0.1)
    assert(String(NoiseManager.last_noise.get("source_id", "")) == "phone", "Ringing phone creates no physical noise")
    phone_locator.call("on_picked_up")
    phone_locator.call("on_released")
    var vacuum_hazard: Variant = builder._objects.get("vacuum")
    phone_locator.set("active", true)
    vacuum_hazard.set("_elapsed", float(vacuum_hazard.get("activation_delay")))
    vacuum_hazard.call("_process", 0.1)
    assert(bool(vacuum_hazard.get("active")), "An active phone incorrectly prevents the robot vacuum from starting")
    phone_locator.set("active", false)
    var vacuum_node := vacuum_hazard as Node3D
    assert(vacuum_node != null, "Robot vacuum has no movable 3D body")
    var vacuum_original_transform := vacuum_node.global_transform
    vacuum_node.global_position = Vector3(4.20, 0.12, -1.00)
    vacuum_hazard.set("armed", true)
    vacuum_hazard.set("active", true)
    vacuum_hazard.call("_cache_collision_exclusions")
    vacuum_hazard.call("_start_vacuum_motion")
    await get_tree().create_timer(0.30).timeout
    var vacuum_position_before := vacuum_node.global_position
    var vacuum_distance_travelled := 0.0
    for vacuum_step in range(24):
        var previous_vacuum_position := vacuum_node.global_position
        vacuum_hazard.call("_physics_process", 0.25)
        vacuum_distance_travelled += vacuum_node.global_position.distance_to(previous_vacuum_position)
        await get_tree().process_frame
    await get_tree().create_timer(0.30).timeout
    print("VACUUM_ROUTE_TEST position=%s distance=%.2f kitchen_door_open=%s" % [
        str(vacuum_node.global_position),
        vacuum_distance_travelled,
        str(bool(builder._objects["kitchen_door"].get("is_open")))
    ])
    assert(bool(vacuum_hazard.call("_position_is_clear", vacuum_node.global_position)), "Robot vacuum finished its route inside furniture or a wall")
    assert(vacuum_distance_travelled > 2.50 and vacuum_node.global_position.distance_to(vacuum_position_before) > 0.60, "Active robot vacuum does not patrol the apartment")
    assert(float(vacuum_hazard.get("_station_exit_remaining")) <= 0.01, "Robot vacuum remains trapped in the dock-exit phase")
    assert(float(vacuum_hazard.get("flee_speed")) > float(vacuum_hazard.get("movement_speed")) and float(vacuum_hazard.get("flee_radius")) >= 2.5, "Robot vacuum does not flee when Denis chases it")
    var vacuum_kitchen_door := builder._objects.get("kitchen_door") as Node
    assert(vacuum_kitchen_door != null and bool(vacuum_kitchen_door.get("is_open")), "Robot vacuum cannot push the kitchen door open")
    assert(String(vacuum_hazard.call("get_prompt", player)).contains("ОСТАНОВИТЬ"), "Moving vacuum has no stop prompt")
    vacuum_hazard.call("perform_interaction", player, 0)
    var vacuum_stopped_position := vacuum_node.global_position
    vacuum_hazard.call("_physics_process", 0.5)
    assert(vacuum_node.global_position.distance_to(vacuum_stopped_position) < 0.001, "Switched-off robot vacuum keeps moving")
    var vacuum_collision_shapes := vacuum_node.find_children("*", "CollisionShape3D", true, false)
    assert(not vacuum_collision_shapes.is_empty(), "Robot vacuum has no physical collision shape")
    for vacuum_collision_shape in vacuum_collision_shapes:
        assert(vacuum_collision_shape is CollisionShape3D and (vacuum_collision_shape as CollisionShape3D).disabled, "Switched-off robot vacuum blocks a doorway instead of allowing Denis to step over it")
    vacuum_hazard.set("active", true)
    vacuum_hazard.call("_start_vacuum_motion")
    for vacuum_collision_shape in vacuum_collision_shapes:
        assert(vacuum_collision_shape is CollisionShape3D and not (vacuum_collision_shape as CollisionShape3D).disabled, "Moving robot vacuum does not restore player avoidance collision")
    vacuum_node.global_transform = vacuum_original_transform
    var station_launch_start := vacuum_node.global_position
    var player_before_station_test: Transform3D = player.global_transform
    player.global_position = station_launch_start + Vector3(0.0, player.global_position.y - station_launch_start.y, 0.42)
    await get_tree().physics_frame
    vacuum_hazard.set("armed", true)
    vacuum_hazard.set("active", true)
    vacuum_hazard.call("_start_vacuum_motion")
    for station_exit_step in range(4):
        vacuum_hazard.call("_physics_process", 0.25)
    assert(vacuum_node.global_position.distance_to(station_launch_start) >= 0.70, "Player standing near the dock prevents the robot vacuum from driving out")
    player.global_transform = player_before_station_test
    vacuum_hazard.call("perform_interaction", player, 0)
    vacuum_node.global_transform = vacuum_original_transform
    var blocker_transform := route_spoon.global_transform
    var blocker_frozen := route_spoon.freeze
    route_spoon.freeze = true
    route_spoon.global_position = station_launch_start + Vector3.BACK * 0.42
    await get_tree().physics_frame
    await get_tree().physics_frame
    vacuum_hazard.set("armed", true)
    vacuum_hazard.set("active", true)
    vacuum_hazard.call("_start_vacuum_motion")
    for blocked_exit_step in range(4):
        vacuum_hazard.call("_physics_process", 0.25)
    assert(
        bool(vacuum_hazard.get("active")) and vacuum_node.global_position.distance_to(station_launch_start) >= 0.70,
        "A temporary physical item can still soft-lock the robot vacuum in its dock"
    )
    route_spoon.global_transform = blocker_transform
    route_spoon.freeze = blocker_frozen
    vacuum_hazard.set("armed", true)
    vacuum_hazard.set("active", false)
    vacuum_hazard.call("_set_vacuum_blocking", false)
    vacuum_hazard.set("_elapsed", 0.0)
    var washer := builder._objects.get("washing_machine") as RigidBody3D
    assert(washer != null, "Bathroom washing machine is missing")
    assert(washer.is_in_group("washing_machine"), "Washing machine is not registered as a gameplay hazard")
    var washer_original_transform := washer.global_transform
    washer.call("force_start_cycle")
    assert(bool(washer.get("active")), "Washing machine cannot start its unbalanced spin cycle")
    var washer_move_start := washer.global_position
    for washer_step in range(8):
        washer.call("_process", 0.25)
    assert(washer.global_position.distance_to(washer_move_start) > 0.35, "Spinning washing machine does not crawl out of the bathroom")
    assert(String(NoiseManager.last_noise.get("source_id", "")) == "washing_machine", "Washing machine spin produces no physical noise")
    assert(bool(builder._objects["bathroom_door"].get("is_open")), "Washing machine cannot open the bathroom route")
    assert(String(washer.call("get_prompt", player)).contains("УДЕРЖИВАТЬ E"), "Active washing machine has no calming prompt")
    washer.call("perform_interaction", player, 1)
    assert(not bool(washer.get("active")), "Holding E does not calm the washing machine")
    assert(float(washer.get("_activation_left")) >= float(washer.get("rearm_delay_min")), "Washing machine rearms too frequently")
    assert(not washer.find_children("*", "CollisionShape3D", true, false).is_empty(), "Washing machine has no physical collision")
    assert(washer.mass >= 60.0 and washer.has_method("on_picked_up"), "Stopped washing machine is not a heavy movable object")
    assert(String(washer.call("get_prompt", player)).contains("ЛКМ + WASD"), "Stopped washing machine does not explain how to move it out of the route")
    var washer_drag_start := washer.global_position
    player.call("_begin_heavy_grab", washer, washer.global_position + Vector3(0.0, 0.15, 0.0))
    assert(player.get("pushed_body") == washer and not washer.freeze, "Player cannot grab the stopped washing machine")
    washer.linear_velocity = Vector3(0.85, 0.0, 0.0)
    for washer_drag_frame in range(6):
        await get_tree().physics_frame
    assert(washer.global_position.distance_to(washer_drag_start) > 0.02, "Stopped washing machine remains immovable and can block a doorway")
    player.call("_stop_pushing")
    washer.freeze = true
    washer.global_transform = washer_original_transform
    for washer_line in [
        "Денис... стиралка опять скачет. Поймай её, пожалуйста.",
        "Денис, она сейчас из ванной уедет. Выключи отжим.",
        "ДЕНИС, БЛЯДЬ, УТИХОМИРЬ ЭТУ СТИРАЛКУ!",
        "КАКОГО ХУЯ СТИРАЛКА ЕДЕТ ПО КОРИДОРУ?! БЕГИ ПРЯТАТЬСЯ!",
    ]:
        var washer_voice_path := VoiceManager.voice_path_for(washer_line, &"rita")
        assert(not washer_voice_path.is_empty() and ResourceLoader.exists(washer_voice_path), "Rita washing-machine reaction has no recorded voice: %s" % washer_line)
        var washer_voice_stream := load(washer_voice_path) as AudioStream
        assert(washer_voice_stream != null and washer_voice_stream.get_length() > 1.0, "Rita washing-machine voice is invalid: %s" % washer_line)
    washer.global_transform = washer_original_transform
    var pads_action: Variant = builder._objects.get("felt_pads")
    pads_action.call("perform_interaction", player, 0)
    assert(bool(player.get("furniture_pads_equipped")), "Felt pads cannot be equipped")
    var oil_action: Variant = builder._objects.get("hinge_oil")
    oil_action.call("perform_interaction", player, 0)
    assert(bool(player.get("hinge_oil_equipped")), "Hinge oil cannot be equipped")
    var bedroom_door: Variant = builder._objects.get("bedroom_door")
    bedroom_door.call("perform_interaction", player, 0)
    assert(bool(bedroom_door.get("oiled")), "Equipped oil does not silence a door")
    var hide_spot := get_tree().get_first_node_in_group("hide_spot")
    assert(hide_spot != null, "Wardrobe hide spot is missing")
    RitaSleep.reset()
    RitaSleep.is_angry = true
    player.call(
        "enter_hide_spot",
        hide_spot,
        hide_spot.get("hide_position"),
        hide_spot.get("exit_position"),
        hide_spot.get("hide_yaw_degrees")
    )
    assert(bool(player.get("is_hidden")) and RitaSleep.player_hidden, "Player cannot enter the wardrobe hide spot")
    var calm_before_hide_tick := RitaSleep.calm_progress
    RitaSleep.call("_process_angry", 1.0)
    assert(RitaSleep.calm_progress > calm_before_hide_tick, "Hiding does not calm angry Rita")
    player.call("exit_hide_spot")
    assert(bool(player.get("is_hidden")), "Player can leave the wardrobe while Rita is still angry")
    RitaSleep.calm_progress = RitaSleep.CALM_REQUIRED - 0.2
    RitaSleep.call("_process_angry", 0.2)
    assert(not RitaSleep.is_angry and RitaDemands.has_active_demand(), "Rita does not issue a demand after Denis survives her rage")
    player.call("exit_hide_spot")
    assert(not bool(player.get("is_hidden")) and not RitaSleep.player_hidden, "Player cannot exit the wardrobe hide spot")
    RitaDemands.reset()
    RitaSleep.reset()
    RitaSleep.add_noise(0.20, &"TEST", &"inaudible_test")
    assert(RitaSleep.wake_level == 0.0, "Inaudible noise increases Rita wake level")
    for _pulse in range(5):
        RitaSleep.add_noise(4.0, &"APPLIANCE", &"phone")
    assert(RitaSleep.wake_level > 8.0 and RitaSleep.wake_level < 20.0, "Phone exposure is not accumulated with controlled annoyance")
    var reaction_stages: Dictionary = RitaSleep.get("_source_reaction_stage")
    assert(int(reaction_stages.get(&"phone", 0)) == 1, "Phone does not begin with a mild warning")
    RunStats.elapsed_time += RitaSleep.REACTION_COOLDOWN + 0.1
    RitaSleep.add_noise(4.0, &"APPLIANCE", &"phone")
    reaction_stages = RitaSleep.get("_source_reaction_stage")
    assert(int(reaction_stages.get(&"phone", 0)) == 2, "Deferred phone complaint is lost after the reaction cooldown")
    RunStats.elapsed_time += RitaSleep.SOURCE_CHAIN_RESET + 0.1
    RitaSleep.add_noise(4.0, &"APPLIANCE", &"phone")
    reaction_stages = RitaSleep.get("_source_reaction_stage")
    assert(int(reaction_stages.get(&"phone", 0)) == 0, "Phone complaint chain does not reset after justified silence")
    RitaSleep.reset()
    RitaSleep.add_noise(6.5, &"MEDIA", &"television")
    RitaSleep.add_noise(6.5, &"MEDIA", &"television")
    reaction_stages = RitaSleep.get("_source_reaction_stage")
    assert(int(reaction_stages.get(&"television", 0)) == 1, "Television does not trigger a source-specific warning")
    assert(String(RitaSleep.call("_source_reaction_line", &"television", 3)).contains("ТЕЛЕК"), "Television escalation does not identify the noisy TV")
    assert(String(RitaSleep.call("_awake_line_for", &"MEDIA", &"television")).contains("ТЕЛЕК"), "Television wake-up scream is generic")
    var wake_before_decay := RitaSleep.wake_level
    RitaSleep.set("_silence_time", 3.1)
    RitaSleep.call("_process", 1.0)
    assert(RitaSleep.wake_level < wake_before_decay, "Wake level does not decay after justified silence")
    RitaSleep.reset()
    RitaSleep.is_angry = true
    RitaSleep.calm_progress = 0.0
    var rage_item := builder._objects.get("mug") as RigidBody3D
    rage_item.call("on_picked_up")
    player.set("held_item", rage_item)
    player.call("_sync_rage_lock")
    assert(player.get("held_item") == null, "Rage mode does not force Denis to drop carried objects")
    RitaSleep.call("_process_angry", 2.0)
    assert(RitaSleep.calm_progress == 0.0, "Angry Rita calms while Denis is outside the wardrobe")
    RitaSleep.reset()
    CallManager.reset()
    RitaDemands.reset()
    var laptop_action: Variant = builder._objects.get("laptop")
    var balance_before_food := RunStats.money_balance
    RitaDemands.assign_after_wake(&"order_food")
    assert(QuestManager.get_objective() == "ЗАКАЗАТЬ РИТЕ ЕДУ НА НОУТБУКЕ", "Rita demand does not override the main route")
    laptop_action.call("perform_interaction", player, 0)
    assert(not RitaDemands.has_active_demand(), "Food order cannot be completed at the laptop")
    assert(RunStats.money_balance <= balance_before_food - 679.5, "Rita food order does not cost money")
    var cleaning_action: Variant = builder._objects.get("rita_bathroom_clean")
    RitaDemands.assign_after_wake(&"clean_bathroom")
    var kettle_state_before_demand: bool = QuestManager.kettle_filled
    var blocked_coffee_step: String = QuestManager.fill_kettle()
    assert(blocked_coffee_step.contains("ПОРУЧЕНИЕ РИТЫ") and QuestManager.kettle_filled == kettle_state_before_demand, "Coffee progresses for free during Rita demand protection")
    RitaSleep.wake_level = 62.0
    var wake_before_protected_noise := RitaSleep.wake_level
    RitaSleep.add_noise(35.0, &"CLEANING", &"bathroom_cleaning")
    assert(RitaSleep.wake_level == wake_before_protected_noise, "Noise grows while Denis is completing Rita's demand")
    RitaSleep.call("_process_demand_sleep", 1.0)
    assert(RitaSleep.wake_level < wake_before_protected_noise and RitaSleep.get_state_text().contains("ЗАСЫПАЕТ"), "Rita does not fall asleep during her demand")
    assert(float(cleaning_action.call("_duration_for", 1)) > float(cleaning_action.call("_duration_for", 0)), "Quiet bathroom cleaning is not a time tradeoff")
    assert(float(cleaning_action.call("_noise_for", 1)) < float(cleaning_action.call("_noise_for", 2)), "Fast bathroom cleaning is not louder than quiet cleaning")
    cleaning_action.call("_begin_task_minigame")
    cleaning_action.set("_task_marker", cleaning_action.get("_task_green_center"))
    var accelerated_time := float(cleaning_action.call("_apply_task_skill_input", 10.0, 10.0))
    var cleaning_task_state: Dictionary = cleaning_action.call("get_task_state")
    assert(accelerated_time < 8.3 and int(cleaning_task_state.get("hits", 0)) == 1, "Green-zone skill check does not accelerate Rita's chore")
    hud.call("_update_task_progress")
    assert(bool(hud.get("task_panel").visible), "Active chore has no visible progress/minigame panel")
    cleaning_action.call("_end_task_minigame")
    var position_before_chore: Vector3 = player.global_position
    player.global_position = (cleaning_action as Node3D).global_position + Vector3(3.0, 0.0, 0.0)
    var aborted_chore: Variant = await cleaning_action.call("interact", player, 0)
    assert(String(aborted_chore).contains("СОРВАНА") and RitaDemands.has_active_demand(), "Bathroom work completes after Denis walks away")
    player.global_position = position_before_chore
    cleaning_action.call("perform_interaction", player, 0)
    assert(not RitaDemands.has_active_demand(), "Bathroom demand cannot be completed at its station")
    assert(RitaSleep.wake_level == 0.0 and float(RitaSleep.get("_post_demand_grace")) > 0.0, "Rita has no quiet grace after a completed demand")
    RitaSleep.add_noise(30.0, &"TEST", &"post_demand_test")
    assert(RitaSleep.wake_level == 0.0, "Noise grows during post-demand sleep grace")
    RitaSleep.set("_post_demand_grace", 0.0)
    RitaSleep.add_noise(10.0, &"TEST", &"after_grace_test")
    assert(RitaSleep.wake_level > 0.0, "Normal hearing does not return after post-demand grace")
    RitaSleep.reset()
    RitaDemands.reset()
    var television_before_movie := tv.global_transform
    var player_before_movie: Vector3 = player.global_position
    tv.set("plugged", false)
    tv.set("powered", false)
    (tv as RigidBody3D).held = false
    (tv as RigidBody3D).freeze = true
    tv.global_position = Vector3(-3.20, 1.15, 5.45)
    player.global_position = Vector3(-3.20, 0.08, 4.25)
    RitaDemands.assign_after_wake(&"festival_cinema")
    assert(RitaDemands.get_objective().contains("ПРИНЕСТИ ТЕЛЕВИЗОР"), "Festival-cinema punishment has no physical TV objective")
    var bedroom_outlet := tv.call("_nearest_outlet", 2.8) as Node3D
    assert(bedroom_outlet != null and tv.call("connect_to_outlet", bedroom_outlet) != "", "Television cannot connect in Rita's bedroom")
    tv.call("_process_festival_movie", 0.1)
    assert(RitaDemands.is_festival_movie_watching(), "Rita does not start the Japanese festival movie with a powered bedroom TV")
    tv.call("_process_festival_movie", 7.0)
    var movie_task_state: Dictionary = tv.call("get_task_state")
    assert(bool(movie_task_state.get("active", false)) and float(movie_task_state.get("progress", 0.0)) > 45.0, "Standing near Rita's movie has no visible progress")
    hud.call("_update_task_progress")
    assert(float(hud.get("task_progress_bar").value) > 45.0, "Rita movie progress is not reflected by the HUD bar")
    assert(String(hud.get("task_label").text).contains(str(int(RitaDemands.get_festival_progress()))), "Rita movie HUD percentage is stale")
    assert(String(hud.get("objective_label").text).contains(str(int(RitaDemands.get_festival_progress()))), "Rita movie objective percentage is stale")
    tv.call("_process_festival_movie", 7.1)
    assert(not RitaDemands.has_active_demand(), "Rita does not fall asleep after Denis stands through the film")
    tv.global_transform = television_before_movie
    tv.set("plugged", false)
    tv.set("powered", false)
    player.global_position = player_before_movie
    RitaSleep.reset()
    RitaDemands.reset()
    var balance_before_cash := RunStats.money_balance
    var cash_stash := get_tree().get_first_node_in_group("cash_stash")
    var cash_value := float(cash_stash.get("amount"))
    var cash_message := String(cash_stash.call("perform_interaction", player, 0))
    assert(cash_message.contains("ЭТО НЕ ВОРОВСТВО"), "Denis does not deny stealing when collecting money")
    assert(RunStats.money_balance >= balance_before_cash + cash_value - 0.5, "Found cash does not restore balance")
    var first_miss_loss := RunStats.miss_payment()
    var second_miss_loss := RunStats.miss_payment()
    assert(second_miss_loss > first_miss_loss, "Repeated missed payments do not escalate the debt")
    var balance_before_payment := RunStats.money_balance
    CallManager.reset()
    CallManager.set("_event_index", 1)
    CallManager.call("_start_question")
    assert(CallManager.question_active and CallManager.question_kind == &"payment", "THE Payment window is not scheduled")
    var answer_window_before_rage: float = CallManager.answer_time_left
    RitaSleep.is_angry = true
    CallManager.call("_process", 2.0)
    assert(CallManager.paused_for_rita and CallManager.answer_time_left == answer_window_before_rage, "Call answer window expires during Rita rage")
    RitaSleep.is_angry = false
    CallManager.call("_process", 1.0)
    assert(not CallManager.paused_for_rita and CallManager.answer_time_left < answer_window_before_rage, "Call timer does not resume after Rita calms")
    CallManager.answer_question()
    assert(RunStats.money_balance >= balance_before_payment + CallManager.PAYMENT_AMOUNT - 0.5, "Answered THE Payment does not credit money")
    var missed_payments_before := RunStats.missed_payments
    var balance_before_missed_window := RunStats.money_balance
    CallManager.reset()
    CallManager.set("_event_index", 1)
    CallManager.call("_start_question")
    CallManager.call("_miss_question")
    assert(RunStats.missed_payments == missed_payments_before + 1, "Missed THE Payment is not recorded")
    assert(RunStats.money_balance < balance_before_missed_window, "Missed THE Payment does not reduce balance")
    CallManager.reset()
    RitaSleep.reset()
    var hold_probe := RigidBody3D.new()
    hold_probe.name = "HeldItemProbe"
    hold_probe.mass = 1.0
    builder.add_child(hold_probe)
    player.set("held_item", hold_probe)
    player.set("_held_rotation_offset", Vector3.ZERO)
    player.call("_rotate_held_item")
    var rotated_offset := player.get("_held_rotation_offset") as Vector3
    assert(absf(rotated_offset.y - deg_to_rad(45.0)) < 0.01, "R does not rotate a held item by 45 degrees")
    player.call("_update_held_item", 1.0)
    player.call("_update_view_hands", 1.0)
    var held_distance := player_camera.global_position.distance_to(hold_probe.global_position)
    assert(held_distance >= 0.70 and held_distance <= 1.10, "Held object is not positioned between the visible hands")
    player.set("held_item", null)
    hold_probe.queue_free()
    var push_probe := RigidBody3D.new()
    push_probe.name = "HeavyPushProbe"
    push_probe.mass = 58.0
    push_probe.collision_layer = 2
    push_probe.collision_mask = 3
    push_probe.axis_lock_angular_x = true
    push_probe.axis_lock_angular_z = true
    var probe_collision := CollisionShape3D.new()
    var probe_shape := BoxShape3D.new()
    probe_shape.size = Vector3(0.8, 0.8, 0.8)
    probe_collision.shape = probe_shape
    push_probe.add_child(probe_collision)
    builder.add_child(push_probe)
    push_probe.global_position = Vector3(0.0, 0.52, -4.8)
    player.global_position = Vector3(0.0, 0.08, -3.2)
    player.global_rotation = Vector3.ZERO
    player.call("_begin_heavy_grab", push_probe, push_probe.global_position + Vector3(0.0, 0.0, 0.38))
    assert(bool(push_probe.get_meta("felt_pads", false)), "Felt pads are not installed when furniture is grabbed")
    Input.action_press("pickup")
    Input.action_press("move_forward")
    var push_start := push_probe.global_position
    for _frame in range(30):
        # This is a physics assertion: render/process frames can run many
        # times before a single fixed physics tick in headless mode.
        await get_tree().physics_frame
    var push_velocity := Vector2(push_probe.linear_velocity.x, push_probe.linear_velocity.z).length()
    var push_distance := Vector2(push_probe.global_position.x - push_start.x, push_probe.global_position.z - push_start.z).length()
    Input.action_release("move_forward")
    Input.action_release("pickup")
    player.call("_stop_pushing")
    print("HEAVY_GRAB_TEST velocity=%.3f distance=%.3f" % [push_velocity, push_distance])
    if push_velocity <= 0.25 or push_distance <= 0.10:
        push_error("58 kg object failed physical grab test")
        get_tree().quit(8)
        return
    push_probe.queue_free()
    var microwave := builder.find_child("Microwave", true, false) as Node3D
    var kettle_item := builder._objects.get("kettle") as Node3D
    assert(microwave != null and kettle_item != null and microwave.global_position.distance_to(kettle_item.global_position) > 0.55, "Kettle overlaps the microwave")
    var map_panel := hud.get("apartment_map") as Control
    var route_target: Dictionary = map_panel.call("_resolve_urgent_target")
    assert(route_target.get("node") is Node3D, "Apartment map cannot resolve the current urgent destination")
    QuestManager.reset()
    QuestManager.register_mug()
    QuestManager.register_coffee()
    QuestManager.register_milk()
    QuestManager.kettle_filled = true
    QuestManager.water_boiled = true
    var route_mug := builder._objects.get("mug") as RigidBody3D
    var route_mug_position := route_mug.global_position
    route_mug.held = false
    route_mug.global_position = Vector3(-5.4, 0.8, 1.8)
    assert(not QuestManager.get_objective().contains("ЗОН"), "Quest objective still depends on a brewing zone")
    var lost_mug_target: Dictionary = map_panel.call("_resolve_urgent_target")
    assert(lost_mug_target.get("node") == route_mug, "Apartment map does not route to the actual position of a lost mug")
    route_mug.global_position = route_mug_position
    var water_action := builder._objects.get("water") as Node3D
    var fill_kettle := builder._objects.get("kettle") as RigidBody3D
    assert(water_action != null and fill_kettle != null, "Running-water test fixtures are missing")
    var fill_kettle_transform := fill_kettle.global_transform
    var money_before_flood := RunStats.money_balance
    var floods_before := RunStats.kitchen_floods
    QuestManager.reset()
    fill_kettle.held = true
    fill_kettle.freeze = true
    var fill_catch_area := water_action.get_node("WaterCatchArea") as Area3D
    fill_kettle.global_position = fill_catch_area.global_position - Vector3(0.0, 0.29, 0.0)
    fill_kettle.global_rotation = Vector3.ZERO
    fill_kettle.set_meta("fill_progress", 0.0)
    fill_kettle.set_meta("filled", false)
    water_action.set("water_fill_progress", 0.0)
    water_action.set("overflow_progress", 0.0)
    water_action.set("kitchen_flooded", false)
    await get_tree().physics_frame
    await get_tree().physics_frame
    assert(fill_catch_area.get_overlapping_areas().has(fill_kettle.get_node("KettleOpeningArea")), "Kettle opening has no physical overlap with the faucet stream")
    assert(water_action.call("_kettle_under_faucet") == fill_kettle, "Faucet does not detect a kettle held under the stream")
    assert(String(water_action.call("get_prompt", player)).contains("ВКЛЮЧИТЬ ВОДУ"), "Held kettle hides the faucet activation prompt")
    assert(String(water_action.call("_toggle_water")).contains("ВОДА ОТКРЫТА"), "Faucet cannot start with the kettle underneath")
    assert(bool(water_action.get_node("WaterStream").visible), "Running faucet has no visible water stream")
    water_action.call("_process_water", 4.0)
    var filling_state: Dictionary = water_action.call("get_appliance_state")
    assert(bool(filling_state.get("active", false)) and absf(float(filling_state.get("value", 0.0)) - 66.7) < 1.0, "Kettle fill progress is not gradual or visible")
    fill_kettle.held = false
    water_action.call("_process_water", 4.1)
    assert(QuestManager.kettle_filled and bool(fill_kettle.get_meta("filled", false)), "A physically full kettle is not registered")
    water_action.call("_process_water", 11.2)
    assert(bool(water_action.get("kitchen_flooded")) and RunStats.kitchen_floods == floods_before + 1, "An unattended running faucet cannot flood the kitchen")
    assert(RunStats.money_balance <= money_before_flood - 649.9, "Kitchen flood has no financial consequence")
    assert(String(water_action.call("_toggle_water")).contains("КРАН ЗАКРЫТ") and not bool(water_action.get_node("WaterStream").visible), "Flooding faucet cannot be shut off")
    var refill_volume := fill_kettle.get_node("ContainerVolume") as ContainerVolume
    var refill_state := fill_kettle.get_node("KettleStateMachine") as KettleStateMachine
    refill_state.state = KettleStateMachine.KettleState.HELD
    assert(refill_state.transition_to(KettleStateMachine.KettleState.POURING), "Filled kettle cannot enter the missed-pour state")
    refill_volume.drain()
    assert(refill_state.state == KettleStateMachine.KettleState.EMPTY and float(fill_kettle.get_meta("fill_progress", -1.0)) == 0.0, "Empty kettle keeps the stale 100% state after a complete miss")
    QuestManager.notify_water_insufficient()
    water_action.set("overflow_progress", 0.0)
    water_action.set("kitchen_flooded", false)
    water_action.call("_update_flood_visual")
    water_action.set("water_fill_progress", 100.0)
    assert(String(water_action.call("_toggle_water")).contains("ВОДА ОТКРЫТА"), "Faucet cannot restart for a retry")
    water_action.call("_process_water", 3.0)
    var refill_hud_state: Dictionary = water_action.call("get_appliance_state")
    assert(absf(float(refill_hud_state.get("value", -1.0)) - 50.0) < 1.0, "Second kettle fill is not reflected by the fill gauge")
    water_action.call("_process_water", 3.1)
    assert(refill_volume.current_ml >= 299.0 and QuestManager.kettle_filled, "Kettle cannot be filled for a second attempt after pouring everything past the mug")
    water_action.call("_toggle_water")
    water_action.set("water_fill_progress", 0.0)
    water_action.set("overflow_progress", 0.0)
    water_action.set("kitchen_flooded", false)
    water_action.call("_update_flood_visual")
    RunStats.money_balance = money_before_flood
    RunStats.kitchen_floods = floods_before
    fill_kettle.global_transform = fill_kettle_transform
    fill_kettle.set_meta("fill_progress", 0.0)
    fill_kettle.set_meta("filled", false)
    QuestManager.reset()
    QuestManager.register_mug()
    QuestManager.register_coffee()
    QuestManager.fill_kettle()
    var kettle_body := builder._objects.get("kettle") as RigidBody3D
    var kettle_base_action := builder._objects.get("kettle_base") as Node
    assert(kettle_body != null and kettle_base_action != null, "Kettle boiling test fixtures are missing")
    assert(QuestManager.start_kettle() == "ЧАЙНИК ВКЛЮЧЁН", "Kettle could not start for removal regression test")
    kettle_body.set_meta("boiling", true)
    kettle_body.held = true
    kettle_base_action.set("_kettle_ref", kettle_body)
    kettle_base_action.set("_kettle_elapsed", 0.0)
    kettle_base_action.call("_process", 4.0)
    var boiling_state: Dictionary = kettle_base_action.call("get_appliance_state")
    assert(bool(boiling_state.get("active", false)) and absf(float(boiling_state.get("value", 0.0)) - 50.0) < 1.0, "Kettle boiling stage has no readable progress")
    kettle_base_action.call("_on_kettle_tick")
    assert(not QuestManager.kettle_boiling and not bool(kettle_body.get_meta("boiling", false)), "Kettle keeps boiling after it is removed from the base")
    kettle_body.held = false
    RitaSleep.reset()
    assert(QuestManager.start_kettle() == "ЧАЙНИК ВКЛЮЧЁН", "Kettle cannot restart after interrupted heating")
    kettle_base_action.call("_start_kettle_cycle", kettle_body)
    var kettle_timer := kettle_base_action.get("_kettle_timer") as Timer
    kettle_timer.stop()
    QuestManager.finish_boiling()
    kettle_body.set_meta("boiling", false)
    kettle_base_action.call("_process_kettle", 5.0)
    var overboil_state: Dictionary = kettle_base_action.call("get_appliance_state")
    assert(bool(overboil_state.get("danger", false)) and float(kettle_base_action.get("_overboil_elapsed")) >= 4.9, "Forgotten kettle does not enter noisy overboil state")
    assert(String(NoiseManager.last_noise.get("source_id", "")) == "kettle_overboil", "Overboiling kettle does not emit escalating noise")
    var boil_volume := kettle_body.get_node("ContainerVolume") as ContainerVolume
    var boil_before := boil_volume.current_ml
    kettle_base_action.call("_process_kettle", 12.0)
    assert(absf((boil_before - boil_volume.current_ml) - 17.0) < 0.2, "Boil-away delay/rate is not 7 seconds then 1.7 ml/s")
    kettle_body.held = true
    var removed_volume := boil_volume.current_ml
    kettle_base_action.call("_process_kettle", 0.1)
    assert(not bool(kettle_base_action.get("_kettle_powered")) and float(kettle_base_action.get("_cooling_elapsed")) > 0.0, "Removed boiled kettle does not begin cooling")
    kettle_base_action.call("_process_kettle", 5.0)
    assert(is_equal_approx(boil_volume.current_ml, removed_volume), "Water keeps boiling away after the kettle leaves the powered base")
    kettle_base_action.call("_process_kettle", 23.0)
    assert(not QuestManager.water_boiled and QuestManager.kettle_filled, "Cooled kettle stays permanently boiled or loses its water")
    kettle_body.held = false
    assert(QuestManager.start_kettle() == "ЧАЙНИК ВКЛЮЧЁН", "Cooled water cannot be boiled again")
    QuestManager.cancel_boiling()
    kettle_base_action.set("_kettle_powered", false)
    kettle_body.set_meta("heat", 0.0)
    boil_volume.add_liquid(maxf(0.0, 300.0 - boil_volume.current_ml), WATER_DEF)
    var dry_state := kettle_body.get_node("KettleStateMachine") as KettleStateMachine
    dry_state.state = KettleStateMachine.KettleState.BOILED
    dry_state.temperature_c = 100.0
    QuestManager.kettle_filled = true
    QuestManager.water_boiled = true
    kettle_body.held = false
    kettle_base_action.set("_kettle_ref", kettle_body)
    kettle_base_action.set("_kettle_powered", true)
    kettle_base_action.set("_overboil_elapsed", 7.0)
    kettle_base_action.call("_process_kettle", 180.0)
    assert(boil_volume.is_empty() and dry_state.state == KettleStateMachine.KettleState.DRY, "Forgotten kettle never reaches DRY")
    assert(not bool(kettle_base_action.get("_kettle_powered")) and not QuestManager.water_boiled, "Dry kettle does not auto-switch off/reset the route")
    assert(dry_state.transition_to(KettleStateMachine.KettleState.FILLING), "Dry kettle cannot be refilled")
    boil_volume.add_liquid(50.0, WATER_DEF)
    assert(boil_volume.current_ml >= 49.9, "Dry kettle rejects refill water")
    RitaDemands.reset()
    RunStats.run_active = false
    RitaDemands.assign_after_wake(&"order_food")
    assert(not RitaDemands.has_active_demand(), "A deferred Rita demand can start after the run is over")
    RunStats.run_active = true
    RitaSleep.reset()
    RitaSleep.add_noise(10.0, &"TEST", &"test")
    assert(RitaSleep.wake_level >= 9.9 and RitaSleep.wake_level <= 10.1, "Wake level failed")
    RitaSleep.reset()
    QuestManager.reset()
    MilkDelivery.reset()
    CoffeeDelivery.reset()
    assert(QuestManager.brew_coffee() == "СНАЧАЛА НУЖНА КРУЖКА", "Quest order guard failed")
    QuestManager.register_mug()
    QuestManager.register_coffee()
    var delivery_jar := builder._objects.get("coffee") as RigidBody3D
    var delivery_emitter := delivery_jar.get_node("CoffeePowderEmitter") as CoffeePowderEmitter
    delivery_emitter.refill()
    delivery_emitter.remove_powder(delivery_emitter.capacity_g)
    assert(CoffeeDelivery.needs_coffee(), "Empty coffee jar does not unlock laptop ordering")
    var coffee_balance_before := RunStats.money_balance
    assert(CoffeeDelivery.order_coffee().contains("КОФЕ ЗАКАЗАН"), "Coffee cannot be ordered from the laptop flow")
    assert(RunStats.money_balance < coffee_balance_before and CoffeeDelivery.state == CoffeeDelivery.DeliveryState.ON_THE_WAY, "Coffee order has no price or courier wait")
    CoffeeDelivery.force_arrival_for_test()
    var coffee_pickup := get_tree().get_first_node_in_group("coffee_delivery_pickup") as Node3D
    assert(coffee_pickup != null and coffee_pickup.visible, "Coffee courier does not leave a visible box")
    assert(CoffeeDelivery.collect_coffee().contains("НОВАЯ БАНКА КОФЕ"), "Delivered coffee cannot be collected")
    assert(not coffee_pickup.visible and is_equal_approx(delivery_emitter.remaining_g, delivery_emitter.capacity_g), "Coffee box remains or jar is not refilled")
    assert(delivery_jar.global_position.distance_to(Vector3(0.45, 0.34, 5.86)) < 0.05, "Courier coffee jar is not placed by the entry")
    assert(delivery_emitter.get_flow_rate(38.0) > 0.0 and delivery_emitter.get_flow_rate(70.0) <= 4.81, "Gentle coffee powder flow is not controllable")
    var milk_balance_before := RunStats.money_balance
    assert(MilkDelivery.order_milk().contains("МОЛОКО ЗАКАЗАНО"), "Milk cannot be ordered from the laptop flow")
    assert(RunStats.money_balance < milk_balance_before and MilkDelivery.state == MilkDelivery.DeliveryState.ON_THE_WAY, "Milk order has no price or delivery wait")
    MilkDelivery.force_arrival_for_test()
    var milk_pickup := get_tree().get_first_node_in_group("milk_delivery_pickup") as Node3D
    assert(MilkDelivery.state == MilkDelivery.DeliveryState.AT_DOOR and milk_pickup != null and milk_pickup.visible, "Courier does not arrive with a visible milk bag")
    var wake_before_doorbell := RitaSleep.wake_level
    MilkDelivery.force_ring_for_test()
    assert(RitaSleep.wake_level > wake_before_doorbell and String(NoiseManager.last_noise.get("source_id", "")) == "doorbell", "Courier doorbell does not wake Rita through apartment acoustics")
    assert(MilkDelivery.collect_milk().contains("МОЛОКО ЗАБРАНО"), "Player cannot collect the required milk (collect_milk returned wrong text)")
    assert(not milk_pickup.visible, "Milk bag remains at the door after collection")
    # Physical milk carton should now be visible at the door; player must carry it to the coffee zone.
    var milk_carton := builder._objects.get("milk_carton") as RigidBody3D
    assert(milk_carton != null and milk_carton.visible, "Physical milk carton not revealed after courier collection")
    milk_carton.call("on_picked_up")
    assert(QuestManager.has_milk, "Milk not registered when physical carton is picked up via on_picked_up")
    RitaSleep.reset()
    assert(QuestManager.fill_kettle() == "ЧАЙНИК НАПОЛНЕН", "Kettle fill route failed")
    assert(QuestManager.start_kettle() == "ЧАЙНИК ВКЛЮЧЁН", "Kettle start route failed")
    QuestManager.finish_boiling()
    var finish_mug := builder._objects.get("mug") as RigidBody3D
    var finish_kettle := builder._objects.get("kettle") as RigidBody3D
    assert(finish_mug != null and finish_kettle != null, "Coffee finish fixtures are missing")
    assert(get_tree().get_nodes_in_group("coffee_powder_station").is_empty(), "Legacy coffee powder station still intercepts interaction")
    assert(get_tree().get_nodes_in_group("water_pour_station").is_empty(), "Legacy water pour station still intercepts interaction")
    assert(get_tree().get_nodes_in_group("milk_pour_station").is_empty(), "Legacy milk pour station still intercepts interaction")
    finish_mug.held = false
    finish_mug.freeze = true
    finish_kettle.held = false
    finish_kettle.freeze = true
    var finish_content := finish_mug.get_node("MugContentController") as MugContentController
    var finish_receiver := finish_mug.get_node("MugOpening/OpeningReceiverArea") as LiquidReceiver
    var test_surfaces := {
        "kitchen_counter": Vector3(5.10, 1.20, -5.10),
        "dining_table": Vector3(5.00, 0.90, -0.10),
        "work_desk": Vector3(-5.20, 0.92, -5.10),
        "hall_console": Vector3(-1.30, 1.12, 5.05),
        "living_floor": Vector3(-3.80, 0.18, 1.25),
    }
    for surface_name in test_surfaces:
        finish_content.empty()
        finish_mug.global_position = test_surfaces[surface_name]
        finish_mug.global_rotation = Vector3.ZERO
        await get_tree().physics_frame
        assert(finish_receiver.on_powder_hit(3.5) > 3.49, "%s rejected coffee powder without a kitchen zone" % surface_name)
        assert(absf(finish_receiver.on_liquid_hit(200.0, load("res://resources/liquids/water.tres"), 95.0) - 200.0) < 0.01, "%s rejected hot water without a kitchen zone" % surface_name)
        assert(absf(finish_receiver.on_liquid_hit(40.0, load("res://resources/liquids/milk.tres"), 8.0) - 40.0) < 0.01, "%s rejected milk without a kitchen zone" % surface_name)
        assert(absf(finish_content.water_ml - 200.0) < 0.01 and absf(finish_content.milk_ml - 40.0) < 0.01 and finish_content.coffee_powder_g >= 3.49, "%s did not retain physical mug contents" % surface_name)
    finish_content.empty()
    finish_mug.global_rotation_degrees.z = 90.0
    await get_tree().physics_frame
    assert(finish_receiver.on_powder_hit(3.0) <= 0.0 and finish_receiver.on_liquid_hit(20.0, load("res://resources/liquids/water.tres"), 95.0) <= 0.0, "A mug lying on its side accepts ingredients")
    finish_mug.global_rotation = Vector3.ZERO
    finish_content.add_powder(3.5)
    finish_receiver.on_liquid_hit(200.0, load("res://resources/liquids/water.tres"), 95.0)
    var partial_water := finish_content.water_ml
    finish_mug.global_position = Vector3(-3.80, 0.18, 1.25)
    await get_tree().physics_frame
    assert(is_equal_approx(finish_content.water_ml, partial_water) and finish_content.coffee_powder_g >= 3.49, "Moving the story mug resets partial coffee progress")
    finish_receiver.on_liquid_hit(40.0, load("res://resources/liquids/milk.tres"), 8.0)
    assert(finish_content.temperature_c >= MugContentController.TEMP_MIN_C, "Milk mixing cooled the coffee below the readiness threshold")
    var finish_spoon := builder._objects.get("spoon") as RigidBody3D
    var finish_tip := finish_spoon.get_node("SpoonTip") as Node3D
    var finish_stir := finish_spoon.get_node("StirController") as StirController
    finish_spoon.held = true
    finish_tip.global_position = finish_mug.to_global(Vector3(0.06, 0.0, 0.0))
    finish_stir.begin_stir(finish_tip, finish_mug, finish_content)
    for stir_step in range(101):
        var stir_angle := TAU * 3.2 * float(stir_step) / 100.0
        finish_tip.global_position = finish_mug.to_global(Vector3(cos(stir_angle) * 0.06, 0.0, sin(stir_angle) * 0.06))
        finish_stir._process(0.03)
    finish_spoon.held = false
    assert(finish_content.is_stirred and finish_stir.get_rotations() >= 3.0, "Three physical spoon rotations were not counted")
    assert(not String(QuestManager.return_to_desk()).contains("ЗАВЕРШЁН"), "Laptop still ends the run before Denis drinks the coffee")
    player.set("held_item", finish_mug)
    finish_mug.call("on_picked_up")
    assert(player.call("_can_drink_held_coffee"), "Finished mug cannot be drunk away from the former coffee zone")
    assert(player.call("begin_drink_coffee", finish_mug), "Held finished coffee cannot start the drinking animation")
    player.set("_drink_elapsed", 2.14)
    player.call("_update_drink_animation", 0.02)
    assert(QuestManager.coffee_drunk and not RunStats.run_active, "The run does not finish after the complete coffee sip")
    assert(finish_content.total_liquid_ml() <= 0.01, "Coffee remains in the mug after it was drunk")
    var sorted_board: Array = RunStats.sort_leaderboard_entries([
        {"name": "BALANCE", "time": 70.0, "balance": 900.0, "score": 100},
        {"name": "FAST", "time": 60.0, "balance": -500.0, "score": 50},
        {"name": "TIE", "time": 70.0, "balance": 1200.0, "score": 10}
    ])
    assert(String(sorted_board[0].get("name")) == "FAST" and String(sorted_board[1].get("name")) == "TIE", "Leaderboard is not sorted by time and then balance")
    assert(hud.get("player_name_edit") is LineEdit and hud.get("result_leaderboard_label") is Label, "Final name entry or leaderboard table is missing")
    var test_cat := builder._objects.get("rita_cat") as RitaCat
    assert(test_cat != null and test_cat.body_controller != test_cat.intention_controller, "RitaCat BODY STATE and INTENTION are not separate controllers")
    assert(test_cat.story_director.stories.size() == 9, "RitaCat does not own eight deck stories plus the isolated flood reaction")
    var deck_probe := CatStoryDeck.new()
    for deck_seed in [101, 202, 303]:
        var probe_cards := deck_probe.build_deck(deck_seed, 4)
        assert(probe_cards.size() == 4, "RitaCat deck does not select four bounded stories")
        var used_categories: Dictionary = {}
        for probe_card in probe_cards:
            for probe_category in CatStoryDeck.CATEGORIES:
                if probe_card in CatStoryDeck.CATEGORIES[probe_category]:
                    assert(not used_categories.has(probe_category), "RitaCat deck selected two stories from one category")
                    used_categories[probe_category] = true
        assert(used_categories.size() == 4, "RitaCat deck omitted or duplicated a category")
        assert(&"FLOOD_ESCAPE_STORY" not in probe_cards, "Emergency flood reaction incorrectly consumes a random-prank deck slot")
    deck_probe.free()
    test_cat.story_director.abort_current(&"flood_story_test")
    flood_visual.set_flood_state(true, 3, 70.0, 4000.0, true)
    for _cat_flood_rise in range(12):
        flood_visual.call("_process", 0.25)
    assert(test_cat.story_director.force_story(&"FLOOD_ESCAPE_STORY"), "RitaCat does not react to a real apartment flood")
    var flood_cat_story := test_cat.story_director.active_story as CatFloodEscapeStory
    flood_cat_story.advance(12.1)
    assert(flood_cat_story.phase == CatStory.Phase.TELEGRAPH, "Flood cat story has no warning phase near the mop")
    flood_cat_story.advance(3.3)
    cleanup_mop.set("held", true)
    flood_cat_story.advance(0.7)
    assert(cleanup_mop.get("item_id") == &"mop" and bool(cleanup_mop.get("held")), "Flood cat can steal or invalidate the mandatory mop")
    flood_cat_story.player_resolve(&"test_player")
    assert(test_cat.story_director.active_story == null, "Flood reaction cannot be resolved by reassuring the cat")
    cleanup_mop.set("held", false)
    flood_visual.set_flood_state(false, 0, 0.0, 0.0, false)
    print("RITA_CAT_STORY_SYSTEM_TESTS_OK")
    print("DENIS_FOUNDATION_TESTS_OK")
    print("DENIS_COMPLETE_PROJECT_TESTS_OK")
    get_tree().quit(0)
