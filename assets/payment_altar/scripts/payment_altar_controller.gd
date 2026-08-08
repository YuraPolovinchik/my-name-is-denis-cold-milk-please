extends Node3D

const SECRET_DOOR_SCRIPT := preload("res://assets/payment_altar/scripts/payment_secret_door.gd")
const ALTAR_SCENE := preload("res://assets/payment_altar/scenes/payment_altar.tscn")
const PROPS_SCENE := preload("res://assets/payment_altar/scenes/payment_altar_props.tscn")

var secret_door: Node3D
var altar: Node3D
var props: Node3D
var _room_lights: Array[Light3D] = []
var _hum: AudioStreamPlayer3D
var _paper_rustle: AudioStreamPlayer3D
var _revealed := false
var _worship_event_played := false
var _ambient_tick := 4.0

var _wall_mat: StandardMaterial3D
var _floor_mat: StandardMaterial3D
var _ceiling_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
var _mirror_mat: StandardMaterial3D
var _black_mat: StandardMaterial3D
var _red_mat: StandardMaterial3D
var _warm_emissive: StandardMaterial3D

func _ready() -> void:
    add_to_group("payment_altar_room")
    _create_materials()
    _build_shell()
    _build_secret_door()
    _build_wall_history()
    _build_lighting()
    _build_audio_zone()
    altar = ALTAR_SCENE.instantiate() as Node3D
    altar.name = "PaymentAltar"
    altar.position = Vector3(0.0, 0.0, 1.78)
    add_child(altar)
    var altar_interaction := altar.get("interaction") as Node
    if altar_interaction != null and altar_interaction.has_signal("worshipped"):
        altar_interaction.connect("worshipped", _on_worshipped)
    props = PROPS_SCENE.instantiate() as Node3D
    props.name = "PaymentAltarProps"
    add_child(props)
    _apply_reveal_state(0.0)

func _process(delta: float) -> void:
    if not _revealed or not RunStats.run_active:
        return
    _ambient_tick -= delta
    if _ambient_tick <= 0.0:
        _ambient_tick = randf_range(5.5, 10.0)
        AudioManager.play_3d(&"clink", global_position + Vector3(randf_range(-1.0, 1.0), 0.85, randf_range(0.5, 2.2)), -29.0, randf_range(0.68, 0.84))

func _create_materials() -> void:
    _wall_mat = _material(Color("261f23"), 0.98)
    _floor_mat = _material(Color("20191a"), 0.92)
    _ceiling_mat = _material(Color("1a1619"), 0.98)
    _wood_mat = _material(Color("38231c"), 0.86)
    _mirror_mat = _material(Color("626b6c"), 0.32)
    _mirror_mat.metallic = 0.58
    _black_mat = _material(Color("141114"), 0.96)
    _red_mat = _material(Color("6f252a"), 0.91)
    _warm_emissive = _material(Color("a24a28"), 0.48)
    _warm_emissive.emission_enabled = true
    _warm_emissive.emission = Color("e06030")
    _warm_emissive.emission_energy_multiplier = 1.15

func _build_shell() -> void:
    _box("Floor", Vector3(0.0, -0.08, 1.25), Vector3(2.90, 0.16, 2.55), _floor_mat, true)
    _box("Ceiling", Vector3(0.0, 3.02, 1.25), Vector3(2.90, 0.16, 2.55), _ceiling_mat, true)
    _box("LeftWall", Vector3(-1.45, 1.50, 1.25), Vector3(0.16, 3.00, 2.55), _wall_mat, true)
    _box("RightWall", Vector3(1.45, 1.50, 1.25), Vector3(0.16, 3.00, 2.55), _wall_mat, true)
    _box("BackWall", Vector3(0.0, 1.50, 2.52), Vector3(2.90, 3.00, 0.16), _wall_mat, true)
    _box("FrontWallLeft", Vector3(-1.12, 1.50, 0.0), Vector3(0.66, 3.00, 0.18), _wall_mat, true)
    _box("FrontWallRight", Vector3(1.12, 1.50, 0.0), Vector3(0.66, 3.00, 0.18), _wall_mat, true)
    _box("DoorHeader", Vector3(0.0, 2.72, 0.0), Vector3(1.62, 0.56, 0.18), _wall_mat, true)
    for x in [-1.31, 1.31]:
        _box("BaseboardSide", Vector3(x, 0.11, 1.30), Vector3(0.10, 0.18, 2.38), _wood_mat, false)
    _box("BaseboardBack", Vector3(0.0, 0.11, 2.39), Vector3(2.55, 0.18, 0.10), _wood_mat, false)

