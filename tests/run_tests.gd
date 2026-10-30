extends SceneTree
## Integration suite, runs in the actual Godot engine without external dependencies.
var checks: int = 0
var failures: int = 0
var world: GameManager

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", description)
	else:
		failures += 1
		push_error("FAIL  " + description)

func frames(count: int) -> void:
	for i: int in count:
		await physics_frame

func fixture(type: String = "destroyer", distance: float = 450) -> void:
	world.start_battle({"version": 1, "units": [VesselCatalog.spec(type, 0, 0, 0), VesselCatalog.spec("destroyer", 1, 0, -distance, 180)], "waves": 0.0, "weather": "clear"})
	for ship: ShipController in world.ships:
		ship.ai.set_physics_process(false)
		ship.crew.efficiency = 1

func run() -> void:
	print("FORTIS integration tests · ", Engine.get_version_info()["string"])
	world = load("res://scenes/main.tscn").instantiate() as GameManager
	root.add_child(world)
	await frames(2)
	check(world.mode == "menu" and world.ships.size() == 2, "Main menu loads with live 3D fleet")
	check(world.hud.screen.get_child_count() > 10, "Main menu controls exist")
	check(world.camera_manager.camera.current, "3D camera is current")
	world.hud.show_settings()
	world.hud.show_licenses()
	world.hud.close_modal()
	world.hud.show_missions(false)
	world.hud.close_modal()
	world.hud.show_base()
	world.hud.close_modal()
	for id: String in VesselCatalog.IDS:
		var data: Dictionary = VesselCatalog.get_stats(id)
		check(float(data["length"]) > float(data["beam"]) and data["health"] > 0, "Valid vessel stats: " + id)
	# Save persistence, backup recovery and version rejection.
	var saver: SaveManager = SaveManager.new()
	var save_dir: String = "user://test_data"
	DirAccess.make_dir_recursive_absolute(save_dir)
	saver.directory = save_dir
	check(saver.write_file("progress.json", {"credits": 123, "completed": [1, 2]}), "Atomic save succeeds")
	check(saver.read_file("progress.json").get("credits") == 123, "Progress round trip")
	saver.write_file("progress.json", {"credits": 456})
	var corrupt: FileAccess = FileAccess.open(save_dir + "/progress.json", FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(saver.read_file("progress.json").get("credits") == 123, "Corrupt save recovers backup")
	var future: FileAccess = FileAccess.open(save_dir + "/future.json", FileAccess.WRITE)
	future.store_string('{"version":999,"data":{}}')
	future.close()
	check(saver.read_file("future.json").is_empty(), "Unsupported schema rejected")
	# Editor creates actual 3D objects; no fake map-only units.
	world.open_editor()
	check(world.ships.size() == 11 and world.editing, "Required 3+2 versus 4+2 scenario in editor")
	var scenario: ScenarioEditor = world.editor
	check(scenario.validate(scenario.scenario), "Default scenario valid")
	scenario.vessel_type = "nuclear"
	scenario.team = 0
	check(scenario.add_unit(Vector3(800, 0, 800)), "Editor adds submarine")
	scenario.rotate_selected(45)
	scenario.move_selected(Vector3(820, 0, 810))
	check(scenario.duplicate_selected(), "Editor duplicates selected unit")
	scenario.delete_selected()
	world.refresh_preview()
	check(world.ships.size() == 12 and world.ships[11] is SubmarineController, "Editor spawns submarine model in real world")
	check(world.save_scenario(), "Scenario saved")
	var saved_x: float = scenario.scenario["units"][11]["x"]
	scenario.scenario["units"][11]["x"] = -999
	check(world.load_scenario() and scenario.scenario["units"][11]["x"] == saved_x, "Scenario loaded with placement")
	var bad: Dictionary = scenario.scenario.duplicate(true)
	bad["units"][0]["type"] = "not-a-vessel"
	check(not scenario.validate(bad), "Invalid scenario rejected")
	bad = scenario.scenario.duplicate(true)
	bad["units"][0]["x"] = INF
	check(not scenario.validate(bad), "Non-finite placement rejected")
	# Ship motion and control transfer continue in a running simulation.
	fixture()
	var ship: ShipController = world.player
	ship.throttle = 1
	await frames(120)
	check(ship.speed > 1.5 and ship.position.z < -2, "Ship accelerates and moves in 3D")
	var old_heading: float = ship.rotation.y
	ship.rudder = 1
	ship.autopilot = true # keep test rudder independent of keyboard reset
	ship.ai.set_physics_process(false)
	await frames(120)
	check(absf(ship.rotation.y - old_heading) > 0.01, "Rudder changes heading")
	ship.throttle = -1
	await frames(270)
	check(ship.speed < 0, "Reverse telegraph brakes then reverses")
	fixture("diesel")
	var submarine: SubmarineController = world.player as SubmarineController
	submarine.change_depth(25)
	await frames(750)
	check(submarine.get_depth() > 15, "Submarine ballast drives a dive")
	check(submarine.battery < 100 and submarine.air < 100, "Submerged consumables decrease")
	submarine.emergency_surface()
	await frames(900)
	check(submarine.get_depth() < 3, "Emergency surfacing")
	# Detection prevents omniscient targeting and tactical markers.
	fixture("destroyer", 4200)
	check(not world.can_detect(0, world.ships[1]), "Distant enemy remains unknown")
	check(not world.combat.fire(world.player, "missile", world.ships[1]), "Cannot fire guided weapon at unknown contact")
	var tactical: TacticalMap = world.hud.map_view
	var point: Vector3 = Vector3(1234, 0, -876)
	check(tactical.map_to_world(tactical.world_to_map(point)).distance_to(point) < 0.01, "Tactical map uses real world coordinates")
	check(not tactical.show_unit(world.ships[1]), "Unknown enemy hidden on tactical map")
	world.ships[1].position.z = -450
	world.update_detection()
	check(world.can_detect(0, world.ships[1]), "Enemy detected within sensor range")
	# Artillery, missile and torpedo impacts in the real physics loop.
	for kind: String in ["gun", "missile", "torpedo"]:
		fixture("destroyer", 350)
		ship = world.player
		var enemy: ShipController = world.ships[1]
		enemy.damage.configure(3000)
		var before: int = ship.ammo[kind]
		check(world.combat.fire(ship, kind, enemy), kind + " launch succeeds")
		check(ship.ammo[kind] == before - 1, kind + " consumes one round")
		check(not world.combat.fire(ship, kind, enemy), kind + " reload enforced")
		world.camera_manager.projectile = world.combat.pool.back()
		world.camera_manager.set_mode(5)
		await frames(300)
		check(enemy.damage.health < enemy.damage.maximum - 20, kind + " projectile hits and damages hull")
	# Live handoff and observer AI.
	world.start_battle({"version": 1, "units": [VesselCatalog.spec("destroyer", 0, 0, 0), VesselCatalog.spec("diesel", 0, 150, 0), VesselCatalog.spec("destroyer", 1, 0, -700, 180)]})
	var first: ShipController = world.player
	world.combat.fire(first, "missile", world.ships[2])
	var in_flight: ProjectileController = world.camera_manager.projectile
	world.switch_ship(world.ships[1])
	check(world.player is SubmarineController and not first.player_controlled and first.ai.is_physics_processing(), "Live handoff returns previous ship to AI")
	check(in_flight.active, "Projectile survives ship switch")
	world.spectator.enter()
	check(not first.player_controlled and not world.player.player_controlled, "Observer gives all vessels to AI")
	await frames(90)
	check(first.ai.state != "Патруль", "AI acquires and attacks in observer mode")
	check(world.spectator.take_control(world.ships[1]), "Observer can retake allied submarine")
	world.spectator.set_speed(4)
	check(Engine.time_scale == 4, "Observer time scale x4")
	world.spectator.set_speed(1)
	# Damage, repairs, economy and mission success are stateful, not UI mockups.
	var damage: DamageSystem = DamageSystem.new()
	damage.configure(100)
	damage.apply_hit(50)
	check(damage.engine < 1 and damage.flooding > 0 and damage.fire > 0, "Damage affects modules, fire and flooding")
	var fire_before: float = damage.fire
	damage.tick(2, "fire", 1)
	check(damage.fire < fire_before, "Crew suppresses fire")
	damage.apply_hit(100)
	check(damage.sinking, "Fatal damage initiates sinking")
	var sink_ship: ShipController = world.ships[2]
	sink_ship.damage.apply_hit(10000)
	var y: float = sink_ship.position.y
	await frames(35)
	check(sink_ship.position.y < y and sink_ship.sink_time > 0, "Sinking moves the actual 3D hull underwater")
	var economy: EconomyManager = EconomyManager.new()
	economy.saver.directory = save_dir
	var credits: int = economy.credits
	economy.reward(0, 1500)
	economy.reward(0, 1500)
	check(economy.credits == credits + 1500, "Mission reward cannot be farmed by replay")
	check(economy.upgrade("engine") and economy.upgrades["engine"] == 1, "Upgrade spends offline credits")
	world.start_mission(0)
	world.player.distance_travelled = 360
	world.mission.tick(0.1)
	check(world.mission.done and world.battle_over, "Mission objectives trigger result screen")
	world.hud.toggle_pause()
	check(paused, "Pause stops the scene tree")
	world.hud.toggle_pause()
	check(not paused, "Resume restores simulation")
	world.show_menu()
	await frames(2)
	check(world.mode == "menu", "Return to main menu")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures == 0 else 1)
