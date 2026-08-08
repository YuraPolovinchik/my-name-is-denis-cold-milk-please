extends Node3D

const PLAYER_CONTROLLER_SCRIPT := preload("res://scripts/player_controller.gd")
const HINGED_DOOR_SCRIPT := preload("res://scripts/interactions/hinged_door.gd")
const DRAWER_SCRIPT := preload("res://scripts/interactions/drawer.gd")
const PHYSICAL_ITEM_SCRIPT := preload("res://scripts/interactions/physical_item.gd")
const SIMPLE_ACTION_SCRIPT := preload("res://scripts/interactions/simple_action.gd")
const HOUSEHOLD_HAZARD_SCRIPT := preload("res://scripts/interactions/household_hazard.gd")
const WASHING_MACHINE_SCRIPT := preload("res://scripts/interactions/washing_machine.gd")
const TELEVISION_SCRIPT := preload("res://scripts/interactions/television.gd")
const MOVABLE_FURNITURE_SCRIPT := preload("res://scripts/interactions/movable_furniture.gd")
const HIDE_SPOT_SCRIPT := preload("res://scripts/interactions/hide_spot.gd")
const CASH_PICKUP_SCRIPT := preload("res://scripts/interactions/cash_pickup.gd")
const MATCH_BEER_SCRIPT := preload("res://scripts/interactions/match_beer.gd")
const SMART_TV_SCRIPT := preload("res://scripts/interactions/smart_tv.gd")
const HEADPHONES_SCRIPT := preload("res://scripts/interactions/noise_cancelling_headphones.gd")
const SMART_KETTLE_SCRIPT := preload("res://scripts/interactions/smart_kettle.gd")
const CONTAINER_VOLUME_SCRIPT := preload("res://scripts/liquid/container_volume.gd")
const LIQUID_RECEIVER_SCRIPT := preload("res://scripts/liquid/liquid_receiver.gd")
const LIQUID_SURFACE_SCRIPT := preload("res://scripts/liquid/liquid_surface.gd")
const MUG_CONTENT_SCRIPT := preload("res://scripts/coffee/mug_content_controller.gd")
const COFFEE_POWDER_EMITTER_SCRIPT := preload("res://scripts/coffee/coffee_powder_emitter.gd")
const SPILL_MANAGER_SCRIPT := preload("res://scripts/liquid/spill_manager.gd")
const APARTMENT_FLOOD_VISUAL_SCRIPT := preload("res://scripts/liquid/apartment_flood_visual.gd")
const KETTLE_STATE_MACHINE_SCRIPT := preload("res://scripts/liquid/kettle_state_machine.gd")
const STIR_CONTROLLER_SCRIPT := preload("res://scripts/coffee/stir_controller.gd")
const PAYMENT_ALTAR_ROOM_SCENE := preload("res://assets/payment_altar/scenes/payment_altar_room.tscn")
const KITCHEN_TOWEL_SCENE := preload("res://scenes/props/kitchen_towel.tscn")
const BATHROOM_MOP_SCENE := preload("res://scenes/props/bathroom_mop.tscn")
const HALLWAY_PHONE_SCENE := preload("res://scenes/props/hallway_phone.tscn")
const RITA_CAT_SCENE := preload("res://characters/rita_cat/rita_cat.tscn")
const WATER_DEF := preload("res://resources/liquids/water.tres")
const MILK_DEF := preload("res://resources/liquids/milk.tres")
const DEBUG_START_KETTLE_READY := false

var _materials: Dictionary = {}
var _objects: Dictionary = {}
var _cash_spawn_timer := 22.0
var _cash_spawn_serial := 0
var _cash_spawn_cursor := 0
var _cash_spawn_points := [
    Vector3(-6.35, 0.10, -4.25),
    Vector3(-3.10, 0.10, -0.85),
    Vector3(-6.20, 0.10, 1.45),
    Vector3(-0.72, 0.16, -2.95),
    Vector3(0.72, 0.16, 1.45),
    Vector3(2.65, 0.10, -1.15),
    Vector3(6.80, 0.10, -1.35),
    Vector3(3.10, 0.10, 3.00),
    Vector3(6.65, 0.10, 5.60),
    Vector3(-2.45, 0.10, 3.25),
    Vector3(-6.05, 0.10, 5.95),
    Vector3(-3.20, 0.10, 8.70)
]

func build_world() -> Dictionary:
    _create_materials()
    _create_environment()
    _create_architecture()
    _create_living_office()
    _create_corridor()
    _create_kitchen()
    _create_closed_rooms()
    _create_walk_in_wardrobe()
    _create_payment_altar_room()
    _create_lived_in_details()
    _create_gameplay_objects()
    _configure_rooms()
    _create_rita_cat_zone()
    AudioManager.create_ambience(self)
    return _objects

func _process(delta: float) -> void:
    if not RunStats.run_active or _materials.is_empty():
        return
    _cash_spawn_timer -= delta
    if _cash_spawn_timer > 0.0:
        return
    var debt_mode := RunStats.money_balance < 0.0
    var active_limit := 7 if debt_mode else 4
    if get_tree().get_nodes_in_group("dynamic_cash").size() < active_limit:
        _spawn_dynamic_cash()
    _cash_spawn_timer = randf_range(10.0, 17.0) if debt_mode else randf_range(24.0, 38.0)

func _create_materials() -> void:
    _materials = {
        "wall": _material(Color("d8d2c8"), 0.88),
        "wall_warm": _material(Color("b9a998"), 0.92),
        "accent": _material(Color("273c48"), 0.82),
        "ceiling": _material(Color("e8e3da"), 0.94),
        "oak": _material(Color("805331"), 0.72),
        "oak_light": _material(Color("a87345"), 0.70),
        "oak_dark": _material(Color("5d3823"), 0.76),
        "tile": _material(Color("9fa3a1"), 0.78),
        "tile_dark": _material(Color("777d7c"), 0.82),
        "cabinet": _material(Color("53675e"), 0.74),
        "cabinet_dark": _material(Color("26332f"), 0.76),
        "counter": _material(Color("d4cec0"), 0.44),
        "counter_edge": _material(Color("948c7d"), 0.52),
        "sofa": _material(Color("526353"), 0.96),
        "fabric_blue": _material(Color("3f5c72"), 0.98),
        "fabric_rust": _material(Color("a5573e"), 0.96),
        "rug": _material(Color("365b62"), 0.98),
        "rug_light": _material(Color("d9b86c"), 0.96),
        "black": _material(Color("191d20"), 0.36),
        "metal": _metal_material(Color("7f898d"), 0.28),
        "water": _glass_material(Color(0.18, 0.72, 1.0, 0.72)),
        "chrome": _metal_material(Color("c4c9c8"), 0.18),
        "white": _material(Color("eeeae2"), 0.58),
        "cream": _material(Color("d7c8ae"), 0.72),
        "brown": _material(Color("4b2416"), 0.58),
        "cardboard": _material(Color("9a7047"), 0.96),
        "coffee": _material(Color("241109"), 0.50),
        "yellow": _material(Color("e5b74f"), 0.72),
        "orange": _material(Color("d4874a"), 0.72),
        "red": _material(Color("a73d36"), 0.64),
        "green": _material(Color("527f4d"), 0.90),
        "leaf": _material(Color("2d6239"), 0.94),
        "bedroom": _material(Color("72525f"), 0.86),
        "mirror": _metal_material(Color("9eb5bb"), 0.12),
        "glass": _glass_material(Color(0.42, 0.62, 0.74, 0.22)),
        "screen": _emissive_material(Color("16375a"), Color("307fd1"), 1.65),
        "warm_light": _emissive_material(Color("ffd39a"), Color("ffb15e"), 1.8),
        "dawn": _emissive_material(Color("202b4b"), Color("b95045"), 0.72),
        "city": _material(Color("111821"), 0.86),
        "city_lit": _emissive_material(Color("d89a55"), Color("e19a4b"), 1.3)
    }

func _create_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("101827")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("70829b")
    env.ambient_light_energy = 0.42
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.08
    world.environment = env
    add_child(world)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-52.0, -22.0, 0.0)
    moon.light_color = Color("8ca9d9")
    moon.light_energy = 0.52
    moon.shadow_enabled = true
    moon.directional_shadow_max_distance = 24.0
    add_child(moon)

    _omni("OfficeFill", Vector3(-3.9, 2.55, -0.8), Color("ffd3a0"), 1.65, 5.8, &"office_lights")
    _omni("DeskLamp", Vector3(-4.6, 1.75, -3.3), Color("ffc078"), 1.15, 3.4, &"office_lights")
    _omni("KitchenMain", Vector3(3.45, 2.55, -1.45), Color("ffd5a4"), 2.25, 6.0, &"kitchen_lights")
    _omni("KitchenCounter", Vector3(3.35, 2.15, -3.65), Color("ffbd70"), 1.0, 3.8, &"kitchen_lights")
    _omni("HallLight", Vector3(0.0, 2.45, 0.4), Color("f1d0ac"), 0.9, 4.4, &"hall_lights")

    # Dawn card and a lightweight skyline visible through both north windows.
    _box("DawnBackdrop", Vector3(0.0, 1.55, -7.60), Vector3(20.0, 4.6, 0.08), "dawn", false)
    for i in range(34):
        var height := 0.45 + float((i * 11) % 12) * 0.16
        var x := -6.7 + float(i) * 0.41
        _box("City_%02d" % i, Vector3(x, height * 0.5, -7.30), Vector3(0.32, height, 0.34), "city", false)
        if i % 3 == 0:
            _box("CityLight_%02d" % i, Vector3(x, minf(height - 0.12, 0.72), -7.10), Vector3(0.055, 0.065, 0.02), "city_lit", false)
    _sphere("DawnGlow", Vector3(6.60, 1.05, -7.25), 0.22, "warm_light", false)

func _create_architecture() -> void:
    # One continuous structural slab; decorative surfaces sit just above it.
    _box("FloorSlab", Vector3(0.0, -0.10, 0.0), Vector3(16.0, 0.20, 13.0), "oak_dark", true)
    _box("Ceiling", Vector3(0.0, 3.02, 0.0), Vector3(16.0, 0.12, 13.0), "ceiling", false)
    _box("WardrobeFloorSlab", Vector3(-4.80, -0.10, 8.0), Vector3(6.40, 0.20, 3.0), "oak_dark", true)
    _box("WardrobeCeiling", Vector3(-4.80, 3.02, 8.0), Vector3(6.40, 0.12, 3.0), "ceiling", false)

    _create_wood_floor(Vector3(-4.80, 0.005, -2.25), Vector2(6.4, 8.5), "office")
    _create_wood_floor(Vector3(-4.80, 0.005, 4.25), Vector2(6.4, 4.5), "bedroom")
    _create_tile_floor(Vector3(0.0, 0.008, 0.0), Vector2(3.2, 13.0), "hall")
    _create_tile_floor(Vector3(4.80, 0.008, -2.25), Vector2(6.4, 8.5), "kitchen")
    _create_tile_floor(Vector3(4.80, 0.008, 4.25), Vector2(6.4, 4.5), "bath")
    _create_wood_floor(Vector3(-4.80, 0.005, 8.0), Vector2(6.4, 3.0), "wardrobe")

    # Outer walls. The north wall is split around two actual windows.
    _wall(Vector3(-8.0, 1.5, 0.0), Vector3(0.18, 3.0, 13.0))
    _wall(Vector3(8.0, 1.5, 0.0), Vector3(0.18, 3.0, 13.0))
    _wall(Vector3(3.35, 1.5, 6.5), Vector3(9.30, 3.0, 0.18))
    _wall(Vector3(-6.71, 1.5, 6.5), Vector3(2.58, 3.0, 0.18))
    _wall(Vector3(-2.59, 1.5, 6.5), Vector3(2.58, 3.0, 0.18))
    _wall(Vector3(-8.0, 1.5, 8.0), Vector3(0.18, 3.0, 3.0))
    _wall(Vector3(-1.60, 1.5, 8.0), Vector3(0.18, 3.0, 3.0))
    # The wardrobe's rear wall hides a mirror-sized doorway. The secret room
    # owns the door itself; these segments close every edge around it.
    _wall(Vector3(-5.97, 1.5, 9.5), Vector3(4.10, 3.0, 0.18))
    _wall(Vector3(-2.02, 1.5, 9.5), Vector3(0.92, 3.0, 0.18))
    _wall(Vector3(-7.20, 1.5, -6.5), Vector3(1.60, 3.0, 0.18))
    _wall(Vector3(-2.25, 1.5, -6.5), Vector3(1.70, 3.0, 0.18))
    _window_wall(Vector3(-4.65, 0.0, -6.5), 3.10)
    # The corridor became wider, so this cap deliberately overlaps the two
    # neighbouring window-wall segments.  Exact coplanar joins produced the
    # bright vertical holes visible from the hallway.
    _box("CorridorNorthCap", Vector3(0.0, 1.5, -6.5), Vector3(3.72, 3.0, 0.22), "wall", true)
    _wall(Vector3(2.25, 1.5, -6.5), Vector3(1.70, 3.0, 0.18))
    _wall(Vector3(7.20, 1.5, -6.5), Vector3(1.60, 3.0, 0.18))
    _window_wall(Vector3(4.65, 0.0, -6.5), 3.10)
    # Close the 20 cm authoring gap between the kitchen window module and the
    # right outer-wall segment. It previously rendered as a bright pink slit.
    var kitchen_window_seam := _box("KitchenWindowSeam", Vector3(6.30, 1.5, -6.5), Vector3(0.28, 3.0, 0.22), "wall", true)
    kitchen_window_seam.add_to_group("wall_hole_patch")

    # Continuous corridor wall runs stop at the jambs instead of overlapping
    # the openings. Small overlap at the outer shell prevents light leaks.
    for wall_x in [-1.60, 1.60]:
        _wall(Vector3(wall_x, 1.5, -4.52), Vector3(0.18, 3.0, 4.16))
        var wall_patch := _box("CorridorWallMiddle", Vector3(wall_x, 1.5, 1.04), Vector3(0.18, 3.0, 4.08), "wall", true)
        wall_patch.add_to_group("wall_hole_patch")
        _wall(Vector3(wall_x, 1.5, 5.56), Vector3(0.18, 3.0, 2.08))
    _wall(Vector3(-4.76, 1.5, 2.0), Vector3(6.48, 3.0, 0.18))
    _wall(Vector3(4.76, 1.5, 2.0), Vector3(6.48, 3.0, 0.18))

    _door_frame(Vector3(-1.60, 0.0, -1.72), true, "oak_dark")
    _door_frame(Vector3(1.60, 0.0, -1.72), true, "oak_dark")
    _door_frame(Vector3(-1.60, 0.0, 3.80), true, "oak_dark")
    _door_frame(Vector3(1.60, 0.0, 3.80), true, "oak_dark")
    _door_frame(Vector3(0.0, 0.0, 6.40), false, "oak_dark")
    _door_frame(Vector3(-4.65, 0.0, 6.50), false, "oak_dark")

    # Baseboards make the rooms read as an apartment rather than a greybox.
    _baseboard(Vector3(-7.84, 0.11, -2.15), Vector3(0.07, 0.20, 8.30))
    _baseboard(Vector3(7.84, 0.11, -2.15), Vector3(0.07, 0.20, 8.30))
    _baseboard(Vector3(-4.80, 0.11, 1.88), Vector3(6.25, 0.20, 0.07))
    _baseboard(Vector3(4.80, 0.11, 1.88), Vector3(6.25, 0.20, 0.07))
    _baseboard(Vector3(-7.84, 0.11, 8.0), Vector3(0.07, 0.20, 2.75))
    _baseboard(Vector3(-1.76, 0.11, 8.0), Vector3(0.07, 0.20, 2.75))
    _baseboard(Vector3(-5.97, 0.11, 9.34), Vector3(3.92, 0.20, 0.07))
    _baseboard(Vector3(-2.03, 0.11, 9.34), Vector3(0.70, 0.20, 0.07))

func _create_living_office() -> void:
    var room := _fixed_root("LivingOffice")
    _box_child(room, "AccentWall", Vector3(-7.89, 1.5, -0.5), Vector3(0.035, 2.72, 3.2), "accent", false)

    # Desk with drawers, cable channel, rounded-looking metal legs and a real laptop action.
    var desk := _furniture_root("WorkDesk", Vector3(-5.65, 0.0, -5.25))
    _box_child(desk, "Top", Vector3(0.0, 0.76, 0.0), Vector3(2.35, 0.10, 0.72), "oak_light", true)
    _box_child(desk, "LeftPedestal", Vector3(-0.91, 0.37, 0.0), Vector3(0.42, 0.72, 0.66), "accent", true)
    for i in range(3):
        _box_child(desk, "DeskDrawer_%d" % i, Vector3(-0.91, 0.59 - float(i) * 0.22, 0.345), Vector3(0.36, 0.17, 0.035), "cabinet_dark", false)
        _box_child(desk, "DeskHandle_%d" % i, Vector3(-0.91, 0.59 - float(i) * 0.22, 0.37), Vector3(0.13, 0.018, 0.025), "metal", false)
    _box_child(desk, "RightLeg", Vector3(0.98, 0.37, 0.0), Vector3(0.07, 0.72, 0.60), "black", true)
    _box_child(desk, "CableTray", Vector3(0.15, 0.59, -0.26), Vector3(1.35, 0.06, 0.10), "black", false)

    var laptop = _action("Laptop", Vector3(-5.55, 0.84, -5.35), "НОУТБУК WONE IT", "laptop")
    laptop.normal_noise = 0.0
    laptop.quiet_noise = 0.0
    laptop.fast_noise = 0.0
    _box_child(laptop, "LaptopBase", Vector3.ZERO, Vector3(0.68, 0.045, 0.48), "black", true)
    _box_child(laptop, "Keyboard", Vector3(0.0, 0.027, 0.02), Vector3(0.56, 0.008, 0.30), "metal", false)
    var screen_pivot := Node3D.new()
    screen_pivot.name = "ScreenPivot"
    screen_pivot.position = Vector3(0.0, 0.02, -0.22)
    screen_pivot.rotation_degrees.x = -12.0
    laptop.add_child(screen_pivot)
    _box_child(screen_pivot, "ScreenCase", Vector3(0.0, 0.28, 0.0), Vector3(0.68, 0.48, 0.035), "black", false)
    _box_child(screen_pivot, "Screen", Vector3(0.0, 0.28, 0.020), Vector3(0.61, 0.40, 0.012), "screen", false)
    var screen_label := _label3d("WONE IT\nDAILY CALL", Vector3(0.0, 0.29, 0.029), Color("d7eeff"), 23)
    screen_label.rotation_degrees.x = 0.0
    screen_pivot.add_child(screen_label)
    _objects["laptop"] = laptop

    # Компактная зона готовой кружки рядом с ноутбуком.
    _create_office_chair(Vector3(-5.65, 0.0, -3.72), 0.0)
    _create_desk_lamp(Vector3(-6.45, 0.82, -5.28))
    _create_notebook_stack(Vector3(-4.75, 0.84, -5.28))

    # Living corner: sofa, rug, coffee table, TV and shelves.
    _create_rug(Vector3(-5.15, 0.025, -0.20), Vector2(3.4, 2.6))
    _create_sofa(Vector3(-7.20, 0.0, -0.20), -90.0)
    _create_coffee_table(Vector3(-5.15, 0.0, -0.20))
    _create_tv_console(Vector3(-1.95, 0.0, -0.20), 90.0)
    _create_bookshelf(Vector3(-6.55, 0.0, 1.45))
    _create_plant(Vector3(-7.25, 0.0, -3.05), 1.0)
    _create_wall_art(Vector3(-7.85, 1.68, -1.15), 90.0)
    _create_city_investigation_board(Vector3(-7.85, 1.15, 0.50), 90.0)

