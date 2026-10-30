class_name TerrainSystem
extends Node3D

const ISLANDS: Array[Dictionary] = [
	{"x": -2200.0, "z": -1500.0, "radius": 530.0, "height": 180.0},
	{"x": 2300.0, "z": -1900.0, "radius": 650.0, "height": 240.0},
	{"x": 1800.0, "z": 1900.0, "radius": 450.0, "height": 125.0},
	{"x": -2300.0, "z": 2100.0, "radius": 700.0, "height": 170.0}]
var islands: Array[Dictionary] = ISLANDS.duplicate(true)
var port_position: Vector3 = Vector3(-1500, 0, 1950)

func _ready() -> void:
	var rock: StandardMaterial3D = ShipModel.material(Color("53645a"), 0)
	var sand: StandardMaterial3D = ShipModel.material(Color("8d8971"), 0)
	for island: Dictionary in islands:
		var body: StaticBody3D = StaticBody3D.new()
		body.position = Vector3(island["x"], -65, island["z"])
		add_child(body)
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = island["radius"] * 0.78
		shape.height = 230
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		for layer: int in 3:
			var mesh: CylinderMesh = CylinderMesh.new()
			mesh.bottom_radius = island["radius"] * (1.25 - layer * 0.3)
			mesh.top_radius = island["radius"] * (0.66 - layer * 0.24)
			mesh.height = island["height"] * 0.7
			mesh.radial_segments = 11
			var instance: MeshInstance3D = MeshInstance3D.new()
			instance.mesh = mesh
			instance.material_override = sand if layer == 0 else rock
			instance.position.y = layer * island["height"] * 0.38
			instance.rotation.y = layer * 0.53
			body.add_child(instance)
	var structures: ShipModel = ShipModel.new()
	add_child(structures)
	var concrete: StandardMaterial3D = ShipModel.material(Color("68767b"), 0.1)
	var dark: StandardMaterial3D = ShipModel.material(Color("283b48"))
	structures.box(Vector3(85, 10, 290), port_position + Vector3(-80, 0, 0), concrete)
	for i: int in 3:
		var pier: Vector3 = port_position + Vector3(i * 45, 0, i * 80 - 80)
		structures.box(Vector3(130, 7, 18), pier, concrete)
		var body: StaticBody3D = StaticBody3D.new()
		body.position = pier
		add_child(body)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(130, 7, 18)
		collision.shape = shape
		body.add_child(collision)
		structures.box(Vector3(32, 25, 45), port_position + Vector3(-110, 15, i * 90 - 80), dark)
		structures.box(Vector3(3, 50, 3), pier + Vector3(-25, 28, 0), concrete)
		structures.box(Vector3(70, 3, 3), pier + Vector3(5, 52, 0), concrete)
	# Lighthouse, navigational buoys and a modest underwater rock field.
	structures.box(Vector3(12, 55, 12), Vector3(-1800, 36, -1400), concrete)
	var beacon: StandardMaterial3D = ShipModel.material(Color("ffe8a1"), 0)
	beacon.emission_enabled = true
	beacon.emission = Color("ffc76e")
	structures.box(Vector3(15, 5, 15), Vector3(-1800, 65, -1400), beacon)
	for i: int in 8:
		var p: Vector3 = Vector3(-1250 + (i % 2) * 200, 1, 1300 + (i / 2) * 180)
		structures.box(Vector3(3, 4, 3), p, ShipModel.material(Color("58c9aa") if i % 2 == 0 else Color("cf7866")))
	for i: int in 14:
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 80 + i * 4
		mesh.height = mesh.radius * 1.3
		mesh.radial_segments = 12
		mesh.rings = 6
		structures.piece(mesh, Vector3(sin(i * 2.3) * 3100, -165, cos(i * 2.3) * 3000), rock)
