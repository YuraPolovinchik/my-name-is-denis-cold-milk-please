class_name CatBalanceRunner
extends Node

const WATER_DEF := preload("res://resources/liquids/water.tres")
const MILK_DEF := preload("res://resources/liquids/milk.tres")

var game: Node
var objects: Dictionary
var player: Node
var cat: RitaCat
var mode := "A"
var wall_start_msec := 0
var last_frame_msec := 0
var max_frame_ms := 0.0
var fps_sum := 0.0
var fps_samples := 0
var route_stages: Array[Dictionary] = []
var wake_start := 0.0
var high_chaos_started_count := 0
var phone_active_since := -1.0
var question_active_since := -1.0
var vacuum_active_since := -1.0
var washer_active_since := -1.0
var finished := false
var wake_trace: Array[Dictionary] = []
var next_trace_time := 0.0
var save_checks: Array[Dictionary] = []

func setup(game_root: Node, world_objects: Dictionary, run_mode: String) -> void:
	game = game_root
	objects = world_objects
	player = objects.get("player") as Node
	cat = objects.get("rita_cat") as RitaCat
	# The graphical QA run drives the route itself; ignore incidental keyboard or
	# mouse input reaching the focused game window while evidence is collected.
	if player != null:
		player.set_physics_process(false)
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		player.set("velocity", Vector3.ZERO)
	mode = run_mode.to_upper()
	if mode == "BASE":
		cat.set_physics_process(false)
		cat.set_process(false)
		cat.story_director.set_process(false)
	wall_start_msec = Time.get_ticks_msec()
	last_frame_msec = wall_start_msec
	wake_start = RitaSleep.wake_level
	Engine.time_scale = 12.0
	call_deferred("_begin")

func _begin() -> void:
	if mode == "B":
		for index in range(3):
			cat.perform_interaction(player, 0)
		var toy := objects.get("cat_toy") as Node
		player.set("held_item", toy)
		cat.perform_interaction(player, 0)
		var food := objects.get("cat_food") as Node
		player.set("held_item", food)
		cat.perform_interaction(player, 0)
		player.set("held_item", null)
		route_stages.append({"time": RunStats.elapsed_time, "stage": "relationship_setup"})
	if mode == "C":
		_start_high_chaos()
		high_chaos_started_count = cat.story_director.telemetry_snapshot().get("started", []).size()
	route_stages.append({"time": RunStats.elapsed_time, "stage": "run_started"})

func _process(_delta: float) -> void:
	if finished or cat == null:
		return
	_sample_performance()
	var elapsed: float = float(RunStats.elapsed_time)
	if elapsed >= next_trace_time:
		next_trace_time += 5.0
		wake_trace.append({
			"time": elapsed,
			"wake": RitaSleep.wake_level,
			"chaos": cat.story_director.chaos.chaos_budget,
			"reasons": cat.story_director.chaos.reasons.duplicate(),
			"last_noise": NoiseManager.last_noise.duplicate(true),
			"last_source": String(RitaSleep.last_noise_source),
			"last_category": String(RitaSleep.last_noise_category),
		})
	_progress_route(elapsed)
	_manage_live_events(elapsed)
	_check_save_load(elapsed)
	if mode == "B" and cat.story_director.active_story != null and cat.story_director.active_story.phase == CatStory.Phase.TELEGRAPH:
		cat.perform_interaction(player, 0)
	if mode == "C" and elapsed >= 120.0 and not has_meta("chaos_cleared"):
		set_meta("chaos_cleared", true)
		_stop_high_chaos()
		route_stages.append({"time": elapsed, "stage": "high_chaos_cleared"})
	if mode == "C" and has_meta("chaos_cleared") and elapsed >= 128.0 and RitaSleep.player_hidden:
		RitaSleep.set_player_hidden(false)
		route_stages.append({"time": elapsed, "stage": "rita_calmed_after_hiding"})
	if mode == "C" and elapsed >= 132.0 and RitaDemands.has_active_demand() and not has_meta("rita_demand_completed"):
		set_meta("rita_demand_completed", true)
		if RitaDemands.active_type == &"festival_cinema":
			RitaDemands.begin_festival_movie()
			RitaDemands.set_festival_progress(100.0)
		RitaDemands.try_complete_at(RitaDemands.get_location())
		route_stages.append({"time": elapsed, "stage": "rita_demand_completed"})
	if elapsed >= 390.0:
		_finish_route_and_report()