func _create_corridor() -> void:
    var hall := _fixed_root("CorridorShell")
    var hall_runner := _box_child(hall, "Runner", Vector3(0.0, 0.024, 0.65), Vector3(1.35, 0.035, 8.80), "rug", false)
    _mark_soft_surface(hall_runner, Vector2(1.35, 8.80))
    for i in range(13):
        _box_child(hall, "RunnerStripe_%d" % i, Vector3(-0.42 + float(i % 2) * 0.84, 0.045, -2.65 + float(i) * 0.55), Vector3(0.10, 0.012, 0.32), "rug_light", false)

    _box_child(hall, "EntryDoor", Vector3(0.0, 1.08, 6.38), Vector3(1.18, 2.16, 0.12), "accent", true)
    _box_child(hall, "EntryInset", Vector3(0.0, 1.08, 6.305), Vector3(0.82, 1.62, 0.025), "oak_dark", false)
    _cylinder_child(hall, "EntryHandle", Vector3(0.40, 1.05, 6.22), Vector3(90.0, 0.0, 0.0), 0.025, 0.13, "metal", false)
    _box_child(hall, "DoorbellPlate", Vector3(0.72, 1.42, 6.22), Vector3(0.16, 0.24, 0.035), "metal", false)
    _cylinder_child(hall, "DoorbellButton", Vector3(0.72, 1.42, 6.195), Vector3(90.0, 0.0, 0.0), 0.038, 0.025, "red", false)

    # The courier puts the insulated milk bag directly inside the threshold.
    # It is hidden and non-colliding until the delivery state reaches AT_DOOR.
    var milk_pickup = _action("MilkDeliveryPickup", Vector3(0.0, 0.23, 5.91), "ПАКЕТ С МОЛОКОМ", "milk_delivery")
    milk_pickup.normal_noise = 2.5
    milk_pickup.quiet_noise = 0.7
    milk_pickup.fast_noise = 5.5
    milk_pickup.noise_category = &"OBJECT_IMPACT"
    milk_pickup.source_id = &"milk_bag"
    _box_child(milk_pickup, "InsulatedBag", Vector3.ZERO, Vector3(0.50, 0.38, 0.30), "fabric_blue", true)
    _box_child(milk_pickup, "BagMilkCarton", Vector3(0.0, 0.11, -0.17), Vector3(0.22, 0.34, 0.09), "white", false)
    _torus_child(milk_pickup, "BagHandle", Vector3(0.0, 0.24, 0.0), Vector3(90.0, 0.0, 0.0), 0.10, 0.15, "black")
    var milk_pickup_label := _label3d("МОЛОКО", Vector3(0.0, 0.11, -0.222), Color("273c48"), 16)
    milk_pickup.add_child(milk_pickup_label)
    _objects["milk_delivery"] = milk_pickup

    var coffee_pickup = _action("CoffeeDeliveryPickup", Vector3(0.48, 0.24, 5.91), "КОРОБКА С КОФЕ", "coffee_delivery")
    coffee_pickup.normal_noise = 2.0
    coffee_pickup.quiet_noise = 0.6
    coffee_pickup.fast_noise = 4.5
    coffee_pickup.noise_category = &"OBJECT_IMPACT"
    coffee_pickup.source_id = &"coffee_box"
    _box_child(coffee_pickup, "CoffeeBox", Vector3.ZERO, Vector3(0.42, 0.34, 0.34), "cardboard", true)
    _cylinder_child(coffee_pickup, "CoffeeJarPreview", Vector3(0.0, 0.20, 0.0), Vector3.ZERO, 0.10, 0.24, "brown", false)
    var coffee_pickup_label := _label3d("КОФЕ", Vector3(0.0, 0.02, -0.175), Color("ffe4b0"), 16)
    coffee_pickup.add_child(coffee_pickup_label)
    _objects["coffee_delivery"] = coffee_pickup

    # Physical milk carton — hidden until collected from the courier.
    # When the player interacts with the delivery bag, this carton becomes visible
    # and can be picked up physically (registers milk via on_picked_up).
    var milk_carton = _physical_item("MilkCarton", &"milk_carton", "ПАКЕТ МОЛОКА", Vector3(0.0, 0.23, 5.91), "milk_carton", 0.35, false)
    milk_carton.visible = false
    milk_carton.freeze = true
    milk_carton.sleeping = true
    milk_carton.collision_layer = 0
    milk_carton.collision_mask = 0
    _objects["milk_carton"] = milk_carton

    var console := _furniture_root("HallConsole", Vector3(-1.36, 0.0, 5.18))
    _box_child(console, "Body", Vector3.UP * 0.50, Vector3(0.38, 0.86, 0.92), "oak", true)
    _box_child(console, "Top", Vector3(0.0, 0.96, 0.0), Vector3(0.44, 0.07, 1.00), "oak_light", true)
    _box_child(console, "Drawer", Vector3(0.215, 0.68, 0.0), Vector3(0.035, 0.18, 0.72), "cabinet", false)
    _cylinder_child(console, "Knob", Vector3(0.255, 0.68, 0.0), Vector3(0.0, 0.0, 90.0), 0.025, 0.035, "metal", false)

    var bench := _furniture_root("ShoeBench", Vector3(1.35, 0.0, 5.20))
    _box_child(bench, "Body", Vector3(0.0, 0.36, 0.0), Vector3(0.42, 0.66, 1.05), "cabinet_dark", true)
    _box_child(bench, "Cushion", Vector3(-0.02, 0.74, 0.0), Vector3(0.46, 0.12, 1.09), "fabric_rust", true)

    var wardrobe := _furniture_root("Wardrobe", Vector3(-1.35, 1.18, 1.48))
    _box_child(wardrobe, "Body", Vector3.ZERO, Vector3(0.44, 2.32, 1.28), "oak_dark", true)
    _box_child(wardrobe, "Door", Vector3(0.235, 0.0, 0.0), Vector3(0.035, 2.10, 1.12), "oak", false)
    _cylinder_child(wardrobe, "Handle", Vector3(0.275, 0.0, -0.38), Vector3(0.0, 0.0, 90.0), 0.025, 0.18, "metal", false)

    _box_child(hall, "Mirror", Vector3(-1.48, 1.72, 2.62), Vector3(0.035, 1.25, 0.72), "mirror", false)
    for i in range(2):
        _box_child(hall, "HallPhotoFrame_%d" % i, Vector3(1.505, 1.48, -0.72 + float(i) * 1.18), Vector3(0.035, 0.58, 0.76), "oak_dark", false)
        _box_child(hall, "HallPhoto_%d" % i, Vector3(1.482, 1.48, -0.72 + float(i) * 1.18), Vector3(0.012, 0.46, 0.62), ["fabric_blue", "fabric_rust"][i], false)

    _loose_box("Parcel", "ПОСЫЛКА", Vector3(-1.34, 0.18, 5.88), Vector3(0.30, 0.34, 0.44), "cardboard", 0.8)
    _loose_box("Backpack", "РЮКЗАК", Vector3(1.36, 0.28, 5.72), Vector3(0.32, 0.52, 0.25), "fabric_blue", 0.6)
    _loose_box("ShoeLeft", "КРОССОВОК", Vector3(1.20, 0.10, 4.86), Vector3(0.18, 0.14, 0.38), "black", 0.3)
    _loose_box("ShoeRight", "КРОССОВОК", Vector3(1.39, 0.10, 4.70), Vector3(0.18, 0.14, 0.38), "black", 0.3)
    _loose_box("Umbrella", "ЗОНТ", Vector3(1.45, 0.48, 5.90), Vector3(0.10, 0.92, 0.10), "fabric_blue", 0.35)

    var slippers = _action("Slippers", Vector3(1.05, 0.10, 4.60), "ТАПОЧКИ РИТЫ", "slippers")
    slippers.normal_noise = 0.0
    slippers.quiet_noise = 0.0
    slippers.fast_noise = 0.0
    _create_slipper(slippers, "Left", Vector3(-0.15, 0.0, 0.0), -7.0)
    _create_slipper(slippers, "Right", Vector3(0.15, 0.0, -0.05), 8.0)
    _objects["slippers"] = slippers

    var felt_pads = _action("FeltPads", Vector3(1.08, 0.84, 5.05), "ВОЙЛОЧНЫЕ НАКЛАДКИ ДЛЯ МЕБЕЛИ", "felt_pads")
    felt_pads.normal_noise = 0.2
    felt_pads.quiet_noise = 0.05
    felt_pads.fast_noise = 0.8
    _box_child(felt_pads, "Package", Vector3.ZERO, Vector3(0.24, 0.06, 0.18), "cardboard", true)
    for pad_index in range(4):
        _cylinder_child(felt_pads, "Pad_%d" % pad_index, Vector3(-0.07 + float(pad_index % 2) * 0.14, 0.04, -0.045 + float(pad_index / 2) * 0.09), Vector3.ZERO, 0.035, 0.012, "brown", false)
    _objects["felt_pads"] = felt_pads

    var hinge_oil = _action("HingeOil", Vector3(1.30, 0.95, 5.42), "СМАЗКА ДЛЯ ДВЕРНЫХ ПЕТЕЛЬ", "hinge_oil")
    hinge_oil.normal_noise = 0.3
    hinge_oil.quiet_noise = 0.05
    hinge_oil.fast_noise = 1.0
    _cylinder_child(hinge_oil, "Can", Vector3.ZERO, Vector3.ZERO, 0.055, 0.24, "yellow", true)
    _cylinder_child(hinge_oil, "Cap", Vector3(0.0, 0.14, 0.0), Vector3.ZERO, 0.04, 0.04, "black", false)
    _objects["hinge_oil"] = hinge_oil
func _create_kitchen() -> void:
    # The complete L is authored as one root and pushed into the north/east
    # walls.  The previous offset left a deep unusable slot behind both runs,
    # so loose props could fall into it and the cabinetry looked like an island.
    var kitchen := _fixed_root("KitchenFurniture", Vector3(2.35, 0.0, -2.05))

    # North run of full-depth lower cabinets and worktop.
    _box_child(kitchen, "LowerBack", Vector3(2.96, 0.48, -4.33), Vector3(3.40, 0.90, 0.07), "cabinet_dark", true)
    _box_child(kitchen, "LowerBottom", Vector3(2.96, 0.08, -4.02), Vector3(3.40, 0.08, 0.62), "cabinet_dark", true)
    for side_x in [1.27, 2.68, 3.62, 4.65]:
        _box_child(kitchen, "LowerSide_%s" % str(side_x), Vector3(side_x, 0.48, -4.02), Vector3(0.07, 0.82, 0.62), "cabinet_dark", true)
    _box_child(kitchen, "LowerShelfLeft", Vector3(1.96, 0.48, -4.02), Vector3(1.30, 0.055, 0.58), "oak_light", true)
    _box_child(kitchen, "LowerShelfRight", Vector3(4.13, 0.48, -4.02), Vector3(0.94, 0.055, 0.58), "oak_light", true)
    _box_child(kitchen, "DrawerBayBack", Vector3(3.15, 0.48, -4.33), Vector3(0.86, 0.90, 0.08), "cabinet_dark", true)
    _box_child(kitchen, "DrawerBayLeft", Vector3(2.69, 0.48, -4.02), Vector3(0.08, 0.90, 0.70), "cabinet_dark", true)
    _box_child(kitchen, "DrawerBayRight", Vector3(3.61, 0.48, -4.02), Vector3(0.08, 0.90, 0.70), "cabinet_dark", true)
    _box_child(kitchen, "DrawerShelf", Vector3(3.15, 0.49, -3.98), Vector3(0.82, 0.06, 0.58), "oak", true)
    _box_child(kitchen, "CounterTop", Vector3(3.04, 0.98, -3.98), Vector3(3.72, 0.10, 0.82), "counter", true)
    _box_child(kitchen, "CounterEdge", Vector3(3.04, 0.98, -3.54), Vector3(3.76, 0.12, 0.055), "counter_edge", false)
    _box_child(kitchen, "DishwasherCavity", Vector3(1.62, 0.48, -4.16), Vector3(0.58, 0.68, 0.30), "black", false)
    _box_child(kitchen, "DishwasherRack", Vector3(1.62, 0.46, -4.00), Vector3(0.52, 0.06, 0.38), "metal", false)
    _create_dishwasher_door(kitchen, Vector3(1.29, 0.15, -3.64), Vector2(0.66, 0.76))
    _create_cabinet_door(kitchen, "LowerDoorRightA", Vector3(3.65, 0.15, -3.64), Vector2(0.48, 0.76), false)
    _create_cabinet_door(kitchen, "LowerDoorRightB", Vector3(4.61, 0.15, -3.64), Vector2(0.48, 0.76), true)

    # Oven and induction hob.
    _box_child(kitchen, "Oven", Vector3(2.18, 0.53, -3.59), Vector3(0.82, 0.80, 0.08), "black", false)
    _box_child(kitchen, "OvenGlass", Vector3(2.18, 0.48, -3.535), Vector3(0.64, 0.42, 0.018), "glass", false)
    for i in range(4):
        _cylinder_child(kitchen, "Hob_%d" % i, Vector3(1.95 + float(i % 2) * 0.45, 1.045, -4.16 + float(i / 2) * 0.38), Vector3.ZERO, 0.14, 0.012, "black", false)

    # Continuous east return: the two slabs overlap at the corner, producing one
    # unbroken L-shaped worktop instead of two disconnected islands.
    # Hollow sink carcass: opening the doors reveals a real interior instead
    # of the old solid block.
    _box_child(kitchen, "SinkBack", Vector3(5.52, 0.48, -1.55), Vector3(0.08, 0.82, 2.00), "cabinet_dark", true)
    _box_child(kitchen, "SinkBottom", Vector3(5.20, 0.10, -1.55), Vector3(0.64, 0.08, 1.92), "cabinet_dark", true)
    _box_child(kitchen, "SinkSideA", Vector3(5.20, 0.48, -2.51), Vector3(0.64, 0.82, 0.07), "cabinet_dark", true)
    _box_child(kitchen, "SinkDivider", Vector3(5.20, 0.48, -1.55), Vector3(0.64, 0.82, 0.07), "cabinet_dark", true)
    _box_child(kitchen, "SinkSideB", Vector3(5.20, 0.48, -0.59), Vector3(0.64, 0.82, 0.07), "cabinet_dark", true)
    _box_child(kitchen, "SinkShelfA", Vector3(5.20, 0.48, -2.03), Vector3(0.60, 0.045, 0.86), "oak_light", true)
    _box_child(kitchen, "SinkShelfB", Vector3(5.20, 0.48, -1.07), Vector3(0.60, 0.045, 0.86), "oak_light", true)
    _box_child(kitchen, "CornerBack", Vector3(5.52, 0.48, -3.30), Vector3(0.08, 0.82, 1.46), "cabinet_dark", true)
    _box_child(kitchen, "CornerBottom", Vector3(5.20, 0.10, -3.30), Vector3(0.64, 0.08, 1.46), "cabinet_dark", true)
    _box_child(kitchen, "CornerBlindFront", Vector3(4.79, 0.48, -3.30), Vector3(0.045, 0.82, 1.42), "cabinet", true)
    _box_child(kitchen, "SinkCounter", Vector3(5.14, 0.98, -2.20), Vector3(0.84, 0.10, 3.64), "counter", true)
    _box_child(kitchen, "SinkCounterEdge", Vector3(4.70, 0.98, -2.20), Vector3(0.055, 0.12, 3.64), "counter_edge", false)
    _box_child(kitchen, "SinkBasin", Vector3(5.18, 1.025, -1.65), Vector3(0.58, 0.045, 0.72), "metal", false)
    _box_child(kitchen, "SinkInset", Vector3(5.17, 1.055, -1.65), Vector3(0.44, 0.025, 0.56), "black", false)
    _cylinder_child(kitchen, "FaucetStem", Vector3(5.23, 1.65, -1.98), Vector3.ZERO, 0.035, 1.20, "chrome", false)
    # The outlet sits over the physical basin, not over its front rim.  Keep
    # this x coordinate in sync with WaterStream/WaterCatchArea below.
    _cylinder_child(kitchen, "FaucetSpout", Vector3(5.09, 2.24, -1.98), Vector3(0.0, 0.0, 90.0), 0.035, 0.46, "chrome", false)
    _cylinder_child(kitchen, "FaucetDrop", Vector3(4.96, 2.06, -1.98), Vector3.ZERO, 0.035, 0.36, "chrome", false)

    # Proper fronts are interactive and expose the corpus when opened.
    _box_child(kitchen, "SinkPlinth", Vector3(4.835, 0.11, -1.55), Vector3(0.045, 0.16, 1.84), "black", false)
    _create_cabinet_door(kitchen, "SinkDoorLeft", Vector3(4.79, 0.15, -2.42), Vector2(0.82, 0.76), false, true)
    _create_cabinet_door(kitchen, "SinkDoorRight", Vector3(4.79, 0.15, -0.68), Vector2(0.82, 0.76), true, true)

    # Refrigerator now lives on the east side wall, clear of the L-worktop.
    var fridge := _furniture_root("Fridge", Vector3(7.38, 1.15, -0.85))
    _box_child(fridge, "Back", Vector3(0.41, 0.0, 0.0), Vector3(0.10, 2.30, 1.05), "cream", true)
    _box_child(fridge, "SideA", Vector3(0.0, 0.0, -0.50), Vector3(0.86, 2.30, 0.08), "cream", true)
    _box_child(fridge, "SideB", Vector3(0.0, 0.0, 0.50), Vector3(0.86, 2.30, 0.08), "cream", true)
    _box_child(fridge, "Top", Vector3(0.0, 1.11, 0.0), Vector3(0.86, 0.08, 1.05), "cream", true)
    _box_child(fridge, "Bottom", Vector3(0.0, -1.11, 0.0), Vector3(0.86, 0.08, 1.05), "cream", true)
    _box_child(fridge, "ShelfBeer", Vector3(0.0, -0.53, 0.0), Vector3(0.78, 0.055, 0.94), "metal", true)
    _box_child(fridge, "ShelfFood", Vector3(0.0, 0.18, 0.0), Vector3(0.78, 0.055, 0.94), "metal", true)
    _box_child(fridge, "ColdLight", Vector3(0.35, 0.72, 0.0), Vector3(0.025, 0.22, 0.18), "white", false)
    var fridge_light := OmniLight3D.new()
    fridge_light.name = "FridgeInteriorLight"
    fridge_light.position = Vector3(-0.12, 0.62, 0.0)
    fridge_light.light_color = Color("c7efff")
    fridge_light.light_energy = 1.15
    fridge_light.omni_range = 1.65
    fridge_light.shadow_enabled = false
    fridge.add_child(fridge_light)
    var fridge_lower := _create_fridge_door(fridge, "FridgeLowerDoor", -1.11, 1.08, &"fridge_lower_door")
    var fridge_upper := _create_fridge_door(fridge, "FridgeUpperDoor", -0.04, 1.14, &"fridge_upper_door")
    _objects["fridge_door"] = fridge_upper
    _objects["fridge_lower_door"] = fridge_lower
    _objects["fridge_upper_door"] = fridge_upper
    _objects["fridge"] = fridge
    _box_child(kitchen, "Microwave", Vector3(1.48, 1.25, -4.0), Vector3(0.62, 0.36, 0.46), "black", false)
    _box_child(kitchen, "MicrowaveGlass", Vector3(1.48, 1.25, -3.755), Vector3(0.43, 0.24, 0.015), "glass", false)
    _cylinder_child(kitchen, "MicrowaveKnob", Vector3(1.72, 1.25, -3.73), Vector3(90.0, 0.0, 0.0), 0.035, 0.035, "metal", false)
    _create_toaster(Vector3(7.42, 1.20, -5.18))

    # The large north window is now completely unobstructed.  Closed storage
    # turns onto the east wall above the return counter, a normal kitchen
    # arrangement that also keeps every door usable.
    var east_upper := Node3D.new()
    east_upper.name = "EastUpperCabinet"
    # North of the faucet arc, with enough vertical clearance for counter
    # appliances.  Its south edge is 0.53 m away from the tap centreline.
    east_upper.position = Vector3(5.37, 0.18, -3.41)
    east_upper.rotation_degrees.y = -90.0
    kitchen.add_child(east_upper)
    _box_child(east_upper, "UpperBack", Vector3(0.0, 1.86, -0.22), Vector3(1.72, 1.18, 0.06), "cabinet_dark", true)
    _box_child(east_upper, "UpperSideL", Vector3(-0.86, 1.86, 0.0), Vector3(0.07, 1.18, 0.44), "cabinet_dark", true)
    _box_child(east_upper, "UpperSideR", Vector3(0.86, 1.86, 0.0), Vector3(0.07, 1.18, 0.44), "cabinet_dark", true)
    _box_child(east_upper, "UpperDivider", Vector3(0.0, 1.86, 0.0), Vector3(0.06, 1.18, 0.44), "cabinet_dark", true)
    _box_child(east_upper, "UpperTop", Vector3(0.0, 2.44, 0.0), Vector3(1.72, 0.07, 0.44), "cabinet_dark", true)
    _box_child(east_upper, "UpperBottom", Vector3(0.0, 1.30, 0.0), Vector3(1.72, 0.07, 0.44), "oak_light", true)
    _box_child(east_upper, "UpperShelf", Vector3(0.0, 1.76, 0.0), Vector3(1.64, 0.055, 0.40), "oak_light", true)
    var upper_door_mount := Node3D.new()
    upper_door_mount.name = "UpperDoorMount"
    upper_door_mount.position.z = 0.245
    east_upper.add_child(upper_door_mount)
    _create_cabinet_door(upper_door_mount, "UpperLeftDoor", Vector3(-0.86, 1.35, 0.0), Vector2(0.82, 1.02), false)

    var mug_door = HINGED_DOOR_SCRIPT.new()
    mug_door.name = "MugCabinetDoor"
    mug_door.display_name = "ШКАФ С КРУЖКАМИ"
    mug_door.door_id = &"mug_cabinet"
    mug_door.source_id = &"mug_cabinet"
    mug_door.noise_category = &"CABINET"
    mug_door.open_angle_degrees = -104.0
    mug_door.normal_noise = 5.0
    mug_door.quiet_noise = 1.0
    mug_door.fast_noise = 17.0
    mug_door.position = Vector3(0.04, 1.35, 0.0)
    upper_door_mount.add_child(mug_door)
    _box_child(mug_door, "DoorPanel", Vector3(0.41, 0.51, 0.0), Vector3(0.82, 1.02, 0.045), "cabinet", true)
    _box_child(mug_door, "Handle", Vector3(0.12, 0.50, 0.035), Vector3(0.025, 0.30, 0.025), "metal", false)
    _objects["mug_cabinet"] = mug_door

    # A working drawer hides the coffee jar.
    var drawer = DRAWER_SCRIPT.new()
    drawer.name = "CoffeeDrawer"
    drawer.display_name = "ЯЩИК С КОФЕ"
    drawer.source_id = &"coffee_drawer"
    drawer.noise_category = &"DRAWER"
    drawer.normal_noise = 8.0
    drawer.quiet_noise = 1.5
    drawer.fast_noise = 23.0
    drawer.position = Vector3(5.50, 0.79, -5.66)
    drawer.open_distance = 0.42
    add_child(drawer)
    _box_child(drawer, "DrawerFront", Vector3(0.0, -0.06, 0.0), Vector3(0.86, 0.40, 0.06), "cabinet", true)
    _box_child(drawer, "Bottom", Vector3(0.0, -0.26, -0.22), Vector3(0.80, 0.055, 0.48), "oak", false)
    _box_child(drawer, "LeftSide", Vector3(-0.38, -0.14, -0.22), Vector3(0.055, 0.24, 0.48), "oak", false)
    _box_child(drawer, "RightSide", Vector3(0.38, -0.14, -0.22), Vector3(0.055, 0.24, 0.48), "oak", false)
    _box_child(drawer, "Back", Vector3(0.0, -0.14, -0.45), Vector3(0.80, 0.24, 0.055), "oak", false)
    _box_child(drawer, "Handle", Vector3(0.0, 0.02, 0.05), Vector3(0.25, 0.025, 0.025), "metal", false)
    var contents_anchor := Node3D.new()
    contents_anchor.name = "ContentsAnchor"
    contents_anchor.position = Vector3(0.0, -0.14, -0.22)
    drawer.add_child(contents_anchor)
    _objects["drawer"] = drawer

    _create_dining_area()
    _create_dish_rack(Vector3(7.28, 1.10, -2.93))
    _create_kitchen_decor()

    var kitchen_door = _create_room_door(
        "KitchenDoor",
        Vector3(1.60, 0.0, -2.36),
        96.0,
        &"kitchen_door",
        "ДВЕРЬ КУХНИ",
        "wall_warm",
        "glass"
    )
    _objects["kitchen_door"] = kitchen_door

    # Light switch and window handle are optional tactile interactions.
    var light_switch = _action("KitchenLightSwitch", Vector3(1.70, 1.28, -2.42), "ВЫКЛЮЧАТЕЛЬ КУХНИ", "light_switch")
    light_switch.set_meta("target_group", "kitchen_lights")
    light_switch.normal_noise = 0.3
    light_switch.quiet_noise = 0.1
    light_switch.fast_noise = 0.5
    _box_child(light_switch, "Plate", Vector3.ZERO, Vector3(0.045, 0.19, 0.13), "white", true)
    _box_child(light_switch, "Rocker", Vector3(-0.026, 0.0, 0.0), Vector3(0.025, 0.10, 0.07), "metal", false)
    _objects["light_switch"] = light_switch

    var window_action = _action("KitchenWindow", Vector3(4.88, 1.50, -6.36), "РУЧКА ОКНА", "window")
    window_action.normal_noise = 1.0
    window_action.quiet_noise = 0.3
    window_action.fast_noise = 3.0
    _box_child(window_action, "HandleMount", Vector3.ZERO, Vector3(0.11, 0.28, 0.025), "white", true)
    _box_child(window_action, "WindowHandle", Vector3(0.0, 0.0, 0.045), Vector3(0.035, 0.21, 0.035), "chrome", false)
    _objects["window"] = window_action

    var dish_station = _action("RitaKitchenDishes", Vector3(7.30, 1.12, -3.12), "ГРЯЗНАЯ ПОСУДА  •  ПЕРЕМЫТЬ", "rita_kitchen_dishes")
    dish_station.normal_duration = 9.0
    dish_station.quiet_duration = 14.0
    dish_station.fast_duration = 4.0
    dish_station.normal_noise = 10.0
    dish_station.quiet_noise = 3.0
    dish_station.fast_noise = 27.0
    dish_station.noise_category = &"DISHES"
    dish_station.source_id = &"rita_dishes"
    for plate_index in range(3):
        _cylinder_child(dish_station, "DirtyPlate_%d" % plate_index, Vector3(0.0, 0.018 + float(plate_index) * 0.028, 0.0), Vector3.ZERO, 0.14, 0.025, "white", plate_index == 0)
    dish_station.add_to_group("rita_demand_station")
    _objects["rita_kitchen_dishes"] = dish_station

