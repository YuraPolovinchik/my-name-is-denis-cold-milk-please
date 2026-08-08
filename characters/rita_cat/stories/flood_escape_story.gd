class_name CatFloodEscapeStory
extends CatStory

var flood: ApartmentFloodVisual
var mop: RigidBody3D
var player: Node3D
var perch := Vector3(2.55, 1.28, 6.08)
var next_meow := 0.8
var chase_tick := 0.0
var heading_to_perch := false
var escaped := false


func _init() -> void:
	story_id = &"FLOOD_ESCAPE_STORY"
	category = &"EMERGENCY_REACTION"
	telegraph_seconds = 3.2


func can_start(next_context: Dictionary) -> bool:
	var world: Dictionary = next_context.get("objects", {})
	flood = world.get("apartment_flood_visual") as ApartmentFloodVisual
	mop = world.get("mop") as RigidBody3D
	player = world.get("player") as Node3D
	return flood != null and flood.active and flood.flood_stage >= 1 and flood.current_depth >= 0.08 and is_instance_valid(mop)


func get_target() -> Node3D:
	return mop


func start(host: Node, next_context: Dictionary) -> void:
	perch = host.call("get_nearest_flood_perch")
	super.start(host, next_context)
	QuestManager.set_bonus_objective(&"cat_flood", "БАТОН БОИТСЯ ВОДЫ • ОТВЛЕКИ ЕГО ИЛИ ДАЙ ЕМУ УЙТИ НАВЕРХ")
	host.call("meow", 5.0)


func telegraph() -> void:
	super.telegraph()
	cat.call("set_body_state", CatBodyController.BodyState.PAW)
	cat.call("set_intention", CatIntentionController.Intention.INTERFERE)
	cat.call("meow", 5.5)
	QuestManager.notification_requested.emit("БАТОН ВЦЕПИЛСЯ В ШВАБРУ • ОН НЕ ХОЧЕТ МОЧИТЬ ЛАПЫ")


func begin_development() -> void:
	cat.call("set_body_state", CatBodyController.BodyState.STARTLED)
	cat.call("set_intention", CatIntentionController.Intention.REACT_TO_DANGER)
	next_meow = 0.7


func advance_development(delta: float) -> void:
	if flood == null or not flood.active:
		_escape_to_perch()
		resolve(&"water_receded")
		return
	if phase_time >= next_meow and next_meow < 5.0:
		next_meow += 2.0
		cat.call("meow", 5.5)
	# Если Денис уже взял швабру, кот несколько секунд бежит прямо перед
	# ним и заставляет маневрировать, но никогда не отбирает обязательный предмет.
	if is_instance_valid(mop) and bool(mop.get("held")) and is_instance_valid(player) and phase_time < 5.8:
		chase_tick -= delta
		if chase_tick <= 0.0:
			chase_tick = 0.65
			var ahead := player.global_position + (-player.global_transform.basis.z * 0.72)
			cat.call("move_to_world", Vector3(ahead.x, 0.10, ahead.z))
			cat.call("set_body_state", CatBodyController.BodyState.TROT)
	elif phase_time >= 5.8 and not heading_to_perch:
		heading_to_perch = true
		cat.call("move_to_world", Vector3(perch.x, 0.10, perch.z))
	if heading_to_perch and (cat.call("at_target") or phase_time >= 12.0):
		_escape_to_perch()
		resolve(&"escaped_upward")


func prevent(_reason: StringName = &"player") -> void:
	if phase != Phase.APPROACH and phase != Phase.TELEGRAPH:
		return
	var memory := cat.get("relationship_memory") as CatRelationshipMemory
	if memory != null:
		memory.successful_prevention()
	_escape_to_perch()
	resolve(&"prevented")


func player_resolve(_reason: StringName = &"player") -> void:
	if phase == Phase.DEVELOPMENT:
		_escape_to_perch()
		resolve(&"reassured")


func cleanup() -> void:
	QuestManager.clear_bonus_objective(&"cat_flood")


func _escape_to_perch() -> void:
	if escaped:
		return
	escaped = true
	cat.call("controlled_jump_to", perch)
	var audio := cat.get("audio_controller") as CatAudioController
	if audio != null:
		audio.friendly_chirp()
