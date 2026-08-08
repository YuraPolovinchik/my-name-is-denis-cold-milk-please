extends CharacterBody3D

const INTERACTION_NORMAL := 0
const INTERACTION_QUIET := 1
const INTERACTION_FAST := 2

signal prompt_changed(text: String)
signal message_requested(text: String)
signal condition_changed(data: Dictionary)
signal pour_session_started(controller: PourController, item: RigidBody3D)
signal pour_session_stopped()

@export var mouse_sensitivity: float = 0.0022
@export var normal_speed: float = 3.6
@export var sprint_speed: float = 5.7
@export var crouch_speed: float = 2.0
@export var tiptoe_speed: float = 1.65

var camera: Camera3D = null
var held_item: RigidBody3D = null
var pushed_body: RigidBody3D = null
var _push_noise_timer := 0.0
var _push_local_point := Vector3.ZERO
var _push_grab_distance := 1.4
var _push_start_body_y := 0.0
var slippers_equipped: bool = false
var furniture_pads_equipped := false
var hinge_oil_equipped := false
var _pitch: float = 0.0
var _step_distance: float = 0.0
var _interaction_target: Node = null
var _interact_time: float = 0.0
var _interact_pending: bool = false
var _interact_fired: bool = false
var _standing_height: float = 1.72
var _crouch_height: float = 1.05
var _view_hands: Node3D = null
var _hold_root: Node3D = null
var _item_anchor: Node3D = null
var _held_original_parent: Node = null
var _left_hand: Node3D = null
var _right_hand: Node3D = null
var _imported_hands_model: Node3D = null
var _using_imported_hands := false
var _hand_motion_time := 0.0
var is_hidden := false
var _rage_lock_active := false
var _active_hide_spot: Node = null
var _hide_exit_position := Vector3.ZERO
var stamina := 100.0
var intoxication := 0.0
var _drunk_control_elapsed := 0.0
var _drunk_control_timer := 0.0
var _drunk_movement_inverted := false
var _drunk_mouse_inverted := false
var _held_rotation_offset := Vector3.ZERO
var _condition_emit_timer := 0.0
var _drink_active := false

# === Режим розлива ===
var pour_mode_active := false
var pour_controller: PourController = null
var _pour_stabilize: bool = false
var _pour_item_initialized := false
var spill_cleanup_controller: SpillCleanupController = null
var _drink_elapsed := 0.0
var _drink_bottle: RigidBody3D
var _drink_return_transform := Transform3D.IDENTITY
var _drink_temporary_pickup := false
var _drink_kind: StringName = &""
var _drink_sips_done := 0

func _ready() -> void:
    collision_layer = 1
    collision_mask = 3

    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.8
    collider.shape = shape
    collider.position.y = 0.9
    add_child(collider)

    camera = Camera3D.new()
    camera.name = "Camera"
    camera.position = Vector3(0.0, 1.58, 0.0)
    camera.current = true
    camera.near = 0.035
    add_child(camera)
    _create_view_hands()
    spill_cleanup_controller = SpillCleanupController.new()
    spill_cleanup_controller.name = "SpillCleanupController"
    add_child(spill_cleanup_controller)
    spill_cleanup_controller.bind_player(self)

    # Захват откладывается на кадр: так окно Godot успевает получить фокус.
    call_deferred("_capture_mouse")

func _exit_tree() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
    if not RunStats.run_active:
        if _drink_active:
            _finish_drink_animation()
        velocity = Vector3.ZERO
        _interact_pending = false
        if pushed_body != null:
            _stop_pushing()
        return
    _sync_rage_lock()
    _update_condition(delta)
    _update_movement(delta)
    _update_pushing(delta)
    _update_held_item(delta)
    _update_view_hands(delta)
    _update_interaction_target()
    _update_interaction_hold(delta)
    
    # Обновление режима розлива
    if pour_mode_active and pour_controller != null and is_instance_valid(pour_controller):
        pour_controller._stabilizing = _pour_stabilize

# Важно: обзор обрабатывается в _input(), а не в _unhandled_input().
# Полноэкранный HUD больше не может съесть движение мыши.
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            _capture_mouse()
        get_viewport().set_input_as_handled()
        return

    # После Esc один клик возвращает мышь. Этот же клик не поднимает предмет.
    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        # После финиша мышь принадлежит полям имени и кнопкам таблицы лидеров.
        if RunStats.run_active and event is InputEventMouseButton and event.pressed:
            _capture_mouse()
            get_viewport().set_input_as_handled()
        return

    if not RunStats.run_active:
        return

    if is_hidden and event.is_action_pressed("interact"):
        exit_hide_spot()
        get_viewport().set_input_as_handled()
        return

    if is_hidden and (
        event.is_action_pressed("pickup")
        or event.is_action_pressed("place")
    ):
        get_viewport().set_input_as_handled()
        return

    if RitaSleep.is_angry and not is_hidden and (
        event.is_action_pressed("pickup")
        or event.is_action_pressed("place")
    ):
        message_requested.emit("НЕ ДО ВЕЩЕЙ — РИТА В ЯРОСТИ. БЕГИ В ГАРДЕРОБНУЮ")
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("rotate_item"):
        if held_item != null and is_instance_valid(held_item):
            _rotate_held_item()
            get_viewport().set_input_as_handled()
        return

    # E имеет отдельный контекст налива и не запускает обычное взаимодействие,
    # пока в руках находится чайник или упаковка молока.
    if event.is_action_pressed("pour_action") and _can_enter_pour_mode():
        _enter_pour_mode()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_released("pour_action") and pour_mode_active:
        _exit_pour_mode()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("interact") and spill_cleanup_controller != null and spill_cleanup_controller.has_target():
        spill_cleanup_controller.start_cleaning()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_released("interact") and spill_cleanup_controller != null and spill_cleanup_controller.cleaning:
        spill_cleanup_controller.stop_cleaning()
        get_viewport().set_input_as_handled()
        return

    if event is InputEventMouseMotion:
        if camera == null or not is_instance_valid(camera):
            return
        var drunk_mouse_scale := _drunk_mouse_multiplier()
        rotate_y(-event.relative.x * mouse_sensitivity * drunk_mouse_scale)
        _pitch = clampf(
            _pitch - event.relative.y * mouse_sensitivity * drunk_mouse_scale,
            deg_to_rad(-86.0),
            deg_to_rad(86.0)
        )
        camera.rotation.x = _pitch
        get_viewport().set_input_as_handled()
        return

    if _drink_active and (
        event.is_action_pressed("pickup")
        or event.is_action_pressed("place")
        or event.is_action_pressed("interact")
        or event.is_action_pressed("rotate_item")
    ):
        message_requested.emit("ДЕНИС ПЬЁТ  •  СЕКУНДУ")
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("interact") and _can_drink_held_coffee():
        if begin_drink_coffee(held_item):
            message_requested.emit("ДЕНИС ПЬЁТ КОФЕ  •  ФИНИШ ПОСЛЕ ГЛОТКА")
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("pickup"):
        _try_pickup()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_released("pickup"):
        if pushed_body != null:
            _stop_pushing()
        get_viewport().set_input_as_handled()
        return

    # ПКМ удерживается только для стабилизации во время активного налива.
    if pour_mode_active and event.is_action_pressed("place"):
        _pour_stabilize = true
        get_viewport().set_input_as_handled()
        return
    if pour_mode_active and event.is_action_released("place"):
        _pour_stabilize = false
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("interact"):
        _interact_pending = true
        _interact_fired = false
        _interact_time = 0.0
        if Input.is_action_pressed("sprint"):
            _fire_interaction(INTERACTION_FAST)
        get_viewport().set_input_as_handled()
        return

    if event.is_action_released("interact") and _interact_pending and not _interact_fired:
        _fire_interaction(INTERACTION_NORMAL)
        get_viewport().set_input_as_handled()
        return

