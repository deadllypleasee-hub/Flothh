extends SceneTree
## Acceptance path through editor -> battle -> missile -> submarine -> observer -> replay.
var world: GameManager
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS  ", description)
	else:
		failures += 1
		push_error("FAIL  " + description)

func frames(count: int) -> void:
	for i: int in count:
		await physics_frame

func run() -> void:
	world = load("res://scenes/main.tscn").instantiate() as GameManager
	root.add_child(world)
	await frames(2)
	world.open_editor()
	world.editor.scenario = VesselCatalog.default_scenario()
	world.editor.scenario["map"] = "ocean"
	world.refresh_preview()
	check(world.ships.size() == 11 and not world.terrain.visible, "Editor creates 11 vessels in an ocean map")
	check(world.editor.scenario["night"] and world.weather.time_of_day > 20 and world.weather.weather == "storm", "Night and storm applied to real 3D world")
	check(world.save_scenario() and world.load_scenario(), "Required battle placement persists")
	check(world.start_battle(world.editor.scenario), "Editor starts the 3D battle")
	for ship: ShipController in world.ships:
		ship.ai.set_physics_process(false)
	check(world.player == world.ships[0] and world.player.player_controlled, "First allied destroyer is controlled")
	var enemy: ShipController = world.ships[5]
	world.player.target = enemy
	check(world.can_detect(0, enemy), "Enemy chosen from detected contacts")
	var hp_before: float = enemy.damage.health
	world.selected_weapon = "missile"
	world.fire_player()
	var missile: ProjectileController = world.camera_manager.projectile
	check(missile != null and missile.active and missile.kind == "missile", "Player launches a real 3D missile")
	world.camera_manager.set_mode(5)
	var launch_position: Vector3 = missile.position
	await frames(60)
	check(missile.position.distance_to(launch_position) > 50 and world.camera_manager.mode == 5, "Missile flight and chase camera update")
	await frames(420)
	check(enemy.damage.health < hp_before - 100, "Missile explosion damages the enemy hull")
	world.map_selected = world.ships[3]
	check(world.spectator.take_control(world.map_selected) and world.player is SubmarineController, "Map selection transfers control to allied submarine")
	var sub: SubmarineController = world.player as SubmarineController
	sub.change_depth(20)
	await frames(650)
	check(sub.get_depth() > 12, "Selected submarine dives in the same battle")
	# Move a test enemy into sonar range through its real transform; every hit still
	# uses the normal projectile, physics loop and damage code.
	var underwater_target: ShipController = world.ships[9]
	underwater_target.position = sub.position + Vector3(0, 0, -420)
	(underwater_target as SubmarineController).target_depth = sub.get_depth()
	underwater_target.damage.configure(200)
	world.update_detection()
	sub.target = underwater_target
	world.selected_weapon = "torpedo"
	world.fire_player()
	var torpedo: ProjectileController = world.camera_manager.projectile
	check(torpedo.active and torpedo.kind == "torpedo" and torpedo.position.y < 0, "Submarine launches a submerged 3D torpedo")
	world.camera_manager.set_mode(5)
	await frames(300)
	check(underwater_target.damage.sinking, "Underwater torpedo impact starts sinking")
	world.spectator.enter()
	world.camera_manager.set_mode(3)
	world.hud.wheel.free_axis = Vector2(1, 1)
	var camera_before: Vector3 = world.camera_manager.free_position
	await frames(60)
	check(world.camera_manager.free_position.distance_to(camera_before) > 20, "Touch wheel moves spectator free camera")
	world.hud.wheel.free_axis = Vector2.ZERO
	world.hud.toggle_pause()
	var simulation_before: float = world.elapsed
	for i: int in 3:
		await process_frame
	check(is_equal_approx(world.elapsed, simulation_before), "Observer pause freezes simulation")
	world.hud.toggle_pause()
	for ship: ShipController in world.ships:
		if ship.team == 1 and not ship.damage.sinking:
			ship.damage.apply_hit(100000)
	await frames(45)
	check(world.battle_over and world.alive_count(1) == 0, "Fleet loss creates battle results")
	check(world.ships[9].position.y < -12, "Destroyed hull continues sinking in 3D")
	world.editor.scenario = world.current_scenario.duplicate(true)
	check(world.save_scenario(), "Battle scenario saved after results")
	check(world.start_battle(world.editor.scenario, true) and world.ships.size() == 11, "Saved 11-vessel battle replays in observer mode")
	# Short accelerated soak with actual AI, full effect budgets and continuous hits.
	world.current_scenario["victory"] = "time"
	world.current_scenario["time_limit"] = 3600
	world.spectator.set_speed(4)
	await frames(900)
	var finite: bool = true
	for ship: ShipController in world.ships:
		finite = finite and ship.position.is_finite() and is_finite(ship.speed) and is_finite(ship.rotation.y)
	check(finite, "x4 AI soak retains finite ship physics")
	check(world.combat.pool.size() <= world.combat.max_projectiles, "Projectile pool remains bounded under AI load")
	check(world.effects.effects.size() <= world.effects.max_effects, "Concurrent GPU effects respect quality budget")
	world.spectator.set_speed(1)
	print("ACCEPTANCE RESULT: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures == 0 else 1)
