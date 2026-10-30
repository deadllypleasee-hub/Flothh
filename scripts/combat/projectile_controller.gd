class_name ProjectileController
extends Node3D
## Reusable projectile, continuous segment collision against hull proxies.
var active: bool = false
var kind: String = "gun"
var launcher: ShipController
var target: ShipController
var system: CombatSystem
var direction: Vector3 = Vector3.FORWARD
var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0
var travelled: float = 0
var trail_timer: float = 0
var visual: MeshInstance3D
var motor: MeshInstance3D

func _ready() -> void:
	visual = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = 0.65 if kind != "gun" else 0.3
	mesh.height = 5 if kind != "gun" else 2
	mesh.radial_segments = 8
	mesh.rings = 2
	visual.mesh = mesh
	visual.rotation.x = PI / 2
	var mat: StandardMaterial3D = ShipModel.material(Color("cfdbdf"))
	if kind == "gun":
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color("ffce76")
	visual.material_override = mat
	add_child(visual)
	motor = MeshInstance3D.new()
	var flame: SphereMesh = SphereMesh.new()
	flame.radius = 1
	flame.height = 4
	flame.radial_segments = 6
	flame.rings = 3
	motor.mesh = flame
	var glow: StandardMaterial3D = ShipModel.material(Color("ffae4b"), 0)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.emission_enabled = true
	glow.emission = Color("ffae4b")
	motor.material_override = glow
	motor.position.z = 3.5
	motor.rotation.x = PI / 2
	add_child(motor)
	visible = false

func launch(owner_ship: ShipController, enemy: ShipController, point: Vector3, aim: Vector3) -> void:
	launcher = owner_ship
	target = enemy
	global_position = point
	direction = aim.normalized()
	velocity = direction * system.WEAPONS[kind]["speed"]
	lifetime = 0
	travelled = 0
	trail_timer = 0
	active = true
	visible = true
	motor.visible = kind == "missile"
	if kind == "gun" and enemy != null:
		var flight_time: float = point.distance_to(enemy.global_position) / system.WEAPONS[kind]["speed"]
		velocity = (enemy.global_position + enemy.velocity * flight_time - point) / maxf(0.01, flight_time)
		velocity.y += 0.5 * 9.8 * flight_time

func _physics_process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	trail_timer += delta
	var previous: Vector3 = global_position
	guide(delta)
	global_position += velocity * delta
	travelled += previous.distance_to(global_position)
	if velocity.length_squared() > 0.01:
		direction = velocity.normalized()
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT)
	var first: ShipController = null
	var nearest_fraction: float = 2.0
	for ship: ShipController in system.world.ships:
		if ship == launcher or ship.damage.sinking:
			continue
		# Ellipsoid in vessel-local coordinates; reduces false hits beside long hulls.
		var inverse: Transform3D = ship.global_transform.affine_inverse()
		var a: Vector3 = inverse * previous
		var b: Vector3 = inverse * global_position
		var extents: Vector3 = Vector3(ship.stats["beam"] * 0.6 + 2, 7, ship.stats["length"] * 0.48)
		var fraction: float = segment_ellipsoid(a / extents, b / extents)
		if fraction >= 0 and fraction < nearest_fraction:
			nearest_fraction = fraction
			first = ship
	if first != null:
		global_position = previous.lerp(global_position, nearest_fraction)
		system.impact(self, first)
		deactivate()
		return
	# Terrain collisions share the same metre coordinates as the map and ships.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous, global_position, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		system.impact(self, null)
		deactivate()
		return
	if kind == "gun" and global_position.y <= system.world.ocean.height_at(global_position):
		system.effects.spawn_effect("splash", global_position)
		deactivate()
	elif lifetime > 45 or travelled > float(system.WEAPONS[kind]["range"]):
		deactivate()
	elif trail_timer > (0.18 if kind == "missile" else 0.4):
		trail_timer = 0
		if kind != "gun":
			system.effects.spawn_effect("trail" if kind == "missile" else "bubble", global_position)

func guide(_delta: float) -> void:
	velocity.y -= 9.8 * _delta

static func segment_ellipsoid(a: Vector3, b: Vector3) -> float:
	if a.length_squared() <= 1:
		return 0
	var d: Vector3 = b - a
	var qa: float = d.dot(d)
	var qb: float = 2 * a.dot(d)
	var qc: float = a.dot(a) - 1
	var discriminant: float = qb * qb - 4 * qa * qc
	if discriminant < 0 or qa < 0.000001:
		return -1
	var t: float = (-qb - sqrt(discriminant)) / (2 * qa)
	return t if t >= 0 and t <= 1 else -1

func deactivate() -> void:
	active = false
	visible = false
	target = null
	launcher = null
