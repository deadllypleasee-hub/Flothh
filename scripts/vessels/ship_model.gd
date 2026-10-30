class_name ShipModel
extends Node3D
## Original procedural geometry. Local bow = -Z; one world unit = one metre.
var turret: Node3D
var propeller: Node3D
var damage_marker: MeshInstance3D

static func material(color: Color, metal: float = 0.5) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.57
	return mat

func piece(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = mesh
	item.position = pos
	item.material_override = mat
	parent.add_child(item)
	return item

func box(dimensions: Vector3, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	return piece(mesh, pos, mat, parent)

func build(stats: Dictionary, team: int) -> void:
	var l: float = stats["length"]
	var b: float = stats["beam"]
	var hull: StandardMaterial3D = material(Color("344958") if team == 0 else Color("564c50"))
	var deck: StandardMaterial3D = material(Color("626f72"))
	var dark: StandardMaterial3D = material(Color("1b2830"))
	var stripe: StandardMaterial3D = material(Color("48c5ce") if team == 0 else Color("e07555"))
	if stats["submarine"]:
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = b * 0.5
		capsule.height = l
		capsule.radial_segments = 16
		capsule.rings = 6
		var body: MeshInstance3D = piece(capsule, Vector3(0, -2, 0), dark)
		body.rotation.x = PI / 2
		box(Vector3(b * 0.40, b * 0.65, l * 0.16), Vector3(0, b * 0.25, -l * 0.08), hull)
		box(Vector3(b * 1.8, 0.4, 3), Vector3(0, -1.5, l * 0.35), hull)
		box(Vector3(0.5, b * 1.5, 4), Vector3(0, -1.5, l * 0.38), hull)
		box(Vector3(0.3, 5, 0.3), Vector3(0, b * 0.7, -l * 0.08), deck)
		box(Vector3(b * 0.44, 0.2, 1), Vector3(0, b * 0.59, -l * 0.08), stripe)
	else:
		piece(hull_mesh(l, b), Vector3.ZERO, hull)
		box(Vector3(b * 0.68, 3, l * 0.38), Vector3(0, 4, l * 0.04), deck)
		box(Vector3(b * 0.52, 4, l * 0.13), Vector3(0, 7, -l * 0.08), hull)
		box(Vector3(b * 0.55, 1.5, l * 0.04), Vector3(0, 8, -l * 0.155), dark)
		box(Vector3(b * 0.56, 0.4, l * 0.045), Vector3(0, 9, -l * 0.16), stripe)
		box(Vector3(1, 12, 1), Vector3(0, 13, 0), hull)
		box(Vector3(b * 0.65, 2.5, 0.65), Vector3(0, 17, 0), deck)
		box(Vector3(b * 0.35, 5, l * 0.06), Vector3(0, 8, l * 0.14), dark)
		for side: int in [-1, 1]:
			for i: int in 4:
				box(Vector3(1.2, 1, 2.4), Vector3(side * b * 0.25, 6, l * (0.02 + i * 0.025)), dark)
		turret = Node3D.new()
		turret.position = Vector3(0, 3.5, -l * 0.31)
		add_child(turret)
		box(Vector3(b * 0.45, 3, l * 0.07), Vector3.ZERO, deck, turret)
		box(Vector3(0.65, 0.65, l * 0.11), Vector3(0, 0.5, -l * 0.07), dark, turret)
		if stats["id"] == "carrier":
			box(Vector3(b, 1, l * 0.89), Vector3(0, 10, 0), dark)
			box(Vector3(0.5, 0.08, l * 0.80), Vector3(-b * 0.2, 10.6, 0), stripe)
			for i: int in 4:
				box(Vector3(9, 0.5, 3), Vector3(b * 0.28, 11.5, i * 15.0 - 25), deck)
		# Rails, helipad and lifeboats are culled beyond 650 metres.
		var details: Node3D = Node3D.new()
		add_child(details)
		for side: int in [-1, 1]:
			for i: int in 10:
				box(Vector3(0.12, 1.3, 0.12), Vector3(side * b * 0.39, 3.7, l * (-0.26 + i * 0.065)), deck, details)
			box(Vector3(0.12, 0.12, l * 0.6), Vector3(side * b * 0.39, 4.3, l * 0.03), deck, details)
		for item: Node in details.get_children():
			(item as GeometryInstance3D).visibility_range_end = 650
		box(Vector3(b * 0.7, 0.1, l * 0.15), Vector3(0, 3.1, l * 0.30), dark)
		box(Vector3(b * 0.42, 0.12, 0.35), Vector3(0, 3.2, l * 0.30), stripe)
	propeller = Node3D.new()
	propeller.position = Vector3(0, -2, l * 0.49)
	add_child(propeller)
	box(Vector3(b * 0.5, 0.3, 0.6), Vector3.ZERO, deck, propeller)
	box(Vector3(0.3, b * 0.5, 0.6), Vector3.ZERO, deck, propeller)
	damage_marker = box(Vector3(b * 0.6, 0.2, 5), Vector3(0, 6, 4), material(Color("261c19")))
	damage_marker.visible = false

static func hull_mesh(length: float, beam: float) -> ArrayMesh:
	var rings: Array[Vector3] = []
	var zs: Array[float] = [-0.50, -0.40, -0.20, 0.25, 0.48]
	var widths: Array[float] = [0.015, 0.31, 0.50, 0.49, 0.34]
	for i: int in zs.size():
		var w: float = beam * widths[i]
		var z: float = length * zs[i]
		rings.append_array([Vector3(-w, 3, z), Vector3(w, 3, z), Vector3(w * 0.72, -3.5, z), Vector3(-w * 0.72, -3.5, z)])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 4:
		for j: int in 4:
			var a: Vector3 = rings[i * 4 + j]
			var b: Vector3 = rings[i * 4 + (j + 1) % 4]
			var c: Vector3 = rings[(i + 1) * 4 + j]
			var d: Vector3 = rings[(i + 1) * 4 + (j + 1) % 4]
			for v: Vector3 in [a, c, b, b, c, d]:
				st.add_vertex(v)
	for base: int in [0, 16]:
		for index: int in ([0, 1, 2, 0, 2, 3] if base == 0 else [0, 2, 1, 0, 3, 2]):
			st.add_vertex(rings[base + index])
	st.generate_normals()
	return st.commit()
