# StreamRenderer.gd
# Визуализирует струю жидкости как баллистическую ленту (ImmediateMesh).
# §8 миссии: ЕДИНАЯ баллистическая траектория для визуала и физики.
# PourController запрашивает точки через compute_trajectory_points().
extends MeshInstance3D

## Число сегментов струи (§8: 12-16)
@export var segments: int = 14

## Гравитация струи (м/с²)
@export var gravity: Vector3 = Vector3(0, -7.5, 0)

## Базовая скорость вылета (м/с) при макс. потоке
@export var base_velocity: float = 1.8

## Шаг по времени между сегментами (с)
@export var time_step: float = 0.035

var _mesh: ImmediateMesh
var _material: StandardMaterial3D
var _stream_color: Color = Color(0.7, 0.85, 1.0, 0.75)
var _segment_visuals: Array[MeshInstance3D] = []

## Последняя вычисленная траектория (мировые координаты) — кэш для физики
var last_trajectory: PackedVector3Array = PackedVector3Array()


func _ready():
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	# Vertices are authored in world space so the renderer must not inherit the
	# player's transform a second time.
	top_level = true
	global_transform = Transform3D.IDENTITY

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.flags_transparent = true
	_material.vertex_color_use_as_albedo = true
	_material.flags_no_depth_test = true
	_material.albedo_color = _stream_color
	material_override = _material

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	visible = false
	for segment_index in range(segments):
		var segment_mesh := CylinderMesh.new()
		segment_mesh.top_radius = 0.5
		segment_mesh.bottom_radius = 0.5
		segment_mesh.height = 1.0
		segment_mesh.radial_segments = 8
		var segment_visual := MeshInstance3D.new()
		segment_visual.name = "StreamSegment_%02d" % segment_index
		segment_visual.mesh = segment_mesh
		segment_visual.material_override = _material
		segment_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment_visual.visible = false
		add_child(segment_visual)
		_segment_visuals.append(segment_visual)


## Вычислить баллистические точки траектории (мировые координаты).
## Используется И визуалом, И физикой попадания (§8 миссии).
## flow_fraction (0..1) масштабирует скорость вылета — тонкая струя у пустого чайника.
func compute_trajectory_points(origin: Vector3, direction: Vector3, flow_fraction: float = 1.0) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.resize(segments + 1)
	var speed: float = base_velocity * lerpf(0.55, 1.0, clampf(flow_fraction, 0.0, 1.0))
	var vel: Vector3 = direction.normalized() * speed
	for i in range(segments + 1):
		var t: float = float(i) * time_step
		pts[i] = origin + vel * t + 0.5 * gravity * t * t
	return pts


## Обновить струю. flow_rate_ml_s — текущий поток (0 = скрыть).
## width — толщина струи в метрах.
func update_stream(origin: Vector3, direction: Vector3, flow_rate_ml_s: float, width: float, flow_fraction: float = 1.0) -> void:
	if flow_rate_ml_s <= 0.0:
		visible = false
		for segment_visual in _segment_visuals:
			segment_visual.visible = false
		last_trajectory = PackedVector3Array()
		return
	visible = true
	last_trajectory = compute_trajectory_points(origin, direction, flow_fraction)
	global_transform = Transform3D(Basis.IDENTITY, origin)

	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	# Вектор "вбок" для ленты — перпендикуляр направлению в горизонтали
	var cam_basis_y := Vector3.UP
	var half_w := width * 0.5
	for i in range(last_trajectory.size()):
		var p: Vector3 = last_trajectory[i]
		# Направление сегмента
		var seg_dir: Vector3
		if i < last_trajectory.size() - 1:
			seg_dir = (last_trajectory[i + 1] - p).normalized()
		else:
			seg_dir = (p - last_trajectory[i - 1]).normalized()
		var side: Vector3 = seg_dir.cross(cam_basis_y).normalized()
		if side.length_squared() < 0.001:
			side = Vector3.RIGHT
		# Сужение к концу + затухание альфы
		var taper: float = pow(0.97, float(i))
		var alpha: float = lerpf(0.85, 0.15, float(i) / float(segments))
		var col := Color(_stream_color.r, _stream_color.g, _stream_color.b, alpha)
		var w := half_w * taper
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex((p - side * w) - origin)
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex((p + side * w) - origin)

	_mesh.surface_end()
	for segment_index in range(_segment_visuals.size()):
		var segment_visual := _segment_visuals[segment_index]
		if segment_index >= last_trajectory.size() - 1:
			segment_visual.visible = false
			continue
		var local_start := last_trajectory[segment_index] - origin
		var local_end := last_trajectory[segment_index + 1] - origin
		var segment_delta := local_end - local_start
		var segment_length := segment_delta.length()
		if segment_length <= 0.0001:
			segment_visual.visible = false
			continue
		var segment_taper := pow(0.97, float(segment_index))
		var segment_width := maxf(width * segment_taper, 0.004)
		segment_visual.position = (local_start + local_end) * 0.5
		segment_visual.quaternion = Quaternion(Vector3.UP, segment_delta / segment_length)
		segment_visual.scale = Vector3(segment_width, segment_length, segment_width)
		segment_visual.visible = true


## Установить цвет струи (по жидкости).
func set_stream_color(color: Color) -> void:
	_stream_color = color
	if _material != null:
		_material.albedo_color = color
