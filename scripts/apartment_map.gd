extends Control

var _font: Font

const MAP_ORIGIN := Vector2(38.0, 56.0)
const MAP_SCALE := Vector2(45.0, 25.0)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _font = ThemeDB.fallback_font
    set_process(true)

func _process(_delta: float) -> void:
    if visible:
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.045, 0.97), true)
    draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.18), false, 2.0)
    draw_string(_font, Vector2(32, 35), "КАРТА КВАРТИРЫ  •  M — ЗАКРЫТЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("edbd68"))

    _draw_room(Rect2(-8.0, -6.5, 6.7, 8.5), "ГОСТИНАЯ / КАБИНЕТ", Color("334c59"))
    _draw_room(Rect2(1.3, -6.5, 6.7, 8.5), "КУХНЯ", Color("475348"))
    _draw_room(Rect2(-1.3, -6.5, 2.6, 13.0), "КОРИДОР", Color("4d5358"))
    _draw_room(Rect2(-8.0, 2.0, 6.7, 4.5), "СПАЛЬНЯ РИТЫ", Color("5b4654"))
    _draw_room(Rect2(1.3, 2.0, 6.7, 4.5), "ВАННАЯ", Color("405463"))
    _draw_room(Rect2(-8.0, 6.5, 6.7, 3.0), "ГАРДЕРОБНАЯ", Color("5c4c3d"))

    # Quiet routes are visible planning information, not magic.
    var runner_a := _to_map(Vector3(0.0, 0.0, -5.8))
    var runner_b := _to_map(Vector3(0.0, 0.0, 5.8))
    draw_line(runner_a, runner_b, Color("76b7a0"), 8.0)
    draw_string(_font, Vector2(640, 470), "зелёный маршрут — ковёр тише пола", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9be8c1"))

    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player != null:
        var player_point := _to_map(player.global_position)
        draw_circle(player_point, 8.0, Color("76b7d7"))
        draw_circle(player_point, 11.0, Color("d8f3ff"), false, 2.0)
        draw_string(_font, player_point + Vector2(13, 5), "ДЕНИС", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d8f3ff"))

    var phone := get_tree().get_first_node_in_group("phone_locator") as Node3D
    if phone != null:
        var phone_point := _to_map(phone.global_position)
        var phone_active := bool(phone.get("active"))
        var phone_color := Color("ef8066") if phone_active else Color("edbd68")
        if phone_active:
            var pulse := 13.0 + sin(Time.get_ticks_msec() * 0.008) * 5.0
            draw_circle(phone_point, pulse, Color(0.95, 0.25, 0.20, 0.18))
        draw_circle(phone_point, 7.0, phone_color)
        draw_string(_font, phone_point + Vector2(13, 5), "ТЕЛЕФОН", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, phone_color)
        var room_name := _room_title(NoiseManager.room_for_position(phone.global_position))
        if phone_active:
            draw_string(_font, Vector2(38, 492), "ВИБРАЦИЯ: %s  •  красная метка пульсирует, пока телефон не заглушён" % room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ef8066"))
        else:
            draw_string(_font, Vector2(38, 492), "ТЕЛЕФОН: %s  •  жёлтая метка показывает, где он лежит" % room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("edbd68"))
    else:
        draw_string(_font, Vector2(38, 492), "Телефон не найден в квартире.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("b8c5cc"))

    var urgent_target := _resolve_urgent_target()
    if not urgent_target.is_empty():
        var target_node := urgent_target.get("node") as Node3D
        if target_node != null:
            _draw_task_marker(target_node.global_position, String(urgent_target.get("label", "ЦЕЛЬ")))

func _draw_room(world_rect: Rect2, title: String, color: Color) -> void:
    var top_left := _to_map(Vector3(world_rect.position.x, 0.0, world_rect.position.y))
    var room_size := Vector2(world_rect.size.x * MAP_SCALE.x, world_rect.size.y * MAP_SCALE.y)
    draw_rect(Rect2(top_left, room_size), color, true)
    draw_rect(Rect2(top_left, room_size), Color(0.92, 0.90, 0.84, 0.78), false, 2.0)
    draw_string(_font, top_left + Vector2(10, 22), title, HORIZONTAL_ALIGNMENT_LEFT, room_size.x - 20.0, 14, Color("f2eee6"))

func _to_map(world_position: Vector3) -> Vector2:
    return MAP_ORIGIN + Vector2(
        (world_position.x + 8.0) * MAP_SCALE.x,
        (world_position.z + 6.5) * MAP_SCALE.y
    )

func _room_title(room_id: StringName) -> String:
    match room_id:
        &"office": return "ГОСТИНАЯ / КАБИНЕТ"
        &"kitchen": return "КУХНЯ"
        &"corridor": return "КОРИДОР"
        &"bedroom": return "СПАЛЬНЯ РИТЫ"
        &"bathroom": return "ВАННАЯ"
        &"wardrobe": return "ГАРДЕРОБНАЯ"
    return "НЕИЗВЕСТНАЯ КОМНАТА"

func _draw_task_marker(world_position: Vector3, label: String) -> void:
    var point := _to_map(world_position)
    var pulse := 11.0 + sin(Time.get_ticks_msec() * 0.006) * 2.5
    draw_circle(point, pulse, Color(0.46, 0.72, 0.84, 0.18))
    draw_circle(point, 6.0, Color("76b7d7"))
    draw_string(_font, point + Vector2(12, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d8f3ff"))

func _resolve_urgent_target() -> Dictionary:
    var delivery := MilkDelivery.get_state()
    if bool(delivery.get("at_door", false)):
        return {"node": _find_node("MilkDeliveryPickup"), "label": "КУРЬЕР / МОЛОКО"}
    var call := CallManager.get_state()
    if bool(call.get("question_active", false)):
        return {"node": _find_node("Laptop"), "label": "СОЗВОН / ПЛАТЁЖ"}
    if RitaDemands.has_active_demand():
        match RitaDemands.get_location():
            &"laptop": return {"node": _find_node("Laptop"), "label": "ПОРУЧЕНИЕ РИТЫ"}
            &"bathroom_clean": return {"node": _find_node("RitaBathroomCleaning"), "label": "УБОРКА ВАННОЙ"}
            &"kitchen_dishes": return {"node": _find_node("RitaKitchenDishes"), "label": "ПОСУДА"}
    if QuestManager.has_bonus_objective(&"football"):
        return {"node": get_tree().get_first_node_in_group("television"), "label": "ФУТБОЛ"}
    var state := QuestManager.get_state()
    if not bool(state.get("has_mug", false)):
        return {"node": get_tree().get_first_node_in_group("mug"), "label": "КРУЖКА"}
    if not bool(state.get("has_coffee", false)):
        return {"node": get_tree().get_first_node_in_group("coffee_jar"), "label": "КОФЕ"}
    if not bool(state.get("has_milk", false)) and (not bool(delivery.get("ordered", false)) or bool(delivery.get("missed", false))):
        return {"node": _find_node("Laptop"), "label": "ЗАКАЗАТЬ МОЛОКО"}
    if not bool(state.get("kettle_filled", false)):
        var empty_kettle := get_tree().get_first_node_in_group("kettle") as Node3D
        if empty_kettle != null and bool(empty_kettle.get("held")):
            return {"node": _find_node("WaterSource"), "label": "ФИЛЬТР ВОДЫ"}
        return {"node": empty_kettle, "label": "ЧАЙНИК"}
    if not bool(state.get("water_boiled", false)):
        var filled_kettle := get_tree().get_first_node_in_group("kettle") as Node3D
        var kettle_base := _find_node("KettleBase")
        if filled_kettle != null and (bool(filled_kettle.get("held")) or kettle_base == null or filled_kettle.global_position.distance_to(kettle_base.global_position) > 1.1):
            return {"node": filled_kettle, "label": "НЕСТИ ЧАЙНИК НА ПОДСТАВКУ"}
        return {"node": _find_node("KettleBase"), "label": "ПОДСТАВКА ЧАЙНИКА"}
    if not bool(state.get("coffee_made", false)):
        if not bool(state.get("has_milk", false)):
            return {"node": _find_node("MilkDeliveryPickup"), "label": "ЖДАТЬ КУРЬЕРА"}
        if not bool(state.get("coffee_powder_poured", false)):
            var route_mug := get_tree().get_first_node_in_group("mug") as Node3D
            return {"node": route_mug, "label": "КРУЖКА — НАСЫПАТЬ КОФЕ"}
        if not bool(state.get("water_poured", false)):
            var route_mug := get_tree().get_first_node_in_group("mug") as Node3D
            return {"node": route_mug, "label": "КРУЖКА — НАЛИТЬ КИПЯТОК"}
        if not bool(state.get("milk_poured", false)):
            var route_mug := get_tree().get_first_node_in_group("mug") as Node3D
            return {"node": route_mug, "label": "КРУЖКА — НАЛИТЬ МОЛОКО"}
    return {"node": get_tree().get_first_node_in_group("mug"), "label": "ВЫПИТЬ КОФЕ"}

func _find_node(node_name: String) -> Node3D:
    var scene := get_tree().current_scene
    if scene == null:
        return null
    return scene.find_child(node_name, true, false) as Node3D
