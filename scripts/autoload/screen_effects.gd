extends Node

var _chromatic_aberration_amount: float = 0.0
var _vignette_intensity: float = 0.0
var _vignette_color: Color = Color.BLACK
var _pulse_time: float = 0.0
var _screen_shake_strength: float = 0.0
var _screen_shake_decay: float = 5.0
var _shake_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_process_screen_shake(delta)
	_process_pulse(delta)

func _process_screen_shake(delta: float) -> void:
	if _screen_shake_strength <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	_screen_shake_strength = maxf(0.0, _screen_shake_strength - _screen_shake_decay * delta)
	var intensity := _screen_shake_strength * 0.5
	_shake_offset = Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
	var viewport := get_viewport()
	if viewport != null:
		viewport.canvas_transform.origin = _shake_offset

func _process_pulse(delta: float) -> void:
	if _vignette_intensity > 0.0:
		_pulse_time += delta * 2.0

func add_screen_shake(strength: float, decay: float = 5.0) -> void:
	_screen_shake_strength = maxf(_screen_shake_strength, strength)
	_screen_shake_decay = decay

func set_chromatic_aberration(amount: float) -> void:
	_chromatic_aberration_amount = clampf(amount, 0.0, 1.0)

func set_vignette(intensity: float, color: Color = Color.BLACK) -> void:
	_vignette_intensity = clampf(intensity, 0.0, 1.0)
	_vignette_color = color

## Обёртка: хроматическая аберрация с пульсацией (совместимость с rita_sleep.gd)
func chromatic_aberration_pulse(amount: float, _duration: float = 0.5) -> void:
	set_chromatic_aberration(amount)
	var tween := create_tween()
	tween.tween_property(self, "_chromatic_aberration_amount", 0.0, _duration)

## Обёртка: пульс виньетки (совместимость с rita_sleep.gd)
func vignette_pulse(intensity: float, _duration: float = 0.5) -> void:
	pulse_vignette(intensity, _duration)

## Обёртка: тряска экрана (совместимость с rita_sleep.gd)
func shake(strength: float, _duration: float = 0.3) -> void:
	add_screen_shake(strength, strength / maxf(_duration, 0.01))

func pulse_vignette(intensity: float, duration: float = 0.5) -> void:
	var tween := create_tween()
	var original := _vignette_intensity
	tween.tween_property(self, "_vignette_intensity", intensity, duration * 0.3)
	tween.tween_property(self, "_vignette_intensity", original, duration * 0.7)

func get_chromatic_aberration() -> float:
	return _chromatic_aberration_amount

func get_vignette_intensity() -> float:
	return _vignette_intensity

func get_vignette_color() -> Color:
	return _vignette_color
