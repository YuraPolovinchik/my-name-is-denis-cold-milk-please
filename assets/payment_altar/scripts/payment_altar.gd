extends Node3D

const INTERACTION_SCRIPT := preload("res://assets/payment_altar/scripts/altar_interaction.gd")
const FLICKER_SCRIPT := preload("res://assets/payment_altar/scripts/candle_flicker.gd")

var interaction: Node3D
var phone_status: Label3D
var relic_glow: OmniLight3D
var candle_lights: Array[OmniLight3D] = []

var _mat_wood: StandardMaterial3D
var _mat_cloth: StandardMaterial3D
var _mat_paper: StandardMaterial3D
var _mat_wax: StandardMaterial3D
var _mat_flame: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_black: StandardMaterial3D
var _mat_red: StandardMaterial3D

func _ready() -> void:
    add_to_group("payment_altar")
    _create_materials()
    _build_table()
    _build_relic()
    _build_offerings()
    _build_candles()
    _build_interaction()

func _create_materials() -> void:
    _mat_wood = _material(Color("261713"), 0.84)
    _mat_cloth = _material(Color("160f16"), 0.96)
    _mat_paper = _material(Color("d5c39a"), 0.92)
    _mat_wax = _material(Color("a8825f"), 0.88)
    _mat_flame = _material(Color("ffb347"), 0.28, Color("ff6b24"), 4.2)
    _mat_glass = _material(Color(0.60, 0.72, 0.73, 0.18), 0.10)
    _mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mat_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
    _mat_metal = _material(Color("5f5550"), 0.42)
    _mat_metal.metallic = 0.72
    _mat_black = _material(Color("171415"), 0.92)
    _mat_red = _material(Color("6b1f24"), 0.88)

func _build_table() -> void:
    _box("AltarTableTop", Vector3(0.0, 0.88, 0.0), Vector3(1.62, 0.13, 0.74), _mat_wood)
    for x in [-0.68, 0.68]:
        for z in [-0.27, 0.27]:
            _box("TableLeg", Vector3(x, 0.43, z), Vector3(0.12, 0.86, 0.12), _mat_wood)
    _box("DarkCloth", Vector3(0.0, 0.958, 0.0), Vector3(1.48, 0.025, 0.67), _mat_cloth)
    _box("ClothDrop", Vector3(0.0, 0.62, -0.382), Vector3(0.78, 0.68, 0.025), _mat_cloth)
    var cloth_label := _label("THE ПЛАТЕЖ", Vector3(0.0, 0.66, -0.405), 28, Color("9b3438"))
    cloth_label.rotation_degrees.y = 180.0

func _build_relic() -> void:
    _box("RelicPlinth", Vector3(0.0, 1.04, 0.04), Vector3(0.70, 0.12, 0.40), _mat_black)
    _box("GlassCaseBack", Vector3(0.0, 1.34, 0.20), Vector3(0.70, 0.56, 0.025), _mat_glass)
    _box("GlassCaseFront", Vector3(0.0, 1.34, -0.16), Vector3(0.70, 0.56, 0.025), _mat_glass)
    _box("GlassCaseLeft", Vector3(-0.34, 1.34, 0.02), Vector3(0.025, 0.56, 0.38), _mat_glass)
    _box("GlassCaseRight", Vector3(0.34, 1.34, 0.02), Vector3(0.025, 0.56, 0.38), _mat_glass)
    _box("GlassCaseTop", Vector3(0.0, 1.63, 0.02), Vector3(0.70, 0.025, 0.38), _mat_glass)
    _box("EmptyEnvelope", Vector3(0.0, 1.25, -0.18), Vector3(0.54, 0.30, 0.025), _mat_paper)
    var main := _label("THE ПЛАТЕЖ", Vector3(0.0, 1.31, -0.205), 29, Color("341d20"))
    main.rotation_degrees.y = 180.0
    var wait := _label("ОЖИДАЕТСЯ", Vector3(0.0, 1.16, -0.208), 16, Color("74282b"))
    wait.rotation_degrees.y = 180.0
    relic_glow = OmniLight3D.new()
    relic_glow.name = "RelicGlow"
    relic_glow.position = Vector3(0.0, 1.48, -0.04)
    relic_glow.light_color = Color("ffb168")
    relic_glow.light_energy = 1.05
    relic_glow.omni_range = 2.4
    relic_glow.shadow_enabled = true
    add_child(relic_glow)

