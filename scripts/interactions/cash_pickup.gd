extends "res://scripts/interactions/interactable.gd"

@export var amount := 200.0
var collected := false

func _ready() -> void:
    add_to_group("cash_stash")

func get_prompt(_actor) -> String:
    return "ПОДОБРАТЬ ДЕНЬГИ — %.0f ₽" % amount

func perform_interaction(_actor, _mode: int) -> String:
    if collected:
        return "ЗДЕСЬ БОЛЬШЕ НЕТ ДЕНЕГ"
    collected = true
    RunStats.collect_cash(amount, has_meta("static_cash"))
    RunStats.denis_spoke.emit("Это не воровство.")
    AudioManager.play_ui(&"success", -12.0)
    visible = false
    call_deferred("queue_free")
    return "ЭТО НЕ ВОРОВСТВО  •  НАЙДЕНО %.0f ₽  •  БАЛАНС %.0f ₽" % [amount, RunStats.money_balance]
