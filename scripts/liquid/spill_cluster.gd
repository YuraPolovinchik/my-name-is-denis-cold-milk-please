# SpillCluster.gd
# Визуальное пятно (лужа) на поверхности после разлива жидкости (§11 миссии).
# Типизированное: вода/молоко/кофе/порошок имеют разный вид.
class_name SpillCluster
extends MeshInstance3D

## Цвет жидкости
var liquid_color: Color = Color.WHITE

## Тип жидкости ("water" | "milk" | "coffee_mix" | "coffee_powder")
var liquid_type: String = "water"

## Радиус лужи
var radius: float = 0.05

## Реальный остаток жидкости в пятне.
var volume_ml: float = 0.0
var initial_volume_ml: float = 0.0

## Время жизни (0 = бесконечно)
@export var lifetime: float = 0.0

var _age: float = 0.0
var _mat: StandardMaterial3D = null


func _ready():
	add_to_group("spills")
	create_mesh()


func create_mesh():
	# Плоский круг (CylinderMesh с нулевой высотой) — лежит на поверхности без z-fighting
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.002
	cm.radial_segments = 16
	mesh = cm

	_mat = StandardMaterial3D.new()
	_mat.flags_transparent = true
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Порошок — матовый и почти непрозрачный; жидкости — глянец
	if liquid_type == "coffee_powder":
		_mat.albedo_color = Color(liquid_color.r, liquid_color.g, liquid_color.b, 0.95)
	else:
		var remaining_ratio := clampf(volume_ml / maxf(initial_volume_ml, volume_ml), 0.0, 1.0)
		var visible_alpha := liquid_color.a * lerpf(0.28, 1.0, sqrt(remaining_ratio))
		_mat.albedo_color = Color(liquid_color.r, liquid_color.g, liquid_color.b, visible_alpha)
		_mat.metallic = 0.3
		_mat.roughness = 0.15
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Увеличить лужу при повторном попадании (слияние §11 миссии).
func grow(amount: float) -> void:
	radius = clampf(radius + amount, 0.04, 0.25)
	create_mesh()

## Добавить реальный объём и пересчитать размер пятна.
func add_volume(amount_ml: float) -> void:
	volume_ml = maxf(0.0, volume_ml + amount_ml)
	initial_volume_ml = maxf(initial_volume_ml, volume_ml)
	_update_radius_from_volume()

## Постепенно впитать жидкость. Возвращает фактически убранный объём.
func absorb_ml(amount_ml: float) -> float:
	var absorbed := minf(maxf(amount_ml, 0.0), volume_ml)
	volume_ml = maxf(0.0, volume_ml - absorbed)
	if volume_ml <= 0.05:
		volume_ml = 0.0
	else:
		_update_radius_from_volume()
	return absorbed

func is_empty() -> bool:
	return volume_ml <= 0.05

func _update_radius_from_volume() -> void:
	# Площадь растёт вместе с объёмом, но пятно остаётся бытового масштаба.
	radius = clampf(0.035 + sqrt(maxf(volume_ml, 0.0)) * 0.018, 0.04, 0.32)
	create_mesh()


func _process(delta: float):
	if lifetime > 0:
		_age += delta
		if _age >= lifetime:
			var fade: float = 1.0 - ((_age - lifetime) / 5.0)
			if fade <= 0.0:
				queue_free()
			elif _mat:
				var c: Color = _mat.albedo_color
				c.a = clampf(fade * 0.6, 0.0, 0.95)
				_mat.albedo_color = c
