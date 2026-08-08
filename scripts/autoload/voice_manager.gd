extends Node

const MANIFEST_PATH := "res://assets/voices/voice_manifest.json"
const DENIS_CALL_REPLIES := [
    "Да, коллеги, здесь важно синхронизироваться.",
    "Давайте я отдельно уточню и вернусь.",
    "Сейчас на нашей стороне всё в работе.",
    "Предлагаю вынести это в отдельный слот."
]

var _manifest: Dictionary = {}
var _players: Dictionary = {}
var _stream_cache: Dictionary = {}

func _ready() -> void:
    _load_manifest()
    _players[&"rita"] = _create_player("RitaVoice", -2.0)
    _players[&"call"] = _create_player("CallVoice", -5.0)
    _players[&"denis"] = _create_player("DenisVoice", -4.0)
    _players[&"courier"] = _create_player("CourierVoice", -1.5)
    RitaSleep.subtitle_requested.connect(speak_rita)
    RitaDemands.subtitle_requested.connect(speak_rita)
    CallManager.subtitle_requested.connect(speak_call_dialogue)
    RunStats.denis_spoke.connect(speak_denis)
    MilkDelivery.courier_spoke.connect(speak_courier)

func speak_rita(text: String) -> void:
    _play_line(text, &"rita")

func speak_call_dialogue(text: String) -> void:
    if text in DENIS_CALL_REPLIES or text.begins_with("THE ПЛАТЁЖ ПОДТВЕРЖДЁН"):
        _play_line(text, &"denis")
    else:
        _play_line(text, &"call")

func speak_denis(text: String) -> void:
    _play_line(text, &"denis")

func speak_courier(text: String) -> void:
    _play_line(text, &"courier")

func voice_path_for(text: String, speaker: StringName) -> String:
    var canonical := _canonical_text(text, speaker)
    var speaker_lines: Dictionary = _manifest.get(String(speaker), {})
    return String(speaker_lines.get(canonical, ""))

func subtitle_hold_time(text: String) -> float:
    for speaker in [&"rita", &"call", &"denis", &"courier"]:
        var stream := _stream_for(text, speaker)
        if stream != null:
            return maxf(2.8, stream.get_length() + 0.35)
    return 2.8

func _play_line(text: String, speaker: StringName) -> bool:
    var stream := _stream_for(text, speaker)
    if stream == null:
        return false
    if _is_test_mode():
        return true
    # The courier is physically outside the apartment. His shout and Rita's
    # response are allowed to overlap instead of cancelling one another.
    var courier_player := _players.get(&"courier") as AudioStreamPlayer
    if speaker == &"courier":
        if courier_player == null:
            return false
        if courier_player.playing:
            courier_player.stop()
        courier_player.stream = stream
        courier_player.play()
        return true
    var rita_player := _players.get(&"rita") as AudioStreamPlayer
    if speaker != &"rita" and rita_player != null and rita_player.playing:
        return false
    for player_variant in _players.values():
        var other := player_variant as AudioStreamPlayer
        if other == courier_player:
            continue
        if other != null and other.playing:
            other.stop()
    var player := _players.get(speaker) as AudioStreamPlayer
    if player == null:
        return false
    player.stream = stream
    player.play()
    return true

func _stream_for(text: String, speaker: StringName) -> AudioStream:
    var path := voice_path_for(text, speaker)
    if path.is_empty():
        return null
    if _stream_cache.has(path):
        return _stream_cache[path] as AudioStream
    if not ResourceLoader.exists(path):
        return null
    var stream := load(path) as AudioStream
    if stream != null:
        _stream_cache[path] = stream
    return stream

func _canonical_text(text: String, speaker: StringName) -> String:
    if speaker == &"call" and text.begins_with("БЫЛ THE ПЛАТЁЖ"):
        return "Был THE Платёж, ты не успел. Жди следующий."
    if speaker == &"denis" and text.begins_with("THE ПЛАТЁЖ ПОДТВЕРЖДЁН"):
        return "THE Платёж подтверждён."
    return text

func _load_manifest() -> void:
    _manifest.clear()
    if not FileAccess.file_exists(MANIFEST_PATH):
        push_warning("Voice bank manifest is missing: %s" % MANIFEST_PATH)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if parsed is Dictionary:
        _manifest = parsed
    else:
        push_warning("Voice bank manifest is invalid: %s" % MANIFEST_PATH)

func _create_player(node_name: String, volume_db: float) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.name = node_name
    player.volume_db = volume_db
    player.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(player)
    return player

func _is_test_mode() -> bool:
    return "--run-foundation-tests" in OS.get_cmdline_user_args()
