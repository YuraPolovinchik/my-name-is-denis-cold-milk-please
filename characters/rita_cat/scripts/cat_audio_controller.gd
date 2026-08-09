class_name CatAudioController
extends Node

var last_meow_msec := -10000

func meow(strength := 3.5) -> void:
	if Time.get_ticks_msec() - last_meow_msec < 900:
		return
	last_meow_msec = Time.get_ticks_msec()
	var host := get_parent() as Node3D
	if host == null:
		return
	AudioManager.play_3d(&"cat_meow", host.global_position, -12.0, randf_range(0.88, 1.12))
	NoiseManager.emit_noise(host.global_position, strength, &"CAT", &"rita_cat")

func panic_yowl(strength := 9.0) -> void:
	# Panic has its own tighter cadence and a louder, less predictable voice.
	# The story still spaces calls out, so this cannot become a per-frame loop.
	if Time.get_ticks_msec() - last_meow_msec < 520:
		return
	last_meow_msec = Time.get_ticks_msec()
	var host := get_parent() as Node3D
	if host == null:
		return
	AudioManager.play_3d(&"cat_meow", host.global_position, -4.0, randf_range(0.74, 1.22))
	NoiseManager.emit_noise(host.global_position, strength, &"CAT", &"rita_cat_panic")

func friendly_chirp() -> void:
	_play_soft_voice(1.28, -17.0)

func purr() -> void:
	_play_soft_voice(0.54, -22.0)

func _play_soft_voice(pitch: float, volume_db: float) -> void:
	if Time.get_ticks_msec() - last_meow_msec < 500:
		return
	last_meow_msec = Time.get_ticks_msec()
	var host := get_parent() as Node3D
	if host != null:
		AudioManager.play_3d(&"cat_meow", host.global_position, volume_db, pitch)
