class_name PouringHUD
extends Control

const BLUE := Color("76b7d7")
const GREEN := Color("72d49b")
const AMBER := Color("edbd68")
const CORAL := Color("ef8066")
const CREAM := Color("f2eee6")
const MUTED := Color("9aa8b2")

var player: CharacterBody3D
var mug_contents: MugContentController
var controller: PourController
var source_volume: ContainerVolume
var powder_source: CoffeePowderEmitter

var panel: Panel
var title_label: Label
var source_label: Label
var source_value_label: Label
var source_bar: ProgressBar
var mug_label: Label
var mug_value_label: Label
var mug_bar: ProgressBar
var minimum_marker: ColorRect
var recommended_marker: ColorRect
var feedback_label: Label
var thresholds_label: Label
var controls_label: Label

var _latest_source_ml := 0.0
var _latest_mug_state: Dictionary = {}
var _shown_source_ml := 0.0
var _shown_mug_ml := 0.0
var _hide_left := 0.0
var _bound_held_item: RigidBody3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	panel.visible = false

func bind(value_player: CharacterBody3D, value_mug_contents: MugContentController) -> void:
	player = value_player
	mug_contents = value_mug_contents
	if player != null:
		if not player.pour_session_started.is_connected(_on_pour_started):
			player.pour_session_started.connect(_on_pour_started)
		if not player.pour_session_stopped.is_connected(_on_pour_stopped):
			player.pour_session_stopped.connect(_on_pour_stopped)
		var existing_controller := player.get("pour_controller") as PourController
		var existing_item := player.get("held_item") as RigidBody3D
		if existing_controller != null and existing_item != null:
			_on_pour_started(existing_controller, existing_item)
	if mug_contents != null:
		_latest_mug_state = mug_contents.get_components()
		if not mug_contents.mug_contents_changed.is_connected(_on_mug_contents_changed):
			mug_contents.mug_contents_changed.connect(_on_mug_contents_changed)

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		panel.visible = false
		return
	var held := player.get("held_item") as RigidBody3D
	if held != _bound_held_item:
		_bound_held_item = held
		if controller == null:
			_bind_source_from_item(held)
	var pouring := controller != null and is_instance_valid(controller) and bool(controller.get("_pouring"))
	var source_held := false
	if held != null and is_instance_valid(held):
		var pourable_source := (
			held.has_method("has_liquid_container") and bool(held.call("has_liquid_container"))
		) or (
			held.has_method("has_powder_emitter") and bool(held.call("has_powder_emitter"))
		)
		source_held = pourable_source
	if pouring or source_held:
		_hide_left = 0.58
	elif _hide_left > 0.0:
		_hide_left -= delta
	panel.visible = pouring or source_held or _hide_left > 0.0
	if not panel.visible or (source_volume == null and powder_source == null) or mug_contents == null:
		return
	_latest_source_ml = powder_source.remaining_g if powder_source != null else source_volume.current_ml
	_latest_mug_state = mug_contents.get_components()
	_shown_source_ml = lerpf(_shown_source_ml, _latest_source_ml, clampf(delta / 0.15, 0.0, 1.0))
	var total_ml := float(_latest_mug_state.get("total_liquid_ml", 0.0))
	_shown_mug_ml = lerpf(_shown_mug_ml, total_ml, clampf(delta / 0.15, 0.0, 1.0))
	_update_display(pouring)

func _on_pour_started(value_controller: PourController, item: RigidBody3D) -> void:
	controller = value_controller
	_bind_source_from_item(item)
	_hide_left = 0.58

func _on_pour_stopped() -> void:
	controller = null
	_hide_left = 0.58

func _bind_source_from_item(item: RigidBody3D) -> void:
	var next_volume: ContainerVolume = null
	var next_powder: CoffeePowderEmitter = null
	if item != null and is_instance_valid(item):
		if item.has_method("get_container_volume"):
			next_volume = item.call("get_container_volume") as ContainerVolume
		else:
			next_volume = item.get_node_or_null("ContainerVolume") as ContainerVolume
		if item.has_method("get_powder_emitter"):
			next_powder = item.call("get_powder_emitter") as CoffeePowderEmitter
		else:
			next_powder = item.get_node_or_null("CoffeePowderEmitter") as CoffeePowderEmitter
	if source_volume == next_volume and powder_source == next_powder:
		return
	if source_volume != null and source_volume.container_volume_changed.is_connected(_on_source_volume_changed):
		source_volume.container_volume_changed.disconnect(_on_source_volume_changed)
	source_volume = next_volume
	powder_source = next_powder
	if source_volume != null:
		_latest_source_ml = source_volume.current_ml
		_shown_source_ml = _latest_source_ml
		if not source_volume.container_volume_changed.is_connected(_on_source_volume_changed):
			source_volume.container_volume_changed.connect(_on_source_volume_changed)
	if powder_source != null:
		_latest_source_ml = powder_source.remaining_g
		_shown_source_ml = _latest_source_ml
		if not powder_source.powder_changed.is_connected(_on_source_volume_changed):
			powder_source.powder_changed.connect(_on_source_volume_changed)

