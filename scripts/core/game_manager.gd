class_name GameManager
extends Node3D
## Composition root. All simulation and tactical coordinates use X/Z in metres.
var ocean: OceanSystem
var terrain: TerrainSystem
var weather: WeatherSystem
var camera_manager: CameraManager
var combat: CombatSystem
var effects: EffectsManager
var hud: MobileControls
var fleet: Node3D
var ships: Array[ShipController] = []
var player: ShipController
var editor: ScenarioEditor = ScenarioEditor.new()
var economy: EconomyManager = EconomyManager.new()
var saver: SaveManager = SaveManager.new()
var mission: MissionManager = MissionManager.new()
var spectator: SpectatorController = SpectatorController.new()
var detected: Array[Array] = [[], []]
var mode: String = "menu"
var editing: bool = false
var elapsed: float = 0
var detection_timer: float = 0
var battle_over: bool = false
var sonar_used: bool = false
var journal: Array[String] = []
var current_scenario: Dictionary = {}
var selected_weapon: String = "missile"
var map_selected: ShipController
var objective_buoy: Node3D

func _ready() -> void:
	economy.load_progress()
	ocean = OceanSystem.new()
	add_child(ocean)
	terrain = TerrainSystem.new()
	add_child(terrain)
	effects = EffectsManager.new()
	add_child(effects)
	combat = CombatSystem.new()
	combat.world = self
	combat.effects = effects
	add_child(combat)
	fleet = Node3D.new()
	add_child(fleet)
	camera_manager = CameraManager.new()
	add_child(camera_manager)
	ocean.follow = camera_manager.camera
	weather = WeatherSystem.new()
	weather.ocean = ocean
	weather.camera = camera_manager.camera
	add_child(weather)
	var buoy_model: ShipModel = ShipModel.new()
	add_child(buoy_model)
	buoy_model.box(Vector3(6, 2, 6), Vector3.ZERO, ShipModel.material(Color("d6a355")))
	buoy_model.box(Vector3(0.8, 8, 0.8), Vector3(0, 4, 0), ShipModel.material(Color("e8b76a")))
	objective_buoy = buoy_model
	objective_buoy.visible = false
	spectator.world = self
	mission.finished.connect(func(_ok: bool, message: String) -> void: finish_battle(message))
	combat.fired.connect(func(projectile: ProjectileController) -> void:
		if projectile.launcher == player:
			camera_manager.projectile = projectile
			log_event("Офицер: пуск · " + projectile.kind))
	combat.hit.connect(func(ship: ShipController, amount: float) -> void:
		camera_manager.shake = 2 if ship == player else 0.5
		if spectator.active and camera_manager.mode == 6:
			camera_manager.follow = ship
		log_event("%s: попадание, −%.0f" % [ship.unit_name, amount]))
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = MobileControls.new()
	hud.world = self
	layer.add_child(hud)
	apply_quality(int(economy.settings.get("quality", 1)))
	show_menu()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--demo-battle" in args:
		start_battle(VesselCatalog.default_scenario())
	elif "--demo-editor" in args:
		open_editor()

func clear_fleet() -> void:
	effects.listener_ship = null
	camera_manager.follow = null
	for projectile: ProjectileController in combat.pool:
		projectile.deactivate()
	for ship: ShipController in ships:
		fleet.remove_child(ship)
		ship.queue_free()
	ships.clear()
	player = null
	map_selected = null
	detected = [[], []]