func _create_cabinet_door(
    parent: Node3D,
    node_name: String,
    pivot_bottom: Vector3,
    panel_size: Vector2,
    hinge_right: bool,
    sideways: bool = false
) -> Node3D:
    var door = HINGED_DOOR_SCRIPT.new()
    door.name = node_name
    door.display_name = "ДВЕРЦА ШКАФА"
    door.door_id = StringName(node_name.to_snake_case())
    door.source_id = door.door_id
    door.noise_category = &"CABINET"
    door.open_angle_degrees = 105.0 if hinge_right else -105.0
    door.normal_noise = 4.0
    door.quiet_noise = 0.8
    door.fast_noise = 12.0
    door.position = pivot_bottom + Vector3.UP * panel_size.y * 0.5
    parent.add_child(door)
    var panel_offset := Vector3.ZERO
    var panel_dimensions := Vector3.ZERO
    if sideways:
        panel_offset.z = (-0.5 if hinge_right else 0.5) * panel_size.x
        panel_dimensions = Vector3(0.045, panel_size.y, panel_size.x)
    else:
        panel_offset.x = (-0.5 if hinge_right else 0.5) * panel_size.x
        panel_dimensions = Vector3(panel_size.x, panel_size.y, 0.045)
    _box_child(door, "Visual", panel_offset, panel_dimensions, "cabinet", false)
    var handle_offset := panel_offset
    if sideways:
        handle_offset.x -= 0.042
        handle_offset.z += (0.32 if hinge_right else -0.32) * panel_size.x
        _box_child(door, "Handle", handle_offset, Vector3(0.03, 0.24, 0.03), "metal", false)
    else:
        handle_offset.z += 0.042
        handle_offset.x += (0.32 if not hinge_right else -0.32) * panel_size.x
        _box_child(door, "Handle", handle_offset, Vector3(0.03, 0.24, 0.03), "metal", false)
    _add_moving_part_area(door, panel_offset, panel_dimensions)
    _objects[node_name.to_snake_case()] = door
    return door

func _create_fridge_door(parent: Node3D, node_name: String, bottom_y: float, height: float, door_id: StringName) -> Node3D:
    var door = HINGED_DOOR_SCRIPT.new()
    door.name = node_name
    door.display_name = "ДВЕРЬ ХОЛОДИЛЬНИКА"
    door.door_id = door_id
    door.source_id = door_id
    door.noise_category = &"FRIDGE"
    door.open_angle_degrees = -105.0
    door.normal_noise = 5.0
    door.quiet_noise = 1.2
    door.fast_noise = 13.0
    door.position = Vector3(-0.48, bottom_y, -0.50)
    parent.add_child(door)
    var panel_offset := Vector3(-0.03, height * 0.5, 0.50)
    var panel_size := Vector3(0.08, height - 0.035, 1.00)
    _box_child(door, "Visual", panel_offset, panel_size, "cream", false)
    _box_child(door, "Handle", panel_offset + Vector3(-0.055, 0.0, 0.36), Vector3(0.035, height * 0.42, 0.035), "metal", false)
    _add_moving_part_area(door, panel_offset + Vector3(-0.07, 0.0, 0.0), panel_size)
    return door

func _create_dishwasher_door(parent: Node3D, pivot_bottom: Vector3, panel_size: Vector2) -> Node3D:
    var door = HINGED_DOOR_SCRIPT.new()
    door.name = "DishwasherDoor"
    door.display_name = "ДВЕРЬ ПОСУДОМОЙКИ"
    door.door_id = &"dishwasher_door"
    door.source_id = &"dishwasher_door"
    door.noise_category = &"CABINET"
    door.motion_axis = "x"
    door.open_angle_degrees = 78.0
    door.normal_noise = 4.5
    door.quiet_noise = 0.8
    door.fast_noise = 14.0
    door.position = pivot_bottom + Vector3(panel_size.x * 0.5, 0.0, 0.0)
    parent.add_child(door)
    var panel_offset := Vector3(0.0, panel_size.y * 0.5, 0.0)
    var panel_dimensions := Vector3(panel_size.x, panel_size.y, 0.055)
    _box_child(door, "Visual", panel_offset, panel_dimensions, "cabinet", false)
    _box_child(door, "Handle", panel_offset + Vector3(0.0, panel_size.y * 0.34, 0.045), Vector3(0.34, 0.035, 0.03), "metal", false)
    _add_moving_part_area(door, panel_offset, panel_dimensions)
    _objects["dishwasher_door"] = door
    return door

func _add_moving_part_area(part: Node3D, local_position: Vector3, size_value: Vector3) -> void:
    var moving_body := StaticBody3D.new()
    moving_body.name = "MovingCollision"
    moving_body.position = local_position
    moving_body.collision_layer = 1
    moving_body.collision_mask = 3
    part.add_child(moving_body)
    var moving_collision := CollisionShape3D.new()
    var moving_shape := BoxShape3D.new()
    moving_shape.size = size_value
    moving_collision.shape = moving_shape
    moving_body.add_child(moving_collision)
    var area := Area3D.new()
    area.name = "InteractionArea"
    area.position = local_position
    area.collision_layer = 2
    area.collision_mask = 0
    part.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size_value
    collision.shape = shape
    area.add_child(collision)

func _create_closed_rooms() -> void:
    # Both private rooms are real, reachable locations.
    var bed := _furniture_root("Bed", Vector3(-6.55, 0.0, 4.70))
    _box_child(bed, "BedBase", Vector3(0.0, 0.34, 0.0), Vector3(2.55, 0.58, 1.55), "oak_dark", true)
    _box_child(bed, "Headboard", Vector3(-1.20, 0.88, 0.0), Vector3(0.16, 1.34, 1.55), "oak_dark", true)
    _box_child(bed, "Mattress", Vector3(0.0, 0.68, 0.0), Vector3(2.42, 0.30, 1.45), "cream", false)
    _box_child(bed, "Duvet", Vector3(0.0, 0.88, 0.14), Vector3(2.20, 0.20, 1.05), "bedroom", false)
    # Sleeping Rita is placed anatomically along the bed, under the duvet.
    _sphere_child(bed, "RitaHead", Vector3(-0.82, 0.99, -0.28), 0.18, "cream", false)
    var hair := _sphere_child(bed, "RitaHair", Vector3(-0.86, 1.04, -0.29), 0.19, "brown", false)
    hair.scale = Vector3(1.04, 0.72, 1.02)
    _box_child(bed, "RitaBody", Vector3(0.10, 0.90, -0.12), Vector3(1.45, 0.16, 0.46), "bedroom", false)

    var bedroom_shell := _fixed_root("RitaBedroomDecor")
    var bedroom_rug := _box_child(bedroom_shell, "BedroomRug", Vector3(-5.85, 0.028, 4.70), Vector3(3.65, 0.035, 2.45), "rug", false)
    _mark_soft_surface(bedroom_rug, Vector2(3.65, 2.45))
    for i in range(5):
        _box_child(bedroom_shell, "RugStripe_%d" % i, Vector3(-7.15 + float(i) * 0.65, 0.052, 4.70), Vector3(0.08, 0.012, 2.12), "rug_light", false)
    _box_child(bedroom_shell, "ArtFrameA", Vector3(-3.10, 1.70, 6.39), Vector3(0.92, 0.76, 0.055), "oak_dark", false)
    _box_child(bedroom_shell, "ArtA", Vector3(-3.10, 1.70, 6.355), Vector3(0.78, 0.62, 0.018), "fabric_rust", false)
    _box_child(bedroom_shell, "ArtFrameB", Vector3(-6.05, 1.72, 6.39), Vector3(0.82, 0.92, 0.055), "oak_dark", false)
    _box_child(bedroom_shell, "ArtB", Vector3(-6.05, 1.72, 6.355), Vector3(0.68, 0.78, 0.018), "fabric_blue", false)
    for i in range(9):
        _sphere_child(bedroom_shell, "FairyLight_%d" % i, Vector3(-7.15 + float(i) * 0.58, 2.38 + sin(float(i) * 0.8) * 0.12, 6.34), 0.035, "warm_light", false)

    var nightstand := _furniture_root("Nightstand", Vector3(-7.12, 0.0, 5.78))
    _box_child(nightstand, "Body", Vector3(0.0, 0.34, 0.0), Vector3(0.62, 0.64, 0.52), "oak", true)
    _box_child(nightstand, "Drawer", Vector3(0.0, 0.45, -0.275), Vector3(0.50, 0.20, 0.035), "oak_light", false)
    _sphere_child(nightstand, "Knob", Vector3(0.0, 0.45, -0.31), 0.035, "metal", false)

    var dresser := _furniture_root("BedroomDresser", Vector3(-2.35, 0.0, 5.72))
    _box_child(dresser, "Body", Vector3(0.0, 0.48, 0.0), Vector3(1.25, 0.92, 0.52), "oak", true)
    for i in range(3):
        _box_child(dresser, "Drawer_%d" % i, Vector3(0.0, 0.70 - float(i) * 0.27, -0.28), Vector3(1.08, 0.21, 0.035), "oak_light", false)
        _box_child(dresser, "Handle_%d" % i, Vector3(0.0, 0.70 - float(i) * 0.27, -0.31), Vector3(0.28, 0.025, 0.025), "metal", false)
    var wardrobe := _furniture_root("Wardrobe", Vector3(-7.18, 1.20, 3.25))
    _box_child(wardrobe, "Body", Vector3.ZERO, Vector3(0.88, 2.38, 0.86), "oak", true)
    _box_child(wardrobe, "Door", Vector3(0.46, 0.0, 0.0), Vector3(0.035, 2.12, 0.70), "oak_light", false)

    var bedroom_door = _create_room_door("BedroomDoor", Vector3(-1.60, 0.0, 3.12), -96.0, &"bedroom_door", "ДВЕРЬ В СПАЛЬНЮ", "bedroom", "oak_dark")
    _objects["bedroom_door"] = bedroom_door

    var bathroom_door = _create_room_door("BathroomDoor", Vector3(1.60, 0.0, 3.12), 96.0, &"bathroom_door", "ДВЕРЬ В ВАННУЮ", "accent", "tile_dark")
    _objects["bathroom_door"] = bathroom_door

    # Compact bathroom with a clear route from the doorway.
    var bath := _fixed_root("BathroomFurniture", Vector3(1.45, 0.0, 1.35))
    _box_child(bath, "Vanity", Vector3(5.90, 0.46, 1.75), Vector3(1.15, 0.86, 0.58), "cabinet_dark", true)
    _box_child(bath, "VanityTop", Vector3(5.90, 0.92, 1.75), Vector3(1.22, 0.08, 0.64), "counter", true)
    _box_child(bath, "Mirror", Vector3(6.46, 1.70, 1.75), Vector3(0.035, 1.10, 0.88), "mirror", false)
    _box_child(bath, "ToiletBase", Vector3(1.10, 0.30, 4.50), Vector3(0.62, 0.55, 0.78), "white", true)
    _box_child(bath, "ToiletTank", Vector3(1.10, 0.72, 4.87), Vector3(0.66, 0.72, 0.25), "white", true)
    _box_child(bath, "ShowerTray", Vector3(5.45, 0.12, 4.20), Vector3(1.55, 0.20, 1.45), "white", true)
    _box_child(bath, "ShowerGlass", Vector3(4.67, 1.18, 4.20), Vector3(0.035, 2.15, 1.45), "glass", false)

    var bathroom_sink = _action("BathroomSink", Vector3(7.18, 1.12, 3.10), "КРАН В ВАННОЙ", "inspect")
    bathroom_sink.set_meta("interaction_message", "ВОДА В ВАННОЙ РАБОТАЕТ")
    _cylinder_child(bathroom_sink, "Tap", Vector3.ZERO, Vector3.ZERO, 0.07, 0.24, "chrome", true)
    var toilet = _action("Toilet", Vector3(2.55, 0.92, 6.08), "СМЫТЬ", "inspect")
    toilet.set_meta("interaction_message", "СЛИШКОМ ШУМНО. ЛУЧШЕ НЕ НАДО")
    _box_child(toilet, "Button", Vector3.ZERO, Vector3(0.16, 0.05, 0.10), "chrome", true)

    var cleaning_bucket = _action("RitaBathroomCleaning", Vector3(5.15, 0.28, 2.35), "ВЕДРО И ЩЁТКА  •  УБРАТЬ ВАННУЮ", "rita_bathroom_clean")
    cleaning_bucket.normal_duration = 8.0
    cleaning_bucket.quiet_duration = 12.0
    cleaning_bucket.fast_duration = 4.0
    cleaning_bucket.normal_noise = 8.0
    cleaning_bucket.quiet_noise = 2.5
    cleaning_bucket.fast_noise = 22.0
    cleaning_bucket.noise_category = &"CLEANING"
    cleaning_bucket.source_id = &"bathroom_cleaning"
    _cylinder_child(cleaning_bucket, "Bucket", Vector3.ZERO, Vector3.ZERO, 0.22, 0.38, "fabric_blue", true)
    _cylinder_child(cleaning_bucket, "BrushHandle", Vector3(0.10, 0.38, 0.0), Vector3(0.0, 0.0, 18.0), 0.025, 0.70, "oak_light", false)
    cleaning_bucket.add_to_group("rita_demand_station")
    _objects["rita_bathroom_clean"] = cleaning_bucket

    # A full-size front-loader lives against the near bathroom wall.  The
    # central aisle remains clear until its deliberately unbalanced spin cycle
    # starts crawling toward the door.
    var washer = WASHING_MACHINE_SCRIPT.new()
    washer.name = "WashingMachine"
    washer.item_id = &"washing_machine"
    washer.display_name = "СТИРАЛЬНАЯ МАШИНА"
    washer.mass = 68.0
    washer.position = Vector3(2.42, 0.61, 2.42)
    add_child(washer)
    _box_child(washer, "Cabinet", Vector3.ZERO, Vector3(0.78, 1.18, 0.72), "white", true)
    _box_child(washer, "Top", Vector3(0.0, 0.62, 0.0), Vector3(0.82, 0.08, 0.76), "counter", false)
    _box_child(washer, "ControlStrip", Vector3(0.0, 0.39, -0.367), Vector3(0.69, 0.19, 0.025), "metal", false)
    _cylinder_child(washer, "ProgramDial", Vector3(0.21, 0.40, -0.388), Vector3(90.0, 0.0, 0.0), 0.075, 0.035, "black", false)
    _box_child(washer, "Display", Vector3(-0.19, 0.40, -0.389), Vector3(0.20, 0.075, 0.016), "screen", false)
    var drum := _cylinder_child(washer, "Drum", Vector3(0.0, -0.08, -0.382), Vector3(90.0, 0.0, 0.0), 0.255, 0.07, "metal", false)
    _cylinder_child(drum, "DrumGlass", Vector3(0.0, 0.045, 0.0), Vector3.ZERO, 0.205, 0.018, "glass", false)
    _cylinder_child(drum, "Laundry", Vector3(0.04, 0.058, -0.03), Vector3.ZERO, 0.13, 0.022, "fabric_blue", false)
    _torus_child(washer, "DoorRim", Vector3(0.0, -0.08, -0.425), Vector3(90.0, 0.0, 0.0), 0.235, 0.305, "black")
    _box_child(washer, "DetergentDrawer", Vector3(-0.26, 0.40, -0.391), Vector3(0.19, 0.10, 0.018), "white", false)
    _box_child(washer, "Indicator", Vector3(0.31, 0.47, -0.396), Vector3(0.045, 0.025, 0.012), "red", false).visible = false
    for foot_x in [-0.28, 0.28]:
        for foot_z in [-0.25, 0.25]:
            _cylinder_child(washer, "Foot", Vector3(foot_x, -0.62, foot_z), Vector3.ZERO, 0.045, 0.07, "black", false)
    _objects["washing_machine"] = washer

func _create_walk_in_wardrobe() -> void:
    var room := _fixed_root("WalkInWardrobe")

    var wardrobe_door = _create_room_door(
        "WardrobeRoomDoor",
        Vector3(-5.42, 0.0, 6.50),
        -100.0,
        &"wardrobe_door",
        "ДВЕРЬ В ГАРДЕРОБНУЮ",
        "oak_dark",
        "fabric_blue",
        90.0
    )
    _objects["wardrobe_door"] = wardrobe_door

    var sign := _label3d("ГАРДЕРОБНАЯ", Vector3(-4.65, 2.57, 6.36), Color("f3dfbb"), 24)
    sign.rotation_degrees.y = 180.0
    add_child(sign)

    # Two real storage runs leave a generous central aisle from the bedroom door.
    for rack_index in range(2):
        var rack_x := -7.55 if rack_index == 0 else -2.05
        _box_child(room, "RackBack_%d" % rack_index, Vector3(rack_x, 1.25, 8.05), Vector3(0.10, 2.35, 2.25), "oak_dark", true)
        for shelf_index in range(3):
            var shelf_y := 0.28 + float(shelf_index) * 0.78
            _box_child(room, "Shelf_%d_%d" % [rack_index, shelf_index], Vector3(rack_x + (0.28 if rack_index == 0 else -0.28), shelf_y, 8.05), Vector3(0.58, 0.07, 2.25), "oak_light", true)
        var rail_x := rack_x + (0.47 if rack_index == 0 else -0.47)
        _cylinder_between(room, "ClothesRail_%d" % rack_index, Vector3(rail_x, 1.84, 7.15), Vector3(rail_x, 1.84, 8.86), 0.025, "chrome")

    var garment_materials := ["fabric_blue", "fabric_rust", "bedroom", "cream"]
    for i in range(12):
        var on_left := i < 6
        var garment_x := -7.02 if on_left else -2.58
        var garment_z := 7.18 + float(i % 6) * 0.32
        var garment_material: String = garment_materials[i % garment_materials.size()]
        _box_child(room, "HangingGarment_%02d" % i, Vector3(garment_x, 1.35, garment_z), Vector3(0.12, 0.86, 0.25), garment_material, false)
        _cylinder_between(room, "Hanger_%02d" % i, Vector3(garment_x, 1.78, garment_z - 0.11), Vector3(garment_x, 1.78, garment_z + 0.11), 0.012, "metal")

    # Folded clothes and shoe boxes are independent physics objects that can be searched.
    for i in range(6):
        var folded := _loose_box(
            "FoldedClothes_%02d" % i,
            "СЛОЖЕННАЯ ОДЕЖДА",
            Vector3(-7.16, 0.39 + float(i / 3) * 0.78, 7.42 + float(i % 3) * 0.48),
            Vector3(0.42, 0.10, 0.34),
            garment_materials[i % garment_materials.size()],
            0.28
        )
        folded.add_to_group("wardrobe_clothes")
    for i in range(4):
        var shoe_box := _loose_box(
            "ShoeBox_%02d" % i,
            "КОРОБКА С ОБУВЬЮ",
            Vector3(-2.42, 0.43 + float(i / 2) * 0.78, 7.55 + float(i % 2) * 0.62),
            Vector3(0.48, 0.20, 0.34),
            "cardboard",
            1.15
        )
        shoe_box.add_to_group("wardrobe_clothes")

    var bench := _furniture_root("WardrobeBench", Vector3(-3.15, 0.0, 8.05))
    bench.mass = 16.0
    bench.display_name = "БАНКЕТКА В ГАРДЕРОБНОЙ"
    _box_child(bench, "Seat", Vector3(0.0, 0.48, 0.0), Vector3(1.25, 0.20, 0.58), "fabric_rust", true)
    for leg_x in [-0.48, 0.48]:
        for leg_z in [-0.20, 0.20]:
            _box_child(bench, "Leg", Vector3(leg_x, 0.22, leg_z), Vector3(0.08, 0.44, 0.08), "oak_dark", true)

    var laundry_basket := _loose_box(
        "WardrobeLaundryBasket",
        "КОРЗИНА С БЕЛЬЁМ",
        Vector3(-6.30, 0.38, 8.82),
        Vector3(0.62, 0.72, 0.52),
        "cream",
        1.8
    )
    laundry_basket.add_to_group("wardrobe_clothes")

    var light := OmniLight3D.new()
    light.name = "WardrobeCeilingLight"
    light.position = Vector3(-4.65, 2.68, 7.80)
    light.light_color = Color("ffd6a0")
    light.light_energy = 1.15
    light.omni_range = 5.5
    room.add_child(light)
    _cylinder_child(room, "WardrobeLamp", Vector3(-4.65, 2.84, 7.80), Vector3.ZERO, 0.24, 0.08, "warm_light", false)

    # A deep cabinet at the back is the gameplay hide spot.
    _box_child(room, "HideCabinetBack", Vector3(-4.65, 1.20, 9.39), Vector3(1.62, 2.40, 0.12), "oak_dark", true)
    _box_child(room, "HideCabinetLeft", Vector3(-5.43, 1.20, 9.12), Vector3(0.10, 2.40, 0.62), "oak_dark", true)
    _box_child(room, "HideCabinetRight", Vector3(-3.87, 1.20, 9.12), Vector3(0.10, 2.40, 0.62), "oak_dark", true)
    _box_child(room, "HideCabinetTop", Vector3(-4.65, 2.40, 9.12), Vector3(1.66, 0.10, 0.62), "oak_dark", true)
    var hide_spot = HIDE_SPOT_SCRIPT.new()
    hide_spot.name = "WardrobeHideSpot"
    hide_spot.display_name = "УКРЫТИЕ В ГАРДЕРОБНОЙ"
    hide_spot.normal_noise = 0.8
    hide_spot.quiet_noise = 0.15
    hide_spot.fast_noise = 5.0
    hide_spot.hide_position = Vector3(-4.65, 0.08, 9.15)
    hide_spot.exit_position = Vector3(-4.65, 0.08, 8.25)
    hide_spot.hide_yaw_degrees = 0.0
    add_child(hide_spot)
    _box_child(hide_spot, "LouveredDoor", Vector3(-4.65, 1.18, 8.82), Vector3(1.46, 2.28, 0.08), "oak", true)
    for slat_index in range(8):
        _box_child(hide_spot, "DoorSlat_%02d" % slat_index, Vector3(-4.65, 0.32 + float(slat_index) * 0.23, 8.765), Vector3(1.20, 0.055, 0.025), "oak_light", false)
    _cylinder_child(hide_spot, "HideHandle", Vector3(-4.05, 1.18, 8.72), Vector3(90.0, 0.0, 0.0), 0.025, 0.20, "metal", false)
    _objects["wardrobe_hide_spot"] = hide_spot