func _on_source_volume_changed(current_ml: float, _delta_ml: float) -> void:
	_latest_source_ml = current_ml

func _on_mug_contents_changed(components: Dictionary) -> void:
	_latest_mug_state = components.duplicate(true)

func _update_display(pouring: bool) -> void:
	if powder_source != null:
		title_label.text = "КОФЕ"
		controls_label.text = "УДЕРЖИВАЙ E — СЫПАТЬ    ПКМ — СТАБИЛИЗИРОВАТЬ    ЛКМ — ПОСТАВИТЬ"
		source_label.text = "Банка"
		source_bar.max_value = maxf(powder_source.capacity_g, 1.0)
		source_bar.value = _shown_source_ml
		source_value_label.text = "%.1f / %.0f г" % [_latest_source_ml, powder_source.capacity_g]
		var powder_g := float(_latest_mug_state.get("coffee_powder_g", 0.0))
		var capacity := 10.0
		mug_bar.max_value = capacity
		mug_bar.value = powder_g
		mug_label.text = "Кружка"
		mug_value_label.text = "кофе %.1f / 5 г" % powder_g
		thresholds_label.text = "минимум 2 г  •  рекомендуется 3–5 г  •  максимум 10 г"
		_place_markers(0.2, 0.4)
		_set_mug_fill_color(_threshold_color(powder_g, 2.0, 5.0, powder_g, capacity))
		_update_feedback(pouring)
		return
	controls_label.text = "УДЕРЖИВАЙ E — НАЛИВАТЬ    ПКМ — СТАБИЛИЗИРОВАТЬ    ЛКМ — ПОСТАВИТЬ"
	var liquid_id := source_volume.liquid.id if source_volume.liquid != null else _source_liquid_from_item()
	var is_milk := liquid_id == "milk"
	var source_capacity := _source_display_capacity()
	title_label.text = "МОЛОКО" if is_milk else "ВОДА"
	source_label.text = "Упаковка" if is_milk else "Чайник"
	source_bar.max_value = source_capacity
	source_bar.value = _shown_source_ml
	source_value_label.text = "%d / %d мл" % [roundi(_latest_source_ml), roundi(source_capacity)]
	var total_ml := float(_latest_mug_state.get("total_liquid_ml", 0.0))
	var water_ml := float(_latest_mug_state.get("water_ml", 0.0))
	var milk_ml := float(_latest_mug_state.get("milk_ml", 0.0))
	var capacity := float(_latest_mug_state.get("capacity_ml", 350.0))
	mug_bar.max_value = maxf(capacity, 1.0)
	mug_bar.value = _shown_mug_ml
	mug_label.text = "Кружка"
	if is_milk:
		mug_value_label.text = "молоко %d / 60 мл  •  всего %d / %d мл" % [roundi(milk_ml), roundi(total_ml), roundi(capacity)]
		thresholds_label.text = "минимум 25 мл  •  рекомендуется 40–60 мл  •  кружка %d мл" % roundi(capacity)
		_place_markers((water_ml + 25.0) / capacity, (water_ml + 50.0) / capacity)
		_set_mug_fill_color(_threshold_color(milk_ml, 25.0, 60.0, total_ml, capacity))
	else:
		mug_value_label.text = "вода %d / 210 мл  •  всего %d / %d мл" % [roundi(water_ml), roundi(total_ml), roundi(capacity)]
		thresholds_label.text = "минимум 170 мл  •  рекомендуется 210 мл  •  кружка %d мл" % roundi(capacity)
		_place_markers(170.0 / capacity, 210.0 / capacity)
		_set_mug_fill_color(_threshold_color(water_ml, 170.0, 210.0, total_ml, capacity))
	_update_feedback(pouring)

func _source_display_capacity() -> float:
	if _bound_held_item != null and is_instance_valid(_bound_held_item) and _bound_held_item.is_in_group("kettle"):
		return 300.0
	var source_owner := source_volume.get_parent()
	while source_owner != null:
		if source_owner.is_in_group("kettle"):
			return 300.0
		source_owner = source_owner.get_parent()
	return maxf(source_volume.capacity_ml, 1.0)

