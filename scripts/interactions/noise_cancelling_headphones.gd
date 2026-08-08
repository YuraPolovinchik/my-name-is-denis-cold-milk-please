extends "res://scripts/interactions/physical_item.gd"

var noise_reduction: float = 0.7
var battery: float = 100.0
var _active: bool = false
var _original_noise_callback: Callable

func _ready() -> void:
    super._ready()
    add_to_group("headphones")
    add_to_group("noise_cancelling")
    display_name = "ШУМОПОДАВЛЯЮЩИЕ НАУШНИКИ"
    mass = 0.25
    impact_noise_scale = 0.3

func _process(delta: float) -> void:
    if _active:
        battery = maxf(0.0, battery - 0.5 * delta)
        if battery <= 0.0:
            deactivate()
    _update_led()

func get_prompt(_actor) -> String:
    if held:
        if _active:
            return "НАУШНИКИ АКТИВНЫ [%.0f%%] — E — ВЫКЛЮЧИТЬ" % battery
        return "E — ВКЛЮЧИТЬ ШУМОПОДАВЛЕНИЕ [%.0f%%]" % battery
    return "ЛКМ — ВЗЯТЬ: ШУМОПОДАВЛЯЮЩИЕ НАУШНИКИ [%.1f кг]" % mass

func interact(actor, mode: int) -> String:
    if not held:
        return "СНАЧАЛА ВОЗЬМИ НАУШНИКИ"
    if mode == 0:  # InteractionMode.NORMAL
        if _active:
            deactivate()
            return "ШУМОПОДАВЛЕНИЕ ВЫКЛЮЧЕНО"
        activate()
        return "ШУМОПОДАВЛЕНИЕ ВКЛЮЧЕНО [%.0f%%]" % battery
    return "ШУМОПОДАВЛЕНИЕ: %s" % ("АКТИВНО" if _active else "ВЫКЛ")

func activate() -> void:
    if _active:
        return
    _active = true
    NoiseManager.set_meta("player_noise_reduction", noise_reduction)

func deactivate() -> void:
    if not _active:
        return
    _active = false
    NoiseManager.remove_meta("player_noise_reduction")

func get_noise_reduction() -> float:
    return noise_reduction if _active else 0.0

func configure_visuals(led_indicator: MeshInstance3D) -> void:
    _led = led_indicator

var _led: MeshInstance3D = null

func _update_led() -> void:
    if _led:
        _led.visible = _active
        if _active and battery < 20.0:
            # Мигание при низком заряде
            _led.visible = int(Time.get_ticks_msec() / 500) % 2 == 0
