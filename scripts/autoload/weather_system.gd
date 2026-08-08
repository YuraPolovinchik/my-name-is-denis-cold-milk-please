extends Node

signal weather_changed(new_weather: String, intensity: float)

var current_weather: String = "clear"
var weather_intensity: float = 0.0
var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.0)
var wind_speed: float = 0.0
var temperature: float = 12.0
var _weather_timer: float = 0.0
var _transition_time: float = 0.0
var _target_weather: String = "clear"
var _target_intensity: float = 0.0
var _rain_particles: CPUParticles3D
var _snow_particles: CPUParticles3D
var _fog_density: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_process_weather_transition(delta)
	_update_particles(delta)

func _process_weather_transition(delta: float) -> void:
	if _transition_time > 0.0:
		_transition_time = maxf(0.0, _transition_time - delta)
		var t := 1.0 - (_transition_time / 5.0)
		weather_intensity = lerpf(weather_intensity, _target_intensity, t)
		if _transition_time <= 0.0:
			current_weather = _target_weather
			weather_changed.emit(current_weather, weather_intensity)

func _update_particles(delta: float) -> void:
	if _rain_particles != null:
		_rain_particles.emitting = current_weather == "rain" and weather_intensity > 0.1
		if _rain_particles.emitting:
			_rain_particles.amount = int(weather_intensity * 2000)
	if _snow_particles != null:
		_snow_particles.emitting = current_weather == "snow" and weather_intensity > 0.1
		if _snow_particles.emitting:
			_snow_particles.amount = int(weather_intensity * 1000)

func set_weather(weather_type: String, intensity: float = 0.5, transition_duration: float = 5.0) -> void:
	_target_weather = weather_type
	_target_intensity = clampf(intensity, 0.0, 1.0)
	_transition_time = transition_duration
	match weather_type:
		"rain":
			_setup_rain()
		"snow":
			_setup_snow()
		"fog":
			_setup_fog()
		_:
			_clear_weather()

func _setup_rain() -> void:
	if _rain_particles == null:
		_rain_particles = CPUParticles3D.new()
		_rain_particles.name = "RainParticles"
		_rain_particles.lifetime = 1.5
		_rain_particles.speed_scale = 1.0
		_rain_particles.direction = Vector3(0.0, -1.0, 0.0)
		_rain_particles.spread = 10.0
		_rain_particles.gravity = Vector3(0.0, -15.0, 0.0)
		_rain_particles.initial_velocity_min = 8.0
		_rain_particles.initial_velocity_max = 12.0
		_rain_particles.scale_amount_min = 0.01
		_rain_particles.scale_amount_max = 0.03
		_rain_particles.color = Color(0.7, 0.75, 0.85, 0.6)
		add_child(_rain_particles)
	_rain_particles.emitting = true

func _setup_snow() -> void:
	if _snow_particles == null:
		_snow_particles = CPUParticles3D.new()
		_snow_particles.name = "SnowParticles"
		_snow_particles.lifetime = 4.0
		_snow_particles.speed_scale = 0.5
		_snow_particles.direction = Vector3(0.0, -1.0, 0.0)
		_snow_particles.spread = 45.0
		_snow_particles.gravity = Vector3(0.0, -2.0, 0.0)
		_snow_particles.initial_velocity_min = 1.0
		_snow_particles.initial_velocity_max = 3.0
		_snow_particles.scale_amount_min = 0.02
		_snow_particles.scale_amount_max = 0.05
		_snow_particles.color = Color(1.0, 1.0, 1.0, 0.8)
		add_child(_snow_particles)
	_snow_particles.emitting = true

func _setup_fog() -> void:
	_fog_density = weather_intensity * 0.05

## Установить случайную погоду
func randomize_weather() -> void:
	var weather_types := ["clear", "rain", "snow", "fog"]
	var random_type: String = weather_types[randi() % weather_types.size()]
	var random_intensity := randf_range(0.3, 0.8)
	set_weather(random_type, random_intensity)

func _clear_weather() -> void:
	if _rain_particles != null:
		_rain_particles.emitting = false
	if _snow_particles != null:
		_snow_particles.emitting = false
	_fog_density = 0.0

func get_wind_force() -> Vector3:
	return wind_direction * wind_speed

func get_temperature() -> float:
	return temperature
