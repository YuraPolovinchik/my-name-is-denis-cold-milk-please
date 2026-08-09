class_name RitaCat
extends CharacterBody3D

@export var cat_display_name := "Батон"
@export var walk_speed := 1.15
@export var trot_speed := 2.0

@onready var body_controller: CatBodyController = $CatBodyController
@onready var intention_controller: CatIntentionController = $CatIntentionController
@onready var relationship_memory: CatRelationshipMemory = $CatRelationshipMemory
@onready var animation_controller: CatAnimationController = $CatAnimationController
@onready var audio_controller: CatAudioController = $CatAudioController
@onready var story_director: CatStoryDirector = $CatStoryDirector
@onready var stuck_recovery: CatStuckRecovery = $CatStuckRecovery
@onready var visual_root: Node3D = $VisualRoot

var objects: Dictionary = {}
var route: Array[Vector3] = []
var move_target := Vector3.ZERO
var wants_motion := false
var idle_left := 8.0
var desired_yaw := 0.0
var awareness_left := 0.0
var movement_speed_multiplier := 1.0
var vacuum_panic_active := false

const CALM_LIFE_SPOTS: Array[Vector3] = [
	Vector3(-6.75, 0.10, -1.10),
	Vector3(-4.30, 0.10, -5.65),
	Vector3(-1.18, 0.10, -1.72),
	Vector3(0.05, 0.10, 1.15),
	Vector3(1.28, 0.10, 3.78),
	Vector3(5.85, 0.10, 1.32),
	Vector3(-3.05, 0.10, 5.75),
]

const FLOOD_PERCHES: Array[Vector3] = [
	Vector3(2.55, 1.28, 6.08),
	Vector3(2.42, 1.30, 2.42),
	Vector3(7.30, 1.08, 3.10),
	Vector3(5.45, 1.12, -5.45),
	Vector3(-5.45, 0.66, -0.20),
	Vector3(-2.35, 1.05, 5.72),
]

func _ready() -> void:
	add_to_group("rita_cat")
	animation_controller.setup(visual_root)
	body_controller.body_state_changed.connect(animation_controller.play_body_state)
	relationship_memory.relationship_changed.connect(_on_relationship_changed)
	stuck_recovery.setup(self)
	desired_yaw = rotation.y
	set_body_state(CatBodyController.BodyState.SIT)

func setup(world_objects: Dictionary) -> void:
	objects = world_objects
	story_director.setup(self, objects)
	SaveManager.register_cat(self)

