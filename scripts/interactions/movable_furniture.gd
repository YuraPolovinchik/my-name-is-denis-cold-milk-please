extends "res://scripts/interactions/physical_item.gd"

func _ready() -> void:
    collision_layer = 2
    collision_mask = 3
    linear_damp = 2.8
    angular_damp = 3.4
    can_sleep = true
    continuous_cd = true
    axis_lock_angular_x = true
    axis_lock_angular_z = true
    freeze = true
    super._ready()
    add_to_group("movable_furniture")

func get_prompt(_actor) -> String:
    if mass <= 12.0:
        return "ЛКМ — ВЗЯТЬ В РУКИ: %s  [%.0f кг]" % [display_name, mass]
    if mass <= 35.0:
        return "УДЕРЖИВАТЬ ЛКМ — ПЕРЕНОСИТЬ ДВУМЯ РУКАМИ: %s  [%.0f кг]" % [display_name, mass]
    return "УДЕРЖИВАТЬ ЛКМ — ТАЩИТЬ ПО ПОЛУ: %s  [%.0f кг]" % [display_name, mass]