func spawn_scenario(scenario: Dictionary, preview: bool = false) -> void:
	clear_fleet()
	current_scenario = scenario.duplicate(true)
	var open_ocean: bool = scenario.get("map", "archipelago") == "ocean"
	terrain.visible = not open_ocean
	terrain.process_mode = Node.PROCESS_MODE_DISABLED if open_ocean else Node.PROCESS_MODE_INHERIT
	# Toggle static collisions along with map geometry.
	for body: Node in terrain.get_children():
		if body is StaticBody3D:
			body.collision_layer = 0 if open_ocean else 1
	for index: int in scenario["units"].size():
		var spec: Dictionary = scenario["units"][index]
		var stats: Dictionary = VesselCatalog.get_stats(spec["type"])
		var ship: ShipController = SubmarineController.new() if stats["submarine"] else ShipController.new()
		ship.setup(spec, ocean, combat, index)
		fleet.add_child(ship)
		ship.ai.world = self
		ship.ai.difficulty = clampi(int(scenario.get("difficulty", 1)), 0, 2)
		for kind: String in ship.ammo:
			ship.ammo[kind] = int(float(ship.ammo[kind]) * float(scenario.get("ammo_scale", 1)))
		if mode == "mission" or mode == "free":
			if ship.team == 0:
				ship.stats["speed"] *= 1 + int(economy.upgrades["engine"]) * 0.05
				ship.stats["sensor"] *= 1 + int(economy.upgrades["sensors"]) * 0.1
				ship.damage.configure(ship.damage.maximum * (1 + int(economy.upgrades["defense"]) * 0.1))
		ship.destroyed.connect(_on_ship_destroyed)
		ship.crew.report.connect(log_event)
		if preview:
			ship.process_mode = Node.PROCESS_MODE_DISABLED
		ships.append(ship)
	weather.auto_cycle = not preview
	weather.apply(scenario.get("weather", "clear"), scenario.get("night", false), float(scenario.get("waves", 1)), float(scenario.get("wind", 0.7)))
	if not ships.is_empty():
		var index: int = clampi(int(scenario.get("player_index", 0)), 0, ships.size() - 1)
		player = ships[index]
		camera_manager.follow = player
	update_detection()

func show_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1
	mode = "menu"
	editing = false
	spectator.active = false
	mission.active = -1
	objective_buoy.visible = false
	spawn_scenario({"units": [VesselCatalog.spec("destroyer", 0, 0, 0), VesselCatalog.spec("diesel", 0, 120, -70)], "waves": 1.5})
	camera_manager.yaw = 0.65
	camera_manager.pitch = 0.23
	camera_manager.distance = 150
	camera_manager.zoom = 1
	camera_manager.set_mode(6)
	camera_manager.framing_offset = Vector3(-80, 0, 50)
	hud.show_menu()

func start_battle(scenario: Dictionary, observe: bool = false) -> bool:
	if not editor.validate(scenario):
		log_event(editor.last_error)
		return false
	if scenario["units"].is_empty():
		log_event("Добавьте хотя бы одно судно")
		return false
	mode = "battle"
	editing = false
	objective_buoy.visible = false
	camera_manager.framing_offset = Vector3.ZERO
	mission.active = -1
	elapsed = 0
	sonar_used = false
	battle_over = false
	get_tree().paused = false
	spectator.set_speed(1)
	spawn_scenario(scenario)
	if observe:
		spectator.enter()
	else:
		if player.team != 0:
			for ship: ShipController in ships:
				if ship.team == 0:
					player = ship
					break
		if player.team == 0:
			switch_ship(player)
		else:
			spectator.enter()
	camera_manager.distance = 160
	camera_manager.zoom = 1
	hud.show_game()
	log_event("Боевой пост готов. Выберите обнаруженную цель.")
	return true

func start_free(vessel_type: String = "destroyer") -> void:
	start_battle({"version": 1, "units": [VesselCatalog.spec(vessel_type, 0, -1000, 1300)], "weather": "clear", "waves": 1.0})
	mode = "free"
	log_event("Свободное плавание · база к юго-западу. Ремонт доступен в порту.")

func start_mission(index: int) -> void:
	var sub: bool = index in [6, 7]
	var units: Array = [VesselCatalog.spec("diesel" if sub else "destroyer", 0, 0, 0)]
	if index == 0:
		units[0]["x"] = -1220
		units[0]["z"] = 1950
	if index == 3:
		units[0]["x"] = -1100
		units[0]["z"] = 1550
	if index == 7:
		units.append(VesselCatalog.spec("diesel", 1, 0, -900, 180))
	if index == 8:
		units.append(VesselCatalog.spec("corvette", 0, 150, -100))
		units.append(VesselCatalog.spec("patrol", 1, 0, -1700, 180))
	if index == 9:
		units.append(VesselCatalog.spec("corvette", 0, 200, 0))
		units.append(VesselCatalog.spec("corvette", 1, -200, -900, 180))
		units.append(VesselCatalog.spec("diesel", 1, 250, -1000, 180))
	start_battle({"version": 1, "units": units, "weather": "clear", "difficulty": 0, "waves": 0.7})
	mode = "mission"
	mission.start(index, self)
	objective_buoy.visible = index in [2, 4, 5]
	hud.show_game()
	log_event(MissionManager.TITLES[index] + ": " + MissionManager.BRIEFS[index])

