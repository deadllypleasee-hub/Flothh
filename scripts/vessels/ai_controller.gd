class_name AIController
extends Node

var ship: ShipController
var world: GameManager
var timer: float = 0.0
var difficulty: int = 1
var state: String = "Патруль"

func _physics_process(delta: float) -> void:
	if ship.damage.sinking or world == null or world.editing or world.mode == "menu":
		return
	timer -= delta
	if timer > 0:
		return
	timer = 0.25 + (2 - difficulty) * 0.12
	if ship.player_controlled:
		if ship.autopilot:
			navigate()
		return
	var enemy: ShipController = world.nearest_detected_enemy(ship)
	if ship.damage.health / ship.damage.maximum < 0.22:
		state = "Отступление / ремонт"
		ship.crew.order("pump" if ship.damage.flooding > 0.4 else "fire")
		if enemy != null:
			steer_to(ship.global_position + (ship.global_position - enemy.global_position).normalized() * 600)
		ship.throttle = 0.8
	elif enemy != null:
		state = "Атака"
		ship.target = enemy
		var distance: float = ship.global_position.distance_to(enemy.global_position)
		var offset: Vector3 = (ship.global_position - enemy.global_position).normalized().cross(Vector3.UP)
		steer_to(enemy.global_position + offset * (650 if distance < 700 else 180))
		ship.throttle = 0.55 if distance < 900 else 0.9
		if ship is SubmarineController:
			(ship as SubmarineController).target_depth = 18 if enemy.is_submarine() else 9
		var kind: String = "torpedo" if enemy.get_depth() > 6 or ship.is_submarine() else "missile"
		if not ship.combat.fire(ship, kind, enemy):
			ship.combat.fire(ship, "gun", enemy)
	else:
		state = "Маршрут" if not ship.waypoints.is_empty() else "Патруль"
		if ship.waypoints.is_empty():
			var angle: float = float(ship.get_index()) * 0.7 + world.elapsed * 0.007
			ship.waypoints.append(Vector3(sin(angle) * 1100, 0, cos(angle) * 1100))
		navigate()
	avoid_collisions()

func navigate() -> void:
	if ship.waypoints.is_empty():
		ship.throttle = 0
		ship.rudder = 0
		ship.autopilot = false
		return
	var point: Vector3 = ship.waypoints[0]
	if Vector2(ship.position.x - point.x, ship.position.z - point.z).length() < 65:
		ship.waypoints.pop_front()
		return
	steer_to(point)
	ship.throttle = 0.65

func steer_to(point: Vector3) -> void:
	var d: Vector3 = point - ship.global_position
	var heading: float = atan2(-d.x, -d.z)
	ship.rudder = clampf(-angle_difference(ship.rotation.y, heading) * 2.5, -1, 1)

func avoid_collisions() -> void:
	for other: ShipController in world.ships:
		if other == ship or other.damage.sinking:
			continue
		var offset: Vector3 = other.global_position - ship.global_position
		if offset.length() < (ship.stats["length"] + other.stats["length"]) * 0.8 and offset.normalized().dot(-ship.basis.z) > 0.4:
			ship.rudder = 1
			ship.throttle = 0.2
	# Coarse static-island avoidance before contact.
	for island: Dictionary in world.terrain.islands:
		var offset: Vector3 = Vector3(island["x"], 0, island["z"]) - ship.position
		offset.y = 0
		if offset.length() < float(island["radius"]) + 180 and offset.normalized().dot(-ship.basis.z) > 0.1:
			ship.rudder = 1
