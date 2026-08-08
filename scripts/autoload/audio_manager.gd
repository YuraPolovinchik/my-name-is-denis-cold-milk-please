extends Node

const SOUND_PATHS := {
    &"step": "res://assets/audio/step.wav",
    &"cloth_step": "res://assets/audio/cloth_step.wav",
    &"door": "res://assets/audio/door.wav",
    &"drawer": "res://assets/audio/drawer.wav",
    &"clink": "res://assets/audio/clink.wav",
    &"switch": "res://assets/audio/switch.wav",
    &"buzz": "res://assets/audio/buzz.wav",
    &"vacuum": "res://assets/audio/vacuum.wav",
    &"kettle": "res://assets/audio/kettle.wav",
    &"success": "res://assets/audio/success.wav",
    &"ui": "res://assets/audio/ui.wav",
    &"ambience": "res://assets/audio/ambience.wav",
    &"cat_meow": "res://characters/rita_cat/audio/cat_meow.wav"
}

var _streams: Dictionary = {}

func _ready() -> void:
    for key in SOUND_PATHS:
        var stream: AudioStream = load(SOUND_PATHS[key])
        if stream != null:
            _streams[key] = stream

func play_3d(sound_id: StringName, position: Vector3, volume_db := -8.0, pitch := 1.0) -> void:
    if _tests_running():
        return
    if not _streams.has(sound_id):
        return
    var player := AudioStreamPlayer3D.new()
    player.stream = _streams[sound_id]
    player.position = position
    player.volume_db = volume_db
    player.pitch_scale = pitch
    player.max_distance = 18.0
    player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func play_ui(sound_id: StringName = &"ui", volume_db := -10.0, pitch := 1.0) -> void:
    if _tests_running():
        return
    if not _streams.has(sound_id):
        return
    var player := AudioStreamPlayer.new()
    player.stream = _streams[sound_id]
    player.volume_db = volume_db
    player.pitch_scale = pitch
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func create_ambience(parent: Node) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    if _tests_running():
        parent.add_child(player)
        return player
    if _streams.has(&"ambience"):
        var source: AudioStream = _streams[&"ambience"]
        if source is AudioStreamWAV:
            var looped := source.duplicate() as AudioStreamWAV
            looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
            player.stream = looped
        else:
            player.stream = source
    player.volume_db = -24.0
    parent.add_child(player)
    if player.stream != null:
        player.play()
    return player

func _tests_running() -> bool:
    return "--run-foundation-tests" in OS.get_cmdline_user_args()