func open_editor() -> void:
	get_tree().paused = false
	Engine.time_scale = 1
	mode = "editor"
	editing = true
	objective_buoy.visible = false
	camera_manager.framing_offset = Vector3.ZERO
	mission.active = -1
	refresh_preview()
	camera_manager.set_mode(4)
	hud.show_editor()

func refresh_preview() -> void:
	spawn_scenario(editor.scenario, true)
	if editor.selected >= 0 and editor.selected < ships.size():
		camera_manager.follow = ships[editor.selected]

func switch_ship(ship: ShipController) -> void:
	if ship == null or ship.team != 0 or ship.damage.sinking:
		return
	for other: ShipController in ships:
		other.player_controlled = false
	player = ship
	effects.listener_ship = player
	player.player_controlled = true
	player.autopilot = false
	spectator.active = false
	camera_manager.follow = player
	camera_manager.set_mode(0)
	log_event("Капитан: управление передано · " + player.unit_name)
	if hud != null and hud.throttle_slider != null:
		hud.throttle_slider.set_value_no_signal(player.throttle * 100)

func next_ship() -> void:
	if ships.is_empty():
		return
	var start: int = ships.find(camera_manager.follow)
	for offset: int in range(1, ships.size() + 1):
		var ship: ShipController = ships[(start + offset) % ships.size()]
		if not ship.damage.sinking and (spectator.active or ship.team == 0):
			if spectator.active:
				camera_manager.follow = ship
			else:
				switch_ship(ship)
			return

func update_detection() -> void:
	detected = [[], []]
	for team: int in 2:
		for candidate: ShipController in ships:
			if candidate.damage.sinking:
				continue
			if candidate.team == team:
				detected[team].append(candidate)
				continue
			for sensor: ShipController in ships:
				if sensor.team != team or sensor.damage.sinking:
					continue
				var reach: float = sensor.stats["sensor"] * sensor.damage.radar
				if candidate.get_depth() > 6:
					reach *= 0.72 if sensor.is_submarine() else 0.43
				if sensor.global_position.distance_to(candidate.global_position) <= reach:
					detected[team].append(candidate)
					break

func can_detect(team: int, ship: ShipController) -> bool:
	return team in [0, 1] and ship in detected[team]

func nearest_detected_enemy(ship: ShipController) -> ShipController:
	var result: ShipController
	var closest: float = INF
	for candidate: ShipController in detected[ship.team]:
		if candidate.team != ship.team and not candidate.damage.sinking:
			var distance: float = ship.global_position.distance_squared_to(candidate.global_position)
			if distance < closest:
				closest = distance
				result = candidate
	return result

func cycle_target() -> void:
	if player == null:
		return
	var targets: Array[ShipController] = []
	for ship: ShipController in detected[player.team]:
		if ship.team != player.team and not ship.damage.sinking:
			targets.append(ship)
	if targets.is_empty():
		player.target = null
		log_event("Оператор: обнаруженных целей нет")
		return
	player.target = targets[(targets.find(player.target) + 1) % targets.size()]
	log_event("Цель: " + player.target.unit_name)

func fire_player() -> void:
	if spectator.active or player == null or editing or mode == "menu":
		return
	var aim: Vector3 = -camera_manager.camera.global_basis.z
	if not combat.fire(player, selected_weapon, player.target, aim):
		log_event(combat.last_error)
	else:
		camera_manager.shake = 0.8
		if OS.has_feature("android"):
			Input.vibrate_handheld(40)

func alive_count(team: int) -> int:
	var count: int = 0
	for ship: ShipController in ships:
		if ship.team == team and not ship.damage.sinking:
			count += 1
	return count

func _on_ship_destroyed(ship: ShipController) -> void:
	log_event(ship.unit_name + ": потеря плавучести, судно тонет")
	effects.spawn_effect("explosion", ship.global_position)
	if player == ship and not spectator.active and mode == "battle":
		next_ship()