func _create_payment_altar_room() -> void:
    var payment_room := PAYMENT_ALTAR_ROOM_SCENE.instantiate() as Node3D
    payment_room.name = "PaymentAltarRoom"
    payment_room.position = Vector3(-3.20, 0.0, 9.50)
    add_child(payment_room)
    _objects["payment_altar_room"] = payment_room
    _objects["payment_altar_door"] = payment_room.get("secret_door")
    var payment_altar := payment_room.get("altar") as Node
    if payment_altar != null:
        _objects["payment_altar"] = payment_altar
        _objects["payment_altar_interaction"] = payment_altar.get("interaction")

func _create_lived_in_details() -> void:
    var entry := _fixed_root("EntryLivedInDetails")
    entry.add_to_group("environment_detail")
    _imported_prop(
        "res://assets/environment/corridor/rug_doormat.glb",
        "EntryDoormat",
        Vector3(0.0, 0.035, 5.72),
        Vector3(1.10, 1.0, 0.92)
    )
    _box_child(entry, "IntercomBody", Vector3(-1.50, 1.52, 5.30), Vector3(0.055, 0.38, 0.24), "cream", false)
    _box_child(entry, "IntercomScreen", Vector3(-1.465, 1.60, 5.30), Vector3(0.012, 0.12, 0.14), "screen", false)
    _cylinder_child(entry, "IntercomButton", Vector3(-1.46, 1.40, 5.30), Vector3(0.0, 0.0, 90.0), 0.025, 0.018, "black", false)
    for hook_index in range(3):
        var hook_z := 0.85 + float(hook_index) * 0.58
        _box_child(entry, "WallHook_%d" % hook_index, Vector3(1.50, 1.92, hook_z), Vector3(0.07, 0.10, 0.16), "metal", false)
        _box_child(entry, "Coat_%d" % hook_index, Vector3(1.43, 1.42, hook_z), Vector3(0.13, 0.86, 0.38), ["fabric_blue", "fabric_rust", "sofa"][hook_index], false)
    _cylinder_child(entry, "KeyBowl", Vector3(-1.30, 1.02, 5.36), Vector3.ZERO, 0.11, 0.040, "cream", false)
    for key_index in range(2):
        _box_child(entry, "Key_%d" % key_index, Vector3(-1.30, 1.055, 5.32 + float(key_index) * 0.07), Vector3(0.08, 0.012, 0.025), "metal", false)
    _box_child(entry, "Receipt", Vector3(-1.30, 1.015, 5.54), Vector3(0.16, 0.008, 0.18), "white", false)
    # A quiet focal point closes the long view without narrowing the route.
    _box_child(entry, "EndWallFrame", Vector3(0.0, 1.66, -6.43), Vector3(1.28, 0.86, 0.055), "oak_dark", false)
    _box_child(entry, "EndWallPrint", Vector3(0.0, 1.66, -6.395), Vector3(1.08, 0.66, 0.018), "fabric_blue", false)
    _box_child(entry, "EndWallPrintAccent", Vector3(0.17, 1.74, -6.382), Vector3(0.34, 0.22, 0.012), "fabric_rust", false)

    var living := _fixed_root("LivingRoomLivedInDetails")
    living.add_to_group("environment_detail")
    _imported_prop(
        "res://assets/environment/living_room/floor_lamp.glb",
        "LivingFloorLamp",
        Vector3(-7.35, 0.02, -1.55),
        Vector3.ONE * 0.92,
        Vector3(0.0, 24.0, 0.0)
    )
    _imported_prop(
        "res://assets/environment/living_room/pillow_warm.glb",
        "SofaPillowWarm",
        Vector3(-7.06, 0.77, -0.48),
        Vector3.ONE * 0.72,
        Vector3(-8.0, 18.0, 76.0),
        "fabric_rust"
    )
    _imported_prop(
        "res://assets/environment/living_room/pillow_blue_long.glb",
        "SofaPillowBlue",
        Vector3(-7.06, 0.78, 0.13),
        Vector3.ONE * 0.68,
        Vector3(5.0, -12.0, 82.0),
        "fabric_blue"
    )
    _box_child(living, "ThrowBlanket", Vector3(-7.08, 0.67, 0.62), Vector3(0.10, 0.78, 0.72), "rug_light", false)
    _box_child(living, "SideTableTop", Vector3(-6.88, 0.48, -1.38), Vector3(0.48, 0.07, 0.48), "oak_light", true)
    _cylinder_child(living, "SideTableLeg", Vector3(-6.88, 0.25, -1.38), Vector3.ZERO, 0.055, 0.46, "black", true)
    _cylinder_child(living, "Candle", Vector3(-6.88, 0.58, -1.38), Vector3.ZERO, 0.055, 0.16, "cream", false)
    _sphere_child(living, "CandleGlow", Vector3(-6.88, 0.69, -1.38), 0.035, "warm_light", false)
    _imported_prop(
        "res://assets/environment/shared/books.glb",
        "LivingShelfBooks",
        Vector3(-6.54, 0.20, 1.17),
        Vector3.ONE * 0.62,
        Vector3(0.0, -4.0, 0.0)
    )
    _imported_prop(
        "res://assets/environment/shared/small_plant.glb",
        "LivingSmallPlant",
        Vector3(-5.64, 0.48, -0.27),
        Vector3.ONE * 0.58
    )

    var workspace := _fixed_root("WorkspaceLivedInDetails")
    workspace.add_to_group("environment_detail")
    _imported_prop(
        "res://assets/environment/workspace/monitor.glb",
        "ExternalMonitor",
        Vector3(-6.18, 0.81, -5.52),
        Vector3.ONE * 0.82,
        Vector3(0.0, 180.0, 0.0)
    )
    _imported_prop(
        "res://assets/environment/workspace/keyboard.glb",
        "ExternalKeyboard",
        Vector3(-6.18, 0.82, -5.08),
        Vector3.ONE * 0.72,
        Vector3(0.0, 180.0, 0.0)
    )
    _imported_prop(
        "res://assets/environment/workspace/mouse.glb",
        "ExternalMouse",
        Vector3(-5.83, 0.82, -5.05),
        Vector3.ONE * 0.68,
        Vector3(0.0, 168.0, 0.0)
    )
    _box_child(workspace, "DeskMat", Vector3(-6.10, 0.816, -5.18), Vector3(1.05, 0.012, 0.44), "black", false)
    _box_child(workspace, "PinBoard", Vector3(-5.70, 1.72, -6.38), Vector3(1.28, 0.68, 0.045), "oak", false)
    for note_index in range(4):
        _box_child(
            workspace,
            "StickyNote_%d" % note_index,
            Vector3(-6.12 + float(note_index % 2) * 0.46, 1.57 + float(note_index / 2) * 0.30, -6.35),
            Vector3(0.22, 0.18, 0.012),
            ["yellow", "cream", "fabric_rust", "fabric_blue"][note_index],
            false
        )
    _box_child(workspace, "PowerStrip", Vector3(-4.78, 0.10, -5.58), Vector3(0.44, 0.08, 0.14), "white", false)
    _cylinder_between(workspace, "MonitorCable", Vector3(-6.18, 0.82, -5.56), Vector3(-5.55, 0.10, -5.61), 0.012, "black")
    _cylinder_between(workspace, "HeadsetCable", Vector3(-5.15, 0.82, -5.50), Vector3(-4.82, 0.10, -5.58), 0.010, "black")
    _cylinder_child(workspace, "DeskWaterGlass", Vector3(-6.58, 0.91, -5.16), Vector3.ZERO, 0.055, 0.18, "glass", false)

    var bedroom := _fixed_root("BedroomLivedInDetails")
    bedroom.add_to_group("environment_detail")
    _imported_prop(
        "res://assets/environment/bedroom/table_lamp.glb",
        "RitaTableLamp",
        Vector3(-7.12, 0.68, 5.78),
        Vector3.ONE * 0.72,
        Vector3(0.0, -15.0, 0.0)
    )
    _box_child(bedroom, "RitaPhone", Vector3(-6.98, 0.70, 5.62), Vector3(0.10, 0.025, 0.18), "black", false)
    _cylinder_child(bedroom, "WaterGlass", Vector3(-7.28, 0.79, 5.70), Vector3.ZERO, 0.045, 0.18, "glass", false)
    _box_child(bedroom, "AlarmClock", Vector3(-7.02, 0.79, 5.92), Vector3(0.18, 0.15, 0.10), "cream", false)
    _box_child(bedroom, "AlarmFace", Vector3(-7.02, 0.79, 5.865), Vector3(0.12, 0.08, 0.008), "screen", false)
    _cylinder_between(bedroom, "PhoneCable", Vector3(-6.98, 0.69, 5.70), Vector3(-7.38, 0.24, 5.90), 0.009, "white")
    _imported_prop(
        "res://assets/environment/shared/books.glb",
        "RitaBedsideBooks",
        Vector3(-2.48, 0.96, 5.70),
        Vector3.ONE * 0.55,
        Vector3(0.0, 7.0, 0.0)
    )
    _imported_prop(
        "res://assets/environment/shared/small_plant.glb",
        "BedroomSmallPlant",
        Vector3(-2.18, 0.95, 5.78),
        Vector3.ONE * 0.52
    )
    # The bedroom reads as used, but its door-to-bed and bed-to-wardrobe aisles stay empty.
    _box_child(bedroom, "BedPillowMain", Vector3(-7.12, 0.98, 4.68), Vector3(0.52, 0.16, 0.62), "cream", false)
    _box_child(bedroom, "BedPillowAccent", Vector3(-6.88, 1.01, 4.98), Vector3(0.42, 0.14, 0.34), "fabric_rust", false)
    _box_child(bedroom, "FoldedThrow", Vector3(-5.62, 1.01, 4.70), Vector3(0.52, 0.08, 1.10), "rug_light", false)
    for slipper_index in range(2):
        _box_child(
            bedroom,
            "BedSlipper_%d" % slipper_index,
            Vector3(-5.72 + float(slipper_index) * 0.36, 0.09, 5.70),
            Vector3(0.25, 0.10, 0.42),
            "fabric_blue",
            false
        )
    _box_child(bedroom, "DresserTray", Vector3(-2.72, 0.965, 5.58), Vector3(0.34, 0.025, 0.22), "metal", false)
    for perfume_index in range(3):
        _cylinder_child(
            bedroom,
            "Perfume_%d" % perfume_index,
            Vector3(-2.82 + float(perfume_index) * 0.12, 1.06, 5.58),
            Vector3.ZERO,
            0.035,
            0.14 + float(perfume_index % 2) * 0.06,
            ["glass", "bedroom", "cream"][perfume_index],
            false
        )
    _box_child(bedroom, "BedroomWallShelf", Vector3(-2.35, 1.48, 6.31), Vector3(1.24, 0.07, 0.30), "oak_light", false)
    _box_child(bedroom, "PhotoFrame", Vector3(-2.62, 1.75, 6.27), Vector3(0.34, 0.42, 0.05), "oak_dark", false)
    _box_child(bedroom, "PhotoPrint", Vector3(-2.62, 1.75, 6.235), Vector3(0.25, 0.32, 0.012), "cream", false)
    _box_child(bedroom, "LaundryHamper", Vector3(-7.35, 0.34, 3.88), Vector3(0.46, 0.66, 0.46), "cream", false)
    _box_child(bedroom, "HamperClothes", Vector3(-7.35, 0.70, 3.88), Vector3(0.38, 0.12, 0.38), "bedroom", false)

    var bathroom := _fixed_root("BathroomLivedInDetails")
    bathroom.add_to_group("environment_detail")
    _box_child(bathroom, "ShowerTileAccent", Vector3(7.91, 1.32, 5.10), Vector3(0.035, 2.42, 1.72), "tile_dark", false)
    for grout_index in range(5):
        _box_child(
            bathroom,
            "ShowerGrout_%d" % grout_index,
            Vector3(7.885, 0.35 + float(grout_index) * 0.48, 5.10),
            Vector3(0.012, 0.018, 1.68),
            "cream",
            false
        )
    _imported_prop(
        "res://assets/environment/bathroom/wall_cabinet.glb",
        "BathroomWallCabinet",
        Vector3(7.72, 1.04, 4.05),
        Vector3.ONE * 0.82,
        Vector3(0.0, -90.0, 0.0)
    )
    _box_child(bathroom, "BathMat", Vector3(5.75, 0.035, 5.48), Vector3(1.20, 0.035, 0.72), "fabric_blue", false)
    _cylinder_child(bathroom, "ToothbrushCup", Vector3(7.12, 1.05, 2.96), Vector3.ZERO, 0.07, 0.16, "cream", false)
    for brush_index in range(2):
        _cylinder_child(bathroom, "Toothbrush_%d" % brush_index, Vector3(7.09 + float(brush_index) * 0.07, 1.19, 2.96), Vector3(0.0, 0.0, -8.0 + float(brush_index) * 16.0), 0.012, 0.26, ["fabric_blue", "fabric_rust"][brush_index], false)
    _cylinder_child(bathroom, "HandSoap", Vector3(7.12, 1.07, 3.28), Vector3.ZERO, 0.065, 0.22, "green", false)
    for bottle_index in range(3):
        _cylinder_child(
            bathroom,
            "ShowerBottle_%d" % bottle_index,
            Vector3(7.10 + float(bottle_index) * 0.16, 0.42, 5.78),
            Vector3.ZERO,
            0.065,
            0.34 + float(bottle_index % 2) * 0.08,
            ["fabric_blue", "cream", "fabric_rust"][bottle_index],
            false
        )
    _box_child(bathroom, "TowelRail", Vector3(7.76, 1.42, 5.42), Vector3(0.07, 0.06, 0.86), "chrome", false)
    _box_child(bathroom, "BathTowel", Vector3(7.70, 1.10, 5.42), Vector3(0.08, 0.62, 0.72), "cream", false)
    _cylinder_child(bathroom, "ToiletPaper", Vector3(1.76, 0.72, 5.66), Vector3(0.0, 0.0, 90.0), 0.11, 0.16, "white", false)
    _box_child(bathroom, "HairDryer", Vector3(7.10, 1.02, 3.44), Vector3(0.24, 0.07, 0.12), "black", false)
    # Shower hardware, spare linen and daily-care storage make the wet zone legible.
    _cylinder_between(bathroom, "ShowerRail", Vector3(7.44, 0.72, 5.16), Vector3(7.44, 2.12, 5.16), 0.022, "chrome")
    _cylinder_child(bathroom, "ShowerHead", Vector3(7.31, 2.12, 5.16), Vector3(0.0, 0.0, 90.0), 0.12, 0.22, "chrome", false)
    _cylinder_between(bathroom, "ShowerHose", Vector3(7.43, 0.72, 5.16), Vector3(7.18, 1.45, 5.16), 0.012, "black")
    _box_child(bathroom, "LinenShelfTop", Vector3(2.02, 1.62, 4.88), Vector3(0.64, 0.07, 0.34), "oak_light", false)
    _box_child(bathroom, "LinenShelfLower", Vector3(2.02, 1.18, 4.88), Vector3(0.64, 0.07, 0.34), "oak_light", false)
    for towel_index in range(3):
        _box_child(
            bathroom,
            "FoldedTowel_%d" % towel_index,
            Vector3(1.86 + float(towel_index % 2) * 0.30, 1.25 + float(towel_index / 2) * 0.44, 4.86),
            Vector3(0.25, 0.12, 0.28),
            ["cream", "fabric_blue", "rug_light"][towel_index],
            false
        )
    _box_child(bathroom, "BathroomHamper", Vector3(2.08, 0.34, 5.26), Vector3(0.52, 0.66, 0.48), "fabric_blue", false)
    _box_child(bathroom, "BathroomHamperLid", Vector3(2.08, 0.70, 5.26), Vector3(0.56, 0.07, 0.52), "oak_light", false)
    _box_child(bathroom, "BathroomPrintFrame", Vector3(1.66, 1.70, 4.42), Vector3(0.055, 0.72, 0.58), "oak_dark", false)
    _box_child(bathroom, "BathroomPrint", Vector3(1.695, 1.70, 4.42), Vector3(0.018, 0.58, 0.44), "green", false)

    # Full floods require the proper tool: the mop is stored visibly against
    # the bathroom wall and must be carried back through the apartment.
    var mop := BATHROOM_MOP_SCENE.instantiate() as RigidBody3D
    mop.name = "BathroomMop"
    mop.position = Vector3(2.62, 0.02, 5.72)
    mop.rotation_degrees = Vector3(0.0, 0.0, -7.0)
    add_child(mop)
    mop.freeze = true
    mop.sleeping = true
    _objects["mop"] = mop

    var kitchen_details := _fixed_root("KitchenLivedInDetails")
    kitchen_details.add_to_group("environment_detail")
    _imported_prop(
        "res://assets/environment/shared/trashcan.glb",
        "KitchenTrashcan",
        Vector3(7.28, 0.02, -1.82),
        Vector3.ONE * 0.72,
        Vector3(0.0, -90.0, 0.0)
    )
    _cylinder_child(kitchen_details, "PaperTowelRoll", Vector3(6.95, 1.24, -5.92), Vector3.ZERO, 0.11, 0.42, "white", false)
    _cylinder_child(kitchen_details, "PaperTowelStand", Vector3(6.95, 1.06, -5.92), Vector3.ZERO, 0.14, 0.035, "metal", false)
    for jar_index in range(3):
        _cylinder_child(
            kitchen_details,
            "PantryJar_%d" % jar_index,
            Vector3(4.92 + float(jar_index) * 0.22, 1.18, -5.98),
            Vector3.ZERO,
            0.075,
            0.24 + float(jar_index) * 0.035,
            ["cream", "glass", "fabric_rust"][jar_index],
            false
        )
    _box_child(kitchen_details, "OvenMitt", Vector3(2.92, 1.66, -6.34), Vector3(0.28, 0.42, 0.06), "fabric_rust", false)
    for container_index in range(3):
        _box_child(
            kitchen_details,
            "CabinetContainer_%d" % container_index,
            Vector3(7.62, 2.10, -5.90 + float(container_index) * 0.26),
            Vector3(0.22, 0.22 + float(container_index % 2) * 0.10, 0.28),
            ["cream", "fabric_blue", "green"][container_index],
            false
        )
    var drawer := _objects.get("drawer") as Node3D
    if drawer != null:
        var drawer_contents := drawer.get_node_or_null("ContentsAnchor") as Node3D
        if drawer_contents != null:
            for utensil_index in range(5):
                _cylinder_child(
                    drawer_contents,
                    "Utensil_%d" % utensil_index,
                    Vector3(-0.27 + float(utensil_index) * 0.13, 0.06, 0.0),
                    Vector3(90.0, 0.0, -8.0 + float(utensil_index) * 4.0),
                    0.012,
                    0.31,
                    "metal",
                    false
                )
    _imported_prop(
        "res://assets/environment/shared/trashcan.glb",
        "BathroomTrashcan",
        Vector3(7.50, 0.02, 4.42),
        Vector3.ONE * 0.62,
        Vector3(0.0, 18.0, 0.0)
    )

    _omni("LivingPractical", Vector3(-7.15, 1.55, -1.42), Color("ffc47d"), 0.58, 3.2, &"office_lights")
    _omni("BedroomPractical", Vector3(-7.05, 1.34, 5.72), Color("ffb989"), 0.42, 2.8, &"bedroom_lights")
    _omni("BathroomMain", Vector3(5.15, 2.55, 4.20), Color("f4ddc0"), 1.12, 4.8, &"bathroom_lights")
    _omni("HallMirrorAccent", Vector3(-1.12, 2.10, 3.05), Color("ffd1a0"), 0.36, 2.2, &"hall_lights")

func _imported_prop(
    resource_path: String,
    node_name: String,
    pos: Vector3,
    scale_value: Vector3,
    rotation_value := Vector3.ZERO,
    material_name := ""
) -> Node3D:
    var packed := load(resource_path) as PackedScene
    if packed == null:
        push_warning("Environment prop could not be loaded: %s" % resource_path)
        return null
    var instance := packed.instantiate() as Node3D
    if instance == null:
        push_warning("Environment prop root is not Node3D: %s" % resource_path)
        return null
    instance.name = node_name
    instance.position = pos
    instance.rotation_degrees = rotation_value
    instance.scale = scale_value
    instance.add_to_group("environment_imported_prop")
    instance.set_meta("source_path", resource_path)
    add_child(instance)
    for mesh_node in instance.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := mesh_node as MeshInstance3D
        mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if not material_name.is_empty():
            mesh_instance.material_override = _materials[material_name]
    return instance

