extends Node3D

var _time := 0.0
var _lights: Array[OmniLight3D] = []
var _flames: Array[Node3D] = []

func _ready() -> void:
    for child in get_children():
        if child is OmniLight3D:
            _lights.append(child)
        elif child is Node3D and String(child.name).begins_with("Flame"):
            _flames.append(child)
            child.set_meta("base_scale", child.scale)

func _process(delta: float) -> void:
    _time += delta
    var soft_flicker := 0.93 + sin(_time * 2.1) * 0.045 + sin(_time * 3.73 + 1.8) * 0.025
    for index in range(_lights.size()):
        _lights[index].light_energy = float(_lights[index].get_meta("base_energy", 0.8)) * soft_flicker
    for index in range(_flames.size()):
        var flame := _flames[index]
        var base_scale: Vector3 = flame.get_meta("base_scale", Vector3.ONE)
        flame.scale = Vector3(
            base_scale.x,
            base_scale.y * (0.86 + sin(_time * (2.5 + index * 0.07) + index) * 0.10),
            base_scale.z
        )
