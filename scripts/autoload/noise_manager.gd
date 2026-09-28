extends Node

signal noise_emitted(data: Dictionary)

const DOOR_OPEN_ATTENUATION := 0.75
const DOOR_CLOSED_ATTENUATION := 0.32
const MIN_HEARD_STRENGTH := 0.65

var _rooms: Dictionary = {}
var _edges: Dictionary = {}
var _door_states: Dictionary = {}
var last_noise: Dictionary = {
    "category": "—",
    "source_room": "—",
    "raw_strength": 0.0,
    "heard_strength": 0.0,
    "source_id": "—"
}

## Радиус, внутри которого шум считается действием самого игрока (наушники глушат его)
const HEADPHONE_SOURCE_RADIUS := 2.2
## Внешние события (звонок, дверной звонок) наушниками не глушатся
const HEADPHONE_EXEMPT_SOURCES: Array[StringName] = [&"phone", &"doorbell"]

func reset() -> void:
    _rooms.clear()
    _edges.clear()
    _door_states.clear()
    if has_meta("player_noise_reduction"):
        remove_meta("player_noise_reduction")
    last_noise = {
        "category": "—",
        "source_room": "—",
        "raw_strength": 0.0,
        "heard_strength": 0.0,
        "source_id": "—"
    }

func configure_rooms(room_defs: Dictionary, edges: Array[Dictionary]) -> void:
    _rooms = room_defs.duplicate(true)
    _edges.clear()
    for edge in edges:
        var a: StringName = edge.get("a", &"")
        var b: StringName = edge.get("b", &"")
        if a == &"" or b == &"":
            continue
        if not _edges.has(a):
            _edges[a] = []
        if not _edges.has(b):
            _edges[b] = []
        _edges[a].append(edge.duplicate(true))
        var reverse: Dictionary = edge.duplicate(true)
        reverse["a"] = b
        reverse["b"] = a
        _edges[b].append(reverse)
        var door_id: StringName = edge.get("door_id", &"")
        if door_id != &"" and not _door_states.has(door_id):
            _door_states[door_id] = bool(edge.get("door_open", true))

func set_door_open(door_id: StringName, is_open: bool) -> void:
    _door_states[door_id] = is_open

func is_door_open(door_id: StringName) -> bool:
    return bool(_door_states.get(door_id, true))

func room_for_position(position: Vector3) -> StringName:
    for room_name in _rooms:
        var data: Dictionary = _rooms[room_name]
        var bounds: AABB = data.get("bounds", AABB())
        if bounds.has_point(position):
            return room_name
    return &"corridor"

func emit_noise(source_position: Vector3, strength: float, category: StringName, source_id: StringName = &"unknown") -> float:
    var raw_strength := clampf(strength, 0.0, 100.0)
    if raw_strength <= 0.01:
        return 0.0
    var source_room: StringName = room_for_position(source_position)
    var heard: float = _attenuate_to_room(source_room, &"bedroom", raw_strength)
    var structure_factor := _structure_borne_factor(category, source_id)
    if structure_factor > 0.0:
        heard = maxf(heard, raw_strength * structure_factor)
    heard = _apply_headphone_reduction(heard, source_position, source_id)
    if heard < MIN_HEARD_STRENGTH:
        heard = 0.0
    last_noise = {
        "category": String(category),
        "source_room": String(source_room),
        "raw_strength": raw_strength,
        "heard_strength": heard,
        "source_id": String(source_id)
    }
    if heard > 0.0:
        RitaSleep.add_noise(heard, category, source_id)
    RunStats.record_noise(raw_strength, heard, category)
    noise_emitted.emit(last_noise)
    return heard

## Шумоподавляющие наушники игрока: глушат его собственные действия,
## пока активны (meta ставит noise_cancelling_headphones.gd).
func _apply_headphone_reduction(heard: float, source_position: Vector3, source_id: StringName) -> float:
    if heard <= 0.0 or not has_meta("player_noise_reduction"):
        return heard
    if source_id in HEADPHONE_EXEMPT_SOURCES:
        return heard
    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return heard
    if player.global_position.distance_to(source_position) > HEADPHONE_SOURCE_RADIUS:
        return heard
    return heard * (1.0 - clampf(float(get_meta("player_noise_reduction")), 0.0, 1.0))

func _structure_borne_factor(category: StringName, source_id: StringName) -> float:
    # Motors and impacts travel through the floor even when airborne sound is blocked by doors.
    match source_id:
        &"vacuum":
            return 0.15
        &"phone":
            return 0.085
        &"kettle_hum":
            return 0.075
        &"doorbell":
            # The bell is fixed to the entrance wall, so its vibration travels
            # through the apartment more efficiently than ordinary airborne sound.
            return 0.34
    match category:
        &"FURNITURE_PUSH":
            return 0.10
        &"OBJECT_IMPACT":
            return 0.11
        &"VOICE_CALL":
            return 0.055
    return 0.0

func _attenuate_to_room(source_room: StringName, target_room: StringName, strength: float) -> float:
    if source_room == target_room:
        var source_data: Dictionary = _rooms.get(source_room, {})
        return strength * float(source_data.get("multiplier", 1.0))
    var queue: Array[Dictionary] = [{"room": source_room, "factor": 1.0}]
    var best: Dictionary = {}
    best[source_room] = 1.0
    while not queue.is_empty():
        var item: Dictionary = queue.pop_front()
        var room: StringName = item["room"]
        var factor: float = item["factor"]
        for edge_variant in _edges.get(room, []):
            var edge: Dictionary = edge_variant
            var next_room: StringName = edge["b"]
            var edge_factor: float = float(edge.get("attenuation", 1.0))
            var door_id: StringName = edge.get("door_id", &"")
            if door_id != &"":
                edge_factor *= DOOR_OPEN_ATTENUATION if is_door_open(door_id) else DOOR_CLOSED_ATTENUATION
            var next_factor: float = factor * edge_factor
            if next_factor <= float(best.get(next_room, 0.0)):
                continue
            best[next_room] = next_factor
            if next_room == target_room:
                var target_data: Dictionary = _rooms.get(target_room, {})
                var room_multiplier: float = float(target_data.get("multiplier", 1.0))
                return strength * next_factor * room_multiplier
            queue.append({"room": next_room, "factor": next_factor})
    return strength * 0.05
