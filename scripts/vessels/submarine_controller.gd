class_name SubmarineController
extends ShipController
## Dedicated vertical dynamics with ballast, dive planes and consumables.
var target_depth: float = 0.0
var ballast: float = 0.0
var vertical_speed: float = 0.0
var battery: float = 100.0
var air: float = 100.0
var noise: float = 0.0
var emergency: bool = false
var dive_plane: float = 0.0

func _update_vertical(delta: float) -> void:
	if emergency:
		target_depth = 0
		air = maxf(0, air - delta * 0.15)
	var depth: float = get_depth()
	var error: float = target_depth - depth
	ballast = move_toward(ballast, clampf(error * 0.04, -1, 1), delta * 0.25)
	dive_plane = clampf(error * 0.025, -0.5, 0.5)
	var desired_vertical: float = -ballast * (2.5 if emergency else 1.6) - dive_plane * absf(speed) * 0.25 - damage.flooding
	vertical_speed = move_toward(vertical_speed, desired_vertical, delta * 0.6)
	position.y += vertical_speed * delta
	var surface_height: float = ocean.height_at(position)
	if target_depth <= 0 and position.y > surface_height - 0.4:
		position.y = lerpf(position.y, surface_height, minf(1, delta * 3))
		vertical_speed = 0
		emergency = false
	position.y = clampf(position.y, -150, maxf(1.5, surface_height))
	var submerged: bool = depth > 5
	if stats["id"] == "diesel":
		battery = clampf(battery + delta * (-0.025 - absf(throttle) * 0.09 if submerged else 0.25), 0, 100)
		if battery <= 0:
			throttle = 0
	air = clampf(air + delta * (-0.025 if submerged else 0.7), 0, 100)
	if air <= 5:
		emergency = true
	noise = clampf(absf(speed) / stats["speed"] * 85 + absf(ballast) * 15, 0, 100)
	model.rotation.x = lerp_angle(model.rotation.x, dive_plane * 0.18, delta)
	var water: Vector3 = BuoyancySystem.sample(ocean, position, rotation.y, stats["length"], stats["beam"])
	model.rotation.z = lerp_angle(model.rotation.z, water.z * maxf(0, 1 - depth / 8) + damage.flooding * 0.18, delta)

func change_depth(amount: float) -> void:
	emergency = false
	target_depth = clampf(target_depth + amount, 0, 140)

func emergency_surface() -> void:
	emergency = true
	target_depth = 0
