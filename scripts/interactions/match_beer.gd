extends "res://scripts/interactions/physical_item.gd"

@export var sips_remaining := 6
@export var stamina_per_sip := 32.0
@export var intoxication_per_sip := 16.0

var _liquid_mesh: Node3D

func _ready() -> void:
    super._ready()
    add_to_group("match_beer")
    _update_liquid()

func configure_visuals(liquid_mesh: Node3D) -> void:
    _liquid_mesh = liquid_mesh
    _update_liquid()

func get_prompt(_actor) -> String:
    if sips_remaining <= 0:
        return "ПУСТАЯ БУТЫЛКА  •  ЛКМ — ВЗЯТЬ"
    return "E — ГЛОТОК ПОД ФУТБОЛ  •  ЛКМ — ВЗЯТЬ  [%d глотков]" % sips_remaining

func interact(actor, _mode: int) -> String:
    if held:
        return "СНАЧАЛА ПОСТАВЬ БУТЫЛКУ"
    var television := _nearest_powered_television(3.4)
    if television == null:
        return "ПИВО НЕ ЛЕЗЕТ  •  ПОСТАВЬ БУТЫЛКУ У ВКЛЮЧЁННОГО ТЕЛЕВИЗОРА"
    if television.has_method("complete_watch_with_beer"):
        return String(television.call("complete_watch_with_beer", actor, self))
    return take_sip(actor)

func take_sip(actor) -> String:
    if sips_remaining <= 0:
        return "БУТЫЛКА ПУСТА"
    if actor == null or not is_instance_valid(actor) or not actor.has_method("begin_drink_match_beer"):
        return "СЕЙЧАС НЕ ДО ПИВА"
    if not bool(actor.call("begin_drink_match_beer", self, stamina_per_sip, intoxication_per_sip)):
        return "РУКИ ЗАНЯТЫ  •  СНАЧАЛА ПОСТАВЬ ПРЕДМЕТ"
    sips_remaining -= 1
    _update_liquid()
    AudioManager.play_3d(&"clink", global_position, -13.0, 1.08)
    NoiseManager.emit_noise(global_position, 1.2, &"DISHES", &"beer_bottle")
    return "ДЕНИС ПОДНОСИТ БУТЫЛКУ  •  СИЛЫ +%.0f  •  КОНТРОЛЬ РУК ХУЖЕ" % stamina_per_sip

func _nearest_powered_television(radius: float) -> Node3D:
    var nearest: Node3D
    var best := radius
    for node in get_tree().get_nodes_in_group("television"):
        if node is Node3D and bool(node.get("powered")):
            var distance := global_position.distance_to((node as Node3D).global_position)
            if distance <= best:
                nearest = node
                best = distance
    return nearest

func _update_liquid() -> void:
    if _liquid_mesh == null:
        return
    var ratio := clampf(float(sips_remaining) / 6.0, 0.0, 1.0)
    _liquid_mesh.visible = sips_remaining > 0
    _liquid_mesh.scale.y = maxf(0.04, ratio)
    _liquid_mesh.position.y = -0.055 - (1.0 - ratio) * 0.085
