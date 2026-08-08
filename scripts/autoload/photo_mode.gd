extends Node

signal photo_mode_entered()
signal photo_mode_exited()
signal screenshot_taken(file_path: String)

var active: bool = false
var _camera_pivot: Node3D
var _free_camera: Camera3D
var _original_camera: Camera3D
var _ui_root: CanvasLayer
var _ui_hidden: bool = false
var _time_scale_before: float = 1.0
var _screenshot_path: String = "user://screenshots/"
var _screenshot_count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_screenshot_path)

## Установить камеру для фоторежима (вызывается из game.gd)
func set_camera(camera: Camera3D) -> void:
	_original_camera = camera

## Установить корневой UI для скрытия/показа
func set_ui_root(ui_root: CanvasLayer) -> void:
	_ui_root = ui_root

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("photo_mode_exit"):
		exit_photo_mode()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	if _free_camera == null:
		return
	var move_speed := 5.0
	if Input.is_action_pressed("photo_mode_speed_up"):
		move_speed = 15.0
	elif Input.is_action_pressed("photo_mode_speed_down"):
		move_speed = 1.0
	var move_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		move_dir -= _free_camera.global_transform.basis.z
	if Input.is_action_pressed("move_back"):
		move_dir += _free_camera.global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		move_dir -= _free_camera.global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		move_dir += _free_camera.global_transform.basis.x
	if Input.is_action_pressed("photo_mode_up"):
		move_dir += Vector3.UP
	if Input.is_action_pressed("photo_mode_down"):
		move_dir -= Vector3.UP
	_free_camera.global_position += move_dir.normalized() * move_speed * delta

func enter_photo_mode() -> void:
	if active:
		return
	active = true
	_time_scale_before = Engine.time_scale
	Engine.time_scale = 0.0
	_original_camera = get_viewport().get_camera_3d()
	if _original_camera == null:
		return
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "PhotoModePivot"
	_camera_pivot.position = _original_camera.global_position
	get_tree().root.add_child(_camera_pivot)
	_free_camera = Camera3D.new()
	_free_camera.name = "PhotoModeCamera"
	_free_camera.current = true
	_free_camera.position = Vector3.ZERO
	_free_camera.rotation = _original_camera.global_rotation
	_camera_pivot.add_child(_free_camera)
	_original_camera.current = false
	_hide_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	photo_mode_entered.emit()

func exit_photo_mode() -> void:
	if not active:
		return
	active = false
	Engine.time_scale = _time_scale_before
	if _original_camera != null:
		_original_camera.current = true
	_free_camera.queue_free()
	_camera_pivot.queue_free()
	_show_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	photo_mode_exited.emit()

func take_screenshot() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var image := viewport.get_texture().get_image()
	_screenshot_count += 1
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "denis_screenshot_%04d_%s.png" % [_screenshot_count, timestamp]
	var full_path := _screenshot_path + filename
	var result := image.save_png(full_path)
	if result == OK:
		screenshot_taken.emit(full_path)

func _hide_ui() -> void:
	var hud := get_tree().get_first_node_in_group("hud") as CanvasLayer
	if hud != null:
		hud.visible = false
		_ui_hidden = true

func _show_ui() -> void:
	if not _ui_hidden:
		return
	var hud := get_tree().get_first_node_in_group("hud") as CanvasLayer
	if hud != null:
		hud.visible = true
		_ui_hidden = false