func _physics_process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(delta * 7.5, 0.0, 1.0))
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if wants_motion:
		_follow_route(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		_idle_life(delta)
	move_and_slide()
	stuck_recovery.sample(delta, wants_motion)
	_update_awareness(delta)

func move_to_world(destination: Vector3) -> void:
	move_target = destination
	route = _build_safe_route(global_position, destination)
	wants_motion = true
	set_body_state(CatBodyController.BodyState.WALK)

func rebuild_route() -> void:
	route = _build_safe_route(global_position, move_target)

func at_target() -> bool:
	return not wants_motion

func _follow_route(_delta: float) -> void:
	if route.is_empty():
		wants_motion = false
		velocity.x = 0.0
		velocity.z = 0.0
		set_body_state(CatBodyController.BodyState.STAND)
		return
	var waypoint := route[0]
	var flat_delta := Vector3(waypoint.x - global_position.x, 0.0, waypoint.z - global_position.z)
	if flat_delta.length() <= 0.18:
		route.pop_front()
		return
	var direction := flat_delta.normalized()
	velocity.x = direction.x * walk_speed * movement_speed_multiplier
	velocity.z = direction.z * walk_speed * movement_speed_multiplier
	face_world_point(global_position + direction)

func _build_safe_route(origin: Vector3, destination: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var from_room := _room_side(origin)
	var to_room := _room_side(destination)
	if from_room != to_room:
		var from_portal := _portal_for(origin)
		var to_portal := _portal_for(destination)
		if from_room != &"HALL":
			points.append(from_portal)
			points.append(Vector3(signf(from_portal.x) * 0.75, 0.1, from_portal.z))
		if to_room != &"HALL":
			points.append(Vector3(signf(to_portal.x) * 0.75, 0.1, to_portal.z))
			points.append(to_portal)
	points.append(Vector3(destination.x, maxf(destination.y, 0.1), destination.z))
	return points

func _room_side(point: Vector3) -> StringName:
	if absf(point.x) <= 1.85:
		return &"HALL"
	return &"RIGHT_REAR" if point.x > 0.0 and point.z > 2.0 else (&"RIGHT_FRONT" if point.x > 0.0 else (&"LEFT_REAR" if point.z > 2.0 else &"LEFT_FRONT"))

func _portal_for(point: Vector3) -> Vector3:
	var x := 1.82 if point.x > 0.0 else -1.82
	var z := 3.78 if point.z > 2.0 else -1.72
	return Vector3(x, 0.1, z)

func face_world_point(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.02:
		var direction := (flat - global_position).normalized()
		desired_yaw = atan2(direction.x, direction.z)

func set_body_state(state: int) -> void:
	body_controller.set_state(state)

func set_intention(next_intention: int) -> void:
	intention_controller.set_intention(next_intention)

func controlled_jump_to(destination: Vector3) -> void:
	wants_motion = false
	velocity = Vector3.ZERO
	set_body_state(CatBodyController.BodyState.JUMP)
	var tween := create_tween()
	var midpoint := (global_position + destination) * 0.5 + Vector3.UP * 0.45
	tween.tween_property(self, "global_position", midpoint, 0.28).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", destination, 0.28).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(set_body_state.bind(CatBodyController.BodyState.SIT))

func begin_calm_life() -> void:
	set_intention(CatIntentionController.Intention.REST)
	set_body_state(CatBodyController.BodyState.GROOM if randf() < 0.45 else CatBodyController.BodyState.SIT)
	idle_left = randf_range(12.0, 25.0)

func hide_from_chaos() -> void:
	set_intention(CatIntentionController.Intention.HIDE)
	move_to_world(Vector3(-5.62, 0.1, 1.52))

func observe_drunk_player() -> void:
	set_intention(CatIntentionController.Intention.OBSERVE)
	move_to_world(Vector3(-5.8, 0.1, 0.7))

func quietly_point_out(target_node: Node3D) -> void:
	set_intention(CatIntentionController.Intention.HELP)
	move_to_world(target_node.global_position + Vector3(0.45, 0.0, 0.25))

func get_nearest_flood_perch() -> Vector3:
	var best := FLOOD_PERCHES[0]
	var best_distance := INF
	for candidate in FLOOD_PERCHES:
		var distance := Vector2(candidate.x - global_position.x, candidate.z - global_position.z).length()
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func meow(strength := 3.5) -> void:
	audio_controller.meow(strength)

func panic_yowl(strength := 9.0) -> void:
	audio_controller.panic_yowl(strength)

func begin_vacuum_panic(source: Node3D) -> void:
	vacuum_panic_active = true
	movement_speed_multiplier = maxf(1.0, trot_speed / maxf(walk_speed, 0.01)) * 1.18
	set_intention(CatIntentionController.Intention.REACT_TO_DANGER)
	continue_vacuum_panic(source)

func continue_vacuum_panic(source: Node3D) -> void:
	if not vacuum_panic_active or not is_instance_valid(source):
		return
	var destination := global_position
	var best_score := -INF
	for candidate in CALM_LIFE_SPOTS:
		if global_position.distance_to(candidate) < 1.15:
			continue
		var source_distance := Vector2(candidate.x - source.global_position.x, candidate.z - source.global_position.z).length()
		var travel_distance := Vector2(candidate.x - global_position.x, candidate.z - global_position.z).length()
		var score := source_distance - travel_distance * 0.08 + randf_range(-0.45, 0.45)
		if score > best_score:
			best_score = score
			destination = candidate
	move_to_world(destination)
	set_body_state(CatBodyController.BodyState.TROT)

func finish_vacuum_panic() -> void:
	vacuum_panic_active = false
	movement_speed_multiplier = 1.0
	wants_motion = false
	route.clear()
	velocity = Vector3.ZERO
	set_intention(CatIntentionController.Intention.REST)
	set_body_state(CatBodyController.BodyState.SIT)

func _idle_life(delta: float) -> void:
	if story_director.active_story != null:
		return
	idle_left -= delta
	if idle_left > 0.0:
		return
	idle_left = randf_range(15.0, 32.0)
	if relationship_memory.trust >= 55.0 and randf() < 0.48:
		var player := objects.get("player") as Node3D
		if player != null and global_position.distance_to(player.global_position) > 2.1:
			var offset := Vector3(0.9, 0.0, 0.7).rotated(Vector3.UP, player.rotation.y)
			move_to_world(player.global_position + offset)
			return
	var roll := randf()
	if roll < 0.27:
		_roam_calmly()
	elif roll < 0.53:
		set_body_state(CatBodyController.BodyState.GROOM)
	elif roll < 0.80:
		set_body_state(CatBodyController.BodyState.LIE)
	else:
		set_body_state(CatBodyController.BodyState.SIT)

func _roam_calmly() -> void:
	var candidates := CALM_LIFE_SPOTS.duplicate()
	candidates.shuffle()
	var flood := objects.get("apartment_flood_visual") as ApartmentFloodVisual
	for candidate in candidates:
		if global_position.distance_to(candidate) < 1.2:
			continue
		if flood != null and flood.get_water_depth_at(candidate) > 0.04:
			continue
		move_to_world(candidate)
		# Doorway loafs are deliberately short: noticeable obstruction, no softlock.
		idle_left = 5.5 if absf(candidate.x - 1.28) < 0.05 and absf(candidate.z - 3.78) < 0.05 else randf_range(10.0, 19.0)
		return

func _update_awareness(delta: float) -> void:
	if story_director.active_story != null or wants_motion:
		return
	awareness_left -= delta
	if awareness_left > 0.0:
		return
	awareness_left = randf_range(0.35, 0.75)
	var player := objects.get("player") as Node3D
	if player == null or global_position.distance_to(player.global_position) > 4.2:
		return
	var held := player.get("held_item") as Node3D
	if held != null and is_instance_valid(held):
		face_world_point(held.global_position)
	else:
		face_world_point(player.global_position)

func interact(_actor = null, _mode := 0) -> String:
	return perform_interaction(_actor, _mode)

func perform_interaction(actor = null, _mode := 0) -> String:
	var held_item := actor.get("held_item") as Node if actor != null else null
	var held_id := StringName(held_item.get("item_id")) if held_item != null else &""
	if held_id == &"cat_food" and relationship_memory.feed():
		if story_director.active_story != null:
			story_director.interact_with_story()
		set_body_state(CatBodyController.BodyState.EAT)
		audio_controller.purr()
		return "%s успокоился и занялся кормом." % cat_display_name
	if held_id == &"cat_toy":
		relationship_memory.play()
		if story_director.active_story != null:
			story_director.interact_with_story()
		set_intention(CatIntentionController.Intention.PLAY)
		audio_controller.friendly_chirp()
		return "%s погнался за игрушечной мышью и забыл о пакости." % cat_display_name
	var active_story_id := story_director.active_story.story_id if story_director.active_story != null else &""
	if story_director.interact_with_story():
		if active_story_id == &"VACUUM_STORY":
			relationship_memory.successful_prevention()
			set_body_state(CatBodyController.BodyState.SIT)
			audio_controller.purr()
			return "%s прижался к полу, выдохнул и перестал орать." % cat_display_name
		return "%s отвлёкся. История предотвращена без штрафа." % cat_display_name
	if relationship_memory.pet():
		set_body_state(CatBodyController.BodyState.SIT)
		audio_controller.purr()
		return "Ты тихо погладил кота. %s теперь доверяет тебе чуть больше." % cat_display_name
	return "%s пока не даётся в руки — лучше не давить." % cat_display_name

func get_prompt(_actor = null) -> String:
	if story_director.active_story != null:
		if story_director.active_story.story_id == &"VACUUM_STORY":
			return "E — УСПОКОИТЬ %s • МОЖНО КОРМОМ ИЛИ ИГРУШКОЙ" % cat_display_name.to_upper()
		return "E — ОТВЛЕЧЬ КОТА ДО ТОГО, КАК ОН ВМЕШАЕТСЯ"
	return "E — ТИХО ПОГЛАДИТЬ %s" % cat_display_name.to_upper()

func _on_relationship_changed(state: Dictionary) -> void:
	var trust := float(state.get("trust", 0.0))
	# Friendship stays diegetic: a trusted cat settles faster and chooses Denis
	# as a calm-life anchor instead of exposing another relationship HUD.
	if trust >= 55.0 and story_director.active_story == null:
		idle_left = minf(idle_left, 3.0)
		set_intention(CatIntentionController.Intention.REST)

func get_debug_state() -> Dictionary:
	return {
		"body": body_controller.get_state_name(),
		"intention": intention_controller.get_intention_name(),
		"relationship": relationship_memory.get_state(),
		"story": story_director.debug_state(),
		"route_points": route.size(),
	}

func get_save_data() -> Dictionary:
	return {
		"name": cat_display_name,
		"relationship": relationship_memory.get_state(),
		"deck": story_director.deck.get_state(),
	}

func load_save_data(saved: Dictionary) -> void:
	cat_display_name = String(saved.get("name", cat_display_name))
	relationship_memory.load_state(saved.get("relationship", {}))
	story_director.deck.load_state(saved.get("deck", {}))