func _progress_route(elapsed: float) -> void:
	if elapsed >= 8.0 and not has_meta("mug_found"):
		set_meta("mug_found", true)
		QuestManager.register_mug()
		QuestManager.register_coffee()
		route_stages.append({"time": elapsed, "stage": "mug_and_coffee"})
	if elapsed >= 24.0 and not has_meta("kettle_started"):
		set_meta("kettle_started", true)
		QuestManager.fill_kettle()
		QuestManager.start_kettle()
		route_stages.append({"time": elapsed, "stage": "kettle_started"})
	if elapsed >= 42.0 and not has_meta("water_boiled"):
		set_meta("water_boiled", true)
		QuestManager.finish_boiling()
		route_stages.append({"time": elapsed, "stage": "water_boiled"})
	if elapsed >= 52.0 and not has_meta("milk_ordered"):
		set_meta("milk_ordered", true)
		MilkDelivery.order_milk()
		route_stages.append({"time": elapsed, "stage": "milk_ordered"})
	if bool(MilkDelivery.get_state().get("at_door", false)) and not QuestManager.has_milk:
		MilkDelivery.collect_milk()
		var carton := objects.get("milk_carton") as Node
		if carton != null:
			carton.call("on_picked_up")
			carton.call("on_released")
		route_stages.append({"time": elapsed, "stage": "milk_collected"})
	if elapsed >= 82.0 and QuestManager.has_milk and not has_meta("mug_filled"):
		set_meta("mug_filled", true)
		var mug := objects.get("mug") as Node
		var content := mug.get_node("MugContentController") as MugContentController
		content.add_powder(3.5)
		content.add_liquid(205.0, WATER_DEF, 95.0)
		content.add_liquid(45.0, MILK_DEF, 8.0)
		route_stages.append({"time": elapsed, "stage": "physical_mug_filled"})
	if elapsed >= 90.0:
		var mug := objects.get("mug") as Node
		var content := mug.get_node("MugContentController") as MugContentController
		if content.total_liquid_ml() > 0.0 and not content.is_stirred:
			content.set_stirred()
			if not has_meta("mug_stirred"):
				set_meta("mug_stirred", true)
				route_stages.append({"time": elapsed, "stage": "mug_stirred"})
	if elapsed >= 205.0 and not has_meta("vacuum_started"):
		set_meta("vacuum_started", true)
		var vacuum := objects.get("vacuum") as Node
		if vacuum != null and not bool(vacuum.get("active")):
			vacuum.call("perform_interaction", player, 0)
		route_stages.append({"time": elapsed, "stage": "vacuum_used"})
	if elapsed >= 245.0 and not has_meta("altar_checked"):
		set_meta("altar_checked", true)
		var room := objects.get("payment_altar_room") as Node
		if room != null and cat.story_director.deck.is_available(&"PAYMENT_ALTAR_STORY"):
			var secret_door := room.get("secret_door") as Node
			secret_door.call("perform_interaction", player, 0)
			route_stages.append({"time": elapsed, "stage": "payment_room_discovered"})

