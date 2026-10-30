extends SceneTree
## Regression tests for Android gestures, waypoint queues and scenario validation.
var checks: int = 0
var failures: int = 0
var world: GameManager
var map: TacticalMap
var taps: Array[Vector3] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", description)
	else:
		failures += 1
		push_error("FAIL  " + description)

func touch(id: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	map._gui_input(event)

func drag(id: int, point: Vector2, relative: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = id
	event.position = point
	event.relative = relative
	map._gui_input(event)

func tap(point: Vector2) -> void:
	touch(0, point, true)
	touch(0, point, false)

func mouse(point: Vector2, pressed: bool, device: int = 0) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	map._gui_input(event)

func invalid(editor: ScenarioEditor, data: Dictionary, reason: String) -> void:
	var previous: String = JSON.stringify(editor.scenario)
	check(not editor.load_scenario(data) and not editor.last_error.is_empty() and JSON.stringify(editor.scenario) == previous, reason)

func setting_fields() -> Array[SpinBox]:
	var fields: Array[SpinBox] = []
	var box: Control = world.hud.modal.get_child(1)
	for child: Node in box.get_children():
		if child is SpinBox:
			fields.append(child)
	return fields

func apply_settings() -> void:
	var box: Control = world.hud.modal.get_child(1)
	for child: Node in box.get_children():
		if child is Button and child.text == "Применить":
			child.pressed.emit()
			return

func run() -> void:
	world = load("res://scenes/main.tscn").instantiate() as GameManager
	root.add_child(world)
	await process_frame
	world.start_battle({"version": 1, "map": "ocean", "units": [VesselCatalog.spec("destroyer", 0, 0, 0), VesselCatalog.spec("destroyer", 1, 0, -2500, 180)]})
	for ship: ShipController in world.ships:
		ship.ai.set_physics_process(false)
	world.hud.toggle_map()
	map = world.hud.map_view
	map.tapped.connect(func(point: Vector3, _index: int) -> void: taps.append(point))
	var ship: ShipController = world.player
	var a: Vector2 = Vector2(650, 390)
	touch(0, a, true)
	check(taps.is_empty() and ship.waypoints.is_empty(), "Touch press alone does not issue a route command")
	touch(0, a, false)
	check(taps.size() == 1 and ship.waypoints.size() == 1 and ship.waypoints[0].distance_to(map.map_to_world(a)) < 0.01, "Touch release sets a real world waypoint")
	tap(Vector2(710, 390))
	check(ship.waypoints.size() == 1 and ship.waypoints[0].distance_to(map.map_to_world(Vector2(710, 390))) < 0.01, "Normal touch replaces the previous route")
	world.hud.append_route_button.button_pressed = true
	tap(Vector2(720, 420))
	tap(Vector2(740, 450))
	check(world.hud.append_route and ship.waypoints.size() == 3, "Android queue toggle appends multiple route points")
	var route: Array[Vector3] = ship.waypoints.duplicate()
	var count: int = taps.size()
	var center: Vector2 = map.center
	touch(0, a, true)
	drag(0, a + Vector2(65, 35), Vector2(65, 35))
	touch(0, a + Vector2(65, 35), false)
	check(map.center != center and taps.size() == count and ship.waypoints == route, "Panning the map does not replace or append a route")
	var scale_before: float = map.metres_per_pixel
	touch(0, Vector2(600, 300), true)
	touch(1, Vector2(700, 300), true)
	drag(1, Vector2(900, 300), Vector2(200, 0))
	touch(1, Vector2(900, 300), false)
	center = map.center
	drag(0, Vector2(620, 300), Vector2(20, 0))
	touch(0, Vector2(620, 300), false)
	check(map.metres_per_pixel < scale_before and taps.size() == count and ship.waypoints == route, "Pinch zoom never emits a route command")
	check(map.center == center and not map.dragging and map.touches.is_empty(), "Remaining pinch finger stays canceled until all fingers lift")
	touch(0, a, true)
	touch(0, a, false, true)
	check(taps.size() == count, "Canceled Android touch issues no command")
	touch(0, a, true)
	drag(0, a + Vector2(3, 2), Vector2(3, 2))
	touch(0, a + Vector2(3, 2), false)
	check(taps.size() == count + 1, "Small finger jitter remains a single tap")
	count = taps.size()
	mouse(a, true, InputEvent.DEVICE_ID_EMULATION)
	mouse(a, false, InputEvent.DEVICE_ID_EMULATION)
	check(taps.size() == count, "Emulated mouse events cannot duplicate Android commands")
	touch(0, a, true)
	world.hud.toggle_map()
	world.hud.toggle_map()
	touch(0, a, false)
	check(taps.size() == count and map.touches.is_empty(), "Closing the map cancels an unfinished gesture")
	touch(0, a, true)
	touch(0, Vector2(-30, 300), false)
	check(taps.size() == count, "A release outside the map issues no command")
	mouse(a, true)
	mouse(a, false)
	check(taps.size() == count + 1, "Physical mouse clicks still work")
	count = taps.size()
	center = map.center
	drag(9, a + Vector2(80, 0), Vector2(80, 0))
	check(map.center == center and taps.size() == count, "Orphan touch drags are ignored")
	ship.waypoints.clear()
	var accepted: bool = true
	for i: int in ShipController.MAX_WAYPOINTS:
		accepted = ship.set_waypoint(Vector3(1000 + i * 10, 0, -1000), true) and accepted
	check(accepted and ship.waypoints.size() == 32, "Route queue accepts 32 points")
	check(not ship.set_waypoint(Vector3(1500, 0, -800), true) and ship.waypoints.size() == 32, "Full route queue is bounded without losing existing points")
	check(not ship.set_waypoint(Vector3(INF, 0, 0)) and not ship.set_waypoint(Vector3(5000, 0, 0)) and ship.waypoints.size() == 32, "Invalid route coordinates preserve the existing queue")
	check(ship.set_waypoint(Vector3(500, 0, -500)) and ship.waypoints.size() == 1, "A new route can replace a full queue")
	# Course values are compass degrees, clockwise from north, in all interfaces.
	for heading: float in [0.0, 45.0, 90.0, 180.0, 270.0, 359.0]:
		var vessel: ShipController = ShipController.new()
		vessel.setup(VesselCatalog.spec("destroyer", 0, 0, 0, heading), world.ocean, world.combat, 0)
		var forward: Vector3 = -vessel.basis.z
		var expected: Vector3 = Vector3(sin(deg_to_rad(heading)), 0, -cos(deg_to_rad(heading)))
		check(absf(vessel.heading_degrees() - heading) < 0.01 and forward.dot(expected) > 0.999, "Editor heading matches compass and 3D bow: %.0f degrees" % heading)
		vessel.free()
	var editor: ScenarioEditor = ScenarioEditor.new()
	var valid: Dictionary = {"version": 1, "map": "ocean", "units": [VesselCatalog.spec("destroyer", 0, 0, 0)]}
	check(editor.load_scenario(valid), "Minimal version 1 scenario remains compatible")
	var bad: Dictionary = valid.duplicate(true)
	bad["units"][0].erase("x")
	invalid(editor, bad, "Missing coordinate is rejected without changing the current scenario")
	bad = valid.duplicate(true)
	bad["night"] = {"invalid": true}
	invalid(editor, bad, "Malformed night flag cannot reach WeatherSystem")
	bad = valid.duplicate(true)
	bad["units"][0]["heading"] = 1.0e200
	invalid(editor, bad, "Oversized heading cannot overflow the 3D transform")
	bad = valid.duplicate(true)
	bad["difficulty"] = 1.5
	invalid(editor, bad, "Fractional AI difficulty rejected")
	bad = valid.duplicate(true)
	bad["player_index"] = 7
	invalid(editor, bad, "Invalid controlled unit index rejected")
	bad = valid.duplicate(true)
	bad["wind"] = -1
	invalid(editor, bad, "Invalid wind angle rejected")
	bad = valid.duplicate(true)
	bad["units"].append(VesselCatalog.spec("destroyer", 1, 0, 0, 90))
	invalid(editor, bad, "Intersecting oriented hulls rejected at scenario load")
	var parallel: Dictionary = valid.duplicate(true)
	parallel["units"].append(VesselCatalog.spec("destroyer", 0, 30, 0))
	check(editor.validate(parallel), "Parallel hulls with safe beam clearance are allowed")
	var land: Dictionary = valid.duplicate(true)
	land["map"] = "archipelago"
	land["units"][0]["x"] = TerrainSystem.ISLANDS[0]["x"]
	land["units"][0]["z"] = TerrainSystem.ISLANDS[0]["z"]
	invalid(editor, land, "Island placement rejected on archipelago map")
	land["map"] = "ocean"
	check(editor.validate(land), "Open ocean correctly ignores island locations")
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(parallel))
	check(editor.validate(json_copy), "JSON floating-point numbers remain supported")
	editor.load_scenario(parallel)
	var units_before: int = editor.scenario["units"].size()
	check(not editor.add_unit(Vector3.ZERO) and editor.scenario["units"].size() == units_before, "Failed placement does not append an overlapping vessel")
	editor.selected = 0
	check(not editor.move_selected(Vector3(30, 0, 0)) and editor.scenario["units"][0]["x"] == 0, "Rejected hull move preserves the previous position")
	check(not editor.rotate_selected(90) and editor.scenario["units"][0]["heading"] == 0, "Rejected rotation preserves the previous heading")
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate["units"].append(VesselCatalog.spec("patrol", 0, 170, 0))
	duplicate["player_index"] = 1
	editor.load_scenario(duplicate)
	editor.selected = 0
	check(not editor.duplicate_selected() and editor.scenario["units"].size() == 2, "Duplicate cannot overlap an existing ship")
	editor.delete_selected()
	check(editor.scenario["player_index"] == 0 and editor.scenario["units"][0]["type"] == "patrol" and editor.validate(editor.scenario), "Deleting a preceding unit preserves the controlled vessel")
	# Editor gestures mutate only valid drags; panning in Add mode cannot spawn ships.
	world.editor.load_scenario(valid)
	world.open_editor()
	world.editor.tool = "add"
	map = world.hud.map_view
	touch(0, a, true)
	drag(0, a + Vector2(80, 0), Vector2(80, 0))
	touch(0, a + Vector2(80, 0), false)
	check(world.editor.scenario["units"].size() == 1, "Panning Add mode never spawns an accidental ship")
	tap(a)
	check(world.editor.scenario["units"].size() == 2 and world.ships.size() == 2, "Deliberate Add tap creates a real 3D vessel")
	world.editor.tool = "select"
	var marker: Vector2 = map.world_to_map(world.ships[0].position)
	var grab: Vector2 = marker + Vector2(6, 0)
	var expected_world: Vector3 = world.ships[0].position + Vector3(map.metres_per_pixel * 40, 0, 0)
	touch(0, grab, true)
	drag(0, grab + Vector2(40, 0), Vector2(40, 0))
	touch(0, grab + Vector2(40, 0), false)
	check(world.ships[0].position.distance_to(expected_world) < 0.01 and world.editor.selected == 0, "Dragging a hull preserves finger offset and updates actual 3D placement")
	var before_settings: String = JSON.stringify(world.editor.scenario)
	world.hud.show_scenario_settings()
	setting_fields()[0].value = 3.5
	world.hud.dismiss_modal()
	check(JSON.stringify(world.editor.scenario) == before_settings, "Canceling settings preserves the scenario and environment")
	world.hud.show_scenario_settings()
	setting_fields()[0].value = 3.5
	apply_settings()
	check(world.hud.modal == null and world.editor.scenario["waves"] == 3.5 and world.ocean.amplitude == 3.5 and world.editor.selected == 0, "Valid settings apply to the scenario and 3D preview together")
	world.editor.load_scenario(parallel)
	world.editor.selected = 0
	world.refresh_preview()
	world.hud.show_scenario_settings()
	setting_fields()[4].value = 90
	apply_settings()
	check(world.hud.modal != null and world.editor.scenario["units"][0]["heading"] == 0 and not world.editor.last_error.is_empty(), "Settings dialog cannot bypass overlapping-hull validation")
	world.hud.dismiss_modal()
	print("NAVIGATION RESULT: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit", 0 if failures == 0 else 1)
