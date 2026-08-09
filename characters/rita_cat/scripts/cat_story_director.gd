class_name CatStoryDirector
extends Node

signal story_started(story_id: StringName)
signal story_finished(story_id: StringName, outcome: StringName)

const STORY_SCRIPTS := {
	&"SPOON_STORY": preload("res://characters/rita_cat/stories/spoon_story.gd"),
	&"MUG_STORY": preload("res://characters/rita_cat/stories/mug_story.gd"),
	&"LAPTOP_STORY": preload("res://characters/rita_cat/stories/laptop_story.gd"),
	&"PHONE_STORY": preload("res://characters/rita_cat/stories/phone_story.gd"),
	&"VACUUM_STORY": preload("res://characters/rita_cat/stories/vacuum_story.gd"),
	&"RITA_DOOR_STORY": preload("res://characters/rita_cat/stories/rita_door_story.gd"),
	&"COURIER_BOX_STORY": preload("res://characters/rita_cat/stories/courier_box_story.gd"),
	&"PAYMENT_ALTAR_STORY": preload("res://characters/rita_cat/stories/payment_story.gd"),
	&"FLOOD_ESCAPE_STORY": preload("res://characters/rita_cat/stories/flood_escape_story.gd"),
}

var cat: Node
var objects: Dictionary = {}
var deck: CatStoryDeck
var chaos: CatChaosObserver
var active_story: CatStory
var stories: Dictionary = {}
var calm_left := 40.0
var evaluate_left := 3.0
var rng := RandomNumberGenerator.new()
var last_quest_signature := ""
var stalled_seconds := 0.0
var helped_signatures: Dictionary = {}
var flood_story_used := false
var vacuum_panic_used := false
var telemetry := {
	"first_story_time": -1.0,
	"started": [],
	"finished": [],
	"prevented": [],
	"calm_windows": [],
	"helpful_actions": [],
	"chaos_refusals": 0,
	"context_refusals": {},
}

func setup(host: Node, world_objects: Dictionary) -> void:
	cat = host
	objects = world_objects
	deck = get_node("CatStoryDeck") as CatStoryDeck
	chaos = get_node("CatChaosObserver") as CatChaosObserver
	chaos.setup(objects)
	deck.build_deck()
	rng.randomize()
	for id in STORY_SCRIPTS:
		var story := STORY_SCRIPTS[id].new() as CatStory
		story.name = String(id).to_pascal_case()
		story.completed.connect(_on_story_completed)
		add_child(story)
		stories[id] = story
	last_quest_signature = _quest_signature()

func _process(delta: float) -> void:
	if cat == null or not RunStats.run_active:
		return
	_track_stagnation(delta)
	if _flood_emergency_ready():
		# A rising flood is a real physical danger, so it safely interrupts a
		# domestic prank instead of waiting forever behind the chaos lock.
		if active_story != null:
			active_story.abort_safely(&"flood_emergency")
		var flood_story := stories.get(&"FLOOD_ESCAPE_STORY") as CatStory
		if flood_story != null:
			flood_story_used = true
			_start_story(flood_story, {"objects": objects, "chaos": chaos.chaos_budget})
			return
	if active_story == null and _vacuum_panic_ready():
		var vacuum_story := stories.get(&"VACUUM_STORY") as CatStory
		if vacuum_story != null and deck.reserve_reactive(&"VACUUM_STORY", &"HOUSEHOLD_EVENT"):
			vacuum_panic_used = true
			_start_story(vacuum_story, {"objects": objects, "chaos": chaos.chaos_budget})
			return
	if active_story != null:
		chaos.sample_now()
		if _urgent_event_conflicts_with(active_story.story_id):
			# Preserve the small story, but freeze its clock while a call, courier or
			# appliance needs immediate attention. Consequences never develop under
			# another urgent notification and the deck card does not restart later.
			return
		active_story.advance(delta)
		return
	calm_left = maxf(0.0, calm_left - delta)
	evaluate_left -= delta
	if evaluate_left > 0.0:
		return
	evaluate_left = rng.randf_range(3.0, 6.0)
	if chaos.chaos_budget >= 5:
		telemetry["chaos_refusals"] = int(telemetry["chaos_refusals"]) + 1
		cat.call("hide_from_chaos")
		return
	if _try_help_player():
		return
	if calm_left > 0.0:
		_record_refusal("calm")
		return
	if RunStats.elapsed_time < 45.0:
		_record_refusal("too_early")
		return
	if not chaos.permits_story():
		_record_refusal("context_%s" % "_".join(chaos.reasons))
		return
	var player := objects.get("player") as Node
	if player != null and float(player.get("intoxication")) >= 45.0:
		cat.call("observe_drunk_player")
		calm_left = 15.0
		return
	for id in deck.remaining():
		var story := stories.get(id) as CatStory
		var story_context := {"objects": objects, "chaos": chaos.chaos_budget}
		if story != null and story.can_start(story_context):
			_start_story(story, story_context)
			return
	_record_refusal("no_eligible_story")
	calm_left = 12.0

func _start_story(story: CatStory, story_context: Dictionary) -> void:
	active_story = story
	chaos.story_active = true
	story.start(cat, story_context)
	if float(telemetry["first_story_time"]) < 0.0:
		telemetry["first_story_time"] = RunStats.elapsed_time
	(telemetry["started"] as Array).append({"id": String(story.story_id), "time": RunStats.elapsed_time})
	story_started.emit(story.story_id)

