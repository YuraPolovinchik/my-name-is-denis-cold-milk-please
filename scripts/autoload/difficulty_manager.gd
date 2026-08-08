extends Node

signal difficulty_changed(new_difficulty: String)

var current_difficulty: String = "normal"
var difficulty_multipliers: Dictionary = {
	"easy": {
		"rita_wake_speed": 0.6,
		"noise_decay": 1.5,
		"stamina_drain": 0.7,
		"call_frequency": 0.7,
		"hazard_delay": 1.5,
		"money_rate": 0.5
	},
	"normal": {
		"rita_wake_speed": 1.0,
		"noise_decay": 1.0,
		"stamina_drain": 1.0,
		"call_frequency": 1.0,
		"hazard_delay": 1.0,
		"money_rate": 1.0
	},
	"hard": {
		"rita_wake_speed": 1.5,
		"noise_decay": 0.7,
		"stamina_drain": 1.3,
		"call_frequency": 1.4,
		"hazard_delay": 0.6,
		"money_rate": 1.5
	},
	"nightmare": {
		"rita_wake_speed": 2.0,
		"noise_decay": 0.4,
		"stamina_drain": 1.8,
		"call_frequency": 2.0,
		"hazard_delay": 0.3,
		"money_rate": 2.0
	}
}

func set_difficulty(difficulty: String) -> void:
	if not difficulty_multipliers.has(difficulty):
		return
	current_difficulty = difficulty
	difficulty_changed.emit(difficulty)

func get_multiplier(key: String) -> float:
	var data: Dictionary = difficulty_multipliers.get(current_difficulty, {})
	return float(data.get(key, 1.0))

func get_rita_wake_speed() -> float:
	return get_multiplier("rita_wake_speed")

func get_noise_decay() -> float:
	return get_multiplier("noise_decay")

func get_stamina_drain() -> float:
	return get_multiplier("stamina_drain")

func get_call_frequency() -> float:
	return get_multiplier("call_frequency")

func get_hazard_delay() -> float:
	return get_multiplier("hazard_delay")

func get_money_rate() -> float:
	return get_multiplier("money_rate")
