class_name BuoyancySystem
extends RefCounted
## Four hull samples drive heave, pitch and roll. Arcade approximation, not CFD.
static func sample(ocean: OceanSystem, p: Vector3, heading: float, length: float, beam: float) -> Vector3:
	var forward: Vector3 = Vector3(-sin(heading), 0, -cos(heading))
	var right: Vector3 = Vector3(cos(heading), 0, -sin(heading))
	var bow: float = ocean.height_at(p + forward * length * 0.35)
	var stern: float = ocean.height_at(p - forward * length * 0.35)
	var port: float = ocean.height_at(p - right * beam * 0.4)
	var starboard: float = ocean.height_at(p + right * beam * 0.4)
	return Vector3((bow + stern + port + starboard) * 0.25, atan2(bow - stern, length * 0.7), atan2(port - starboard, beam * 0.8))
