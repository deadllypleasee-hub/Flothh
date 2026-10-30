class_name MissileController
extends ProjectileController

func _init() -> void:
	kind = "missile"

func guide(delta: float) -> void:
	var desired: Vector3 = direction
	if is_instance_valid(target) and not target.damage.sinking:
		var point: Vector3 = target.global_position + Vector3.UP * 2
		if lifetime < 1.3:
			point.y = maxf(25, point.y)
		desired = (point - global_position).normalized()
	var turn: float = minf(1, delta * 1.5)
	direction = direction.slerp(desired, turn).normalized()
	velocity = direction * float(system.WEAPONS[kind]["speed"])