func _create_room_door(node_name: String, pivot: Vector3, angle: float, door_id: StringName, title: String, panel_material: String, inset_material: String, closed_angle := 0.0, starts_open_value := false):
    var door = HINGED_DOOR_SCRIPT.new()
    door.name = node_name
    door.display_name = title
    door.door_id = door_id
    door.source_id = door_id
    door.noise_category = &"DOOR"
    door.open_angle_degrees = angle
    door.closed_angle_degrees = closed_angle
    door.starts_open = starts_open_value
    door.normal_noise = 7.0
    door.quiet_noise = 1.2
    door.fast_noise = 22.0
    door.position = pivot
    add_child(door)
    _box_child(door, "Panel", Vector3(0.0, 1.10, 0.64), Vector3(0.055, 2.20, 1.28), panel_material, true)
    for face_x in [-0.032, 0.032]:
        _box_child(door, "InsetUpper", Vector3(face_x, 1.52, 0.64), Vector3(0.012, 0.48, 0.88), inset_material, false)
        _box_child(door, "InsetLower", Vector3(face_x, 0.62, 0.64), Vector3(0.012, 0.54, 0.88), inset_material, false)
    _box_child(door, "MiddleRail", Vector3(-0.034, 1.08, 0.64), Vector3(0.014, 0.10, 1.02), panel_material, false)
    _cylinder_child(door, "HandleHallSide", Vector3(-0.075, 1.02, 1.04), Vector3(0.0, 0.0, 90.0), 0.022, 0.18, "metal", false)
    _cylinder_child(door, "HandleRoomSide", Vector3(0.075, 1.02, 1.04), Vector3(0.0, 0.0, 90.0), 0.022, 0.18, "metal", false)
    return door
func _create_gameplay_objects() -> void:
    var player = PLAYER_CONTROLLER_SCRIPT.new()
    player.name = "Player"
    player.add_to_group("player")
    player.position = Vector3(-5.50, 0.08, -3.75)
    player.rotation_degrees.y = 0.0
    add_child(player)
    _objects["player"] = player

    _create_power_outlets()
    var television = TELEVISION_SCRIPT.new()
    television.name = "PortableTelevision"
    television.item_id = &"television"
    television.display_name = "ТЕЛЕВИЗОР С ФУТБОЛОМ"
    television.mass = 3.2
    television.quest_critical = true
    television.position = Vector3(-1.95, 1.15, -0.20)
    television.rotation_degrees.y = 90.0
    television.collision_layer = 2
    television.collision_mask = 1
    add_child(television)
    var tv_shape := BoxShape3D.new()
    tv_shape.size = Vector3(1.45, 0.84, 0.16)
    _rigid_collision(television, tv_shape)
    _box_child(television, "Case", Vector3.ZERO, Vector3(1.45, 0.84, 0.16), "black", false)
    # A box splits its UVs between six faces, which crops the video on the front.
    # The television glass is a single 16:9 quad so the whole frame maps 1:1.
    var tv_screen := MeshInstance3D.new()
    tv_screen.name = "Screen"
    tv_screen.position = Vector3(0.0, 0.0, -0.091)
    var tv_screen_quad := QuadMesh.new()
    tv_screen_quad.size = Vector2(1.30, 0.73)
    tv_screen.mesh = tv_screen_quad
    tv_screen.material_override = _materials["screen"]
    television.add_child(tv_screen)
    var pitch := _box_child(television, "Pitch", Vector3(0.0, 0.0, -0.108), Vector3(1.15, 0.46, 0.008), "green", false)
    var ball := _sphere_child(television, "Ball", Vector3.ZERO + Vector3(0.0, 0.0, -0.125), 0.035, "white", false)
    var score := _label3d("НЕТ ПИТАНИЯ", Vector3(0.0, 0.29, -0.14), Color("ffffff"), 18)
    score.rotation_degrees.y = 180.0
    television.add_child(score)
    television.configure_visuals(tv_screen, score, ball)
    pitch.visible = false
    _objects["television"] = television

    # The match beer is a physical resource: Denis has to open the fridge and take a bottle.
    var fridge_node := _objects.get("fridge") as Node3D
    var fridge_center := fridge_node.global_position if fridge_node != null else Vector3(7.38, 1.15, -0.85)
    var beer_positions := [
        fridge_center + Vector3(-0.33, -0.32, -0.26),
        fridge_center + Vector3(-0.33, -0.32, 0.0),
        fridge_center + Vector3(-0.33, -0.32, 0.26)
    ]
    for beer_index in range(beer_positions.size()):
        var beer := _create_match_beer("MatchBeerBottle_%d" % beer_index, beer_positions[beer_index], beer_index)
        _objects["match_beer" if beer_index == 0 else "match_beer_%d" % beer_index] = beer

    # SpillManager — система луж (§11 миссии), должен существовать до первого пролива
    var spill_mgr := SPILL_MANAGER_SCRIPT.new()
    spill_mgr.name = "SpillManager"
    add_child(spill_mgr)
    _objects["spill_manager"] = spill_mgr

    # Mug starts behind the interactive upper-cabinet door.
    var mug := _physical_item("Mug", &"mug", "КРУЖКА", Vector3(7.56, 1.68, -5.02), "mug", 0.42, true)
    mug.freeze = true
    mug.sleeping = true
    _objects["mug"] = mug
    # Регистрируем MugContentController в квесте — кофе считается готовым по реальному составу
    var mug_ctrl := mug.get_node_or_null("MugContentController")
    if mug_ctrl:
        QuestManager.register_mug_content_controller(mug_ctrl)

    # Coffee is physically present behind the closed drawer front.
    var coffee := _physical_item("CoffeeJar", &"coffee_jar", "РАСТВОРИМЫЙ КОФЕ", Vector3(5.50, 0.72, -6.03), "coffee_jar", 0.62, true)
    _objects["coffee"] = coffee
    var coffee_drawer := _objects.get("drawer") as Node3D
    if coffee_drawer != null:
        coffee.reparent(coffee_drawer, true)
        coffee.freeze = true
        coffee.sleeping = true

    # Cylinder collision rests exactly on the base ring at this height.  The
    # flat foot below also removes the optical gap caused by the round body.
    var kettle := _physical_item("Kettle", &"kettle", "ЧАЙНИК", Vector3(4.45, 1.352, -5.99), "kettle", 1.05, true)
    kettle.freeze = true
    kettle.sleeping = true
    _objects["kettle"] = kettle

    var spoon := _physical_item("Teaspoon", &"spoon", "ЧАЙНАЯ ЛОЖКА", Vector3(5.72, 1.13, -5.82), "spoon", 0.08, false)
    spoon.rotation_degrees.x = 90.0
    spoon.freeze = true
    spoon.sleeping = true
    _objects["spoon"] = spoon

    var towel := KITCHEN_TOWEL_SCENE.instantiate() as RigidBody3D
    towel.name = "KitchenTowel"
    towel.position = Vector3(7.33, 1.34, -4.80)
    towel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    add_child(towel)
    _cylinder_child(self, "KitchenTowelHook", Vector3(7.33, 1.46, -4.84), Vector3(90.0, 0.0, 0.0), 0.025, 0.16, "chrome", false)
    towel.add_to_group("noise_dampeners")
    _objects["towel"] = towel

    var water = _action("WaterSource", Vector3(5.30, 1.72, -2.02), "КУХОННЫЙ КРАН", "water")
    # The action uses world coordinates, while the visible sink belongs to a translated
    # KitchenFurniture root. Keep the handle, stream and flood on the actual faucet.
    water.position = Vector3(7.65, 1.72, -4.03)
    water.normal_noise = 4.0
    water.quiet_noise = 1.4
    water.fast_noise = 9.0
    water.noise_category = &"APPLIANCE"
    _cylinder_child(water, "TapTarget", Vector3(0.0, 0.0, 0.10), Vector3(90.0, 0.0, 0.0), 0.115, 0.30, "chrome", true)
    var water_stream := _cylinder_child(water, "WaterStream", Vector3(-0.34, -0.24, 0.0), Vector3.ZERO, 0.026, 0.80, "water", false)
    water_stream.visible = false
    var water_catch := Area3D.new()
    water_catch.name = "WaterCatchArea"
    water_catch.position = Vector3(-0.34, -0.24, 0.0)
    water_catch.collision_layer = 0
    water_catch.collision_mask = 16
    water_catch.monitoring = true
    water_catch.monitorable = true
    var water_catch_collision := CollisionShape3D.new()
    var water_catch_shape := CylinderShape3D.new()
    water_catch_shape.radius = 0.072
    water_catch_shape.height = 0.80
    water_catch_collision.shape = water_catch_shape
    water_catch.add_child(water_catch_collision)
    water.add_child(water_catch)
    var kitchen_flood := _cylinder_child(water, "KitchenFlood", Vector3(-0.21, -1.685, 0.55), Vector3.ZERO, 0.58, 0.018, "water", false)
    kitchen_flood.visible = false
    _objects["water"] = water

    # Continuous animated water follows the real apartment plan. Individual
    # SpillCluster nodes remain underneath as physical mop targets.
    var apartment_flood_visual := Node3D.new()
    apartment_flood_visual.name = "ApartmentFloodVisual"
    apartment_flood_visual.set_script(APARTMENT_FLOOD_VISUAL_SCRIPT)
    add_child(apartment_flood_visual)
    _objects["apartment_flood_visual"] = apartment_flood_visual

    var base = _action("KettleBase", Vector3(4.45, 1.055, -5.99), "ПОДСТАВКА ЧАЙНИКА", "kettle_base")
    base.normal_noise = 2.0
    base.quiet_noise = 0.5
    base.fast_noise = 7.0
    base.noise_category = &"KETTLE"
    _cylinder_child(base, "Base", Vector3.ZERO, Vector3.ZERO, 0.27, 0.055, "black", true)
    _cylinder_child(base, "Ring", Vector3(0.0, 0.032, 0.0), Vector3.ZERO, 0.20, 0.012, "metal", false)
    for steam_index in range(3):
        var steam := _sphere_child(base, "Steam%s" % String.chr(65 + steam_index), Vector3(0.0, 0.34 + float(steam_index) * 0.11, 0.0), 0.055 + float(steam_index) * 0.012, "glass", false)
        steam.visible = false
    _objects["kettle_base"] = base

    # Постоянная телефонная станция на консоли у входной двери.
    var phone_station := Node3D.new()
    phone_station.name = "HallwayPhoneStation"
    phone_station.position = Vector3(-1.30, 0.0, 5.05)
    add_child(phone_station)
    _box_child(phone_station, "ConsoleSurface", Vector3(0.0, 0.96, 0.0), Vector3(0.42, 0.08, 1.02), "oak_dark", true)
    _box_child(phone_station, "ConsoleLegFront", Vector3(0.0, 0.49, -0.39), Vector3(0.28, 0.90, 0.09), "oak_dark", true)
    _box_child(phone_station, "ConsoleLegRear", Vector3(0.0, 0.49, 0.39), Vector3(0.28, 0.90, 0.09), "oak_dark", true)
    _box_child(phone_station, "PhoneChargingPad", Vector3(0.0, 1.012, -0.18), Vector3(0.25, 0.018, 0.40), "black", false)
    var phone_anchor := Node3D.new()
    phone_anchor.name = "PhonePlacementAnchor"
    phone_anchor.position = Vector3(0.0, 1.04, -0.18)
    phone_anchor.set_meta("phone_hint", "ТЕЛЕФОН НА КОНСОЛИ У ВХОДА")
    phone_station.add_child(phone_anchor)
    var phone := HALLWAY_PHONE_SCENE.instantiate() as HallwayPhone
    phone.name = "Phone"
    phone.activation_delay = 34.0
    phone.activation_delay_min = 24.0
    phone.activation_delay_max = 52.0
    phone.pulse_interval = 1.7
    phone.pulse_noise = 13.0
    phone.rearm_delay_min = 48.0
    phone.rearm_delay_max = 92.0
    phone_station.add_child(phone)
    phone.global_transform = phone_anchor.global_transform
    phone.placement_anchor = phone_anchor
    var phone_lamp := _cylinder_child(phone_station, "SmallLamp", Vector3(0.0, 1.22, 0.31), Vector3.ZERO, 0.075, 0.34, "cream", false)
    phone_lamp.rotation_degrees.z = -12.0
    var phone_interaction_area := Area3D.new()
    phone_interaction_area.name = "InteractionArea"
    phone_interaction_area.position = Vector3(0.0, 1.08, -0.18)
    phone_interaction_area.collision_layer = 0
    phone_interaction_area.collision_mask = 0
    phone_station.add_child(phone_interaction_area)
    var phone_anchors: Array[Node3D] = [phone_anchor]
    var random_phone_places: Array[Dictionary] = [
        {"name": "PhoneAnchorWorkDesk", "position": Vector3(-4.82, 0.84, -5.23), "hint": "ТЕЛЕФОН НА РАБОЧЕМ СТОЛЕ"},
        {"name": "PhoneAnchorCoffeeTable", "position": Vector3(-5.48, 0.50, -0.23), "hint": "ТЕЛЕФОН НА ЖУРНАЛЬНОМ СТОЛИКЕ"},
        {"name": "PhoneAnchorDiningTable", "position": Vector3(5.43, 0.84, 1.05), "hint": "ТЕЛЕФОН НА ОБЕДЕННОМ СТОЛЕ"},
        {"name": "PhoneAnchorBedroomDresser", "position": Vector3(-2.35, 0.97, 5.66), "hint": "ТЕЛЕФОН НА КОМОДЕ В СПАЛЬНЕ"},
    ]
    for place in random_phone_places:
        var random_anchor := Node3D.new()
        random_anchor.name = String(place["name"])
        random_anchor.position = place["position"]
        random_anchor.set_meta("phone_hint", String(place["hint"]))
        add_child(random_anchor)
        phone_anchors.append(random_anchor)
    phone.configure_random_anchors(phone_anchors)
    _objects["phone_station"] = phone_station
    _objects["phone"] = phone

    var vacuum_station := Node3D.new()
    vacuum_station.name = "RobotVacuumStation"
    # Dedicated charging bay at the blind end of the hall.  It faces down the
    # corridor and stays completely outside every door leaf and doorway.
    vacuum_station.position = Vector3(0.92, 0.0, -5.42)
    vacuum_station.rotation_degrees.y = -90.0
    add_child(vacuum_station)
    _box_child(vacuum_station, "StationMat", Vector3(0.42, 0.018, 0.0), Vector3(1.42, 0.025, 1.05), "rug", false)
    _box_child(vacuum_station, "BackPanel", Vector3(-0.25, 0.47, 0.0), Vector3(0.07, 0.88, 1.02), "cabinet_dark", false)
    _box_child(vacuum_station, "ServiceShelf", Vector3(-0.16, 0.86, 0.0), Vector3(0.28, 0.06, 1.04), "oak_dark", false)
    _box_child(vacuum_station, "PowerOutlet", Vector3(-0.205, 0.46, 0.36), Vector3(0.018, 0.20, 0.15), "white", false)
    _box_child(vacuum_station, "PowerSocket", Vector3(-0.192, 0.46, 0.36), Vector3(0.012, 0.075, 0.075), "black", false)
    _box_child(vacuum_station, "SpareFilterBox", Vector3(-0.02, 0.98, -0.30), Vector3(0.24, 0.18, 0.28), "cardboard", false)
    _box_child(vacuum_station, "StatusPlate", Vector3(-0.205, 0.65, -0.10), Vector3(0.014, 0.14, 0.36), "metal", false)
    var station_label := _label3d("БАЗА РОБОТА", Vector3(-0.194, 0.65, -0.10), Color("172329"), 20)
    station_label.name = "StationLabel"
    station_label.rotation_degrees.y = 90.0
    vacuum_station.add_child(station_label)
    _box_child(vacuum_station, "ChargingDock", Vector3(-0.10, 0.11, 0.0), Vector3(0.18, 0.22, 0.66), "black", true)
    _box_child(vacuum_station, "DockLight", Vector3(-0.205, 0.15, 0.0), Vector3(0.012, 0.055, 0.12), "green", false)
    var vacuum_anchor := Node3D.new()
    vacuum_anchor.name = "VacuumSpawnAnchor"
    vacuum_anchor.position = Vector3(0.22, 0.12, 0.0)
    vacuum_station.add_child(vacuum_anchor)
    var exit_marker := Node3D.new()
    exit_marker.name = "ExitDirection"
    exit_marker.position = Vector3(1.02, 0.12, 0.0)
    vacuum_station.add_child(exit_marker)
    var exit_area := Area3D.new()
    exit_area.name = "ExitClearanceArea"
    exit_area.position = Vector3(0.70, 0.15, 0.0)
    exit_area.collision_layer = 0
    exit_area.collision_mask = 3
    exit_area.monitoring = true
    var exit_collision := CollisionShape3D.new()
    var exit_shape := BoxShape3D.new()
    exit_shape.size = Vector3(1.20, 0.24, 0.72)
    exit_collision.shape = exit_shape
    exit_area.add_child(exit_collision)
    vacuum_station.add_child(exit_area)
    _omni("VacuumStationLight", Vector3(0.92, 1.35, -4.92), Color("d8ecdf"), 0.72, 2.35, &"practical_light")
    var vacuum = HOUSEHOLD_HAZARD_SCRIPT.new()
    vacuum.name = "RobotVacuum"
    vacuum.hazard_type = "vacuum"
    vacuum.display_name = "РОБОТ-ПЫЛЕСОС"
    vacuum.activation_delay = 42.0
    vacuum.pulse_interval = 1.35
    vacuum.pulse_noise = 18.0
    vacuum.rearm_delay_min = 90.0
    vacuum.rearm_delay_max = 135.0
    vacuum.movement_speed = 1.18
    vacuum.flee_speed = 2.10
    vacuum.flee_radius = 3.20
    vacuum.normal_noise = 1.0
    vacuum.quiet_noise = 0.2
    vacuum.fast_noise = 3.0
    vacuum.station_anchor = vacuum_anchor
    vacuum.exit_direction = Vector3.BACK
    vacuum.exit_clearance_distance = 0.72
    vacuum_station.add_child(vacuum)
    vacuum.global_position = vacuum_anchor.global_position
    _cylinder_child(vacuum, "VacuumBody", Vector3.ZERO, Vector3.ZERO, 0.29, 0.10, "black", true)
    _cylinder_child(vacuum, "VacuumTop", Vector3(0.0, 0.065, 0.0), Vector3.ZERO, 0.21, 0.035, "metal", false)
    _cylinder_child(vacuum, "LeftWheel", Vector3(-0.22, -0.035, 0.0), Vector3(0.0, 0.0, 90.0), 0.065, 0.05, "metal", false)
    _cylinder_child(vacuum, "RightWheel", Vector3(0.22, -0.035, 0.0), Vector3(0.0, 0.0, 90.0), 0.065, 0.05, "metal", false)
    _box_child(vacuum, "FrontBumper", Vector3(0.0, 0.005, -0.275), Vector3(0.34, 0.055, 0.045), "metal", false)
    _cylinder_child(vacuum, "Indicator", Vector3(0.0, 0.09, -0.11), Vector3.ZERO, 0.035, 0.012, "red", false).visible = false
    _objects["vacuum"] = vacuum
    _objects["vacuum_station"] = vacuum_station
    
    # Новые интерактивные объекты
    var smart_tv := _spawn_smart_tv()
    _objects["smart_tv"] = smart_tv
    
    var smart_kettle := _spawn_smart_kettle()
    _objects["smart_kettle"] = smart_kettle
    
    var headphones := _spawn_noise_cancelling_headphones()
    _objects["headphones"] = headphones
    
    _create_loose_clutter()
    _create_cash_stashes()

func _create_cash_stashes() -> void:
    var stashes := [
        {"name": "DeskCash", "position": Vector3(-4.65, 0.86, -5.12), "amount": 180.0},
        {"name": "CoffeeTableCash", "position": Vector3(-5.15, 0.58, -0.20), "amount": 120.0},
        {"name": "NightstandCash", "position": Vector3(-7.10, 0.70, 5.42), "amount": 250.0},
        {"name": "DresserCash", "position": Vector3(-2.78, 0.98, 5.88), "amount": 350.0},
        {"name": "WardrobeCash", "position": Vector3(-6.95, 0.36, 8.72), "amount": 450.0},
        {"name": "HallCash", "position": Vector3(-0.72, 0.16, -4.82), "amount": 300.0},
        {"name": "KitchenCash", "position": Vector3(2.82, 1.12, -4.92), "amount": 420.0},
        {"name": "EmergencyCash", "position": Vector3(-4.20, 0.10, 7.45), "amount": 600.0}
    ]
    for data in stashes:
        var stash := _spawn_cash_stash(String(data["name"]), data["position"], float(data["amount"]), false)
        _objects[String(data["name"]).to_snake_case()] = stash

func _spawn_dynamic_cash() -> void:
    var player := get_tree().get_first_node_in_group("player") as Node3D
    var selected := Vector3.ZERO
    var found_point := false
    for attempt in range(_cash_spawn_points.size()):
        var index := (_cash_spawn_cursor + attempt) % _cash_spawn_points.size()
        var candidate: Vector3 = _cash_spawn_points[index]
        if player != null and player.global_position.distance_to(candidate) < 1.25:
            continue
        var occupied := false
        for cash_node in get_tree().get_nodes_in_group("cash_stash"):
            if cash_node is Node3D and (cash_node as Node3D).global_position.distance_to(candidate) < 0.70:
                occupied = true
                break
        if occupied:
            continue
        selected = candidate
        _cash_spawn_cursor = (index + 1) % _cash_spawn_points.size()
        found_point = true
        break
    if not found_point:
        return
    _cash_spawn_serial += 1
    var debt_bonus := mini(180, RunStats.missed_payments * 45)
    var amount := float(randi_range(90, 240) + debt_bonus)
    var stash := _spawn_cash_stash("DynamicCash_%03d" % _cash_spawn_serial, selected, amount, true)
    stash.add_to_group("dynamic_cash")
    var room_title := _cash_room_title(NoiseManager.room_for_position(selected))
    QuestManager.notification_requested.emit("ГДЕ-ТО ПОЯВИЛИСЬ ДЕНЬГИ  •  %s  •  %.0f ₽" % [room_title, amount])