func _build_secret_door() -> void:
    secret_door = Node3D.new()
    secret_door.name = "PaymentSecretDoor"
    secret_door.set_script(SECRET_DOOR_SCRIPT)
    secret_door.position = Vector3(-0.74, 0.0, -0.05)
    secret_door.set("display_name", "СТАРОЕ ЗЕРКАЛО")
    secret_door.set("door_id", &"payment_altar_door")
    secret_door.set("source_id", &"payment_altar_door")
    secret_door.set("noise_category", &"DOOR")
    # Swing outward into the free rear aisle of the wardrobe. An inward swing
    # hid the investigation board and narrowed the already compact room.
    secret_door.set("open_angle_degrees", 102.0)
    secret_door.set("normal_noise", 2.6)
    secret_door.set("quiet_noise", 0.6)
    secret_door.set("fast_noise", 7.5)
    add_child(secret_door)
    var panel := _box_to(secret_door, "HiddenDoorPanel", Vector3(0.74, 1.22, 0.0), Vector3(1.48, 2.44, 0.10), _wood_mat, false)
    _box_to(secret_door, "OutsideMirror", Vector3(0.74, 1.28, -0.061), Vector3(1.30, 2.12, 0.025), _mirror_mat, false)
    _box_to(secret_door, "MirrorFrameTop", Vector3(0.74, 2.38, -0.072), Vector3(1.48, 0.09, 0.06), _wood_mat, false)
    _box_to(secret_door, "MirrorFrameBottom", Vector3(0.74, 0.18, -0.072), Vector3(1.48, 0.09, 0.06), _wood_mat, false)
    for x in [0.04, 1.44]:
        _box_to(secret_door, "MirrorFrameSide", Vector3(x, 1.28, -0.072), Vector3(0.09, 2.29, 0.06), _wood_mat, false)
    var inside_title := _label_to(secret_door, "ДЕНЬ 100\nTHE ПЛАТЕЖ", Vector3(0.74, 1.54, 0.062), 24, Color("8f3035"))
    inside_title.rotation_degrees.y = 180.0
    _box_to(secret_door, "Handle", Vector3(1.34, 1.18, -0.10), Vector3(0.18, 0.055, 0.055), _black_mat, false)
    var moving_body := StaticBody3D.new()
    moving_body.name = "MovingCollision"
    moving_body.position = panel.position
    moving_body.collision_layer = 1
    moving_body.collision_mask = 3
    secret_door.add_child(moving_body)
    var moving_shape := CollisionShape3D.new()
    var door_box := BoxShape3D.new()
    door_box.size = Vector3(1.48, 2.44, 0.10)
    moving_shape.shape = door_box
    moving_body.add_child(moving_shape)
    var area := Area3D.new()
    area.name = "InteractionArea"
    area.position = panel.position
    area.collision_layer = 2
    area.collision_mask = 0
    secret_door.add_child(area)
    var area_shape := CollisionShape3D.new()
    var area_box := BoxShape3D.new()
    area_box.size = Vector3(1.54, 2.50, 0.22)
    area_shape.shape = area_box
    area.add_child(area_shape)
    secret_door.connect("secret_visibility_changed", _on_secret_visibility_changed)