func _physics_process(delta: float) -> void:
	if mode not in ["battle", "free", "mission"] or battle_over:
		return
	elapsed += delta
	detection_timer -= delta
	if detection_timer <= 0:
		detection_timer = 0.5
		update_detection()
	mission.tick(delta)
	if objective_buoy.visible:
		objective_buoy.global_position = mission.marker + Vector3.UP * ocean.height_at(mission.marker)
	spectator.tick(delta)
	if camera_manager.mode == 5 and (not is_instance_valid(camera_manager.projectile) or not camera_manager.projectile.active):
		camera_manager.set_mode(6 if spectator.active else 0)
	if mode == "battle" and elapsed > 5:
		if current_scenario.get("victory", "elimination") == "elimination" and (alive_count(0) == 0 or alive_count(1) == 0):
			finish_battle("Победа союзного флота" if alive_count(1) == 0 and alive_count(0) > 0 else "Союзный флот потерян")
		elif elapsed >= float(current_scenario.get("time_limit", 900)):
			finish_battle("Время истекло · союзных: %d · вражеских: %d" % [alive_count(0), alive_count(1)])
	if not spectator.active and player != null and not hud.modal_visible:
		var axis: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		if axis != 0 or hud.wheel.active:
			player.rudder = axis if axis != 0 else hud.wheel.axis
		elif not player.autopilot:
			player.rudder = move_toward(player.rudder, 0, delta * 2)
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S):
			player.autopilot = false
			player.throttle = clampf(player.throttle + (float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))) * delta * 0.5, -1, 1)
			hud.throttle_slider.set_value_no_signal(player.throttle * 100)
	if camera_manager.mode == 3:
		camera_manager.free_axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))) + hud.wheel.free_axis

func finish_battle(message: String) -> void:
	if battle_over:
		return
	battle_over = true
	Engine.time_scale = 1
	log_event(message)
	hud.show_results(message)

func log_event(message: String) -> void:
	journal.append("%02d:%02d  %s" % [int(elapsed) / 60, int(elapsed) % 60, message])
	if journal.size() > 80:
		journal.pop_front()
	if hud != null:
		hud.toast = message
		hud.toast_time = 4.0

func save_scenario() -> bool:
	if not editor.validate(editor.scenario):
		log_event(editor.last_error)
		return false
	var ok: bool = saver.write_file("scenario.json", editor.scenario)
	log_event("Сценарий сохранён локально" if ok else saver.last_error)
	return ok

func load_scenario() -> bool:
	var data: Dictionary = saver.read_file("scenario.json")
	if not editor.load_scenario(data):
		log_event("Не удалось загрузить: " + editor.last_error)
		return false
	refresh_preview()
	log_event("Сценарий загружен")
	return true

func apply_quality(level: int) -> void:
	level = clampi(level, 0, 2)
	economy.settings["quality"] = level
	effects.max_effects = [10, 20, 32][level]
	effects.particle_scale = [0.5, 0.75, 1.0][level]
	weather.rain.amount = [80, 200, 320][level]
	weather.sun.shadow_enabled = level > 0
	camera_manager.camera.far = [3600, 5200, 6500][level]
	get_viewport().scaling_3d_scale = [0.65, 0.8, 1.0][level]
	effects.audio_enabled = bool(economy.settings.get("sound", true))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or mode in ["menu", "editor"]:
		return
	if event.keycode == KEY_ESCAPE:
		hud.toggle_pause()
	elif event.keycode == KEY_M:
		hud.toggle_map()
	elif event.keycode == KEY_TAB:
		next_ship()
	elif event.keycode == KEY_T:
		cycle_target()
	elif event.keycode == KEY_SPACE:
		fire_player()
	elif event.keycode == KEY_C:
		camera_manager.set_mode((camera_manager.mode + 1) % 7)
	elif event.keycode in [KEY_1, KEY_2, KEY_3]:
		selected_weapon = ["gun", "missile", "torpedo"][event.keycode - KEY_1]
	elif player is SubmarineController:
		if event.keycode == KEY_BRACKETLEFT:
			(player as SubmarineController).change_depth(10)
		elif event.keycode == KEY_BRACKETRIGHT:
			(player as SubmarineController).change_depth(-10)
