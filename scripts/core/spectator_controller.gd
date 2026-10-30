class_name SpectatorController
extends RefCounted

var world: GameManager
var active: bool = false
var time_scale: float = 1.0
var cinematic_timer: float = 0.0

func enter() -> void:
	active = true
	for ship: ShipController in world.ships:
		ship.player_controlled = false
	world.camera_manager.set_mode(3)

func take_control(ship: ShipController) -> bool:
	if ship == null or ship.team != 0 or ship.damage.sinking:
		return false
	active = false
	world.switch_ship(ship)
	return true

func set_speed(value: float) -> void:
	time_scale = clampf(value, 1, 4)
	Engine.time_scale = time_scale

func tick(delta: float) -> void:
	if not active or world.camera_manager.mode != 6:
		return
	cinematic_timer += delta
	if cinematic_timer > 8:
		cinematic_timer = 0
		for projectile: ProjectileController in world.combat.pool:
			if projectile.active:
				world.camera_manager.projectile = projectile
				world.camera_manager.set_mode(5)
				return
