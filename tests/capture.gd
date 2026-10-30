extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game: GameManager = load("res://scenes/main.tscn").instantiate() as GameManager
	root.add_child(game)
	for i: int in 40:
		await process_frame
	root.get_texture().get_image().save_png("res://build/menu.png")
	game.start_battle(VesselCatalog.default_scenario())
	for ship: ShipController in game.ships:
		ship.ai.set_physics_process(false)
	game.player.throttle = 0.6
	for i: int in 60:
		await process_frame
	root.get_texture().get_image().save_png("res://build/battle.png")
	game.hud.toggle_map()
	game.hud.append_route_button.button_pressed = true
	game.player.set_waypoint(Vector3(500, 0, -400))
	game.player.set_waypoint(Vector3(1000, 0, -1200), true)
	for i: int in 10:
		await process_frame
	root.get_texture().get_image().save_png("res://build/tactical.png")
	game.open_editor()
	for i: int in 15:
		await process_frame
	root.get_texture().get_image().save_png("res://build/editor.png")
	game.queue_free()
	await process_frame
	quit()
