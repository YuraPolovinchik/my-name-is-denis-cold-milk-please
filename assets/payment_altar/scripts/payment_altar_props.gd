extends Node3D

var _paper: StandardMaterial3D
var _paper_old: StandardMaterial3D
var _cork: StandardMaterial3D
var _ink: StandardMaterial3D
var _red: StandardMaterial3D
var _chalk: StandardMaterial3D
var _metal: StandardMaterial3D

func _ready() -> void:
    add_to_group("payment_altar_props")
    _paper = _material(Color("d8c89f"), 0.94)
    _paper_old = _material(Color("a98e61"), 0.98)
    _cork = _material(Color("70472e"), 0.96)
    _ink = _material(Color("191617"), 0.92)
    _red = _material(Color("74252a"), 0.90)
    _chalk = _material(Color("c8bfa9"), 0.98)
    _metal = _material(Color("625851"), 0.45)
    _metal.metallic = 0.62
    _build_investigation_wall()
    _build_calendar()
    _build_floor_symbol()
    _build_threshold_papers()

func _build_investigation_wall() -> void:
    var board := Node3D.new()
    board.name = "InvestigationWall"
    board.position = Vector3(-1.37, 0.0, 1.30)
    add_child(board)
    _box_to(board, "CorkBoard", Vector3(0.0, 1.55, 0.0), Vector3(0.07, 1.72, 1.72), _cork)
    _box_to(board, "FrameTop", Vector3(0.045, 2.43, 0.0), Vector3(0.11, 0.08, 1.84), _ink)
    _box_to(board, "FrameBottom", Vector3(0.045, 0.67, 0.0), Vector3(0.11, 0.08, 1.84), _ink)
    for z in [-0.88, 0.88]:
        _box_to(board, "FrameSide", Vector3(0.045, 1.55, z), Vector3(0.11, 1.84, 0.08), _ink)
    var note_texts := [
        "ПЛАТЁЖ\nВ ОБРАБОТКЕ",
        "ОЖИДАЙТЕ ДО\nКОНЦА НЕДЕЛИ",
        "ПЕРЕНЕСЕНО ПО\nТЕХНИЧЕСКИМ ПРИЧИНАМ",
        "СРЕДСТВА БУДУТ\nЗАЧИСЛЕНЫ",
        "УТОЧНЯЕМ\nИНФОРМАЦИЮ",
        "ГДЕ ДЕНЬГИ"
    ]
    var note_positions := [
        Vector3(0.085, 2.05, -0.52),
        Vector3(0.088, 1.67, 0.38),
        Vector3(0.090, 1.12, -0.42),
        Vector3(0.087, 0.93, 0.47),
        Vector3(0.091, 2.10, 0.52),
        Vector3(0.094, 1.52, -0.05)
    ]
    for index in range(note_texts.size()):
        var note_size := Vector3(0.018, 0.34 if index != 2 else 0.44, 0.46)
        _box_to(board, "EvidencePaper%02d" % index, note_positions[index] + Vector3(0.022, 0.0, 0.0), note_size, _paper if index % 2 == 0 else _paper_old)
        var label := _label_to(board, note_texts[index], note_positions[index] + Vector3(0.045, 0.0, 0.0), 11 if index != 2 else 9, Color("241b19"))
        label.rotation_degrees.y = 90.0
    var day_label := _label_to(board, "ДЕНЬ 100", Vector3(0.105, 2.34, -0.04), 30, Color("9e3338"))
    day_label.rotation_degrees.y = 90.0
    # Threads connect only mundane evidence: calendar, calculator, receipt,
    # empty wallet and the loading-circle print.
    var pins := [
        Vector3(0.115, 1.99, -0.52),
        Vector3(0.115, 1.62, 0.38),
        Vector3(0.115, 1.10, -0.42),
        Vector3(0.115, 0.94, 0.47),
        Vector3(0.115, 1.52, -0.05)
    ]
    var links := [[0, 4], [1, 4], [2, 4], [3, 4], [0, 2], [1, 3]]
    for link_index in range(links.size()):
        _cylinder_between(board, "RedThread%02d" % link_index, pins[links[link_index][0]], pins[links[link_index][1]], 0.008, _red)
    for pin in pins:
        _sphere_to(board, "Pin", pin + Vector3(0.015, 0.0, 0.0), 0.025, _red)