func _update_feedback(pouring: bool) -> void:
	if not pouring or controller == null:
		feedback_label.text = "E — НАЧАТЬ СЫПАТЬ" if powder_source != null else "E — НАЧАТЬ НАЛИВ"
		feedback_label.modulate = BLUE
		return
	var state := controller.last_feedback_state
	var flow := controller.current_flow_rate_ml_s
	match state:
		"in_mug":
			feedback_label.text = (
				"✓ В КРУЖКУ  •  +%.1f г/с" % flow
				if controller.powder_mode
				else "✓ В КРУЖКУ  •  +%.0f мл/с" % flow
			)
			feedback_label.modulate = GREEN
		"mug_wall":
			feedback_label.text = "✕ ПО КРУЖКЕ  •  МИМО %.1f г" % controller.spilled_ml if controller.powder_mode else "✕ ПО КРУЖКЕ  •  ПРОЛИТО %.0f мл" % controller.spilled_ml
			feedback_label.modulate = AMBER
		"overflow":
			feedback_label.text = "ЛИШНИЙ КОФЕ  •  МИМО %.1f г" % controller.spilled_ml if controller.powder_mode else "ПЕРЕПОЛНЕНИЕ  •  ПРОЛИТО %.0f мл" % controller.spilled_ml
			feedback_label.modulate = CORAL
		"miss":
			feedback_label.text = "✕ МИМО  •  РАССЫПАНО %.1f г" % controller.spilled_ml if controller.powder_mode else "✕ МИМО  •  ПРОЛИТО %.0f мл" % controller.spilled_ml
			feedback_label.modulate = CORAL
		_:
			if controller.prediction_state == "green":
				feedback_label.text = "ТОЧКА В КРУЖКЕ • ЛЕЙ"
				feedback_label.modulate = GREEN
			elif controller.prediction_state == "orange":
				feedback_label.text = "КРАЙ КРУЖКИ • ПОДПРАВЬ"
				feedback_label.modulate = AMBER
			else:
				feedback_label.text = "НАПРАВЬ НОСИК НА КРУЖКУ"
				feedback_label.modulate = MUTED

func _source_liquid_from_item() -> String:
	if _bound_held_item != null and StringName(_bound_held_item.get("item_id")) == &"milk_carton":
		return "milk"
	return "water"

func _threshold_color(active_ml: float, minimum: float, recommended: float, total_ml: float, capacity: float) -> Color:
	if total_ml >= capacity * 0.92:
		return CORAL
	if active_ml < minimum:
		return BLUE
	if active_ml <= recommended:
		return GREEN
	return AMBER

func _place_markers(minimum_fraction: float, recommended_fraction: float) -> void:
	var bar_x := mug_bar.position.x
	var bar_y := mug_bar.position.y
	var bar_width := mug_bar.size.x
	minimum_marker.position = Vector2(bar_x + bar_width * clampf(minimum_fraction, 0.0, 1.0) - 1.0, bar_y - 2.0)
	recommended_marker.position = Vector2(bar_x + bar_width * clampf(recommended_fraction, 0.0, 1.0) - 1.0, bar_y - 2.0)

func _set_mug_fill_color(color: Color) -> void:
	var fill := mug_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = color

func _build_ui() -> void:
	panel = Panel.new()
	panel.name = "PouringPanel"
	panel.position = Vector2(24, 400)
	panel.size = Vector2(540, 184)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.055, 0.90)
	panel_style.border_color = Color(0.55, 0.72, 0.82, 0.34)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0, 0, 0, 0.42)
	panel_style.shadow_size = 7
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	title_label = _label(panel, Vector2(14, 8), Vector2(150, 22), 17, CREAM)
	feedback_label = _label(panel, Vector2(170, 8), Vector2(356, 22), 15, BLUE)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source_label = _label(panel, Vector2(14, 38), Vector2(100, 18), 12, MUTED)
	source_value_label = _label(panel, Vector2(310, 38), Vector2(216, 18), 12, CREAM)
	source_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source_bar = _bar(panel, Vector2(14, 58), Vector2(512, 12), BLUE)
	mug_label = _label(panel, Vector2(14, 82), Vector2(100, 18), 12, MUTED)
	mug_value_label = _label(panel, Vector2(140, 82), Vector2(386, 18), 12, CREAM)
	mug_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mug_bar = _bar(panel, Vector2(14, 102), Vector2(512, 14), BLUE)
	minimum_marker = _marker(panel, Color.WHITE)
	recommended_marker = _marker(panel, AMBER)
	thresholds_label = _label(panel, Vector2(14, 122), Vector2(512, 18), 11, MUTED)
	thresholds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label = _label(panel, Vector2(14, 150), Vector2(512, 22), 12, CREAM)
	controls_label.text = "E — НАЛИВАТЬ    ПКМ — СТАБИЛИЗИРОВАТЬ    ЛКМ — ПОСТАВИТЬ"
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _label(parent: Node, pos: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _bar(parent: Node, pos: Vector2, size_value: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = size_value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.10)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _marker(parent: Node, color: Color) -> ColorRect:
	var marker := ColorRect.new()
	marker.size = Vector2(2, 18)
	marker.color = color
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(marker)
	return marker