func _spawn_cash_stash(node_name: String, position_value: Vector3, amount: float, spawned: bool) -> Node3D:
    var stash: Variant = CASH_PICKUP_SCRIPT.new()
    stash.name = node_name
    stash.display_name = "ПОЯВИВШИЕСЯ ДЕНЬГИ" if spawned else "СПРЯТАННЫЕ ДЕНЬГИ"
    stash.amount = amount
    stash.position = position_value
    stash.normal_noise = 0.5
    stash.quiet_noise = 0.1
    stash.fast_noise = 1.2
    stash.noise_category = &"OBJECT_LIFT"
    stash.source_id = &"cash"
    add_child(stash)
    _box_child(stash, "Banknotes", Vector3.ZERO, Vector3(0.28, 0.025, 0.14), "green", true)
    _box_child(stash, "PaperBand", Vector3(0.0, 0.018, 0.0), Vector3(0.055, 0.012, 0.15), "cream", false)
    return stash as Node3D

func _cash_room_title(room_id: StringName) -> String:
    match room_id:
        &"office": return "ГОСТИНАЯ / КАБИНЕТ"
        &"kitchen": return "КУХНЯ"
        &"corridor": return "КОРИДОР"
        &"bedroom": return "СПАЛЬНЯ"
        &"bathroom": return "ВАННАЯ"
        &"wardrobe": return "ГАРДЕРОБНАЯ"
    return "КВАРТИРА"

func _create_loose_clutter() -> void:
    # Living room: every prop is independent and can hide the phone.
    _loose_box("RemoteControl", "ПУЛЬТ", Vector3(-5.00, 0.52, -0.12), Vector3(0.11, 0.035, 0.28), "black", 0.12)
    _loose_box("Magazine", "ЖУРНАЛ", Vector3(-5.28, 0.51, 0.08), Vector3(0.34, 0.025, 0.45), "fabric_blue", 0.10)
    _loose_box("BookLooseA", "КНИГА", Vector3(-6.42, 1.18, 1.18), Vector3(0.28, 0.07, 0.42), "fabric_rust", 0.18)
    _loose_box("BookLooseB", "КНИГА", Vector3(-6.18, 1.25, 1.24), Vector3(0.26, 0.06, 0.38), "green", 0.18)

    # Kitchen clutter is spaced across separate landing zones.
    _parked_loose_box("CerealBox", "ХЛОПЬЯ", Vector3(3.85, 1.28, -6.05), Vector3(0.24, 0.48, 0.16), "yellow", 0.28)
    _parked_loose_box("TeaBox", "КОРОБКА ЧАЯ", Vector3(4.15, 1.17, -6.05), Vector3(0.22, 0.22, 0.16), "fabric_rust", 0.20)
    _parked_loose_box("CuttingBoard", "РАЗДЕЛОЧНАЯ ДОСКА", Vector3(6.62, 1.10, -5.96), Vector3(0.55, 0.045, 0.34), "oak_light", 0.30)
    _parked_loose_box("DishTowel", "КУХОННОЕ ПОЛОТЕНЦЕ", Vector3(7.52, 1.18, -3.90), Vector3(0.42, 0.055, 0.48), "fabric_blue", 0.15)
    _parked_loose_box("Sponge", "ГУБКА", Vector3(7.14, 1.14, -4.02), Vector3(0.16, 0.07, 0.10), "yellow", 0.08)
    _parked_loose_box("SoapBottle", "СРЕДСТВО ДЛЯ ПОСУДЫ", Vector3(7.45, 1.24, -3.15), Vector3(0.13, 0.32, 0.13), "green", 0.24)

    # Bedroom props make searching under and around furniture meaningful.
    _loose_box("BedroomPillow", "ПОДУШКА РИТЫ", Vector3(-7.35, 0.98, 4.42), Vector3(0.55, 0.17, 0.44), "white", 0.20)
    _loose_box("LaundryBasket", "КОРЗИНА С БЕЛЬЁМ", Vector3(-2.20, 0.35, 4.35), Vector3(0.52, 0.65, 0.52), "cream", 0.55)
    _loose_box("ClothesPile", "КУЧА ОДЕЖДЫ", Vector3(-2.85, 0.16, 4.05), Vector3(0.58, 0.24, 0.44), "fabric_blue", 0.30)
    _loose_box("Perfume", "ДУХИ РИТЫ", Vector3(-2.55, 1.02, 5.72), Vector3(0.10, 0.22, 0.10), "glass", 0.18)
    _loose_box("HairBrush", "РАСЧЁСКА", Vector3(-2.20, 1.00, 5.68), Vector3(0.10, 0.06, 0.30), "fabric_rust", 0.12)
func _create_power_outlets() -> void:
    var outlets := [
        Vector3(-1.72, 0.38, -0.20),
        Vector3(1.72, 0.38, -4.10),
        Vector3(-1.72, 0.38, 4.70),
        Vector3(1.72, 0.38, 4.70),
        Vector3(-3.00, 0.38, 5.92)
    ]
    for i in range(outlets.size()):
        var outlet = _action("PowerOutlet_%d" % i, outlets[i], "РОЗЕТКА 220В", "inspect")
        outlet.add_to_group("power_outlet")
        outlet.set_meta("interaction_message", "СЮДА МОЖНО ПОДКЛЮЧИТЬ ТЕЛЕВИЗОР")
        _box_child(outlet, "Plate", Vector3.ZERO, Vector3(0.08, 0.22, 0.16), "white", true)
        _cylinder_child(outlet, "SocketA", Vector3(-0.045, 0.035, -0.09), Vector3(90.0, 0.0, 0.0), 0.018, 0.015, "black", false)
        _cylinder_child(outlet, "SocketB", Vector3(-0.045, -0.035, -0.09), Vector3(90.0, 0.0, 0.0), 0.018, 0.015, "black", false)
func _configure_rooms() -> void:
    var rooms := {
        &"office": {"bounds": AABB(Vector3(-8.1, -1.0, -6.6), Vector3(6.5, 5.0, 8.6)), "multiplier": 0.56},
        &"corridor": {"bounds": AABB(Vector3(-1.6, -1.0, -6.6), Vector3(3.2, 5.0, 13.2)), "multiplier": 0.90},
        &"kitchen": {"bounds": AABB(Vector3(1.6, -1.0, -6.6), Vector3(6.5, 5.0, 8.6)), "multiplier": 0.72},
        &"bedroom": {"bounds": AABB(Vector3(-8.1, -1.0, 2.0), Vector3(6.5, 5.0, 4.6)), "multiplier": 1.0},
        &"bathroom": {"bounds": AABB(Vector3(1.6, -1.0, 2.0), Vector3(6.5, 5.0, 4.6)), "multiplier": 0.72},
        &"wardrobe": {"bounds": AABB(Vector3(-8.1, -1.0, 6.5), Vector3(6.5, 5.0, 3.1)), "multiplier": 0.42}
    }
    var edges: Array[Dictionary] = [
        {"a": &"office", "b": &"corridor", "attenuation": 0.78},
        {"a": &"corridor", "b": &"kitchen", "attenuation": 0.86, "door_id": &"kitchen_door", "door_open": false},
        {"a": &"corridor", "b": &"bedroom", "attenuation": 0.54, "door_id": &"bedroom_door", "door_open": false},
        {"a": &"corridor", "b": &"bathroom", "attenuation": 0.62, "door_id": &"bathroom_door", "door_open": false},
        {"a": &"bedroom", "b": &"wardrobe", "attenuation": 0.38, "door_id": &"wardrobe_door", "door_open": false}
    ]
    NoiseManager.configure_rooms(rooms, edges)
    NoiseManager.set_door_open(&"bedroom_door", false)
    NoiseManager.set_door_open(&"bathroom_door", false)
    NoiseManager.set_door_open(&"wardrobe_door", false)

# --- Procedural furniture assets ------------------------------------------------

func _create_office_chair(pos: Vector3, angle: float) -> void:
    var chair := _furniture_root("OfficeChair", pos)
    chair.rotation_degrees.y = angle
    _cylinder_child(chair, "Post", Vector3(0.0, 0.42, 0.0), Vector3.ZERO, 0.045, 0.52, "metal", true)
    _cylinder_child(chair, "Seat", Vector3(0.0, 0.66, 0.0), Vector3.ZERO, 0.38, 0.13, "fabric_blue", true)
    _box_child(chair, "Back", Vector3(0.0, 1.03, 0.28), Vector3(0.62, 0.68, 0.12), "fabric_blue", true)
    for i in range(5):
        var angle_rad := TAU * float(i) / 5.0
        var end := Vector3(cos(angle_rad) * 0.34, 0.18, sin(angle_rad) * 0.34)
        _cylinder_between(chair, "ChairBase_%d" % i, Vector3(0.0, 0.20, 0.0), end, 0.025, "metal")
        _sphere_child(chair, "Wheel_%d" % i, end + Vector3.DOWN * 0.06, 0.055, "black", false)

func _create_desk_lamp(pos: Vector3) -> void:
    var lamp := _furniture_root("DeskLamp", pos)
    _cylinder_child(lamp, "Base", Vector3.ZERO, Vector3.ZERO, 0.18, 0.045, "black", true)
    _cylinder_child(lamp, "Stem", Vector3(0.0, 0.30, 0.0), Vector3.ZERO, 0.025, 0.58, "metal", false)
    _sphere_child(lamp, "Shade", Vector3(0.0, 0.61, 0.08), 0.16, "black", false)
    _sphere_child(lamp, "Glow", Vector3(0.0, 0.55, 0.11), 0.085, "warm_light", false)

func _create_notebook_stack(pos: Vector3) -> void:
    var books := _furniture_root("NotebookStack", pos)
    _box_child(books, "BookA", Vector3.ZERO, Vector3(0.34, 0.045, 0.46), "fabric_rust", true)
    _box_child(books, "BookB", Vector3(0.02, 0.055, -0.01), Vector3(0.30, 0.045, 0.43), "fabric_blue", false)
    _cylinder_child(books, "Pen", Vector3(-0.12, 0.105, 0.0), Vector3(90.0, 0.0, 18.0), 0.012, 0.35, "yellow", false)

func _create_sofa(pos: Vector3, angle: float) -> void:
    var sofa := _furniture_root("Sofa", pos + Vector3.UP * 0.30)
    sofa.rotation_degrees.y = angle
    _box_child(sofa, "Base", Vector3.ZERO, Vector3(2.15, 0.45, 0.88), "sofa", true)
    _box_child(sofa, "Back", Vector3(0.0, 0.62, 0.35), Vector3(2.15, 0.78, 0.24), "sofa", true)
    _box_child(sofa, "LeftArm", Vector3(-1.00, 0.43, 0.0), Vector3(0.22, 0.62, 0.88), "sofa", true)
    _box_child(sofa, "RightArm", Vector3(1.00, 0.43, 0.0), Vector3(0.22, 0.62, 0.88), "sofa", true)
    _box_child(sofa, "SeatLeft", Vector3(-0.48, 0.30, -0.08), Vector3(0.88, 0.18, 0.66), "fabric_blue", false)
    _box_child(sofa, "SeatRight", Vector3(0.48, 0.30, -0.08), Vector3(0.88, 0.18, 0.66), "fabric_blue", false)
    _box_child(sofa, "CushionA", Vector3(-0.55, 0.68, 0.15), Vector3(0.48, 0.48, 0.14), "fabric_rust", false)
    _box_child(sofa, "CushionB", Vector3(0.40, 0.68, 0.15), Vector3(0.56, 0.46, 0.14), "rug_light", false)
    for x in [-0.82, 0.82]:
        _box_child(sofa, "Leg", Vector3(x, -0.26, 0.24), Vector3(0.09, 0.18, 0.09), "oak_dark", false)

func _create_coffee_table(pos: Vector3) -> void:
    var table := _furniture_root("CoffeeTable", pos)
    _box_child(table, "Top", Vector3(0.0, 0.42, 0.0), Vector3(1.12, 0.08, 0.72), "oak_light", true)
    _box_child(table, "Shelf", Vector3(0.0, 0.16, 0.0), Vector3(0.92, 0.05, 0.58), "oak", false)
    for x in [-0.46, 0.46]:
        for z in [-0.27, 0.27]:
            _box_child(table, "Leg", Vector3(x, 0.20, z), Vector3(0.055, 0.40, 0.055), "black", true)
    _box_child(table, "Remote", Vector3(0.20, 0.49, 0.02), Vector3(0.10, 0.025, 0.28), "black", false)

func _create_tv_console(pos: Vector3, angle: float) -> void:
    var console := _furniture_root("TVConsole", pos)
    console.rotation_degrees.y = angle
    _box_child(console, "Body", Vector3(0.0, 0.38, 0.0), Vector3(1.68, 0.65, 0.42), "oak", true)
    _box_child(console, "DoorA", Vector3(-0.42, 0.38, -0.225), Vector3(0.76, 0.48, 0.035), "oak_light", false)
    _box_child(console, "DoorB", Vector3(0.42, 0.38, -0.225), Vector3(0.76, 0.48, 0.035), "oak_light", false)

func _create_bookshelf(pos: Vector3) -> void:
    var shelf := _furniture_root("Bookshelf", pos + Vector3.UP * 0.91)
    _box_child(shelf, "Back", Vector3.ZERO, Vector3(1.55, 1.72, 0.16), "oak_dark", true)
    _box_child(shelf, "SideL", Vector3(-0.78, 0.0, -0.12), Vector3(0.10, 1.82, 0.42), "oak", true)
    _box_child(shelf, "SideR", Vector3(0.78, 0.0, -0.12), Vector3(0.10, 1.82, 0.42), "oak", true)
    for row in range(4):
        var y := -0.78 + float(row) * 0.53
        _box_child(shelf, "Shelf_%d" % row, Vector3(0.0, y, -0.12), Vector3(1.55, 0.07, 0.42), "oak_light", true)
        for book in range(5):
            var mat_name: String = ["fabric_blue", "fabric_rust", "yellow", "green"][((row * 5) + book) % 4]
            var height := 0.25 + float((row + book) % 3) * 0.045
            _box_child(shelf, "Book_%d_%d" % [row, book], Vector3(-0.57 + float(book) * 0.23, y + 0.05 + height * 0.5, -0.36), Vector3(0.14, height, 0.22), mat_name, false)

func _create_plant(pos: Vector3, scale_value: float) -> void:
    var plant := _furniture_root("Plant", pos)
    _cylinder_child(plant, "Pot", Vector3(0.0, 0.22 * scale_value, 0.0), Vector3.ZERO, 0.22 * scale_value, 0.42 * scale_value, "fabric_rust", true)
    _cylinder_child(plant, "Stem", Vector3(0.0, 0.68 * scale_value, 0.0), Vector3.ZERO, 0.035 * scale_value, 0.72 * scale_value, "green", false)
    for i in range(7):
        var angle := TAU * float(i) / 7.0
        var leaf_pos := Vector3(cos(angle) * 0.19, 0.66 + float(i % 3) * 0.18, sin(angle) * 0.19) * scale_value
        var leaf := _sphere_child(plant, "Leaf_%d" % i, leaf_pos, 0.18 * scale_value, "leaf", false)
        leaf.scale = Vector3(0.62, 1.45, 0.45)

func _create_wall_art(pos: Vector3, angle: float) -> void:
    var art := _fixed_root("WallArt", pos)
    var wall_normal := Vector3.ZERO
    if absf(pos.x) >= absf(pos.z):
        wall_normal = Vector3(-signf(pos.x), 0.0, 0.0)
    else:
        wall_normal = Vector3(0.0, 0.0, -signf(pos.z))
    place_wall_prop(art, Transform3D(Basis.IDENTITY, pos), wall_normal, 0.07)
    # Локальная +X — лицевая сторона. Рама собрана рейками, а не сплошным
    # чёрным блоком, поэтому изображение не утоплено и имеет реальную глубину.
    _box_child(art, "BackPanel", Vector3.ZERO, Vector3(0.045, 0.96, 1.36), "cabinet_dark", false)
    _box_child(art, "FrameTop", Vector3(0.030, 0.49, 0.0), Vector3(0.075, 0.08, 1.44), "black", false)
    _box_child(art, "FrameBottom", Vector3(0.030, -0.49, 0.0), Vector3(0.075, 0.08, 1.44), "black", false)
    _box_child(art, "FrameLeft", Vector3(0.030, 0.0, -0.68), Vector3(0.075, 0.92, 0.08), "black", false)
    _box_child(art, "FrameRight", Vector3(0.030, 0.0, 0.68), Vector3(0.075, 0.92, 0.08), "black", false)
    _box_child(art, "Paper", Vector3(0.048, 0.0, 0.0), Vector3(0.012, 0.88, 1.28), "cream", false)
    _box_child(art, "ShapeA", Vector3(0.056, 0.14, -0.24), Vector3(0.008, 0.28, 0.42), "fabric_rust", false)
    _box_child(art, "ShapeB", Vector3(0.057, -0.14, 0.24), Vector3(0.008, 0.34, 0.52), "fabric_blue", false)

func _create_city_investigation_board(pos: Vector3, angle: float) -> void:
    var board := _fixed_root("CityInvestigationBoard", pos)
    var wall_normal := Vector3.ZERO
    if absf(pos.x) >= absf(pos.z):
        wall_normal = Vector3(-signf(pos.x), 0.0, 0.0)
    else:
        wall_normal = Vector3(0.0, 0.0, -signf(pos.z))
    place_wall_prop(board, Transform3D(Basis.IDENTITY, pos), wall_normal, 0.07)

    # Доска — кремовый фон с тёмной рамкой, как типичная расследовательская доска.
    _box_child(board, "BackPanel", Vector3.ZERO, Vector3(0.045, 1.10, 1.50), "cabinet_dark", false)
    _box_child(board, "CorkBoard", Vector3(0.025, 0.0, 0.0), Vector3(0.018, 1.02, 1.42), "cream", false)

    # Рамка из досок — имитирует деревянную доску для наклеек.
    _box_child(board, "FrameTop", Vector3(0.030, 0.52, 0.0), Vector3(0.075, 0.08, 1.58), "oak_dark", false)
    _box_child(board, "FrameBottom", Vector3(0.030, -0.52, 0.0), Vector3(0.075, 0.08, 1.58), "oak_dark", false)
    _box_child(board, "FrameLeft", Vector3(0.030, 0.0, -0.75), Vector3(0.075, 1.06, 0.08), "oak_dark", false)
    _box_child(board, "FrameRight", Vector3(0.030, 0.0, 0.75), Vector3(0.075, 1.06, 0.08), "oak_dark", false)

    # Города с рейтинговыми номерами. Расположены по вертикали с отступом.
    var cities := [
        {"name": "МОСКВА",         "rank": "1", "y_offset": 0.38},
        {"name": "САНКТ-ПЕТЕРБУРГ", "rank": "2", "y_offset": 0.15},
        {"name": "ЧЕЛЯБИНСК",      "rank": "3", "y_offset": -0.08},
        {"name": "НОВОСИБИРСК",     "rank": "4", "y_offset": -0.31},
        {"name": "ЕКАТЕРИНБУРГ",    "rank": "5", "y_offset": -0.54}
    ]

    # Пины / карточки для каждого города
    for city in cities:
        var card_y: float = float(city["y_offset"])
        # Карточка с номером рейтинга
        _box_child(board, "Pin_%s" % city["name"], Vector3(0.055, card_y, -0.58), Vector3(0.012, 0.08, 0.08), "red", false)
        # Галочка на карточке (пометка галочкой)
        _box_child(board, "Check_%s" % city["name"], Vector3(0.058, card_y, -0.54), Vector3(0.006, 0.04, 0.04), "cream", false)
        # Название города
        var city_label := _label3d(city["name"], Vector3(0.055, card_y + 0.10, -0.58), Color("191d20"), 13)
        board.add_child(city_label)
        # Номер рейтинга
        var rank_label := _label3d(city["rank"], Vector3(0.055, card_y - 0.06, -0.54), Color("d7c8ae"), 16)
        board.add_child(rank_label)

    # Красные нити, соединяющие города цепочкой по рейтингу
    for i in range(cities.size() - 1):
        var start_y: float = float(cities[i]["y_offset"])
        var end_y: float = float(cities[i + 1]["y_offset"])
        var start_pos := Vector3(0.055, start_y, -0.55)
        var end_pos := Vector3(0.055, end_y, -0.55)
        _cylinder_between(board, "Thread_%d_%d" % [i, i + 1], start_pos, end_pos, 0.006, "red")

    # Заголовок доски
    var title_label := _label3d("РЕЙТИНГ ГОРОДОВ", Vector3(0.055, 0.58, 0.0), Color("d7c8ae"), 15)
    board.add_child(title_label)

    # Декоративные бумажки-примечания на доске
    _box_child(board, "Note_1", Vector3(0.055, 0.22, 0.45), Vector3(0.012, 0.16, 0.10), "yellow", false)
    _box_child(board, "Note_2", Vector3(0.055, -0.18, 0.38), Vector3(0.012, 0.14, 0.09), "orange", false)
    _box_child(board, "Note_3", Vector3(0.055, -0.42, 0.42), Vector3(0.012, 0.12, 0.08), "fabric_rust", false)

    # Крепёжные пины (гвоздики) в углах доски
    for corner in [Vector3(0.055, 0.50, -0.72), Vector3(0.055, 0.50, 0.72), Vector3(0.055, -0.50, -0.72), Vector3(0.055, -0.50, 0.72)]:
        _sphere_child(board, "Nail_%s" % str(corner), corner, 0.014, "metal", false)

func place_wall_prop(
    prop: Node3D,
    wall_transform: Transform3D,
    wall_normal: Vector3,
    prop_depth: float,
    visual_gap: float = 0.006
) -> void:
    var normal := wall_normal.normalized()
    prop.global_position = wall_transform.origin + normal * (prop_depth * 0.5 + visual_gap)
    var yaw := 0.0
    if normal.is_equal_approx(Vector3.LEFT):
        yaw = PI
    elif normal.is_equal_approx(Vector3.FORWARD):
        yaw = PI * 0.5
    elif normal.is_equal_approx(Vector3.BACK):
        yaw = -PI * 0.5
    prop.global_rotation = Vector3(0.0, yaw, 0.0)

