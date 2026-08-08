extends "res://scripts/interactions/interactable.gd"

signal worshipped(first_time: bool)

var worship_count := 0

func _ready() -> void:
    display_name = "THE ПЛАТЕЖ"
    normal_noise = 0.5
    quiet_noise = 0.1
    fast_noise = 1.5
    normal_duration = 0.55
    quiet_duration = 0.9
    fast_duration = 0.25
    noise_category = &"PAYMENT_ALTAR"
    source_id = &"payment_relic"
    add_to_group("payment_altar_interaction")

func get_prompt(_actor) -> String:
    return "E — ПОКЛОНИТЬСЯ THE ПЛАТЕЖУ"

func perform_interaction(actor, _mode: int) -> String:
    var first_time := worship_count == 0
    worship_count += 1
    if RunStats.has_method("record_payment_altar_bow"):
        RunStats.record_payment_altar_bow()
    _camera_reverence(actor)
    AudioManager.play_3d(&"success", global_position, -10.0, 0.62)
    worshipped.emit(first_time)
    var lines := [
        "КОГДА-НИБУДЬ.",
        "Я ВСЁ ЕЩЁ ВЕРЮ.",
        "СЕГОДНЯ ТОЧНО.",
        "НЕ ПОДВЕДИ.",
        "СТО ДНЕЙ — ЭТО УЖЕ ОТНОШЕНИЯ."
    ]
    return lines[(worship_count - 1) % lines.size()]

func _camera_reverence(actor: Node) -> void:
    if actor == null:
        return
    var camera := actor.get_node_or_null("Camera") as Camera3D
    if camera == null:
        return
    var original_fov := camera.fov
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(camera, "fov", maxf(48.0, original_fov - 7.0), 0.42)
    tween.tween_interval(0.35)
    tween.tween_property(camera, "fov", original_fov, 0.65)