func _build_calendar() -> void:
    var calendar := Node3D.new()
    calendar.name = "WaitingCalendar"
    calendar.position = Vector3(1.37, 0.0, 1.30)
    add_child(calendar)
    _box_to(calendar, "CalendarBacking", Vector3(0.0, 1.56, 0.0), Vector3(0.07, 1.72, 1.42), _paper_old)
    var title := _label_to(calendar, "КАЛЕНДАРЬ ОЖИДАНИЯ", Vector3(-0.055, 2.24, 0.0), 18, Color("3a2520"))
    title.rotation_degrees.y = -90.0
    var hundred := _label_to(calendar, "100", Vector3(-0.060, 1.72, 0.0), 70, Color("8b2b30"))
    hundred.rotation_degrees.y = -90.0
    var promise := _label_to(calendar, "ВОТ ТЕПЕРЬ ТОЧНО", Vector3(-0.061, 1.10, 0.0), 19, Color("292020"))
    promise.rotation_degrees.y = -90.0
    var future := _label_to(calendar, "→  ?  ?  ?", Vector3(-0.061, 0.84, 0.0), 23, Color("8b2b30"))
    future.rotation_degrees.y = -90.0
    for row in range(5):
        for column in range(7):
            var tally := _box_to(
                calendar,
                "CrossedDay",
                Vector3(-0.051, 1.44 - row * 0.105, -0.51 + column * 0.17),
                Vector3(0.018, 0.012, 0.13),
                _ink,
                Vector3(0.0, 0.0, -34.0 if (row + column) % 2 == 0 else 34.0)
            )
            tally.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_floor_symbol() -> void:
    var floor_symbol := Node3D.new()
    floor_symbol.name = "PaymentWaitingCircle"
    add_child(floor_symbol)
    for segment in range(28):
        var angle := TAU * float(segment) / 28.0
        var radius := 0.88
        var mark := _box_to(
            floor_symbol,
            "WaitingCircleMark",
            Vector3(cos(angle) * radius, 0.018, 1.24 + sin(angle) * radius),
            Vector3(0.15, 0.012, 0.035),
            _chalk,
            Vector3(0.0, -rad_to_deg(angle), 0.0)
        )
        mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for cardinal in range(4):
        var angle := TAU * float(cardinal) / 4.0
        _cylinder_to(
            floor_symbol,
            "WaxPoint",
            Vector3(cos(angle) * 0.68, 0.025, 1.24 + sin(angle) * 0.68),
            0.08,
            0.025,
            _red
        )
    var centre := _label_to(floor_symbol, "THE ПЛАТЕЖ\nРУБ  • • •", Vector3(0.0, 0.026, 1.24), 24, Color("bcb39f"))
    centre.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    var arrows := ["ОЖИДАЙТЕ", "ПЕРЕНЕСЁН", "СЕГОДНЯ?", "ЗАВТРА?"]
    for index in range(arrows.size()):
        var angle := TAU * float(index) / 4.0
        var label := _label_to(
            floor_symbol,
            arrows[index],
            Vector3(cos(angle) * 0.48, 0.027, 1.24 + sin(angle) * 0.48),
            10,
            Color("8f3033")
        )
        label.rotation_degrees = Vector3(-90.0, 0.0, -rad_to_deg(angle))

func _build_threshold_papers() -> void:
    var scraps := [
        "МЫ ЖДЁМ",
        "ОН БЫЛ ОБЕЩАН",
        "ЕЩЁ НЕМНОГО",
        "НЕ СПРАШИВАЙ\nБУХГАЛТЕРИЮ",
        "СРЕДСТВА СКОРО\nПОСТУПЯТ",
        "МЫ НЕ ЗАБЫЛИ"
    ]
    for index in range(scraps.size()):
        var x := -1.02 + float(index % 3) * 0.98
        var z := 0.18 + float(index / 3) * 0.30
        _box("FloorPaper%02d" % index, Vector3(x, 0.022 + index * 0.001, z), Vector3(0.52, 0.012, 0.23), _paper if index % 2 == 0 else _paper_old, Vector3(0.0, -9.0 + index * 4.5, 0.0))
        var label := _label(scraps[index], Vector3(x, 0.030 + index * 0.001, z), 10, Color("332321"))
        label.rotation_degrees = Vector3(-90.0, 0.0, -9.0 + index * 4.5)

func _box(node_name: String, pos: Vector3, size: Vector3, mat: Material, rotation_value := Vector3.ZERO) -> MeshInstance3D:
    return _box_to(self, node_name, pos, size, mat, rotation_value)

func _box_to(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material, rotation_value := Vector3.ZERO) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = mat
    instance.mesh = mesh
    instance.position = pos
    instance.rotation_degrees = rotation_value
    parent.add_child(instance)
    return instance

func _cylinder_to(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    mesh.material = mat
    instance.mesh = mesh
    instance.position = pos
    parent.add_child(instance)
    return instance

func _cylinder_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, mat: Material) -> void:
    var direction := finish - start
    var instance := _cylinder_to(parent, node_name, (start + finish) * 0.5, radius, direction.length(), mat)
    instance.quaternion = Quaternion(Vector3.UP, direction.normalized())

func _sphere_to(parent: Node3D, node_name: String, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 8
    mesh.rings = 4
    mesh.material = mat
    instance.mesh = mesh
    instance.position = pos
    parent.add_child(instance)
    return instance

func _label(text_value: String, pos: Vector3, size: int, color: Color) -> Label3D:
    return _label_to(self, text_value, pos, size, color)

func _label_to(parent: Node3D, text_value: String, pos: Vector3, size: int, color: Color) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = size
    label.modulate = color
    label.outline_size = 3
    label.outline_modulate = Color(0.04, 0.025, 0.02, 0.65)
    parent.add_child(label)
    return label

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