func _create_dining_area() -> void:
    # Keep the kitchen work aisle open: dining belongs against the south wall,
    # not in the centre of the room.
    var dining := _furniture_root("DiningArea", Vector3(5.72, 0.0, 1.26))
    _box_child(dining, "TableTop", Vector3.ZERO + Vector3.UP * 0.76, Vector3(1.45, 0.10, 0.82), "oak_light", true)
    for x in [-0.58, 0.58]:
        for z in [-0.28, 0.28]:
            _box_child(dining, "TableLeg", Vector3(x, 0.38, z), Vector3(0.07, 0.72, 0.07), "black", true)
    _create_dining_chair(Vector3(4.58, 0.0, 1.26), -90.0)
    _create_dining_chair(Vector3(6.86, 0.0, 1.26), 90.0)
    _cylinder_child(dining, "FruitBowl", Vector3(0.0, 0.86, 0.0), Vector3.ZERO, 0.22, 0.08, "cream", false)
    _sphere_child(dining, "Apple", Vector3(-0.08, 0.94, 0.0), 0.07, "red", false)
    _sphere_child(dining, "Orange", Vector3(0.07, 0.94, 0.03), 0.075, "yellow", false)

func _create_dining_chair(pos: Vector3, angle: float) -> void:
    var chair := _furniture_root("DiningChair", pos)
    chair.rotation_degrees.y = angle
    _box_child(chair, "Seat", Vector3(0.0, 0.48, 0.0), Vector3(0.55, 0.10, 0.55), "oak", true)
    _box_child(chair, "Back", Vector3(0.0, 0.84, 0.24), Vector3(0.55, 0.62, 0.08), "oak", true)
    for x in [-0.22, 0.22]:
        for z in [-0.20, 0.20]:
            _box_child(chair, "Leg", Vector3(x, 0.23, z), Vector3(0.055, 0.46, 0.055), "black", true)

func _create_toaster(pos: Vector3) -> void:
    var toaster := _furniture_root("Toaster", pos)
    _box_child(toaster, "Body", Vector3.ZERO, Vector3(0.42, 0.28, 0.25), "metal", true)
    _box_child(toaster, "Slot", Vector3(0.0, 0.15, 0.0), Vector3(0.27, 0.025, 0.06), "black", false)
    _box_child(toaster, "Lever", Vector3(0.24, 0.0, 0.0), Vector3(0.05, 0.10, 0.04), "black", false)

func _create_dish_rack(pos: Vector3) -> void:
    var rack := _furniture_root("DishRack", pos)
    _box_child(rack, "Tray", Vector3.ZERO, Vector3(0.46, 0.04, 0.68), "metal", true)
    for i in range(4):
        var plate := _cylinder_child(rack, "Plate_%d" % i, Vector3(0.0, 0.15, -0.22 + float(i) * 0.14), Vector3(90.0, 0.0, 0.0), 0.15, 0.025, "white", false)
        plate.scale.x = 0.85

func _create_kitchen_decor() -> void:
    var decor := _fixed_root("KitchenDecor", Vector3(2.35, 0.0, -2.05))
    _create_rug(Vector3(5.72, 0.012, 1.26), Vector2(2.55, 1.28))
    _create_wall_art(Vector3(7.84, 1.55, -0.35), -90.0)
    _cylinder_child(decor, "KnifeBlock", Vector3(4.37, 1.18, -3.87), Vector3.ZERO, 0.14, 0.32, "oak", false)
    for i in range(3):
        _box_child(decor, "Knife_%d" % i, Vector3(4.30 + float(i) * 0.07, 1.47, -3.87), Vector3(0.025, 0.28 + float(i) * 0.04, 0.08), "metal", false)
    _cylinder_child(decor, "Soap", Vector3(5.05, 1.22, -1.05), Vector3.ZERO, 0.08, 0.28, "yellow", false)
    _create_plant(Vector3(6.18, 1.04, -5.92), 0.42)
    _create_plant(Vector3(2.35, 0.0, -0.35), 0.55)
    var note := _label3d("НЕ ГРЕМЕТЬ.\nРИТА СПИТ.", Vector3(1.34, 1.78, -3.10), Color("f3d887"), 22)
    note.rotation_degrees.y = -90.0
    add_child(note)

func _create_rug(pos: Vector3, size_value: Vector2) -> void:
    var rug := _fixed_root("LivingRug")
    var base := _box_child(rug, "Base", pos, Vector3(size_value.x, 0.035, size_value.y), "rug", false)
    _mark_soft_surface(base, size_value)
    for i in range(7):
        var x := pos.x - size_value.x * 0.38 + float(i) * size_value.x * 0.126
        _box_child(rug, "Pattern_%d" % i, Vector3(x, pos.y + 0.021, pos.z), Vector3(0.06, 0.012, size_value.y * 0.82), "rug_light", false)

func _mark_soft_surface(surface: Node3D, size_value: Vector2) -> void:
    surface.add_to_group("soft_surface")
    surface.set_meta("soft_size", size_value)

func _create_slipper(parent: Node3D, node_name: String, pos: Vector3, angle: float) -> void:
    var root := Node3D.new()
    root.name = node_name
    root.position = pos
    root.rotation_degrees.y = angle
    parent.add_child(root)
    var sole := _box_child(root, "Sole", Vector3.ZERO, Vector3(0.22, 0.07, 0.44), "fabric_rust", true)
    sole.scale.x = 0.90
    _box_child(root, "Strap", Vector3(0.0, 0.06, -0.03), Vector3(0.23, 0.08, 0.18), "cream", false)

# --- Primitive asset helpers ---------------------------------------------------

func _create_match_beer(node_name: String, pos: Vector3, beer_index: int) -> RigidBody3D:
    var beer = MATCH_BEER_SCRIPT.new()
    beer.name = node_name
    beer.item_id = StringName("match_beer_bottle_%d" % beer_index)
    beer.display_name = "ХОЛОДНОЕ ПИВО ДЛЯ МАТЧА"
    beer.mass = 0.48
    beer.position = pos
    beer.collision_layer = 2
    beer.collision_mask = 3
    add_child(beer)
    var beer_shape := CylinderShape3D.new()
    beer_shape.radius = 0.072
    beer_shape.height = 0.38
    _rigid_collision(beer, beer_shape)
    _cylinder_child(beer, "BottleGlass", Vector3.ZERO, Vector3.ZERO, 0.065, 0.32, "glass", false)
    var beer_liquid := _cylinder_child(beer, "BeerLiquid", Vector3(0.0, -0.055, 0.0), Vector3.ZERO, 0.052, 0.22, "yellow", false)
    _cylinder_child(beer, "Label", Vector3(0.0, -0.025, 0.0), Vector3.ZERO, 0.068, 0.105, "fabric_blue", false)
    _cylinder_child(beer, "Neck", Vector3(0.0, 0.19, 0.0), Vector3.ZERO, 0.033, 0.11, "glass", false)
    _cylinder_child(beer, "Cap", Vector3(0.0, 0.255, 0.0), Vector3.ZERO, 0.037, 0.025, "metal", false)
    beer.configure_visuals(beer_liquid)
    beer.freeze = true
    beer.sleeping = true
    return beer

func _create_rita_cat_zone() -> void:
    # A compact, wall-side home base makes the cat feel resident without narrowing
    # the coffee route. The courier box doubles as a safe optional story location.
    var cat_bed := Node3D.new()
    cat_bed.name = "RitaCatBed"
    cat_bed.position = Vector3(-5.62, 0.08, 1.52)
    add_child(cat_bed)
    _cylinder_child(cat_bed, "BedBase", Vector3.ZERO, Vector3.ZERO, 0.42, 0.10, "fabric_blue", false)
    _cylinder_child(cat_bed, "BedCushion", Vector3(0.0, 0.075, 0.0), Vector3.ZERO, 0.34, 0.09, "cream", false)
    _objects["cat_bed"] = cat_bed

    var cat_box := Node3D.new()
    cat_box.name = "CatCourierBox"
    cat_box.position = Vector3(-3.10, 0.16, 1.54)
    add_child(cat_box)
    _box_child(cat_box, "BoxFloor", Vector3.ZERO, Vector3(0.62, 0.08, 0.50), "cardboard", false)
    _box_child(cat_box, "BoxBack", Vector3(0.0, 0.20, 0.23), Vector3(0.62, 0.40, 0.05), "cardboard", false)
    _box_child(cat_box, "BoxLeft", Vector3(-0.285, 0.20, 0.0), Vector3(0.05, 0.40, 0.50), "cardboard", false)
    _box_child(cat_box, "BoxRight", Vector3(0.285, 0.20, 0.0), Vector3(0.05, 0.40, 0.50), "cardboard", false)
    _objects["cat_box"] = cat_box

    var food_bowl := Node3D.new()
    food_bowl.name = "CatFoodBowl"
    food_bowl.position = Vector3(-5.10, 0.08, 1.02)
    add_child(food_bowl)
    _cylinder_child(food_bowl, "Bowl", Vector3.ZERO, Vector3.ZERO, 0.19, 0.07, "metal", false)
    _cylinder_child(food_bowl, "Food", Vector3(0.0, 0.047, 0.0), Vector3.ZERO, 0.14, 0.025, "brown", false)
    _objects["cat_food_bowl"] = food_bowl

    var cat_food := _physical_item("CatFoodTin", &"cat_food", "КОРМ ДЛЯ БАТОНА", Vector3(-5.08, 0.19, 1.02), "cat_food", 0.18, false)
    cat_food.freeze = true
    cat_food.sleeping = true
    _objects["cat_food"] = cat_food
    var cat_toy := _physical_item("CatMouseToy", &"cat_toy", "ИГРУШЕЧНАЯ МЫШЬ БАТОНА", Vector3(-5.92, 0.15, 1.20), "cat_toy", 0.08, false)
    cat_toy.freeze = true
    cat_toy.sleeping = true
    _objects["cat_toy"] = cat_toy

    var cat := RITA_CAT_SCENE.instantiate() as RitaCat
    cat.name = "RitaCat"
    cat.position = Vector3(-5.62, 0.12, 1.52)
    add_child(cat)
    _objects["rita_cat"] = cat
    cat.setup(_objects)

func _physical_item(node_name: String, item_id: StringName, display: String, pos: Vector3, model_type: String, mass_value: float, critical: bool) -> RigidBody3D:
    var body = PHYSICAL_ITEM_SCRIPT.new()
    body.name = node_name
    body.item_id = item_id
    body.display_name = display
    body.mass = mass_value
    body.quest_critical = critical
    body.position = pos
    body.collision_layer = 2
    body.collision_mask = 3

    match model_type:
        "mug":
            _cylinder_child(body, "Mesh", Vector3.ZERO, Vector3.ZERO, 0.135, 0.25, "white", false)
            _cylinder_child(body, "MugInner", Vector3(0.0, 0.132, 0.0), Vector3.ZERO, 0.108, 0.008, "black", false)
            _torus_child(body, "Handle", Vector3(0.145, 0.0, 0.0), Vector3(90.0, 0.0, 0.0), 0.045, 0.085, "white")
            # Denis's story mug has a real printed graphic instead of another
            # anonymous white cylinder.  The quad follows the front tangent of
            # the cup and keeps the handle/opening completely unobstructed.
            var mug_print := MeshInstance3D.new()
            mug_print.name = "DenisMugLisaPrint"
            mug_print.position = Vector3(0.0, 0.0, 0.1362)
            var print_mesh := QuadMesh.new()
            print_mesh.size = Vector2(0.155, 0.205)
            var print_material := StandardMaterial3D.new()
            print_material.albedo_texture = load("res://assets/textures/denis_mug_lisa.png")
            print_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            print_material.cull_mode = BaseMaterial3D.CULL_DISABLED
            print_material.roughness = 0.58
            print_material.metallic = 0.0
            print_mesh.material = print_material
            mug_print.mesh = print_mesh
            body.add_child(mug_print)
            var mug_shape := CylinderShape3D.new()
            mug_shape.radius = 0.14
            mug_shape.height = 0.26
            _rigid_collision(body, mug_shape)

            # MugContentController — содержимое кружки (мл жидкостей + г порошка, температура, is_stirred)
            var mcc := MUG_CONTENT_SCRIPT.new()
            mcc.name = "MugContentController"
            mcc.capacity_ml = 350.0
            body.add_child(mcc)

            # LiquidReceiver (MugOpeningArea) — отверстие кружки сверху (§9 миссии, r=0.042)
            var mug_opening := Node3D.new()
            mug_opening.name = "MugOpening"
            mug_opening.position = Vector3(0.0, 0.135, 0.0)
            body.add_child(mug_opening)
            var opening_marker := Node3D.new()
            opening_marker.name = "OpeningMarker"
            mug_opening.add_child(opening_marker)
            var opening_normal := Node3D.new()
            opening_normal.name = "OpeningNormal"
            mug_opening.add_child(opening_normal)
            var receiver := LIQUID_RECEIVER_SCRIPT.new()
            receiver.name = "OpeningReceiverArea"
            receiver.position = Vector3(0.0, 0.13, 0.0)  # верхняя кромка кружки
            receiver.position = Vector3.ZERO
            receiver.detection_radius = 0.072
            receiver.detection_height = 0.034
            receiver.mug_content_controller_path = NodePath("../../MugContentController")
            receiver.opening_normal_path = NodePath("../OpeningNormal")
            mug_opening.add_child(receiver)

            var grip_point := Node3D.new()
            grip_point.name = "GripPoint"
            grip_point.position = Vector3(0.14, 0.0, 0.0)
            body.add_child(grip_point)
            var interaction_area := Area3D.new()
            interaction_area.name = "InteractionArea"
            body.add_child(interaction_area)
            body.grip_point_path = NodePath("GripPoint")

            # LiquidSurface — горизонтальная поверхность жидкости с lag/slosh (§10/§17)
            var surface := LIQUID_SURFACE_SCRIPT.new()
            surface.name = "LiquidSurface"
            body.add_child(surface)
            surface.setup(body, mcc)

            # SpoonTip — точка кончика ложки для перемешивания (§16 миссии)
            var spoon_tip := Node3D.new()
            spoon_tip.name = "SpoonTip"
            spoon_tip.position = Vector3(0.0, 0.10, 0.0)
            body.add_child(spoon_tip)
        "coffee_jar":
            _cylinder_child(body, "Mesh", Vector3.ZERO, Vector3.ZERO, 0.145, 0.32, "brown", false)
            _cylinder_child(body, "Label", Vector3(0.0, -0.015, 0.0), Vector3.ZERO, 0.148, 0.15, "fabric_rust", false)
            _cylinder_child(body, "Cap", Vector3(0.0, 0.18, 0.0), Vector3.ZERO, 0.15, 0.06, "black", false)
            var jar_label := _label3d("КОФЕ", Vector3(0.0, -0.02, 0.151), Color("ffe4b0"), 18)
            body.add_child(jar_label)
            var jar_shape := CylinderShape3D.new()
            jar_shape.radius = 0.15
            jar_shape.height = 0.39
            _rigid_collision(body, jar_shape)
            var powder_emitter := COFFEE_POWDER_EMITTER_SCRIPT.new()
            powder_emitter.name = "CoffeePowderEmitter"
            body.add_child(powder_emitter)
            var powder_origin := Node3D.new()
            powder_origin.name = "PowderOrigin"
            powder_origin.position = Vector3(0.0, 0.22, 0.0)
            body.add_child(powder_origin)
            var powder_direction := Node3D.new()
            powder_direction.name = "PowderDirection"
            powder_direction.position = Vector3(0.0, 0.42, 0.0)
            body.add_child(powder_direction)
            var powder_stream := Node3D.new()
            powder_stream.name = "PowderStream"
            body.add_child(powder_stream)
            body.pour_origin_path = NodePath("PowderOrigin")
            body.pour_direction_path = NodePath("PowderDirection")
            body.powder_emitter_path = NodePath("CoffeePowderEmitter")
        "kettle":
            var kettle_body := _sphere_child(body, "Mesh", Vector3(0.0, -0.02, 0.0), 0.24, "cabinet", false)
            kettle_body.scale.y = 1.12
            _cylinder_child(body, "KettleFoot", Vector3(0.0, -0.235, 0.0), Vector3.ZERO, 0.18, 0.06, "black", false)
            _box_child(body, "BodyBand", Vector3(0.0, -0.06, 0.225), Vector3(0.26, 0.075, 0.025), "black", false)
            _sphere_child(body, "Indicator", Vector3(0.10, -0.10, 0.225), 0.022, "warm_light", false)
            _cylinder_child(body, "Lid", Vector3(0.0, 0.24, 0.0), Vector3.ZERO, 0.14, 0.05, "metal", false)
            _sphere_child(body, "LidKnob", Vector3(0.0, 0.30, 0.0), 0.045, "black", false)
            _torus_child(body, "Handle", Vector3(0.0, 0.15, 0.0), Vector3(90.0, 0.0, 0.0), 0.19, 0.245, "black")
            var kettle_spout := _cone_child(body, "Spout", Vector3(-0.27, 0.08, 0.0), Vector3(0.0, 0.0, 70.0), 0.08, 0.03, 0.32, "metal")
            var kettle_shape := CylinderShape3D.new()
            kettle_shape.radius = 0.26
            kettle_shape.height = 0.52
            _rigid_collision(body, kettle_shape)
            
            # Grip и pour точки для режима розлива
            var grip_pt := Node3D.new()
            grip_pt.name = "GripPoint"
            grip_pt.position = Vector3(0.0, 0.22, 0.0)
            body.add_child(grip_pt)
            
            var pour_grip := Node3D.new()
            pour_grip.name = "PourGripPoint"
            pour_grip.position = Vector3(0.0, 0.28, 0.0)
            body.add_child(pour_grip)
            var right_grip := Node3D.new()
            right_grip.name = "RightHandGrip"
            right_grip.position = Vector3(0.21, 0.21, 0.02)
            body.add_child(right_grip)
            var left_support := Node3D.new()
            left_support.name = "LeftHandSupport"
            left_support.position = Vector3(-0.12, -0.18, 0.0)
            body.add_child(left_support)
            var pour_pivot := Node3D.new()
            pour_pivot.name = "PourPivot"
            pour_pivot.position = pour_grip.position
            body.add_child(pour_pivot)
            
            var pour_origin := Node3D.new()
            pour_origin.name = "PourOrigin"
            pour_origin.position = Vector3(0.0, 0.16, 0.0)
            kettle_spout.add_child(pour_origin)
            
            var pour_dir := Node3D.new()
            pour_dir.name = "PourDirection"
            pour_dir.position = Vector3(0.0, 0.36, 0.0)
            kettle_spout.add_child(pour_dir)

            # Реальное отверстие чайника для попадания струи крана.
            var opening := Area3D.new()
            opening.name = "KettleOpeningArea"
            opening.position = Vector3(0.0, 0.29, 0.0)
            opening.collision_layer = 16
            opening.collision_mask = 0
            var opening_collision := CollisionShape3D.new()
            var opening_shape := CylinderShape3D.new()
            opening_shape.radius = 0.105
            opening_shape.height = 0.045
            opening_collision.shape = opening_shape
            opening.add_child(opening_collision)
            body.add_child(opening)
            
            # ContainerVolume чайника. Для вертикального среза один debug-флаг
            # даёт ровно 300 мл горячей воды; объём затем только расходуется.
            var cv := CONTAINER_VOLUME_SCRIPT.new()
            cv.name = "ContainerVolume"
            cv.container_type = CONTAINER_VOLUME_SCRIPT.ContainerType.KETTLE
            cv.capacity_ml = 1700.0
            cv.default_liquid = WATER_DEF
            body.add_child(cv)

            # KettleStateMachine — состояния EMPTY→...→POURING, температура (§5 миссии)
            var ksm := KETTLE_STATE_MACHINE_SCRIPT.new()
            ksm.name = "KettleStateMachine"
            ksm.container_volume = cv
            body.add_child(ksm)
            if DEBUG_START_KETTLE_READY:
                cv.add_liquid(300.0, WATER_DEF)
                ksm.temperature_c = 95.0
                ksm.state = KETTLE_STATE_MACHINE_SCRIPT.KettleState.HELD
                QuestManager.kettle_filled = true
                QuestManager.water_boiled = true
            
            # NodePath'ы
            body.grip_point_path = NodePath("GripPoint")
            body.pour_grip_point_path = NodePath("PourGripPoint")
            body.pour_origin_path = NodePath("Spout/PourOrigin")
            body.pour_direction_path = NodePath("Spout/PourDirection")
            body.container_volume_path = NodePath("ContainerVolume")
        "towel":
            _box_child(body, "Mesh", Vector3.ZERO, Vector3(0.58, 0.055, 0.42), "yellow", false)
            for i in range(5):
                _box_child(body, "Fold_%d" % i, Vector3(-0.22 + float(i) * 0.11, 0.034, 0.0), Vector3(0.025, 0.018, 0.39), "rug_light", false)
            var towel_shape := BoxShape3D.new()
            towel_shape.size = Vector3(0.58, 0.06, 0.42)
            _rigid_collision(body, towel_shape)
        "milk_carton":
            _box_child(body, "Mesh", Vector3.ZERO, Vector3(0.22, 0.30, 0.11), "white", false)
            _box_child(body, "Label", Vector3(0.0, -0.02, 0.057), Vector3(0.18, 0.18, 0.006), "fabric_blue", false)
            _cylinder_child(body, "Cap", Vector3(0.065, 0.17, 0.0), Vector3.ZERO, 0.032, 0.035, "fabric_blue", false)
            var carton_label := _label3d("МОЛОКО", Vector3(0.0, -0.02, 0.061), Color("273c48"), 14)
            body.add_child(carton_label)
            var carton_shape := BoxShape3D.new()
            carton_shape.size = Vector3(0.22, 0.30, 0.11)
            _rigid_collision(body, carton_shape)
            
            # ContainerVolume с молоком
            var cv := CONTAINER_VOLUME_SCRIPT.new()
            cv.name = "ContainerVolume"
            cv.container_type = CONTAINER_VOLUME_SCRIPT.ContainerType.MILK_PACK
            cv.capacity_ml = 1000.0
            body.add_child(cv)
            cv.fill_completely(MILK_DEF)

            var grip_pt := Node3D.new()
            grip_pt.name = "GripPoint"
            grip_pt.position = Vector3(0.0, 0.05, 0.0)
            body.add_child(grip_pt)
            var pour_grip := Node3D.new()
            pour_grip.name = "PourGripPoint"
            pour_grip.position = Vector3(0.0, 0.10, 0.0)
            body.add_child(pour_grip)
            var pour_origin := Node3D.new()
            pour_origin.name = "PourOrigin"
            pour_origin.position = Vector3(0.065, 0.19, 0.0)
            body.add_child(pour_origin)
            var pour_dir := Node3D.new()
            pour_dir.name = "PourDirection"
            pour_dir.position = Vector3(0.25, 0.19, 0.0)
            body.add_child(pour_dir)

            body.grip_point_path = NodePath("GripPoint")
            body.pour_grip_point_path = NodePath("PourGripPoint")
            body.pour_origin_path = NodePath("PourOrigin")
            body.pour_direction_path = NodePath("PourDirection")
            body.container_volume_path = NodePath("ContainerVolume")
        "cat_food":
            _cylinder_child(body, "Tin", Vector3.ZERO, Vector3.ZERO, 0.08, 0.11, "yellow", false)
            _cylinder_child(body, "Lid", Vector3(0.0, 0.06, 0.0), Vector3.ZERO, 0.082, 0.015, "metal", false)
            var food_shape := CylinderShape3D.new()
            food_shape.radius = 0.082
            food_shape.height = 0.13
            _rigid_collision(body, food_shape)
        "cat_toy":
            var mouse_body := _sphere_child(body, "Mouse", Vector3.ZERO, 0.075, "fabric_blue", false)
            mouse_body.scale = Vector3(1.0, 0.65, 1.35)
            _sphere_child(body, "EarLeft", Vector3(-0.045, 0.045, -0.055), 0.025, "fabric_rust", false)
            _sphere_child(body, "EarRight", Vector3(0.045, 0.045, -0.055), 0.025, "fabric_rust", false)
            var toy_shape := SphereShape3D.new()
            toy_shape.radius = 0.085
            _rigid_collision(body, toy_shape)
        "spoon":
            _cylinder_child(body, "Handle", Vector3(0.0, 0.015, 0.0), Vector3.ZERO, 0.012, 0.28, "metal", false)
            var bowl := _sphere_child(body, "Bowl", Vector3(0.0, -0.155, 0.0), 0.055, "metal", false)
            bowl.scale = Vector3(0.62, 0.22, 1.0)
            var spoon_shape := CapsuleShape3D.new()
            spoon_shape.radius = 0.026
            spoon_shape.height = 0.36
            _rigid_collision(body, spoon_shape)
            var grip_pt := Node3D.new()
            grip_pt.name = "GripPoint"
            grip_pt.position = Vector3(0.0, 0.09, 0.0)
            body.add_child(grip_pt)
            var stir_grip := Node3D.new()
            stir_grip.name = "StirGripPoint"
            stir_grip.position = Vector3(0.0, 0.07, 0.0)
            body.add_child(stir_grip)
            var spoon_tip := Node3D.new()
            spoon_tip.name = "SpoonTip"
            spoon_tip.position = Vector3(0.0, -0.19, 0.0)
            body.add_child(spoon_tip)
            var stir := STIR_CONTROLLER_SCRIPT.new()
            stir.name = "StirController"
            body.add_child(stir)
            body.grip_point_path = NodePath("GripPoint")
    add_child(body)
    return body