func _manage_live_events(elapsed: float) -> void:
	var respond_normally := mode != "C" or has_meta("chaos_cleared")
	if CallManager.question_active:
		if question_active_since < 0.0:
			question_active_since = elapsed
		if respond_normally and elapsed - question_active_since >= 0.2:
			CallManager.answer_question()
			question_active_since = -1.0
	else:
		question_active_since = -1.0
	var phone := objects.get("phone") as Node
	if phone != null and bool(phone.get("active")):
		if phone_active_since < 0.0:
			phone_active_since = elapsed
		var phone_wait := 7.0 if cat.story_director.deck.is_available(&"PHONE_STORY") else 0.35
		if respond_normally and elapsed - phone_active_since >= phone_wait:
			phone.call("on_picked_up")
			phone_active_since = -1.0
	else:
		phone_active_since = -1.0
	var vacuum := objects.get("vacuum") as Node
	if vacuum != null and bool(vacuum.get("active")):
		if vacuum_active_since < 0.0:
			vacuum_active_since = elapsed
		var vacuum_wait := 7.0 if cat.story_director.deck.is_available(&"VACUUM_STORY") else 0.35
		if respond_normally and elapsed - vacuum_active_since >= vacuum_wait:
			vacuum.call("perform_interaction", player, 0)
			vacuum_active_since = -1.0
	else:
		vacuum_active_since = -1.0
	var washer := objects.get("washing_machine") as Node
	if washer != null and bool(washer.get("active")):
		if washer_active_since < 0.0:
			washer_active_since = elapsed
		if respond_normally and elapsed - washer_active_since >= 0.25:
			washer.call("calm_machine")
			washer_active_since = -1.0
	else:
		washer_active_since = -1.0

func _start_high_chaos() -> void:
	var phone := objects.get("phone") as Node
	phone.call("activate_phone")
	CallManager.time_to_question = 0.0
	var vacuum := objects.get("vacuum") as Node
	if not bool(vacuum.get("active")):
		vacuum.call("perform_interaction", player, 0)
	var washer := objects.get("washing_machine") as Node
	washer.call("start_spin_cycle")
	QuestManager.set_spill_cleanup_required(true, {"coverage": 1.0})
	RitaSleep.wake_level = 76.0
	RitaSleep.wake_changed.emit(RitaSleep.wake_level, RitaSleep.get_state_text())

func _stop_high_chaos() -> void:
	var phone := objects.get("phone") as Node
	if bool(phone.get("active")):
		phone.call("on_picked_up")
	if CallManager.question_active:
		CallManager.answer_question()
	var vacuum := objects.get("vacuum") as Node
	if bool(vacuum.get("active")):
		vacuum.call("perform_interaction", player, 0)
	var washer := objects.get("washing_machine") as Node
	if bool(washer.get("active")):
		washer.call("calm_machine")
	QuestManager.set_spill_cleanup_required(false)
	if RitaSleep.is_angry:
		RitaSleep.set_player_hidden(true)
	else:
		RitaSleep.wake_level = minf(RitaSleep.wake_level, 28.0)
		RitaSleep.wake_changed.emit(RitaSleep.wake_level, RitaSleep.get_state_text())

func _sample_performance() -> void:
	var now := Time.get_ticks_msec()
	max_frame_ms = maxf(max_frame_ms, float(now - last_frame_msec))
	last_frame_msec = now
	var fps := float(Engine.get_frames_per_second())
	if fps > 0.0:
		fps_sum += fps
		fps_samples += 1