func _capture_mouse() -> void:
    if not is_inside_tree():
        return
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _create_view_hands() -> void:
    _hold_root = Node3D.new()
    _hold_root.name = "FirstPersonHoldRoot"
    camera.add_child(_hold_root)
    _item_anchor = Node3D.new()
    _item_anchor.name = "ItemAnchor"
    _hold_root.add_child(_item_anchor)
    _view_hands = Node3D.new()
    _view_hands.name = "ViewHands"
    _hold_root.add_child(_view_hands)
    # The imported rifle pose folds both forearms across the centre of the
    # screen and hides domestic props.  Purpose-built procedural hands keep
    # the held object readable and avoid inheriting a weapon silhouette.
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color("d7a07f")
    skin.roughness = 0.82
    var sleeve := StandardMaterial3D.new()
    sleeve.albedo_color = Color("243746")
    sleeve.roughness = 0.92

    _left_hand = _create_hand_model("LeftHand", -1.0, skin, sleeve)
    _right_hand = _create_hand_model("RightHand", 1.0, skin, sleeve)
    _view_hands.add_child(_left_hand)
    _view_hands.add_child(_right_hand)

func _try_create_imported_hands() -> bool:
    var asset_path := "res://assets/models/cc0_fps_hands/rifle_hands.glb"
    if not ResourceLoader.exists(asset_path):
        return false
    var packed := load(asset_path) as PackedScene
    if packed == null:
        return false
    _imported_hands_model = packed.instantiate() as Node3D
    if _imported_hands_model == null:
        return false
    _imported_hands_model.name = "ImportedFPSHands"
    _view_hands.add_child(_imported_hands_model)
    var gun := _imported_hands_model.find_child("Gun", true, false) as GeometryInstance3D
    _left_hand = _imported_hands_model.find_child("Hand1", true, false) as Node3D
    _right_hand = _imported_hands_model.find_child("Hand2", true, false) as Node3D
    if gun != null:
        gun.visible = false
    if _left_hand == null or _right_hand == null:
        _imported_hands_model.queue_free()
        _imported_hands_model = null
        _left_hand = null
        _right_hand = null
        return false
    var imported_skin := StandardMaterial3D.new()
    imported_skin.albedo_color = Color("c98f70")
    imported_skin.roughness = 0.86
    (_left_hand as GeometryInstance3D).material_override = imported_skin
    (_right_hand as GeometryInstance3D).material_override = imported_skin
    for child in _imported_hands_model.find_children("*", "GeometryInstance3D", true, false):
        (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var animation_player := _imported_hands_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if animation_player != null:
        animation_player.stop()
    _imported_hands_model.scale = Vector3.ONE * 0.12
    _imported_hands_model.position = Vector3(0.0, -0.25, -0.40)
    _using_imported_hands = true
    return true

func _create_hand_model(node_name: String, side: float, skin: Material, sleeve: Material) -> Node3D:
    var hand := Node3D.new()
    hand.name = node_name

    var sleeve_mesh := CylinderMesh.new()
    sleeve_mesh.top_radius = 0.048
    sleeve_mesh.bottom_radius = 0.060
    var sleeve_direction := Vector3(side * 0.18, -0.28, 0.36)
    sleeve_mesh.height = sleeve_direction.length()
    sleeve_mesh.radial_segments = 10
    var sleeve_instance := _view_hand_mesh(hand, "Sleeve", sleeve_mesh, sleeve_direction * 0.5, Vector3.ZERO, sleeve)
    sleeve_instance.quaternion = Quaternion(Vector3.UP, sleeve_direction.normalized())

    var wrist_mesh := CylinderMesh.new()
    wrist_mesh.top_radius = 0.041
    wrist_mesh.bottom_radius = 0.045
    wrist_mesh.height = 0.11
    wrist_mesh.radial_segments = 10
    _view_hand_mesh(hand, "Wrist", wrist_mesh, Vector3(0.0, 0.0, 0.015), Vector3(90.0, 0.0, 0.0), skin)

    var palm_mesh := BoxMesh.new()
    palm_mesh.size = Vector3(0.135, 0.075, 0.15)
    _view_hand_mesh(hand, "Palm", palm_mesh, Vector3.ZERO, Vector3.ZERO, skin)

    for finger_index in range(4):
        var finger_mesh := CapsuleMesh.new()
        finger_mesh.radius = 0.016
        finger_mesh.height = 0.125
        var finger_x := -0.052 + float(finger_index) * 0.035
        _view_hand_mesh(hand, "Finger_%d" % finger_index, finger_mesh, Vector3(finger_x, -0.005, -0.125), Vector3(90.0, 0.0, 0.0), skin)

    var thumb_mesh := CapsuleMesh.new()
    thumb_mesh.radius = 0.019
    thumb_mesh.height = 0.115
    _view_hand_mesh(hand, "Thumb", thumb_mesh, Vector3(side * 0.085, 0.015, -0.035), Vector3(72.0, 0.0, -52.0 * side), skin)
    return hand

func _view_hand_mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, rot_degrees: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.position = pos
    instance.rotation_degrees = rot_degrees
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance

func _update_view_hands(delta: float) -> void:
    if _left_hand == null or _right_hand == null:
        return
    _hand_motion_time += delta * (1.4 + Vector2(velocity.x, velocity.z).length() * 2.2)
    var blend := minf(1.0, delta * 11.0)
    if _using_imported_hands and _imported_hands_model != null:
        _left_hand.visible = not _drink_active
        _right_hand.visible = true
        var model_target := Vector3(0.0, -0.42, -0.18)
        var model_rotation := Vector3(-5.0, 0.0, 0.0)
        if _drink_active:
            model_target = Vector3(0.13, -0.28, -0.50)
            model_rotation = Vector3(-15.0, 8.0, -10.0)
        elif pushed_body != null and is_instance_valid(pushed_body):
            model_target = Vector3(0.0, -0.22, -0.52)
            model_rotation = Vector3(-14.0, 0.0, 0.0)
        elif held_item != null and is_instance_valid(held_item):
            var held_kind: Variant = held_item.get("item_id")
            if held_kind == &"kettle":
                model_target = Vector3(0.08, -0.31, -0.42) if not pour_mode_active else Vector3(0.14, -0.29, -0.38)
                model_rotation = Vector3(-12.0, 5.0, -8.0 if not pour_mode_active else -15.0)
            elif held_kind == &"milk_carton":
                model_target = Vector3(0.06, -0.27, -0.42)
                model_rotation = Vector3(-10.0, 4.0, -6.0)
            elif held_kind == &"spoon":
                model_target = Vector3(0.12, -0.25, -0.43)
                model_rotation = Vector3(-12.0, 9.0, -10.0)
            elif held_kind == &"towel":
                model_target = Vector3(0.20, -0.48, -0.72)
                model_rotation = Vector3(-18.0, 9.0, -8.0)
            elif held_kind == &"mop":
                model_target = Vector3(0.12, -0.31, -0.48)
                model_rotation = Vector3(-16.0, 7.0, -10.0)
            else:
                model_target = Vector3(0.04, -0.26, -0.42)
                model_rotation = Vector3(-9.0, 2.0, -4.0)
        else:
            model_target.y += sin(_hand_motion_time) * minf(0.012, Vector2(velocity.x, velocity.z).length() * 0.003)
        var imported_drift := intoxication / 100.0
        model_target.x += sin(_hand_motion_time * 0.73) * imported_drift * 0.035
        model_target.y += cos(_hand_motion_time * 0.91) * imported_drift * 0.025
        model_rotation.z += sin(_hand_motion_time * 0.61) * imported_drift * 5.0
        _imported_hands_model.position = _imported_hands_model.position.lerp(model_target, blend)
        _imported_hands_model.rotation_degrees = _imported_hands_model.rotation_degrees.lerp(model_rotation, blend)
        return
    var left_target := Vector3(-0.27, -0.39, -0.48)
    var right_target := Vector3(0.27, -0.39, -0.48)
    var left_rotation := Vector3(-8.0, -7.0, -7.0)
    var right_rotation := Vector3(-8.0, 7.0, 7.0)

    if _drink_active:
        left_target = Vector3(-0.25, -0.34, -0.47)
        right_target = Vector3(0.14, -0.07, -0.29)
        left_rotation = Vector3(-9.0, -7.0, -7.0)
        right_rotation = Vector3(-58.0, 12.0, -22.0)
    elif pushed_body != null and is_instance_valid(pushed_body):
        left_target = Vector3(-0.24, -0.20, -0.88)
        right_target = Vector3(0.24, -0.20, -0.88)
        left_rotation = Vector3(-18.0, -5.0, -3.0)
        right_rotation = Vector3(-18.0, 5.0, 3.0)
    elif held_item != null and is_instance_valid(held_item):
        var held_kind: Variant = held_item.get("item_id")
        if held_kind == &"kettle":
            var left_marker := held_item.get_node_or_null("LeftHandSupport") as Node3D
            var right_marker := held_item.get_node_or_null("RightHandGrip") as Node3D
            left_target = _hold_root.to_local(left_marker.global_position) if left_marker != null else Vector3(-0.02, -0.42, -0.70)
            right_target = _hold_root.to_local(right_marker.global_position) if right_marker != null else Vector3(0.32, -0.34, -0.62)
            left_target += Vector3(-0.035, -0.015, 0.015)
            right_target += Vector3(0.025, -0.015, 0.015)
            # With the wrist rooted on the grip marker the sleeves should run
            # back toward the lower screen corners, not across the kettle.
            left_rotation = Vector3(-3.0, -5.0, -3.0)
            right_rotation = Vector3(-3.0, 5.0, 3.0)
        elif held_kind == &"spoon":
            left_target = Vector3(-0.24, -0.39, -0.48)
            right_target = Vector3(0.15, -0.24, -0.56)
            right_rotation = Vector3(-24.0, 12.0, 8.0)
        elif held_kind == &"towel":
            left_target = Vector3(-0.24, -0.47, -0.82)
            right_target = Vector3(0.34, -0.45, -0.82)
            left_rotation = Vector3(-20.0, -10.0, -6.0)
            right_rotation = Vector3(-20.0, 10.0, 6.0)
        elif held_kind == &"mop":
            left_target = Vector3(-0.10, -0.24, -0.66)
            right_target = Vector3(0.22, -0.43, -0.76)
            left_rotation = Vector3(-18.0, -6.0, -4.0)
            right_rotation = Vector3(-24.0, 8.0, 5.0)
        else:
            var grip_width := clampf(0.16 + held_item.mass * 0.010, 0.17, 0.25)
            left_target = Vector3(-grip_width * 0.55, -0.30, -0.62)
            right_target = Vector3(grip_width, -0.27, -0.60)
            left_rotation = Vector3(-14.0, -14.0, -8.0)
            right_rotation = Vector3(-14.0, 14.0, 8.0)
    else:
        var bob := sin(_hand_motion_time) * minf(0.012, Vector2(velocity.x, velocity.z).length() * 0.003)
        left_target.y += bob
        right_target.y -= bob

    var hand_drift := intoxication / 100.0
    var drunk_x := sin(_hand_motion_time * 0.73) * hand_drift * 0.038
    var drunk_y := cos(_hand_motion_time * 0.91) * hand_drift * 0.026
    left_target += Vector3(drunk_x, drunk_y, 0.0)
    right_target += Vector3(drunk_x, -drunk_y * 0.65, 0.0)
    left_rotation.z += sin(_hand_motion_time * 0.61) * hand_drift * 6.0
    right_rotation.z += sin(_hand_motion_time * 0.61) * hand_drift * 6.0

    _left_hand.position = _left_hand.position.lerp(left_target, blend)
    _right_hand.position = _right_hand.position.lerp(right_target, blend)
    _left_hand.rotation_degrees = _left_hand.rotation_degrees.lerp(left_rotation, blend)
    _right_hand.rotation_degrees = _right_hand.rotation_degrees.lerp(right_rotation, blend)

func set_view_hands_visible(value: bool) -> void:
    if _view_hands != null:
        _view_hands.visible = value

func _attach_item_to_hold_rig(item: RigidBody3D) -> void:
    if item == null or _item_anchor == null or item.get_parent() == _item_anchor:
        return
    _held_original_parent = item.get_parent()
    if _held_original_parent != null and _held_original_parent.is_in_group("drawer"):
        _held_original_parent = _held_original_parent.get_parent()
    item.reparent(_item_anchor, true)

func _detach_item_from_hold_rig(item: RigidBody3D) -> void:
    if item == null or item.get_parent() != _item_anchor:
        return
    var target_parent := _held_original_parent
    if target_parent == null or not is_instance_valid(target_parent):
        target_parent = get_tree().current_scene
    item.reparent(target_parent, true)
    _held_original_parent = null

func get_held_item() -> RigidBody3D:
    return held_item

func get_condition_state() -> Dictionary:
    return {
        "stamina": stamina,
        "intoxication": intoxication,
        "speed_factor": _stamina_speed_factor(),
        "movement_inverted": _drunk_movement_inverted,
        "mouse_inverted": _drunk_mouse_inverted
    }

func drink_match_beer(stamina_gain: float, intoxication_gain: float) -> void:
    stamina = clampf(stamina + stamina_gain, 0.0, 100.0)
    intoxication = clampf(intoxication + intoxication_gain, 0.0, 100.0)
    RunStats.record_beer_sip(intoxication)
    condition_changed.emit(get_condition_state())

func begin_drink_match_beer(bottle: RigidBody3D, stamina_gain: float, intoxication_gain: float) -> bool:
    if _drink_active or bottle == null or not is_instance_valid(bottle) or RitaSleep.is_angry or is_hidden:
        return false
    if held_item != null and held_item != bottle:
        return false
    _drink_active = true
    _drink_kind = &"beer"
    _drink_elapsed = 0.0
    _drink_bottle = bottle
    _drink_temporary_pickup = held_item == null
    _drink_return_transform = bottle.global_transform
    if _drink_temporary_pickup:
        held_item = bottle
        bottle.call("on_picked_up")
    _held_rotation_offset = Vector3.ZERO
    drink_match_beer(stamina_gain, intoxication_gain)
    return true

func _can_drink_held_coffee() -> bool:
    return (
        held_item != null
        and is_instance_valid(held_item)
        and StringName(held_item.get("item_id")) == &"mug"
        and bool(held_item.get_meta("coffee_ready", false))
        and QuestManager.coffee_made
        and not QuestManager.coffee_drunk
    )

func begin_drink_coffee(mug: RigidBody3D) -> bool:
    if _drink_active or mug == null or not is_instance_valid(mug) or RitaSleep.is_angry or is_hidden:
        return false
    if QuestManager.spill_cleanup_required:
        message_requested.emit("СНАЧАЛА УБЕРИ КРУПНУЮ ЛУЖУ НА КУХНЕ")
        return false
    if (held_item != null and held_item != mug) or not bool(mug.get_meta("coffee_ready", false)):
        return false
    _drink_active = true
    _drink_kind = &"coffee"
    _drink_elapsed = 0.0
    _drink_bottle = mug
    _drink_temporary_pickup = held_item == null
    _drink_return_transform = mug.global_transform
    if _drink_temporary_pickup:
        held_item = mug
        mug.call("on_picked_up")
    _drink_sips_done = 0
    _held_rotation_offset = Vector3.ZERO
    return true

func is_drinking_beer() -> bool:
    return _drink_active

func _update_drink_animation(delta: float) -> void:
    if not _drink_active or _drink_bottle == null or not is_instance_valid(_drink_bottle) or camera == null:
        _finish_drink_animation()
        return
    _drink_elapsed += delta
    var duration := 2.15 if _drink_kind == &"coffee" else 1.65
    var progress := clampf(_drink_elapsed / duration, 0.0, 1.0)
    var lift := sin(progress * PI)
    var carry_position := camera.to_global(Vector3(0.22, -0.30, -0.70))
    var mouth_position := camera.to_global(Vector3(0.16, -0.15, -0.36))
    _drink_bottle.global_position = carry_position.lerp(mouth_position, lift)
    var target_rotation := Vector3(
        camera.global_rotation.x + deg_to_rad((-72.0 if _drink_kind == &"coffee" else -56.0) * lift),
        camera.global_rotation.y,
        deg_to_rad(-10.0 * lift)
    )
    _drink_bottle.global_rotation = target_rotation
    if _drink_kind == &"coffee":
        var target_sips := int(progress >= 0.30) + int(progress >= 0.60) + int(progress >= 0.90)
        var mug_controller := _drink_bottle.get_node_or_null("MugContentController")
        while _drink_sips_done < target_sips and mug_controller and mug_controller.has_method("drink_sip"):
            var remaining: float = mug_controller.call("total_liquid_ml")
            var sips_left := maxi(1, 3 - _drink_sips_done)
            mug_controller.call("drink_sip", remaining / float(sips_left))
            _drink_sips_done += 1
    if progress >= 1.0:
        _finish_drink_animation(false, true)

func _finish_drink_animation(drop_in_place := false, completed := false) -> void:
    if not _drink_active:
        return
    var bottle := _drink_bottle
    var temporary := _drink_temporary_pickup
    var drink_kind := _drink_kind
    _drink_active = false
    _drink_kind = &""
    _drink_elapsed = 0.0
    _drink_bottle = null
    _drink_temporary_pickup = false
    _drink_sips_done = 0
    if bottle == null or not is_instance_valid(bottle):
        held_item = null
        return
    if temporary:
        if held_item == bottle:
            held_item = null
        if not drop_in_place:
            bottle.global_transform = _drink_return_transform
        _detach_item_from_hold_rig(bottle)
        bottle.call("on_released")
        bottle.linear_velocity = Vector3.ZERO
        bottle.angular_velocity = Vector3.ZERO
    else:
        held_item = bottle
        _held_rotation_offset = bottle.global_rotation - Vector3(0.0, camera.global_rotation.y, 0.0)
    if completed and drink_kind == &"coffee":
        bottle.set_meta("coffee_ready", false)
        var coffee_surface := bottle.get_node_or_null("CoffeeSurface") as Node3D
        if coffee_surface != null:
            coffee_surface.visible = false
        QuestManager.drink_coffee()

func on_match_watched(with_beer: bool) -> void:
    stamina = clampf(stamina + (8.0 if with_beer else 5.0), 0.0, 100.0)
    condition_changed.emit(get_condition_state())

func on_match_missed() -> void:
    stamina = maxf(0.0, stamina - 16.0)
    condition_changed.emit(get_condition_state())

func _update_condition(delta: float) -> void:
    var movement_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var drain := 0.10
    if movement_input.length() > 0.1 and not is_hidden:
        drain += 0.28
        if Input.is_action_pressed("sprint") and not RitaSleep.is_angry:
            drain += 2.35
        elif Input.is_action_pressed("tiptoe"):
            drain += 0.16
    if held_item != null and is_instance_valid(held_item):
        drain += held_item.mass * 0.025
    if pushed_body != null and is_instance_valid(pushed_body):
        drain += pushed_body.mass * 0.032
    # Применяем модификатор сложности
    drain *= DifficultyManager.get_stamina_drain()
    stamina = maxf(0.0, stamina - drain * delta)
    intoxication = maxf(0.0, intoxication - 0.18 * delta)
    _update_drunk_controls(delta)
    _condition_emit_timer -= delta
    if _condition_emit_timer <= 0.0:
        _condition_emit_timer = 0.15
        condition_changed.emit(get_condition_state())

func _stamina_speed_factor() -> float:
    return lerpf(0.58, 1.0, sqrt(clampf(stamina / 100.0, 0.0, 1.0)))

func _drunk_severity() -> float:
    return smoothstep(10.0, 100.0, intoxication)

func _update_drunk_controls(delta: float) -> void:
    _drunk_control_elapsed += delta
    var severity := _drunk_severity()
    if intoxication < 18.0:
        _drunk_control_timer = 0.0
        _drunk_movement_inverted = false
        _drunk_mouse_inverted = false
        return
    _drunk_control_timer -= delta
    if _drunk_control_timer > 0.0:
        return
    var inversion_chance := clampf((intoxication - 28.0) / 72.0, 0.0, 1.0)
    _drunk_movement_inverted = randf() < inversion_chance
    _drunk_mouse_inverted = randf() < inversion_chance * 0.92
    if intoxication >= 85.0 and not _drunk_movement_inverted and not _drunk_mouse_inverted:
        if randf() < 0.5:
            _drunk_movement_inverted = true
        else:
            _drunk_mouse_inverted = true
    _drunk_control_timer = randf_range(
        lerpf(4.8, 1.15, severity),
        lerpf(7.2, 2.20, severity)
    )

func _apply_drunk_movement_input(raw_input: Vector2) -> Vector2:
    var result := -raw_input if _drunk_movement_inverted else raw_input
    var severity := _drunk_severity()
    if severity <= 0.0 or result.length_squared() < 0.001:
        return result
    var weave_radians := sin(_drunk_control_elapsed * lerpf(1.15, 2.40, severity)) * deg_to_rad(18.0) * severity
    return result.rotated(weave_radians)

func _drunk_mouse_multiplier() -> float:
    var severity := _drunk_severity()
    var unstable_sensitivity := lerpf(1.0, 1.42, severity)
    unstable_sensitivity *= 1.0 + sin(_drunk_control_elapsed * 2.15) * severity * 0.16
    return unstable_sensitivity * (-1.0 if _drunk_mouse_inverted else 1.0)

func _drunk_fumble_chance() -> float:
    var severity := _drunk_severity()
    return pow(severity, 1.35) * 0.78

func _drunk_throw_strength() -> float:
    return lerpf(3.2, 10.5, _drunk_severity())

func _rotate_held_item() -> void:
    var axis_name := "ПО ГОРИЗОНТАЛИ"
    if Input.is_action_pressed("crouch"):
        _held_rotation_offset.z = wrapf(_held_rotation_offset.z + deg_to_rad(45.0), -PI, PI)
        axis_name = "КРЕН"
    elif Input.is_action_pressed("sprint"):
        _held_rotation_offset.x = wrapf(_held_rotation_offset.x + deg_to_rad(45.0), -PI, PI)
        axis_name = "НАКЛОН"
    else:
        _held_rotation_offset.y = wrapf(_held_rotation_offset.y + deg_to_rad(45.0), -PI, PI)
    var item_name := String(held_item.get("display_name")) if held_item.get("display_name") != null else String(held_item.name)
    message_requested.emit("ПОВОРОТ: %s  •  %s 45°" % [item_name, axis_name])

func equip_slippers() -> void:
    slippers_equipped = true

func equip_furniture_pads() -> void:
    furniture_pads_equipped = true

func equip_hinge_oil() -> void:
    hinge_oil_equipped = true

func has_hinge_oil() -> bool:
    return hinge_oil_equipped

func _update_movement(delta: float) -> void:
    if camera == null:
        return
    if is_hidden:
        velocity = Vector3.ZERO
        camera.position.y = move_toward(camera.position.y, _standing_height, delta * 3.5)
        return
    var input_vector: Vector2 = _apply_drunk_movement_input(
        Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    )
    var direction: Vector3 = (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
    var speed: float = normal_speed
    var step_noise: float = 2.1
    var escaping_rita := RitaSleep.is_angry
    var on_soft_surface := _is_soft_surface_at(global_position)
    var flood_depth := _get_flood_depth_at(global_position)

    if escaping_rita:
        speed = sprint_speed * 1.08
        step_noise = 6.5
        camera.position.y = move_toward(camera.position.y, _standing_height, delta * 5.0)
    elif Input.is_action_pressed("crouch"):
        speed = crouch_speed
        step_noise = 0.85
        camera.position.y = move_toward(camera.position.y, _crouch_height, delta * 3.5)
    elif Input.is_action_pressed("tiptoe"):
        speed = tiptoe_speed
        step_noise = 0.55
        camera.position.y = move_toward(camera.position.y, _standing_height - 0.06, delta * 3.5)
    elif Input.is_action_pressed("sprint") and stamina > 6.0:
        speed = sprint_speed
        step_noise = 5.8
        camera.position.y = move_toward(camera.position.y, _standing_height, delta * 3.5)
    else:
        camera.position.y = move_toward(camera.position.y, _standing_height, delta * 3.5)

    if slippers_equipped and not escaping_rita:
        step_noise *= 0.55
        speed *= 0.88
    if on_soft_surface and not escaping_rita:
        step_noise *= 0.42
    if not escaping_rita:
        speed *= _stamina_speed_factor()
        var drunk_severity := _drunk_severity()
        speed *= lerpf(1.0, 0.72, drunk_severity)
        step_noise *= lerpf(1.0, 1.65, drunk_severity)
        camera.rotation.z = lerp_angle(
            camera.rotation.z,
            sin(_drunk_control_elapsed * 1.45) * deg_to_rad(4.5) * drunk_severity,
            minf(1.0, delta * 3.2)
        )
    if _drink_active:
        speed *= 0.38

    if flood_depth > 0.02:
        var wading := clampf(flood_depth / 0.72, 0.0, 1.0)
        # По колено уже нельзя нормально бежать: вода физически тормозит игрока.
        speed *= lerpf(0.88, 0.34, wading)
        step_noise += lerpf(2.5, 14.0, wading)
        camera.position.y += sin(Time.get_ticks_msec() * 0.009) * 0.0035 * wading

    if pushed_body != null and is_instance_valid(pushed_body):
        speed = _push_speed_for_mass(pushed_body.mass)
        step_noise += minf(12.0, pushed_body.mass * 0.18)

    if held_item != null and is_instance_valid(held_item):
        var carried_mass := maxf(held_item.mass, 0.1)
        speed /= clampf(1.0 + maxf(0.0, carried_mass - 2.0) * 0.075, 1.0, 2.35)
        step_noise += minf(8.0, carried_mass * 0.32)

    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if not is_on_floor():
        velocity.y -= 18.0 * delta
    else:
        velocity.y = -0.1

    var previous_position: Vector3 = global_position
    move_and_slide()
    var moved: float = Vector2(
        global_position.x - previous_position.x,
        global_position.z - previous_position.z
    ).length()

    if is_on_floor() and moved > 0.001:
        _step_distance += moved
        if _step_distance >= 1.45:
            _step_distance = 0.0
            if slippers_equipped and not escaping_rita:
                RunStats.record_noise_prevented(0.9)
            if on_soft_surface and not escaping_rita:
                RunStats.record_noise_prevented(1.1)
            NoiseManager.emit_noise(global_position, step_noise, &"FOOTSTEP", &"denis_step")
            if flood_depth > 0.02:
                NoiseManager.emit_noise(global_position, 5.0 + flood_depth * 18.0, &"WATER_SPLASH", &"denis_wading")
                AudioManager.play_3d(&"step", global_position, -10.0, randf_range(0.62, 0.78))
            else:
                AudioManager.play_3d(&"cloth_step" if slippers_equipped or on_soft_surface else &"step", global_position, -16.0, randf_range(0.92, 1.08))
            # Визуальный эффект пыли при ходьбе (только на твердых поверхностях)
            if flood_depth <= 0.02 and not on_soft_surface and not slippers_equipped:
                VisualEffects.spawn_dust(global_position + Vector3(0, 0.1, 0), 1)

func _get_flood_depth_at(world_position: Vector3) -> float:
    var flood := get_tree().get_first_node_in_group("apartment_flood_visual") as ApartmentFloodVisual
    return flood.get_water_depth_at(world_position) if flood != null else 0.0

func _is_soft_surface_at(world_position: Vector3) -> bool:
    for node in get_tree().get_nodes_in_group("soft_surface"):
        if not node is Node3D:
            continue
        var surface := node as Node3D
        var soft_size: Vector2 = surface.get_meta("soft_size", Vector2.ZERO)
        var local_point := surface.to_local(world_position)
        if absf(local_point.x) <= soft_size.x * 0.5 and absf(local_point.z) <= soft_size.y * 0.5:
            return true
    return false

func _update_pushing(delta: float) -> void:
    if pushed_body == null or not is_instance_valid(pushed_body):
        pushed_body = null
        return
    if not Input.is_action_pressed("pickup") or camera == null:
        _stop_pushing()
        return
    var global_grab_point := pushed_body.to_global(_push_local_point)
    var hand_distance := camera.global_position.distance_to(global_grab_point)
    if hand_distance > _push_grab_distance + 2.6:
        _stop_pushing()
        return
    var target_grab_point := camera.global_position + (-camera.global_transform.basis.z * _push_grab_distance)
    var mass_ratio := clampf((pushed_body.mass - 12.0) / 78.0, 0.0, 1.0)
    var allowed_lift := lerpf(0.52, 0.08, mass_ratio)
    var desired_body_y := clampf(
        pushed_body.global_position.y + target_grab_point.y - global_grab_point.y,
        _push_start_body_y - 0.10,
        _push_start_body_y + allowed_lift
    )
    target_grab_point.y = global_grab_point.y + desired_body_y - pushed_body.global_position.y
    var grab_error := target_grab_point - global_grab_point
    var target_speed := _push_speed_for_mass(pushed_body.mass)
    var spring_strength := lerpf(4.8, 1.9, mass_ratio)
    var desired_velocity := grab_error * spring_strength
    var drive_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if drive_input.length() > 0.05:
        var drive_direction := (transform.basis * Vector3(drive_input.x, 0.0, drive_input.y)).normalized()
        desired_velocity += drive_direction * target_speed
        var drunk_ratio := intoxication / 100.0
        desired_velocity += camera.global_transform.basis.x * sin(Time.get_ticks_msec() * 0.0047) * drunk_ratio * 0.42
    if desired_velocity.length() > target_speed:
        desired_velocity = desired_velocity.normalized() * target_speed
    var planar_velocity := Vector3(pushed_body.linear_velocity.x, 0.0, pushed_body.linear_velocity.z)
    var desired_planar := Vector3(desired_velocity.x, 0.0, desired_velocity.z)
    var response := lerpf(18.0, 8.0, mass_ratio)
    planar_velocity = planar_velocity.move_toward(desired_planar, response * delta)
    pushed_body.linear_velocity.x = planar_velocity.x
    pushed_body.linear_velocity.z = planar_velocity.z
    var vertical_target := clampf(desired_velocity.y, -0.65, lerpf(1.25, 0.28, mass_ratio))
    pushed_body.linear_velocity.y = move_toward(pushed_body.linear_velocity.y, vertical_target, lerpf(5.0, 1.4, mass_ratio) * delta)
    pushed_body.sleeping = false
    _push_noise_timer -= delta
    if _push_noise_timer <= 0.0 and pushed_body.linear_velocity.length() > 0.08:
        _push_noise_timer = 0.42
        var strength: float = clampf(4.0 + pushed_body.mass * 0.28 + pushed_body.linear_velocity.length() * 3.0, 8.0, 38.0)
        var undampened_strength: float = strength
        if _is_soft_surface_at(pushed_body.global_position):
            strength *= 0.58
        if bool(pushed_body.get_meta("felt_pads", false)):
            strength *= 0.52
        RunStats.record_noise_prevented(undampened_strength - strength)
        NoiseManager.emit_noise(pushed_body.global_position, strength, &"FURNITURE_PUSH", StringName(pushed_body.name.to_snake_case()))
        AudioManager.play_3d(&"clink", pushed_body.global_position, -11.0, randf_range(0.62, 0.82))

func _stop_pushing() -> void:
    if pushed_body != null and is_instance_valid(pushed_body):
        pushed_body.linear_velocity *= 0.55
    pushed_body = null
    _push_noise_timer = 0.0

func _begin_heavy_grab(body: RigidBody3D, hit_position: Vector3) -> void:
    pushed_body = body
    pushed_body.freeze = false
    pushed_body.sleeping = false
    if furniture_pads_equipped:
        pushed_body.set_meta("felt_pads", true)
    _push_local_point = pushed_body.to_local(hit_position)
    _push_grab_distance = clampf(camera.global_position.distance_to(hit_position), 0.75, 2.85)
    _push_start_body_y = pushed_body.global_position.y
    _push_noise_timer = 0.0

func _push_speed_for_mass(body_mass: float) -> float:
    return lerpf(1.60, 0.55, clampf((body_mass - 13.0) / 77.0, 0.0, 1.0))

func _update_held_item(delta: float) -> void:
    if held_item == null or not is_instance_valid(held_item):
        held_item = null
        return
    if camera == null:
        return
    _attach_item_to_hold_rig(held_item)
    if _drink_active:
        _update_drink_animation(delta)
        return
    
    # === Режим розлива (чайник/молоко) ===
    if pour_mode_active and held_item.has_method("get_pour_grip_global_position"):
        # Корпус справа снизу; PourGripPoint совмещается с опорой руки.
        # Keep the kettle low/right so it never covers the mug or impact marker.
        var grip_anchor: Vector3 = camera.global_position + camera.global_transform.basis.x * 0.48 \
            + camera.global_transform.basis.y * 0.08 \
            - camera.global_transform.basis.z * 1.05
        # Небольшая дрожь строится заново от базовой точки каждый кадр и потому
        # не накапливает transform. Удержание ПКМ действительно стабилизирует руку.
        var tremor_scale: float = 0.22 if _pour_stabilize else 1.0
        var tremor_time: float = float(Time.get_ticks_msec()) * 0.001
        grip_anchor += camera.global_transform.basis.x * sin(tremor_time * 13.7) * 0.006 * tremor_scale
        grip_anchor += camera.global_transform.basis.y * cos(tremor_time * 17.3) * 0.004 * tremor_scale
        var live_tilt := pour_controller.tilt_angle if pour_controller != null else 0.0
        var live_kind: Variant = held_item.get("item_id")
        var pour_roll := _pour_roll_degrees(StringName(live_kind), live_tilt)
        var pour_rot := Vector3(
            deg_to_rad(-14.0 + sin(tremor_time * 11.9) * 0.8 * tremor_scale),
            camera.global_rotation.y + deg_to_rad(20.0),
            deg_to_rad(pour_roll + cos(tremor_time * 15.1) * 0.7 * tremor_scale)
        )
        held_item.rotation.x = lerp_angle(held_item.rotation.x, pour_rot.x, minf(1.0, delta * 12.0))
        held_item.rotation.y = lerp_angle(held_item.rotation.y, pour_rot.y, minf(1.0, delta * 12.0))
        held_item.rotation.z = lerp_angle(held_item.rotation.z, pour_rot.z, minf(1.0, delta * 12.0))
        var grip_position: Vector3 = held_item.call("get_pour_grip_global_position")
        var body_target := grip_anchor - (grip_position - held_item.global_position)
        held_item.global_position = held_item.global_position.lerp(body_target, minf(1.0, delta * 15.0))
        return
    
    # === Обычный режим ношения ===
    var held_kind: Variant = held_item.get("item_id")
    var carry_local := Vector3(0.0, -0.20, -0.80)
    var carry_rotation := Vector3.ZERO
    match held_kind:
        &"kettle":
            carry_local = Vector3(0.34, -0.32, -1.08)
            carry_rotation = Vector3(deg_to_rad(-8.0), deg_to_rad(10.0), deg_to_rad(-8.0))
        &"milk_carton":
            carry_local = Vector3(0.34, -0.25, -0.88)
            carry_rotation = Vector3(deg_to_rad(-12.0), deg_to_rad(12.0), deg_to_rad(-10.0))
        &"mug":
            carry_local = Vector3(0.16, -0.31, -0.62)
            carry_rotation = Vector3(deg_to_rad(-5.0), deg_to_rad(8.0), 0.0)
        &"spoon":
            carry_local = Vector3(0.15, -0.26, -0.56)
            carry_rotation = Vector3(deg_to_rad(72.0), 0.0, deg_to_rad(-8.0))
        &"towel":
            carry_local = Vector3(0.40, -0.44, -1.12)
            carry_rotation = Vector3(deg_to_rad(22.0), deg_to_rad(-18.0), deg_to_rad(12.0))
        &"mop":
            carry_local = Vector3(0.38, -0.92, -1.18)
            carry_rotation = Vector3(0.0, 0.0, deg_to_rad(-10.0))
    var target: Vector3 = camera.to_global(carry_local)
    var scrubbing_towel: bool = (
        held_kind == &"mop"
        and spill_cleanup_controller != null
        and spill_cleanup_controller.cleaning
        and spill_cleanup_controller.has_target()
    )
    if scrubbing_towel:
        target = spill_cleanup_controller.get_scrub_world_position()
    var drunk_ratio := intoxication / 100.0
    target += camera.global_transform.basis.x * sin(Time.get_ticks_msec() * 0.0041) * drunk_ratio * 0.075
    target += camera.global_transform.basis.y * cos(Time.get_ticks_msec() * 0.0053) * drunk_ratio * 0.045
    held_item.global_position = held_item.global_position.lerp(target, minf(1.0, delta * 18.0))
    var rotation_target := Vector3(
        camera.global_rotation.x + carry_rotation.x + sin(Time.get_ticks_msec() * 0.0037) * drunk_ratio * 0.10,
        camera.global_rotation.y + carry_rotation.y + cos(Time.get_ticks_msec() * 0.0043) * drunk_ratio * 0.08,
        camera.global_rotation.z + carry_rotation.z + sin(Time.get_ticks_msec() * 0.0051) * drunk_ratio * 0.12
    )
    if scrubbing_towel:
        rotation_target = Vector3(0.0, camera.global_rotation.y + sin(spill_cleanup_controller.scrub_phase) * 0.22, 0.0)
    held_item.rotation.x = lerp_angle(held_item.rotation.x, rotation_target.x, minf(1.0, delta * 13.0))
    held_item.rotation.y = lerp_angle(held_item.rotation.y, rotation_target.y, minf(1.0, delta * 13.0))
    held_item.rotation.z = lerp_angle(held_item.rotation.z, rotation_target.z, minf(1.0, delta * 13.0))

func _pour_roll_degrees(item_kind: StringName, live_tilt: float) -> float:
    # Чайник и банка стоят справа от центра экрана. Положительный
    # крен направляет их носик/горлышко к центру и к кружке.
    if item_kind == &"kettle" or item_kind == &"coffee_jar":
        return 5.0 + live_tilt
    return -5.0 - live_tilt

func _update_interaction_target() -> void:
    if camera == null:
        return
    if _drink_active:
        _interaction_target = null
        prompt_changed.emit("ДЕНИС ПЬЁТ КОФЕ  •  ФИНИШ ПОСЛЕ ГЛОТКА" if _drink_kind == &"coffee" else "ДЕНИС ПЬЁТ ПИВО  •  БУТЫЛКА У РТА")
        return
    if is_hidden:
        _interaction_target = _active_hide_spot
        prompt_changed.emit("РИТА ИЩЕТ ТЕБЯ — СИДИ ТИХО" if RitaSleep.is_angry else "E — ВЫЙТИ ИЗ ГАРДЕРОБНОЙ")
        return
    if held_item != null and is_instance_valid(held_item) and StringName(held_item.get("item_id")) == &"mop":
        _interaction_target = null
        prompt_changed.emit(spill_cleanup_controller.get_prompt() if spill_cleanup_controller != null else "ЛКМ — ПОЛОЖИТЬ ШВАБРУ")
        return
    var hit: Dictionary = _raycast(3.1)
    _interaction_target = null
    var prompt: String = ""
    var rage_escape := RitaSleep.is_angry

    if not hit.is_empty():
        var collider: Object = hit.get("collider")
        var node: Node = collider as Node
        while node != null:
            if node.has_method("interact"):
                if not rage_escape or node.is_in_group("door") or node.is_in_group("hide_spot"):
                    _interaction_target = node
                    if node.is_in_group("television"):
                        # The TV owns its hold-E mute hint; do not append the generic
                        # quiet/fast interaction suffix or duplicate the E key label.
                        prompt = String(node.get_prompt(self))
                    else:
                        prompt = "E — %s" % String(node.get_prompt(self)) if rage_escape else "E — %s | удерживать E — тихо | Shift+E — быстро" % String(node.get_prompt(self))
                break
            if not rage_escape and node is RigidBody3D and node.has_method("on_picked_up"):
                prompt = String(node.get_prompt(self))
                break
            node = node.get_parent()

    if rage_escape and _interaction_target == null:
        prompt = "РИТА В ЯРОСТИ — БЕГИ В СПАЛЬНЮ > ГАРДЕРОБНУЮ > ШКАФ"
    elif held_item != null and _interaction_target == null:
        if _can_drink_held_coffee():
            prompt = "E — ВЫПИТЬ КОФЕ И ЗАВЕРШИТЬ ЗАБЕГ  |  ПКМ — ПОСТАВИТЬ"
        elif held_item.has_method("has_liquid_container") and bool(held_item.call("has_liquid_container")):
            if _held_pourable_near_receiver():
                prompt = "E — НАЛИВАТЬ  |  ПКМ — СТАБИЛИЗИРОВАТЬ  |  ЛКМ — ПОСТАВИТЬ"
            else:
                prompt = "ЛКМ — ПОСТАВИТЬ"
        else:
            prompt = "R — ПОВОРОТ | Shift+R — НАКЛОН | C+R — КРЕН | ЛКМ — ПОСТАВИТЬ"
    elif held_item != null:
        prompt += "  |  R — ПОВОРОТ  |  ЛКМ — ПОСТАВИТЬ"
    elif pushed_body != null and is_instance_valid(pushed_body):
        var mode_text := "ПЕРЕНОСИТЬ" if pushed_body.mass <= 35.0 else "ТАЩИТЬ ПО ПОЛУ"
        var furniture_name := str(pushed_body.get("display_name")) if pushed_body.get("display_name") != null else str(pushed_body.name)
        prompt = "УДЕРЖИВАЙ ЛКМ + WASD — %s %s [%.0f кг]" % [mode_text, furniture_name, pushed_body.mass]
    prompt_changed.emit(prompt)

func _sync_rage_lock() -> void:
    var should_lock := RitaSleep.is_angry and not is_hidden
    if should_lock and not _rage_lock_active:
        _rage_lock_active = true
        if _drink_active:
            _finish_drink_animation(true)
        if held_item != null:
            _drop_held(false)
        if pushed_body != null:
            _stop_pushing()
        message_requested.emit("РИТА ВСТАЛА. БРОСЬ ВСЁ И БЕГИ В ГАРДЕРОБНУЮ")
    elif not RitaSleep.is_angry:
        _rage_lock_active = false

func enter_hide_spot(spot: Node, hide_position: Vector3, exit_position: Vector3, hide_yaw_degrees: float) -> void:
    if is_hidden:
        return
    if _drink_active:
        _finish_drink_animation(true)
    if held_item != null:
        _drop_held(true)
    if pushed_body != null:
        _stop_pushing()
    is_hidden = true
    _active_hide_spot = spot
    _hide_exit_position = exit_position
    global_position = hide_position
    rotation.y = deg_to_rad(hide_yaw_degrees)
    _pitch = 0.0
    if camera != null:
        camera.rotation.x = 0.0
    velocity = Vector3.ZERO
    collision_layer = 0
    collision_mask = 0
    set_view_hands_visible(false)
    RitaSleep.set_player_hidden(true)

func exit_hide_spot() -> void:
    if not is_hidden:
        return
    if RitaSleep.is_angry:
        message_requested.emit("СЛИШКОМ РАНО — РИТА ЕЩЁ ИЩЕТ ТЕБЯ")
        return
    is_hidden = false
    global_position = _hide_exit_position
    velocity = Vector3.ZERO
    collision_layer = 1
    collision_mask = 3
    _active_hide_spot = null
    set_view_hands_visible(true)
    RitaSleep.set_player_hidden(false)
    message_requested.emit("ДЕНИС ВЫШЕЛ ИЗ ГАРДЕРОБНОЙ")

func _update_interaction_hold(delta: float) -> void:
    if not _interact_pending or _interact_fired:
        return
    if not Input.is_action_pressed("interact"):
        _interact_pending = false
        return
    _interact_time += delta
    if _interact_time >= 0.75:
        _fire_interaction(INTERACTION_QUIET)

func _fire_interaction(mode: int) -> void:
    if _interact_fired:
        return
    _interact_fired = true
    _interact_pending = false
    if _interaction_target == null or not is_instance_valid(_interaction_target):
        return
    var result: Variant = await _interaction_target.interact(self, mode)
    if result != null and String(result) != "":
        message_requested.emit(String(result))

func _try_pickup() -> void:
    if held_item != null:
        _place_or_drop()
        return
    var hit: Dictionary = _raycast(3.0)
    if hit.is_empty():
        return
    var node: Node = hit.get("collider") as Node
    while node != null:
        if node is RigidBody3D and node.has_method("on_picked_up"):
            var body := node as RigidBody3D
            var item_mass := maxf(body.mass, 0.1)
            if item_mass > 12.0:
                var hit_position: Vector3 = hit.get("position", body.global_position)
                _begin_heavy_grab(body, hit_position)
                var mode_text := "ДВУХРУЧНЫЙ ПЕРЕНОС" if item_mass <= 35.0 else "ТЯЖЁЛОЕ ВОЛОЧЕНИЕ"
                message_requested.emit("%s: ДЕРЖИ ЛКМ И ДВИГАЙСЯ WASD — %s [%.0f кг]" % [mode_text, String(body.get("display_name")), item_mass])
                return
            held_item = body
            held_item.call("on_picked_up")
            _held_rotation_offset = held_item.global_rotation - Vector3(0.0, camera.global_rotation.y, 0.0)
            var lift_noise := clampf(item_mass * 0.75, 0.0, 10.0)
            if lift_noise > 1.0:
                NoiseManager.emit_noise(held_item.global_position, lift_noise, &"OBJECT_LIFT", StringName(held_item.name.to_snake_case()))
            message_requested.emit("ВЗЯТО: %s [%.1f кг]" % [String(held_item.get("display_name")), item_mass])
            return
        node = node.get_parent()

func _place_or_drop() -> void:
    if held_item == null or camera == null:
        return
    var drunk_fumble := randf() < _drunk_fumble_chance()
    if drunk_fumble:
        _drop_held(false, true)
        return
    var hit: Dictionary = _raycast(3.2)
    if hit.is_empty():
        _drop_held(false)
        return
    var fallback_point: Vector3 = camera.global_position + -camera.global_transform.basis.z * 1.4
    var point: Vector3 = hit.get("position", fallback_point)
    var normal: Vector3 = hit.get("normal", Vector3.UP)
    var drunk_inaccuracy := intoxication / 100.0 * 0.24
    point += camera.global_transform.basis.x * randf_range(-drunk_inaccuracy, drunk_inaccuracy)
    point += -camera.global_transform.basis.z * randf_range(-drunk_inaccuracy * 0.45, drunk_inaccuracy * 0.45)
    if StringName(held_item.get("item_id")) == &"mug":
        if normal.normalized().dot(Vector3.UP) < 0.82:
            message_requested.emit("КРУЖКЕ НУЖНА РОВНАЯ ГОРИЗОНТАЛЬНАЯ ПОВЕРХНОСТЬ")
            return
        var proposed_position := point + Vector3.UP * 0.145
        var proposed_basis := Basis(Vector3.UP, camera.global_rotation.y)
        var shape_owners := held_item.get_shape_owners()
        if not shape_owners.is_empty():
            var shape_owner: int = shape_owners[0]
            if held_item.shape_owner_get_shape_count(shape_owner) > 0:
                var shape := held_item.shape_owner_get_shape(shape_owner, 0)
                var shape_query := PhysicsShapeQueryParameters3D.new()
                shape_query.shape = shape
                shape_query.transform = Transform3D(proposed_basis, proposed_position + Vector3.UP * 0.018)
                shape_query.collision_mask = 3
                shape_query.exclude = [get_rid(), held_item.get_rid()]
                if not get_world_3d().direct_space_state.intersect_shape(shape_query, 4).is_empty():
                    message_requested.emit("ЗДЕСЬ НЕТ СВОБОДНОГО МЕСТА ДЛЯ КРУЖКИ")
                    return
        held_item.global_transform = Transform3D(proposed_basis, proposed_position)
    else:
        held_item.global_position = point + normal * 0.16
    _drop_held(true)

func _drop_held(gentle: bool, drunk_fumble := false) -> void:
    if held_item == null:
        return
    var item: RigidBody3D = held_item
    held_item = null
    _held_rotation_offset = Vector3.ZERO
    _detach_item_from_hold_rig(item)
    item.call("on_released")
    if not gentle and camera != null:
        var throw_strength := _drunk_throw_strength() if drunk_fumble else 2.0
        var throw_direction := -camera.global_transform.basis.z
        if drunk_fumble:
            throw_direction = (
                throw_direction
                + camera.global_transform.basis.x * randf_range(-0.55, 0.55)
                + Vector3.UP * randf_range(-0.22, 0.35)
            ).normalized()
            if item.has_method("arm_forced_impact_noise"):
                item.call("arm_forced_impact_noise", lerpf(8.0, 30.0, _drunk_severity()))
            message_requested.emit("РУКИ НЕ СЛУШАЮТСЯ — ПРЕДМЕТ ВЫЛЕТЕЛ!")
        item.linear_velocity = throw_direction * throw_strength
        var spin := lerpf(2.5, 11.0, _drunk_severity()) if drunk_fumble else 2.5
        item.angular_velocity = Vector3(
            randf_range(-spin, spin),
            randf_range(-spin * 0.7, spin * 0.7),
            randf_range(-spin, spin)
        )
        # Эффект тряски камеры при бросании
        VisualEffects.spawn_impact_shake(lerpf(0.15, 0.38, _drunk_severity()) if drunk_fumble else 0.15)

func _raycast(distance: float) -> Dictionary:
    if camera == null:
        return {}
    var ray_from: Vector3 = camera.global_position
    var ray_to: Vector3 = ray_from + (-camera.global_transform.basis.z * distance)
    var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
    var exclusions: Array[RID] = [get_rid()]
    if held_item != null:
        exclusions.append(held_item.get_rid())
    query.exclude = exclusions
    query.collision_mask = 3
    query.collide_with_areas = true
    query.collide_with_bodies = true
    return get_world_3d().direct_space_state.intersect_ray(query)

# === Режим розлива ===

## Можно ли войти в режим розлива?
func _can_enter_pour_mode() -> bool:
    if held_item == null:
        return false
    var has_liquid: bool = (
        held_item.has_method("has_liquid_container")
        and held_item.call("has_liquid_container")
        and held_item.call("has_pourable_liquid")
    )
    var has_powder: bool = (
        held_item.has_method("has_powder_emitter")
        and held_item.call("has_powder_emitter")
        and held_item.call("has_pourable_powder")
    )
    return has_liquid or has_powder

func _held_pourable_near_receiver() -> bool:
    if held_item == null or not is_instance_valid(held_item):
        return false
    var source_position := held_item.global_position
    if held_item.has_method("get_pour_origin_global_position"):
        source_position = held_item.call("get_pour_origin_global_position")
    for receiver in get_tree().get_nodes_in_group("liquid_receiver"):
        if receiver is Node3D and source_position.distance_to((receiver as Node3D).global_position) <= 1.35:
            return true
    return false

## Войти в режим розлива (удержание E с чайником/молоком).
func _enter_pour_mode() -> void:
    if pour_mode_active:
        return
    if held_item == null:
        return
    
    # Создаём PourController как child игрока
    pour_controller = PourController.new()
    add_child(pour_controller)
    if not pour_controller.start_pouring(held_item):
        pour_controller = null
        return
    pour_controller.target_tilt = pour_controller.MAX_TILT
    
    pour_mode_active = true
    held_item.call("enter_pour_mode")
    pour_session_started.emit(pour_controller, held_item)
    message_requested.emit(
        "E — НАСЫПАТЬ | ПКМ — СТАБИЛИЗИРОВАТЬ | МЫШЬ — НАПРАВЛЯТЬ БАНКУ"
        if pour_controller.powder_mode
        else "E — НАЛИВАТЬ | ПКМ — СТАБИЛИЗИРОВАТЬ | МЫШЬ — НАПРАВЛЯТЬ НОСИК"
    )

## Выйти из режима розлива.
func _exit_pour_mode() -> void:
    if not pour_mode_active:
        return
    
    if pour_controller != null and is_instance_valid(pour_controller):
        var finishing_source := pour_controller.source_volume
        var finishing_liquid_id := pour_controller.liquid_def.id if pour_controller.liquid_def != null else ""
        pour_controller.target_tilt = 0.0
        pour_controller.stop_pouring()
        # Сохраняем статистику
        if pour_controller.hit_ml > 0 or pour_controller.spilled_ml > 0:
            var liquid_id := "coffee_powder" if pour_controller.powder_mode else "water"
            if held_item != null and is_instance_valid(held_item) and held_item.has_method("get_container_volume"):
                var cv = held_item.call("get_container_volume")
                if cv != null and cv.liquid != null:
                    liquid_id = cv.liquid.id
            RunStats.record_pour_stats(pour_controller.hit_ml, pour_controller.spilled_ml, liquid_id)
        if finishing_liquid_id == "water" and finishing_source != null and finishing_source.is_empty():
            var mug := get_tree().get_first_node_in_group("mug")
            var mug_contents := mug.get_node_or_null("MugContentController") as MugContentController if mug != null else null
            if mug_contents != null and mug_contents.water_ml < MugContentController.WATER_MIN_ML:
                QuestManager.notify_water_insufficient()
        pour_controller.queue_free()
    
    pour_controller = null
    pour_mode_active = false
    _pour_stabilize = false
    pour_session_stopped.emit()
    
    if held_item != null and is_instance_valid(held_item) and held_item.has_method("exit_pour_mode"):
        held_item.call("exit_pour_mode")