func _build_wall_history() -> void:
    # Three atlas panels carry dozens of repetitions with three draw calls.
    _textured_quad(
        "BackWallWriting",
        Vector3(0.0, 1.56, 2.425),
        Vector2(2.58, 2.62),
        Vector3(0.0, 180.0, 0.0),
        "res://assets/payment_altar/textures/wall_text_atlas.png"
    )
    _textured_quad(
        "LeftWallWriting",
        Vector3(-1.355, 1.58, 1.28),
        Vector2(2.36, 2.62),
        Vector3(0.0, -90.0, 0.0),
        "res://assets/payment_altar/textures/wall_text_small.png"
    )
    _textured_quad(
        "RightWallWriting",
        Vector3(1.355, 1.58, 1.28),
        Vector2(2.36, 2.62),
        Vector3(0.0, 90.0, 0.0),
        "res://assets/payment_altar/textures/wall_text_tallies.png"
    )
    var title := _label("THE ПЛАТЕЖ", Vector3(0.0, 2.55, 2.41), 47, Color("c55b45"))
    title.rotation_degrees.y = 180.0
    var subtitle := _label("ОН БЫЛ ОБЕЩАН  •  МЫ ЖДЁМ", Vector3(0.0, 2.24, 2.405), 17, Color("d1b18c"))
    subtitle.rotation_degrees.y = 180.0
    var vertical := _label("О Ж И Д А Й Т Е", Vector3(1.345, 1.50, 0.96), 19, Color("8e3036"))
    vertical.rotation_degrees = Vector3(0.0, 90.0, 90.0)
    # A ceiling inscription is only visible after stepping inside.
    var ceiling_text := _label("THE ПЛАТЕЖ НЕ ЗАБЫЛ", Vector3(0.0, 2.915, 1.50), 19, Color("7f3538"))
    ceiling_text.rotation_degrees = Vector3(90.0, 0.0, 0.0)

func _build_lighting() -> void:
    var hidden_warm := OmniLight3D.new()
    hidden_warm.name = "HiddenAmberFill"
    hidden_warm.position = Vector3(0.0, 2.35, 1.70)
    hidden_warm.light_color = Color("ff9a56")
    hidden_warm.light_energy = 0.0
    hidden_warm.omni_range = 4.1
    hidden_warm.shadow_enabled = true
    hidden_warm.set_meta("open_energy", 0.72)
    add_child(hidden_warm)
    _room_lights.append(hidden_warm)
    var burgundy_rim := OmniLight3D.new()
    burgundy_rim.name = "BurgundyRim"
    burgundy_rim.position = Vector3(1.05, 1.15, 2.12)
    burgundy_rim.light_color = Color("9a2836")
    burgundy_rim.light_energy = 0.0
    burgundy_rim.omni_range = 2.5
    burgundy_rim.shadow_enabled = false
    burgundy_rim.set_meta("open_energy", 0.30)
    add_child(burgundy_rim)
    _room_lights.append(burgundy_rim)
    var corridor_spill := OmniLight3D.new()
    corridor_spill.name = "ColdCorridorSpill"
    corridor_spill.position = Vector3(0.0, 1.85, 0.22)
    corridor_spill.light_color = Color("8ea4b0")
    corridor_spill.light_energy = 0.0
    corridor_spill.omni_range = 2.7
    corridor_spill.shadow_enabled = false
    corridor_spill.set_meta("open_energy", 0.22)
    add_child(corridor_spill)
    _room_lights.append(corridor_spill)
    _box("HiddenFixture", Vector3(0.0, 2.88, 1.76), Vector3(0.28, 0.035, 0.10), _warm_emissive, false)

func _build_audio_zone() -> void:
    var zone := Node3D.new()
    zone.name = "PaymentAltarAudioZone"
    zone.add_to_group("payment_altar_audio_zone")
    add_child(zone)
    _hum = _loop_player("res://assets/audio/ambience.wav", "LowWaitingHum", -72.0, 0.54)
    _paper_rustle = _loop_player("res://assets/audio/buzz.wav", "PaperAndPrinter", -78.0, 0.42)
    zone.add_child(_hum)
    zone.add_child(_paper_rustle)
    if "--run-foundation-tests" not in OS.get_cmdline_user_args():
        _hum.play()
        _paper_rustle.play()

func _loop_player(path: String, node_name: String, volume: float, pitch: float) -> AudioStreamPlayer3D:
    var player := AudioStreamPlayer3D.new()
    player.name = node_name
    var source := load(path) as AudioStream
    if source is AudioStreamWAV:
        var looped := source.duplicate() as AudioStreamWAV
        looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
        player.stream = looped
    else:
        player.stream = source
    player.volume_db = volume
    player.pitch_scale = pitch
    player.max_distance = 5.0
    player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    return player