func _check_save_load(elapsed: float) -> void:
	if elapsed >= 20.0 and not has_meta("save_before_story"):
		set_meta("save_before_story", true)
		var selected_before := cat.story_director.deck.selected_stories.duplicate()
		var saved_position := cat.global_position
		var expected_position := Vector3(saved_position.x, maxf(0.1, saved_position.y), saved_position.z)
		var saved_ok := SaveManager.save_game()
		cat.global_position += Vector3(0.8, 0.0, 0.0)
		var loaded_ok := SaveManager.load_game()
		save_checks.append({
			"case": "A_before_story",
			"saved": saved_ok,
			"loaded": loaded_ok,
			"deck_preserved": selected_before == cat.story_director.deck.selected_stories,
			"position_restored": cat.global_position.distance_to(expected_position) < 0.05,
		})
	if mode == "B" and not has_meta("save_during_telegraph") and cat.story_director.active_story != null and cat.story_director.active_story.phase == CatStory.Phase.TELEGRAPH:
		set_meta("save_during_telegraph", true)
		var active_id := cat.story_director.active_story.story_id
		var saved_ok := SaveManager.save_game()
		var loaded_ok := SaveManager.load_game()
		save_checks.append({
			"case": "B_during_telegraph",
			"story": String(active_id),
			"saved": saved_ok,
			"loaded": loaded_ok,
			"cancelled_safely": cat.story_director.active_story == null,
			"consumed_once": not cat.story_director.deck.is_available(active_id),
			"laptop_unblocked": not bool(objects["laptop"].get_meta("cat_blocked", false)),
		})
	var completed := cat.story_director.deck.completed_cat_stories
	if mode == "C" and not completed.is_empty() and not has_meta("save_after_story"):
		set_meta("save_after_story", true)
		var completed_before := completed.duplicate()
		var saved_ok := SaveManager.save_game()
		var loaded_ok := SaveManager.load_game()
		save_checks.append({"case": "C_after_story", "saved": saved_ok, "loaded": loaded_ok, "completed_preserved": completed_before == cat.story_director.deck.completed_cat_stories})
	if &"PAYMENT_ALTAR_STORY" in completed and not has_meta("save_after_payment"):
		set_meta("save_after_payment", true)
		var saved_ok := SaveManager.save_game()
		var loaded_ok := SaveManager.load_game()
		save_checks.append({"case": "D_after_payment", "saved": saved_ok, "loaded": loaded_ok, "payment_repeated": cat.story_director.deck.is_available(&"PAYMENT_ALTAR_STORY")})

func _finish_route_and_report() -> void:
	finished = true
	if mode == "C" and not has_meta("chaos_cleared"):
		_stop_high_chaos()
	var mug := objects.get("mug") as Node
	var content := mug.get_node("MugContentController") as MugContentController
	if not content.is_stirred:
		content.set_stirred()
	if not QuestManager.coffee_made:
		QuestManager.brew_coffee()
	if QuestManager.spill_cleanup_required:
		QuestManager.set_spill_cleanup_required(false)
	QuestManager.drink_coffee()
	route_stages.append({"time": RunStats.elapsed_time, "stage": "coffee_drunk"})
	cat.story_director.abort_current(&"qa_run_finished")
	var telemetry := cat.story_director.telemetry_snapshot()
	var started_before_clear := high_chaos_started_count
	var report := {
		"mode": mode,
		"game_duration_seconds": RunStats.elapsed_time,
		"wall_duration_seconds": float(Time.get_ticks_msec() - wall_start_msec) / 1000.0,
		"deck": telemetry.get("deck", []),
		"stories_started": telemetry.get("started", []),
		"stories_finished": telemetry.get("finished", []),
		"stories_prevented": telemetry.get("prevented", []),
		"calm_windows": telemetry.get("calm_windows", []),
		"helpful_actions": telemetry.get("helpful_actions", []),
		"chaos_refusals": telemetry.get("chaos_refusals", 0),
		"context_refusals": telemetry.get("context_refusals", {}),
		"stories_before_high_chaos_clear": started_before_clear,
		"rita_wake_start": wake_start,
		"rita_wake_end": RitaSleep.wake_level,
		"route_stages": route_stages,
		"coffee_finished": QuestManager.coffee_drunk,
		"laptop_blocked": bool(objects["laptop"].get_meta("cat_blocked", false)),
		"spoon_held": bool(objects["spoon"].get("held")),
		"active_story_after_cleanup": String(cat.story_director.debug_state().get("active_story", "")),
		"average_fps": fps_sum / maxf(1.0, float(fps_samples)),
		"max_frame_ms": max_frame_ms,
		"renderer": RenderingServer.get_current_rendering_method(),
		"milk_delivery": MilkDelivery.get_state(),
		"run_active": RunStats.run_active,
		"rita_angry": RitaSleep.is_angry,
		"relationship": cat.relationship_memory.get_state(),
		"wake_trace": wake_trace,
		"save_checks": save_checks,
	}
	var path := ProjectSettings.globalize_path("res://docs/evidence/rita_cat/balance_run_%s.json" % mode.to_lower())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("CAT_BALANCE_RUN_%s_OK %s" % [mode, JSON.stringify(report)])
	Engine.time_scale = 1.0
	get_tree().quit(0)
