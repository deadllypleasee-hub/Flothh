class_name ShipController
extends CharacterBody3D
const MAX_WAYPOINTS: int = 32

signal destroyed(ship: ShipController)
var stats: Dictionary
var team: int = 0
var unit_name: String = ""
var ocean: OceanSystem
var model: ShipModel
var damage: DamageSystem = DamageSystem.new()
var crew: CrewSystem = CrewSystem.new()
var ai: AIController
var combat: CombatSystem
var player_controlled: bool = false
var throttle: float = 0.0
var rudder: float = 0.0
var speed: float = 0.0
var turn_rate: float = 0.0
var ammo: Dictionary = {}
var cooldowns: Dictionary = {"gun": 0.0, "missile": 0.0, "torpedo": 0.0}
var target: ShipController
var waypoints: Array[Vector3] = []
var autopilot: bool = false
var sink_time: float = 0.0
var effect_clock: float = 0.0
var weapon_aim: Vector3 = Vector3.FORWARD
var distance_travelled: float = 0.0
var gun_index: int = 0

func setup(spec: Dictionary, water: OceanSystem, weapons_system: CombatSystem, index: int) -> void:
	stats = VesselCatalog.get_stats(spec.get("type", "destroyer"))
	team = int(spec.get("team", 0))
	unit_name = ("ФОРТИС" if team == 0 else "ШТОРМ") + " %02d" % (index + 1)
	ocean = water
	combat = weapons_system
	position = Vector3(float(spec.get("x", 0)), 0, float(spec.get("z", 0)))
	rotation.y = -deg_to_rad(fposmod(float(spec.get("heading", 0)), 360))
	speed = clampf(float(spec.get("speed", 0)), -stats["speed"] * 0.3, stats["speed"])
	damage.configure(stats["health"])
	ammo = stats["ammo"].duplicate()
	damage.sunk.connect(func() -> void: destroyed.emit(self))

func _ready() -> void:
	model = ShipModel.new()
	add_child(model)
	model.build(stats, team)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(stats["beam"], 7, stats["length"] * 0.86)
	collision.shape = shape
	add_child(collision)
	collision_layer = 2
	collision_mask = 3
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	ai = AIController.new()
	ai.ship = self
	add_child(ai)

func _physics_process(delta: float) -> void:
	for kind: String in cooldowns:
		cooldowns[kind] = maxf(0, float(cooldowns[kind]) - delta)
	if damage.sinking:
		sink_time += delta
		position.y -= delta * (0.35 + sink_time * 0.05)
		model.rotation.z = lerp_angle(model.rotation.z, 0.8, delta * 0.1)
		speed = move_toward(speed, 0, delta)
		position += -basis.z * speed * delta
		if sink_time > 70:
			visible = false
		return
	crew.tick(delta, damage)
	var desired: float = throttle * stats["speed"] * damage.engine
	if desired < 0:
		desired *= 0.32
	var drag: float = 0.15 + absf(speed) * 0.014
	speed = move_toward(speed, desired, delta * (stats["acceleration"] + drag))
	var turn_target: float = -rudder * stats["turn"] * clampf(speed / 8.0, -0.5, 1.0) * damage.steering
	turn_rate = move_toward(turn_rate, turn_target, delta * 0.05)
	rotation.y += turn_rate * delta
	velocity = -basis.z * speed
	# Small lateral wind drift; no physical-accuracy claim.
	velocity += Vector3(ocean.wind_direction.x, 0, ocean.wind_direction.y) * ocean.amplitude * 0.08
	var previous: Vector3 = position
	move_and_slide()
	distance_travelled += Vector2(position.x - previous.x, position.z - previous.z).length()
	if get_slide_collision_count() > 0 and absf(speed) > 2:
		var impact_speed: float = absf(speed)
		speed *= 0.75
		damage.apply_hit(impact_speed * delta * 3, 0)
	position.x = clampf(position.x, -4700, 4700)
	position.z = clampf(position.z, -4700, 4700)
	_update_vertical(delta)
	model.propeller.rotation.z += speed * delta
	model.damage_marker.visible = damage.health < damage.maximum * 0.8
	if is_instance_valid(target) and model.turret != null:
		var direction: Vector3 = target.global_position - global_position
		model.turret.rotation.y = lerp_angle(model.turret.rotation.y, atan2(-direction.x, -direction.z) - rotation.y, delta * 2)
	effect_clock += delta
	if effect_clock > 0.8 and combat != null and combat.effects != null:
		effect_clock = 0
		if absf(speed) > 3 and position.y > -3:
			combat.effects.spawn_effect("wake", global_position + basis.z * stats["length"] * 0.42)
		if damage.fire > 0.08:
			combat.effects.spawn_effect("smoke", global_position + Vector3(0, 9, 0))
			combat.effects.spawn_effect("fire", global_position + Vector3(0, 7, 0))

func _update_vertical(delta: float) -> void:
	var water: Vector3 = BuoyancySystem.sample(ocean, position, rotation.y, stats["length"], stats["beam"])
	position.y = lerpf(position.y, water.x - damage.flooding * 4, minf(1, delta * 2))
	model.rotation.x = lerp_angle(model.rotation.x, water.y, delta * 2)
	model.rotation.z = lerp_angle(model.rotation.z, water.z + turn_rate * speed * 0.045 + damage.flooding * 0.25, delta * 2)

func heading_degrees() -> float:
	return fposmod(snappedf(-rad_to_deg(rotation.y), 0.001), 360.0)

func is_submarine() -> bool:
	return stats.get("submarine", false)

func set_waypoint(point: Vector3, append: bool = false) -> bool:
	if not point.is_finite() or absf(point.x) > 4600 or absf(point.z) > 4600:
		return false
	if append and waypoints.size() >= MAX_WAYPOINTS:
		return false
	if not append:
		waypoints.clear()
	waypoints.append(Vector3(point.x, 0, point.z))
	autopilot = true
	return true

func get_depth() -> float:
	return maxf(0, -position.y)