func _action(node_name: String, pos: Vector3, display: String, action_type: String):
    var action = SIMPLE_ACTION_SCRIPT.new()
    action.name = node_name
    action.position = pos
    action.display_name = display
    action.action_type = action_type
    action.source_id = StringName(node_name.to_snake_case())
    add_child(action)
    return action

func _fixed_root(node_name: String, pos := Vector3.ZERO) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.position = pos
    root.add_to_group("fixed_furniture")
    add_child(root)
    return root

func _loose_box(node_name: String, display: String, pos: Vector3, size_value: Vector3, material_name: String, mass_value: float) -> RigidBody3D:
    var item = PHYSICAL_ITEM_SCRIPT.new()
    item.name = node_name
    item.item_id = StringName(node_name.to_snake_case())
    item.display_name = display
    item.mass = mass_value
    item.position = pos
    item.collision_layer = 2
    item.collision_mask = 3
    add_child(item)
    _box_child(item, "Mesh", Vector3.ZERO, size_value, material_name, true)
    # Decorative clutter is authored directly on shelves and surfaces. Starting
    # it as a live rigid body makes stacked props explode during the first
    # physics frames and repeatedly wake Rita without player input. It becomes
    # physical normally after the player picks it up and releases it.
    item.freeze = true
    item.sleeping = true
    return item
func _parked_loose_box(node_name: String, display: String, pos: Vector3, size_value: Vector3, material_name: String, mass_value: float) -> RigidBody3D:
    var item := _loose_box(node_name, display, pos, size_value, material_name, mass_value)
    # Countertop clutter stays parked until Denis picks it up. On release the
    # existing physical-item code restores normal gravity and collisions.
    item.freeze = true
    item.sleeping = true
    return item
func _furniture_root(node_name: String, pos := Vector3.ZERO) -> Node3D:
    var root = MOVABLE_FURNITURE_SCRIPT.new()
    root.name = node_name
    root.item_id = StringName(node_name.to_snake_case())
    root.position = pos
    root.display_name = _furniture_display_name(node_name)
    root.mass = _furniture_mass(node_name)
    root.impact_noise_scale = 1.35
    root.add_to_group("furniture")
    add_child(root)
    return root

func _furniture_mass(node_name: String) -> float:
    var weights := {
        "Sofa": 58.0, "Bed": 72.0, "Bookshelf": 46.0, "Wardrobe": 68.0,
        "Fridge": 82.0, "WorkDesk": 31.0, "DiningArea": 27.0,
        "TVConsole": 24.0, "ShoeBench": 17.0, "HallConsole": 19.0,
        "OfficeChair": 9.5, "DiningChair": 7.0, "CoatRack": 11.0,
        "CoffeeTable": 13.5, "Plant": 4.2, "DeskLamp": 2.6,
        "Nightstand": 12.0, "BedroomDresser": 34.0, "BedsideLamp": 1.8,
        "NotebookStack": 1.1, "Toaster": 2.4, "DishRack": 3.0
    }
    return float(weights.get(node_name, 5.0))

func _furniture_display_name(node_name: String) -> String:
    var names := {
        "WorkDesk": "РАБОЧИЙ СТОЛ", "OfficeChair": "РАБОЧЕЕ КРЕСЛО",
        "Sofa": "ДИВАН", "CoffeeTable": "ЖУРНАЛЬНЫЙ СТОЛИК",
        "TVConsole": "ТУМБА ПОД ТЕЛЕВИЗОР", "Bookshelf": "КНИЖНЫЙ ШКАФ",
        "DiningArea": "ОБЕДЕННЫЙ СТОЛ", "DiningChair": "ОБЕДЕННЫЙ СТУЛ",
        "KitchenFurniture": "КУХОННЫЙ ГАРНИТУР", "BedroomFurniture": "МЕБЕЛЬ СПАЛЬНИ",
        "BathroomFurniture": "МЕБЕЛЬ ВАННОЙ", "Plant": "КОМНАТНОЕ РАСТЕНИЕ",
        "DeskLamp": "НАСТОЛЬНАЯ ЛАМПА", "NotebookStack": "БЛОКНОТЫ",
        "Toaster": "ТОСТЕР", "DishRack": "СУШИЛКА ДЛЯ ПОСУДЫ",
        "KitchenDecor": "КУХОННЫЕ ПРИНАДЛЕЖНОСТИ", "CorridorFurniture": "МЕБЕЛЬ ПРИХОЖЕЙ"
    }
    return String(names.get(node_name, node_name.to_snake_case().replace("_", " ").to_upper()))

func _wall(pos: Vector3, size_value: Vector3) -> void:
    _box("Wall", pos, size_value, "wall", true)

func _baseboard(pos: Vector3, size_value: Vector3) -> void:
    _box("Baseboard", pos, size_value, "white", false)

func _window_wall(origin: Vector3, width: float) -> void:
    _wall(origin + Vector3(0.0, 0.38, 0.0), Vector3(width, 0.76, 0.18))
    _wall(origin + Vector3(0.0, 2.61, 0.0), Vector3(width, 0.78, 0.18))
    _box("WindowGlass", origin + Vector3(0.0, 1.50, 0.0), Vector3(width - 0.10, 1.46, 0.035), "glass", false)
    _box("WindowFrameL", origin + Vector3(-width * 0.5, 1.50, 0.0), Vector3(0.09, 1.56, 0.12), "white", false)
    _box("WindowFrameR", origin + Vector3(width * 0.5, 1.50, 0.0), Vector3(0.09, 1.56, 0.12), "white", false)
    _box("WindowFrameM", origin + Vector3(0.0, 1.50, -0.02), Vector3(0.07, 1.50, 0.08), "white", false)
    _box("WindowSill", origin + Vector3(0.0, 0.78, 0.10), Vector3(width + 0.18, 0.09, 0.36), "white", true)

func _door_frame(origin: Vector3, along_z: bool, material_name: String) -> void:
    if along_z:
        _box("DoorFrameA", origin + Vector3(0.0, 1.12, -0.70), Vector3(0.28, 2.24, 0.11), material_name, false)
        _box("DoorFrameB", origin + Vector3(0.0, 1.12, 0.70), Vector3(0.28, 2.24, 0.11), material_name, false)
        _box("DoorFrameTop", origin + Vector3(0.0, 2.24, 0.0), Vector3(0.28, 0.12, 1.51), material_name, false)
        _box("DoorThreshold", origin + Vector3(0.0, 0.018, 0.0), Vector3(0.25, 0.036, 1.36), "oak_light", false)
        var lintel := _box("DoorLintel", origin + Vector3(0.0, 2.65, 0.0), Vector3(0.18, 0.70, 1.52), "wall", true)
        lintel.add_to_group("door_lintel")
    else:
        _box("DoorFrameA", origin + Vector3(-0.70, 1.12, 0.0), Vector3(0.11, 2.24, 0.28), material_name, false)
        _box("DoorFrameB", origin + Vector3(0.70, 1.12, 0.0), Vector3(0.11, 2.24, 0.28), material_name, false)
        _box("DoorFrameTop", origin + Vector3(0.0, 2.24, 0.0), Vector3(1.51, 0.12, 0.28), material_name, false)
        _box("DoorThreshold", origin + Vector3(0.0, 0.018, 0.0), Vector3(1.36, 0.036, 0.25), "oak_light", false)
        var lintel := _box("DoorLintel", origin + Vector3(0.0, 2.65, 0.0), Vector3(1.52, 0.70, 0.18), "wall", true)
        lintel.add_to_group("door_lintel")

func _create_wood_floor(center: Vector3, size_value: Vector2, prefix: String) -> void:
    var rows := int(floor(size_value.y / 0.42))
    for row in range(rows):
        var z := center.z - size_value.y * 0.5 + 0.22 + float(row) * 0.42
        var offset := 0.0 if row % 2 == 0 else 0.52
        for col in range(4):
            var x := center.x - size_value.x * 0.5 + 0.62 + float(col) * 1.24 + offset
            if x > center.x + size_value.x * 0.5 - 0.20:
                x -= size_value.x
            var material_name := "oak_light" if (row + col) % 3 != 0 else "oak"
            _box("%s_Plank_%d_%d" % [prefix, row, col], Vector3(x, center.y, z), Vector3(1.18, 0.018, 0.38), material_name, false)

func _create_tile_floor(center: Vector3, size_value: Vector2, prefix: String) -> void:
    var columns := int(ceil(size_value.x / 0.58))
    var rows := int(ceil(size_value.y / 0.58))
    for column in range(columns):
        for row in range(rows):
            var x := center.x - size_value.x * 0.5 + 0.29 + float(column) * 0.58
            var z := center.z - size_value.y * 0.5 + 0.29 + float(row) * 0.58
            var material_name := "tile" if (column + row) % 4 != 0 else "tile_dark"
            _box("%s_Tile_%d_%d" % [prefix, column, row], Vector3(x, center.y, z), Vector3(0.54, 0.018, 0.54), material_name, false)

func _box(node_name: String, pos: Vector3, size_value: Vector3, material_name: String, collision_enabled: bool) -> MeshInstance3D:
    return _box_child(self, node_name, pos, size_value, material_name, collision_enabled)

func _box_child(parent: Node3D, node_name: String, local_pos: Vector3, size_value: Vector3, material_name: String, collision_enabled: bool) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.position = local_pos
    var mesh := BoxMesh.new()
    mesh.size = size_value
    instance.mesh = mesh
    instance.material_override = _materials[material_name]
    parent.add_child(instance)
    if collision_enabled:
        var shape := BoxShape3D.new()
        shape.size = size_value
        _static_collision(instance, shape)
    return instance

func _cylinder_child(parent: Node3D, node_name: String, local_pos: Vector3, rotation_value: Vector3, radius: float, height: float, material_name: String, collision_enabled: bool) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.position = local_pos
    instance.rotation_degrees = rotation_value
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 18
    instance.mesh = mesh
    instance.material_override = _materials[material_name]
    parent.add_child(instance)
    if collision_enabled:
        var shape := CylinderShape3D.new()
        shape.radius = radius
        shape.height = height
        _static_collision(instance, shape)
    return instance

func _cone_child(parent: Node3D, node_name: String, local_pos: Vector3, rotation_value: Vector3, bottom_radius: float, top_radius: float, height: float, material_name: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.position = local_pos
    instance.rotation_degrees = rotation_value
    var mesh := CylinderMesh.new()
    mesh.top_radius = top_radius
    mesh.bottom_radius = bottom_radius
    mesh.height = height
    mesh.radial_segments = 18
    instance.mesh = mesh
    instance.material_override = _materials[material_name]
    parent.add_child(instance)
    return instance

func _sphere(node_name: String, pos: Vector3, radius: float, material_name: String, collision_enabled: bool) -> MeshInstance3D:
    return _sphere_child(self, node_name, pos, radius, material_name, collision_enabled)

func _sphere_child(parent: Node3D, node_name: String, local_pos: Vector3, radius: float, material_name: String, collision_enabled: bool) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.position = local_pos
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 18
    mesh.rings = 10
    instance.mesh = mesh
    instance.material_override = _materials[material_name]
    parent.add_child(instance)
    if collision_enabled:
        var shape := SphereShape3D.new()
        shape.radius = radius
        _static_collision(instance, shape)
    return instance

func _torus_child(parent: Node3D, node_name: String, local_pos: Vector3, rotation_value: Vector3, inner_radius: float, outer_radius: float, material_name: String) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.position = local_pos
    instance.rotation_degrees = rotation_value
    var mesh := TorusMesh.new()
    mesh.inner_radius = inner_radius
    mesh.outer_radius = outer_radius
    mesh.rings = 18
    mesh.ring_segments = 10
    instance.mesh = mesh
    instance.material_override = _materials[material_name]
    parent.add_child(instance)
    return instance

func _cylinder_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, material_name: String) -> void:
    var direction := finish - start
    var instance := _cylinder_child(parent, node_name, (start + finish) * 0.5, Vector3.ZERO, radius, direction.length(), material_name, false)
    instance.quaternion = Quaternion(Vector3.UP, direction.normalized())

func _rigid_collision(parent: RigidBody3D, shape: Shape3D) -> void:
    var collision := CollisionShape3D.new()
    collision.shape = shape
    parent.add_child(collision)

func _static_collision(parent: Node3D, shape: Shape3D) -> void:
    var rigid := _rigid_ancestor(parent)
    if rigid != null:
        var collision := CollisionShape3D.new()
        collision.shape = shape
        collision.transform = rigid.global_transform.affine_inverse() * parent.global_transform
        rigid.add_child(collision)
        return
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 3
    parent.add_child(body)
    var collision := CollisionShape3D.new()
    collision.shape = shape
    body.add_child(collision)

func _rigid_ancestor(node: Node) -> RigidBody3D:
    var current := node
    while current != null:
        if current is RigidBody3D:
            return current as RigidBody3D
        current = current.get_parent()
    return null

func _label3d(text_value: String, pos: Vector3, color: Color, size_value: int) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = size_value
    label.modulate = color
    label.outline_size = 5
    label.no_depth_test = false
    label.double_sided = true
    return label

func _omni(node_name: String, pos: Vector3, color: Color, energy: float, range_value: float, group_name: StringName) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.name = node_name
    light.position = pos
    light.light_color = color
    light.light_energy = energy
    light.omni_range = range_value
    light.shadow_enabled = node_name in ["OfficeFill", "KitchenMain"]
    light.add_to_group(String(group_name))
    add_child(light)
    return light

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material

func _metal_material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := _material(color, roughness)
    material.metallic = 0.78
    return material

func _glass_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness = 0.16
    material.metallic = 0.08
    return material

func _emissive_material(color: Color, emission_color: Color, energy: float) -> StandardMaterial3D:
    var material := _material(color, 0.46)
    material.emission_enabled = true
    material.emission = emission_color
    material.emission_energy_multiplier = energy
    return material

func _spawn_smart_tv() -> Node3D:
    var smart_tv := SMART_TV_SCRIPT.new()
    smart_tv.name = "SmartTV"
    smart_tv.display_name = "СМАРТ-ТВ"
    smart_tv.position = Vector3(-7.15, 1.35, 2.85)
    smart_tv.rotation_degrees.y = 90.0
    add_child(smart_tv)
    
    # Визуализация Smart TV
    var tv_body := _box_child(smart_tv, "TVBody", Vector3.ZERO, Vector3(1.20, 0.68, 0.08), "black", true)
    var tv_screen := MeshInstance3D.new()
    tv_screen.name = "Screen"
    var screen_mesh := PlaneMesh.new()
    screen_mesh.size = Vector2(1.10, 0.62)
    tv_screen.mesh = screen_mesh
    tv_screen.position = Vector3(0.0, 0.0, -0.041)
    tv_screen.rotation_degrees.y = 180.0
    tv_screen.material_override = _materials["screen"]
    smart_tv.add_child(tv_screen)
    
    var status_light := _box_child(smart_tv, "StatusLight", Vector3(0.0, -0.32, -0.041), Vector3(0.08, 0.015, 0.008), "red", false)
    status_light.visible = false
    
    var speaker_left := _box_child(smart_tv, "SpeakerL", Vector3(-0.52, -0.28, -0.01), Vector3(0.06, 0.12, 0.06), "black", false)
    var speaker_right := _box_child(smart_tv, "SpeakerR", Vector3(0.52, -0.28, -0.01), Vector3(0.06, 0.12, 0.06), "black", false)
    
    # Создаем Label3D для отображения канала
    var channel_label := _label3d("СМАРТ-ТВ\nФУТБОЛ", Vector3(0.0, 0.0, -0.05), Color("ffffff"), 14)
    channel_label.rotation_degrees.y = 180.0
    smart_tv.add_child(channel_label)
    
    smart_tv.configure_visuals(tv_screen, channel_label, status_light)
    return smart_tv

func _spawn_smart_kettle() -> Node3D:
    var smart_kettle := SMART_KETTLE_SCRIPT.new()
    smart_kettle.name = "SmartKettle"
    smart_kettle.display_name = "УМНЫЙ ЧАЙНИК"
    smart_kettle.position = Vector3(4.20, 1.36, -5.39)
    add_child(smart_kettle)
    
    # Визуализация умного чайника
    var kettle_body := _cylinder_child(smart_kettle, "Body", Vector3.ZERO, Vector3.ZERO, 0.16, 0.28, "black", true)
    kettle_body.scale.y = 1.15
    var kettle_lid := _cylinder_child(smart_kettle, "Lid", Vector3(0.0, 0.16, 0.0), Vector3.ZERO, 0.10, 0.035, "metal", false)
    var spout := _cone_child(smart_kettle, "Spout", Vector3(0.18, 0.06, 0.0), Vector3(0.0, 0.0, -65.0), 0.05, 0.02, 0.22, "metal")
    
    var temp_display := _box_child(smart_kettle, "TempDisplay", Vector3(0.0, 0.10, -0.155), Vector3(0.10, 0.04, 0.008), "screen", false)
    var temp_label := _label3d("--°C", Vector3(0.0, 0.10, -0.160), Color("00ff00"), 16)
    temp_label.rotation_degrees.y = 180.0
    smart_kettle.add_child(temp_label)
    
    # Пар для умного чайника
    for i in range(3):
        var steam := _sphere_child(smart_kettle, "Steam%d" % i, Vector3(0.0, 0.30 + float(i) * 0.08, 0.0), 0.04 + float(i) * 0.01, "glass", false)
        steam.visible = false
    
    smart_kettle.configure_visuals(temp_label, smart_kettle.get_node("Steam0"), smart_kettle.get_node("Steam1"), smart_kettle.get_node("Steam2"))
    return smart_kettle

func _spawn_noise_cancelling_headphones() -> Node3D:
    var headphones := HEADPHONES_SCRIPT.new()
    headphones.name = "NoiseCancellingHeadphones"
    headphones.display_name = "ШУМОПОДАВЛЯЮЩИЕ НАУШНИКИ"
    headphones.position = Vector3(-4.65, 0.86, -4.90)
    headphones.rotation_degrees.y = -45.0
    add_child(headphones)
    
    # Визуализация наушников
    var headband := _box_child(headphones, "Headband", Vector3(0.0, 0.06, 0.0), Vector3(0.16, 0.03, 0.12), "black", true)
    var cup_left := _cylinder_child(headphones, "CupL", Vector3(-0.09, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), 0.05, 0.06, "black", false)
    var cup_right := _cylinder_child(headphones, "CupR", Vector3(0.09, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), 0.05, 0.06, "black", false)
    var cushion_left := _cylinder_child(headphones, "CushionL", Vector3(-0.09, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), 0.04, 0.065, "metal", false)
    var cushion_right := _cylinder_child(headphones, "CushionR", Vector3(0.09, 0.0, 0.0), Vector3(0.0, 0.0, 90.0), 0.04, 0.065, "metal", false)
    
    var led_indicator := _box_child(headphones, "LED", Vector3(0.0, 0.08, -0.06), Vector3(0.02, 0.008, 0.008), "red", false)
    led_indicator.visible = false
    
    headphones.configure_visuals(led_indicator)
    return headphones