func _on_story_completed(id: StringName, outcome: StringName) -> void:
	# An interrupted story still consumes its deck card. Re-queuing it caused
	# the same scenario to restart after every courier/call interruption.
	deck.mark_completed(id)
	active_story = null
	chaos.story_active = false
	var relationship := cat.get("relationship_memory") as CatRelationshipMemory
	var trust_extension := relationship.trust * 0.12 if relationship != null else 0.0
	calm_left = (18.0 if outcome == &"aborted" else (rng.randf_range(30.0, 60.0) if outcome == &"prevented" else rng.randf_range(60.0, 120.0))) + trust_extension
	(telemetry["finished"] as Array).append({"id": String(id), "outcome": String(outcome), "time": RunStats.elapsed_time})
	(telemetry["calm_windows"] as Array).append(calm_left)
	if outcome == &"prevented":
		(telemetry["prevented"] as Array).append(String(id))
	cat.call("begin_calm_life")
	story_finished.emit(id, outcome)

func _urgent_event_conflicts_with(story_id: StringName) -> bool:
	if story_id == &"FLOOD_ESCAPE_STORY":
		return false
	for reason in chaos.reasons:
		if reason in ["cat_story", "rita_near_wake"]:
			continue
		if story_id == &"PHONE_STORY" and reason == "phone":
			continue
		if story_id == &"VACUUM_STORY" and reason == "vacuum":
			continue
		return true
	return false

func _flood_emergency_ready() -> bool:
	if flood_story_used or (active_story != null and active_story.story_id == &"FLOOD_ESCAPE_STORY"):
		return false
	var flood_story := stories.get(&"FLOOD_ESCAPE_STORY") as CatStory
	return flood_story != null and flood_story.can_start({"objects": objects, "chaos": chaos.chaos_budget})

func _vacuum_panic_ready() -> bool:
	if vacuum_panic_used or deck == null or &"VACUUM_STORY" in deck.completed_cat_stories:
		return false
	var vacuum_story := stories.get(&"VACUUM_STORY") as CatStory
	return vacuum_story != null and vacuum_story.can_start({"objects": objects, "chaos": chaos.chaos_budget})

func force_story(id: StringName) -> bool:
	if active_story != null or not stories.has(id):
		return false
	var story := stories[id] as CatStory
	var story_context := {"objects": objects, "chaos": 0}
	if not story.can_start(story_context):
		return false
	_start_story(story, story_context)
	return true

func interact_with_story() -> bool:
	if active_story == null:
		return false
	if active_story.phase == CatStory.Phase.APPROACH or active_story.phase == CatStory.Phase.TELEGRAPH:
		active_story.prevent(&"player")
	else:
		active_story.player_resolve(&"player")
	return true

func abort_current(reason: StringName = &"shutdown") -> void:
	if active_story != null:
		active_story.abort_safely(reason)

func _track_stagnation(delta: float) -> void:
	var signature := _quest_signature()
	if signature != last_quest_signature:
		last_quest_signature = signature
		stalled_seconds = 0.0
	else:
		stalled_seconds += delta

func _try_help_player() -> bool:
	if stalled_seconds < 42.0 or chaos.chaos_budget > 2 or helped_signatures.has(last_quest_signature):
		return false
	if rng.randf() > (cat.get("relationship_memory") as CatRelationshipMemory).helpful_probability():
		stalled_seconds = 22.0
		return false
	var helpful_target: Node3D
	if not QuestManager.has_mug:
		helpful_target = objects.get("mug") as Node3D
	elif not QuestManager.has_coffee:
		helpful_target = objects.get("coffee") as Node3D
	elif not QuestManager.coffee_powder_poured:
		helpful_target = objects.get("mug") as Node3D
	elif not QuestManager.kettle_filled:
		helpful_target = objects.get("water") as Node3D
	else:
		helpful_target = objects.get("spoon") as Node3D
	if helpful_target == null:
		return false
	helped_signatures[last_quest_signature] = true
	(telemetry["helpful_actions"] as Array).append({"quest": last_quest_signature, "time": RunStats.elapsed_time, "target": helpful_target.name})
	cat.call("quietly_point_out", helpful_target)
	calm_left = 30.0
	return true

func _quest_signature() -> String:
	return "%s%s%s%s%s%s%s" % [QuestManager.has_mug, QuestManager.has_coffee, QuestManager.coffee_powder_poured, QuestManager.kettle_filled, QuestManager.water_poured, QuestManager.milk_poured, QuestManager.coffee_made]

func debug_state() -> Dictionary:
	return {
		"deck": deck.selected_stories if deck != null else [],
		"completed": deck.completed_cat_stories if deck != null else [],
		"active_story": active_story.story_id if active_story != null else &"",
		"phase": active_story.phase if active_story != null else CatStory.Phase.IDLE,
		"calm_left": calm_left,
		"chaos": chaos.chaos_budget if chaos != null else 0,
		"flood_story_used": flood_story_used,
		"vacuum_panic_used": vacuum_panic_used,
	}

func telemetry_snapshot() -> Dictionary:
	var result := telemetry.duplicate(true)
	result["deck"] = deck.selected_stories.duplicate() if deck != null else []
	result["completed"] = deck.completed_cat_stories.duplicate() if deck != null else []
	result["chaos"] = chaos.chaos_budget if chaos != null else 0
	return result

func _record_refusal(reason: String) -> void:
	var refusals := telemetry["context_refusals"] as Dictionary
	refusals[reason] = int(refusals.get(reason, 0)) + 1
