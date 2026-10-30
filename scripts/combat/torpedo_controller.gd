class_name TorpedoController
extends ProjectileController

func _init() -> void:
	kind = "torpedo"

func guide(delta: float) -> void:
	var desired: Vector3 = direction
	if is_instance_valid(target) and not target.damage.sinking:
		var point: Vector3 = target.global_position
		point.y = minf(-2, point.y)
		desired = (point - global_position).normalized()
	direction = direction.slerp(desired, minf(1, delta * 0.9)).normalized()
	velocity = direction * float(system.WEAPONS[kind]["speed"])
	if global_position.y > -1:
		velocity.y = minf(-2, velocity.y)
