extends "res://scripts/interactions/television.gd"

var channel_index: int = 0
var channels: Array[Dictionary] = [
    {"name": "ФУТБОЛ", "color": Color("4b8d58"), "noise": 6.5},
    {"name": "НОВОСТИ", "color": Color("307fd1"), "noise": 4.0},
    {"name": "МУЗЫКА", "color": Color("e5b74f"), "noise": 8.0},
    {"name": "КИНО", "color": Color("7f638f"), "noise": 5.0},
    {"name": "ТИШИНА", "color": Color("1a1a2a"), "noise": 0.5}
]
var is_smart_tv: bool = true
var voice_control_enabled: bool = false
var scheduled_recording: bool = false

func _ready() -> void:
    super._ready()
    add_to_group("smart_tv")

func get_prompt(_actor) -> String:
    if is_smart_tv and powered:
        return "СМАРТ-ТВ: %s | E — КАНАЛ+ | удерживать E — ЗВУК %s | Shift+E — РАСПИСАНИЕ" % [channels[channel_index]["name"], "ВЫКЛ" if muted else "ВКЛ"]
    return super.get_prompt(_actor)

func interact(actor, mode: int) -> String:
    if is_smart_tv and powered and mode == 0:  # InteractionMode.NORMAL
        channel_index = (channel_index + 1) % channels.size()
        _apply_channel()
        return "ПЕРЕКЛЮЧЕНО НА: %s" % channels[channel_index]["name"]
    return super.interact(actor, mode)

func _apply_channel() -> void:
    var channel := channels[channel_index]
    if _screen_fallback_material != null:
        _screen_fallback_material.albedo_color = channel["color"]
    if _score_label != null:
        _score_label.text = "СМАРТ-ТВ\n%s" % channel["name"]
    _update_screen()

func schedule_recording() -> String:
    scheduled_recording = not scheduled_recording
    return "ЗАПИСЬ %s" % ("ВКЛЮЧЕНА" if scheduled_recording else "ВЫКЛЮЧЕНА")

func enable_voice_control() -> String:
    voice_control_enabled = not voice_control_enabled
    return "ГОЛОСОВОЕ УПРАВЛЕНИЕ %s" % ("ВКЛЮЧЕНО" if voice_control_enabled else "ВЫКЛЮЧЕНО")
