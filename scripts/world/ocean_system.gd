class_name OceanSystem
extends Node3D

var clock: float = 0.0
var amplitude: float = 1.0
var wind_direction: Vector2 = Vector2(0.8, 0.6)
var material: ShaderMaterial
var surface: MeshInstance3D
var follow: Node3D

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/ocean.gdshader")
	surface = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	plane.subdivide_width = 256
	plane.subdivide_depth = 256
	surface.mesh = plane
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	# A cheap far surface sits below the dense local wave patch.
	var far_surface: MeshInstance3D = MeshInstance3D.new()
	var far_plane: PlaneMesh = PlaneMesh.new()
	far_plane.size = Vector2(18000, 18000)
	far_surface.mesh = far_plane
	far_surface.position.y = -5
	var far_material: StandardMaterial3D = ShipModel.material(Color("102c39"), 0.35)
	far_material.roughness = 0.3
	far_surface.material_override = far_material
	far_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far_surface)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var seabed: PlaneMesh = PlaneMesh.new()
	seabed.size = Vector2(18000, 18000)
	floor_mesh.mesh = seabed
	floor_mesh.position.y = -180
	floor_mesh.material_override = ShipModel.material(Color("172e32"), 0.0)
	add_child(floor_mesh)

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(follow):
		surface.global_position.x = snappedf(follow.global_position.x, 100)
		surface.global_position.z = snappedf(follow.global_position.z, 100)
	material.set_shader_parameter("clock", clock)
	material.set_shader_parameter("amplitude", amplitude)
	material.set_shader_parameter("direction", wind_direction)

func height_at(point: Vector3) -> float:
	var p: Vector2 = Vector2(point.x, point.z)
	return amplitude * (sin(p.dot(wind_direction) * 0.045 + clock * 0.9) * 0.65 + sin(p.dot(Vector2(-0.6, 0.8)) * 0.083 + clock * 1.37) * 0.35)