func _build_offerings() -> void:
    # The arrangement is deliberate: orderly near the relic, increasingly
    # desperate toward the edges.
    _box("Calculator", Vector3(-0.55, 1.04, 0.13), Vector3(0.34, 0.07, 0.23), _mat_black)
    for row in range(3):
        for column in range(3):
            _box("CalculatorKey", Vector3(-0.65 + column * 0.10, 1.083, 0.07 + row * 0.065), Vector3(0.055, 0.018, 0.038), _mat_paper if row == 0 else _mat_metal)
    _box("OldPhone", Vector3(0.56, 1.05, 0.10), Vector3(0.28, 0.09, 0.42), _mat_black)
    _box("PhoneScreen", Vector3(0.56, 1.102, -0.01), Vector3(0.22, 0.012, 0.12), _mat_red)
    phone_status = _label("В ОБРАБОТКЕ", Vector3(0.56, 1.116, -0.075), 10, Color("f2d0a4"))
    phone_status.rotation_degrees.x = -90.0
    _box("EmptyWallet", Vector3(-0.72, 1.03, -0.20), Vector3(0.34, 0.065, 0.24), _mat_red)
    _box("WalletFlap", Vector3(-0.72, 1.10, -0.30), Vector3(0.34, 0.04, 0.14), _mat_red)
    _cylinder("OfferingBowl", Vector3(0.72, 1.04, -0.20), 0.18, 0.06, _mat_metal)
    for coin_index in range(7):
        var angle := float(coin_index) * 2.4
        _cylinder(
            "Coin",
            Vector3(0.72 + cos(angle) * 0.10, 1.09 + float(coin_index % 2) * 0.008, -0.20 + sin(angle) * 0.10),
            0.035,
            0.012,
            _mat_metal
        )
    # Receipts and a deliberately unbranded instant-noodle cup sit on the floor.
    for paper_index in range(6):
        _box(
            "PaperOffering",
            Vector3(-0.95 + paper_index * 0.37, 0.025 + paper_index * 0.001, -0.62 + absf(2.5 - paper_index) * 0.06),
            Vector3(0.28, 0.012, 0.19),
            _mat_paper,
            Vector3(0.0, -11.0 + paper_index * 4.2, 0.0)
        )
    _cylinder("EmptyMug", Vector3(-1.03, 0.15, -0.18), 0.12, 0.26, _mat_paper)
    _cylinder("FoodCup", Vector3(1.02, 0.17, -0.12), 0.14, 0.31, _mat_red)
    _box("SingleSock", Vector3(0.82, 0.035, -0.68), Vector3(0.34, 0.025, 0.11), _mat_cloth, Vector3(0.0, 18.0, 0.0))
    _box("USBDrive", Vector3(-0.45, 0.035, -0.76), Vector3(0.16, 0.035, 0.07), _mat_metal)
    _box("Battery", Vector3(0.46, 0.045, -0.76), Vector3(0.08, 0.07, 0.22), _mat_black, Vector3(0.0, -22.0, 0.0))

func _build_candles() -> void:
    var flicker := Node3D.new()
    flicker.name = "CandleFlicker"
    flicker.set_script(FLICKER_SCRIPT)
    for candle_index in range(16):
        var side := -1.0 if candle_index % 2 == 0 else 1.0
        var lane := float(candle_index / 2)
        var x: float = side * (0.26 + fmod(lane, 4.0) * 0.26)
        var z: float = -0.54 + floor(lane / 4.0) * 0.36
        var height: float = 0.13 + float((candle_index * 7) % 6) * 0.035
        _cylinder_to(flicker, "Candle%02d" % candle_index, Vector3(x, 0.99 + height * 0.5, z), 0.035, height, _mat_wax)
        if candle_index in [5, 12, 15]:
            continue
        var flame := _sphere_to(flicker, "Flame%02d" % candle_index, Vector3(x, 1.00 + height + 0.045, z), Vector3(0.025, 0.07, 0.025), _mat_flame)
        flame.set_meta("candle", candle_index)
    for light_index in range(3):
        var light := OmniLight3D.new()
        light.name = "CandleLight%d" % light_index
        light.position = [Vector3(-0.62, 1.25, -0.32), Vector3(0.62, 1.25, -0.30), Vector3(0.0, 1.32, 0.28)][light_index]
        light.light_color = Color("ff8b4b")
        light.light_energy = [0.44, 0.40, 0.34][light_index]
        light.omni_range = 2.4
        light.shadow_enabled = light_index == 0
        light.set_meta("base_energy", light.light_energy)
        candle_lights.append(light)
        flicker.add_child(light)
    add_child(flicker)

func _build_interaction() -> void:
    interaction = Node3D.new()
    interaction.name = "PaymentRelic"
    interaction.set_script(INTERACTION_SCRIPT)
    interaction.position = Vector3(0.0, 1.30, -0.10)
    add_child(interaction)
    var area := Area3D.new()
    area.name = "InteractionArea"
    area.collision_layer = 2
    area.collision_mask = 0
    interaction.add_child(area)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.78, 0.75, 0.55)
    collision.shape = shape
    area.add_child(collision)

func set_reveal_amount(value: float) -> void:
    visible = value > 0.01
    var amount := clampf(value, 0.0, 1.0)
    relic_glow.light_energy = lerpf(0.0, 1.05, amount)
    for light in candle_lights:
        light.light_energy = float(light.get_meta("base_energy", 0.7)) * amount

func trigger_payment_event() -> void:
    if phone_status != null:
        phone_status.text = "THE ПЛАТЕЖ БЛИЗКО"
    if relic_glow != null:
        var tween := create_tween()
        tween.tween_property(relic_glow, "light_energy", 3.2, 0.18)
        tween.tween_interval(0.65)
        tween.tween_property(relic_glow, "light_energy", 1.05, 0.8)
    await get_tree().create_timer(1.0).timeout
    if phone_status != null:
        phone_status.text = "СТАТУС: ПЕРЕНЕСЁН"

func _box(node_name: String, pos: Vector3, size: Vector3, mat: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = mat
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.rotation_degrees = rotation_degrees_value
    add_child(mesh_instance)
    return mesh_instance

func _cylinder(node_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
    return _cylinder_to(self, node_name, pos, radius, height, mat)

func _cylinder_to(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 1.05
    mesh.height = height
    mesh.radial_segments = 10
    mesh.material = mat
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    parent.add_child(mesh_instance)
    return mesh_instance

func _sphere_to(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = node_name
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 8
    mesh.rings = 4
    mesh.material = mat
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.scale = size
    parent.add_child(mesh_instance)
    return mesh_instance

func _label(text_value: String, pos: Vector3, font_size: int, color: Color) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = font_size
    label.modulate = color
    label.outline_size = 4
    label.outline_modulate = Color(0.03, 0.02, 0.02, 0.90)
    label.no_depth_test = false
    add_child(label)
    return label

func _material(color: Color, roughness: float, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    if emission_energy > 0.0:
        material.emission_enabled = true
        material.emission = emission
        material.emission_energy_multiplier = emission_energy
    return material
