class_name CombatSystem
extends Node3D

signal fired(projectile: ProjectileController)
signal hit(ship: ShipController, damage: float)
const WEAPONS: Dictionary = {
	"gun": {"range": 1800.0, "reload": 2.4, "damage": 52.0, "speed": 320.0},
	"missile": {"range": 3600.0, "reload": 6.0, "damage": 210.0, "speed": 155.0},
	"torpedo": {"range": 2500.0, "reload": 7.0, "damage": 280.0, "speed": 65.0}}
var world: GameManager
var effects: EffectsManager
var pool: Array[ProjectileController] = []
var max_projectiles: int = 64
var last_error: String = ""

func fire(ship: ShipController, kind: String, enemy: ShipController = null, aim: Vector3 = Vector3.ZERO) -> bool:
	last_error = ""
	if not WEAPONS.has(kind) or ship.damage.sinking:
		return reject("Оружие недоступно")
	if ship.damage.weapons <= 0.05 or ship.damage.power < 0.08:
		return reject("Отказ вооружения / электропитания")
	if int(ship.ammo.get(kind, 0)) <= 0:
		return reject("Боезапас исчерпан")
	if float(ship.cooldowns[kind]) > 0:
		return reject("Перезарядка: %.1f с" % ship.cooldowns[kind])
	if kind in ["gun", "missile"] and ship.get_depth() > 5:
		return reject("Для этого оружия необходимо всплыть")
	if kind != "gun" and (not is_instance_valid(enemy) or enemy.damage.sinking):
		return reject("Назначьте обнаруженную цель")
	if enemy != null:
		if enemy.team == ship.team or enemy.damage.sinking:
			return reject("Недопустимая цель")
		if world != null and not world.can_detect(ship.team, enemy):
			return reject("Контакт потерян")
		if ship.global_position.distance_to(enemy.global_position) > float(WEAPONS[kind]["range"]):
			return reject("Цель вне дальности")
		if kind != "torpedo" and enemy.get_depth() > 6:
			return reject("Подводная цель: примените торпеду")
	var projectile: ProjectileController = acquire(kind)
	if projectile == null:
		return reject("Лимит снарядов; повторите выстрел")
	var direction: Vector3 = -ship.basis.z if aim.is_zero_approx() else aim.normalized()
	if enemy != null:
		direction = (enemy.global_position - ship.global_position).normalized()
	var point: Vector3 = ship.global_position - ship.basis.z * ship.stats["length"] * 0.35
	point.y += 8 if kind != "torpedo" else -3
	if kind == "torpedo":
		point.y = minf(-3, point.y)
	projectile.launch(ship, enemy, point, direction)
	ship.ammo[kind] = int(ship.ammo[kind]) - 1
	ship.cooldowns[kind] = float(WEAPONS[kind]["reload"]) / maxf(0.4, ship.crew.efficiency)
	if kind == "gun":
		effects.spawn_effect("muzzle", point)
		if ship.model.turret != null:
			var tween: Tween = create_tween()
			tween.tween_property(ship.model.turret, "position:z", -ship.stats["length"] * 0.31 + 1, 0.06)
			tween.tween_property(ship.model.turret, "position:z", -ship.stats["length"] * 0.31, 0.35)
	else:
		effects.play_sound("launch", point)
	fired.emit(projectile)
	return true

func reject(message: String) -> bool:
	last_error = message
	return false

func acquire(kind: String) -> ProjectileController:
	for projectile: ProjectileController in pool:
		if not projectile.active and projectile.kind == kind:
			return projectile
	if pool.size() >= max_projectiles:
		# Recycle an inactive object of another kind to avoid pool fragmentation.
		for i: int in pool.size():
			if not pool[i].active:
				pool[i].queue_free()
				pool.remove_at(i)
				break
		if pool.size() >= max_projectiles:
			return null
	var projectile: ProjectileController
	if kind == "missile":
		projectile = MissileController.new()
	elif kind == "torpedo":
		projectile = TorpedoController.new()
	else:
		projectile = ProjectileController.new()
	projectile.system = self
	add_child(projectile)
	pool.append(projectile)
	return projectile

func impact(projectile: ProjectileController, ship: ShipController) -> void:
	var underwater: bool = projectile.kind == "torpedo"
	effects.spawn_effect("underwater" if underwater else "explosion", projectile.global_position)
	if not underwater:
		effects.spawn_effect("smoke", projectile.global_position)
	if underwater:
		effects.spawn_effect("splash", Vector3(projectile.position.x, 0, projectile.position.z))
	if ship != null:
		var amount: float = WEAPONS[projectile.kind]["damage"]
		ship.damage.apply_hit(amount, 0 if projectile.position.z < ship.position.z else 2)
		hit.emit(ship, amount)