func _on_secret_visibility_changed(opened: bool) -> void:
    set_revealed(opened)

func set_revealed(value: bool, immediate := false) -> void:
    if _revealed == value and not immediate:
        return
    var first_discovery := value and not bool(get_meta("discovered", false))
    _revealed = value
    if value:
        set_meta("discovered", true)
    var target := 1.0 if value else 0.0
    if immediate:
        _apply_reveal_state(target)
    else:
        var tween := create_tween()
        tween.set_parallel(true)
        for light in _room_lights:
            tween.tween_property(light, "light_energy", float(light.get_meta("open_energy", 1.0)) * target, 1.15)
        if altar != null:
            tween.tween_method(Callable(altar, "set_reveal_amount"), 0.0 if value else 1.0, target, 1.05)
        tween.tween_property(_hum, "volume_db", -26.0 if value else -72.0, 1.35)
        tween.tween_property(_paper_rustle, "volume_db", -36.0 if value else -78.0, 1.35)
    if value:
        AudioManager.play_3d(&"door", global_position, -15.0, 0.72)
        if first_discovery:
            QuestManager.notification_requested.emit("ОБНАРУЖЕНО СВЯТИЛИЩЕ THE ПЛАТЕЖА")
            RunStats.denis_spoke.emit("Это уже не ожидание. Это отдел.")

func _apply_reveal_state(amount: float) -> void:
    for light in _room_lights:
        light.light_energy = float(light.get_meta("open_energy", 1.0)) * amount
    if altar != null and altar.has_method("set_reveal_amount"):
        altar.call("set_reveal_amount", amount)
    if _hum != null:
        _hum.volume_db = lerpf(-72.0, -26.0, amount)
    if _paper_rustle != null:
        _paper_rustle.volume_db = lerpf(-78.0, -36.0, amount)

func _on_worshipped(first_time: bool) -> void:
    if altar != null and altar.has_method("trigger_payment_event"):
        altar.call("trigger_payment_event")
    if not first_time or _worship_event_played:
        return
    _worship_event_played = true
    QuestManager.notification_requested.emit("THE ПЛАТЕЖ БЛИЗКО  •  СТАТУС УТОЧНЯЕТСЯ")
    RunStats.denis_spoke.emit("Сегодня точно.")

func force_revealed_for_capture() -> void:
    if secret_door != null and secret_door.has_method("force_open_for_capture"):
        secret_door.call("force_open_for_capture")
    set_revealed(true, true)

func _box(node_name: String, pos: Vector3, size: Vector3, mat: Material, collision_enabled: bool) -> MeshInstance3D:
    return _box_to(self, node_name, pos, size, mat, collision_enabled)

func _box_to(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material, collision_enabled: bool) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh.material = mat
    instance.mesh = mesh
    instance.position = pos
    parent.add_child(instance)
    if collision_enabled:
        var body := StaticBody3D.new()
        body.name = "Collision"
        body.collision_layer = 1
        body.collision_mask = 3
        instance.add_child(body)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    return instance

func _textured_quad(node_name: String, pos: Vector3, size: Vector2, rotation_value: Vector3, texture_path: String) -> void:
    var texture := load(texture_path) as Texture2D
    if texture == null:
        return
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var quad := QuadMesh.new()
    quad.size = size
    quad.material = material
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = quad
    instance.position = pos
    instance.rotation_degrees = rotation_value
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)

func _label(text_value: String, pos: Vector3, size: int, color: Color) -> Label3D:
    return _label_to(self, text_value, pos, size, color)

func _label_to(parent: Node3D, text_value: String, pos: Vector3, size: int, color: Color) -> Label3D:
    var label := Label3D.new()
    label.text = text_value
    label.position = pos
    label.font_size = size
    label.modulate = color
    label.outline_size = 4
    label.outline_modulate = Color(0.03, 0.02, 0.025, 0.82)
    parent.add_child(label)
    return label

func _material(color: Color, roughness: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    return material
