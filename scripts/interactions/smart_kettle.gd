extends "res://scripts/interactions/interactable.gd"

var temperature: float = 20.0
var target_temperature: float = 100.0
var heating_speed: float = 15.0
var keep_warm: bool = false
var scheduled_time: float = 0.0
var _is_heating: bool = false

func _ready() -> void:
    add_to_group("smart_kettle")
    display_name = "УМНЫЙ ЧАЙНИК"
    normal_noise = 3.0
    quiet_noise = 1.0
    fast_noise = 8.0
    noise_category = &"KETTLE"
    source_id = &"smart_kettle"

func _process(delta: float) -> void:
    if not RunStats.run_active:
        return
    if _is_heating:
        temperature = minf(temperature + heating_speed * delta, target_temperature)
        if temperature >= target_temperature:
            _is_heating = false
            temperature = target_temperature
            QuestManager.notification_requested.emit("УМНЫЙ ЧАЙНИК ДОСТИГ %d°C" % int(target_temperature))
            if keep_warm:
                _is_heating = true
                target_temperature = 85.0
    elif keep_warm and temperature < 80.0:
        temperature = minf(temperature + 2.0 * delta, 80.0)
    elif temperature > 25.0:
        temperature = maxf(temperature - 0.5 * delta, 25.0)
    _update_visuals()

func get_prompt(_actor) -> String:
    if _is_heating:
        return "НАГРЕВ: %d°C → %d°C" % [int(temperature), int(target_temperature)]
    if keep_warm:
        return "ПОДДЕРЖАНИЕ ТЕПЛА: %d°C" % int(temperature)
    return "УМНЫЙ ЧАЙНИК: %d°C" % int(temperature)

func perform_interaction(_actor, mode: int) -> String:
    match mode:
        InteractionMode.QUIET:
            target_temperature = 85.0
            _is_heating = true
            return "ТИХИЙ НАГРЕВ ДО 85°C"
        InteractionMode.FAST:
            target_temperature = 100.0
            heating_speed = 25.0
            _is_heating = true
            return "БЫСТРЫЙ НАГРЕВ ДО 100°C"
        _:
            target_temperature = 100.0
            heating_speed = 15.0
            _is_heating = true
            return "НАГРЕВ ДО 100°C"

func set_keep_warm(value: bool) -> void:
    keep_warm = value

func schedule_boiling(delay: float) -> String:
    scheduled_time = delay
    return "ЧАЙНИК ВКЛЮЧИТСЯ ЧЕРЕЗ %.0f СЕК" % delay

func configure_visuals(temp_label: Label3D, steam1: MeshInstance3D, steam2: MeshInstance3D, steam3: MeshInstance3D) -> void:
    _temp_label = temp_label
    _steam_particles = [steam1, steam2, steam3]

var _temp_label: Label3D = null
var _steam_particles: Array = []

func _update_visuals() -> void:
    if _temp_label:
        _temp_label.text = "%d°C" % int(temperature)
        if temperature >= 90.0:
            _temp_label.modulate = Color("ff4444")
        elif temperature >= 60.0:
            _temp_label.modulate = Color("ffaa00")
        else:
            _temp_label.modulate = Color("00ff00")
    
    for i in range(_steam_particles.size()):
        var steam: MeshInstance3D = _steam_particles[i]
        if steam:
            steam.visible = temperature > 70.0 and _is_heating
            if steam.visible:
                steam.position.y = 0.30 + float(i) * 0.08 + sin(Time.get_ticks_msec() * 0.002 + float(i)) * 0.02
                var scale_factor: float = 0.8 + sin(Time.get_ticks_msec() * 0.003 + float(i) * 2.0) * 0.2
                steam.scale = Vector3(scale_factor, 1.0, scale_factor)
