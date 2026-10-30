class_name TacticalMap
extends Control

signal tapped(point: Vector3, unit_index: int)
signal unit_moved(index: int, point: Vector3)
const DRAG_THRESHOLD: float = 12.0
var world: GameManager
var mini: bool = false
var center: Vector2 = Vector2.ZERO
var metres_per_pixel: float = 9.0
var dragging: bool = false
var dragged_unit: int = -1
var last_position: Vector2
var touches: Dictionary = {}
var pinch_distance: float = 0
var refresh: float = 0
var press_position: Vector2
var pointer_id: int = -2
var pointer_moved: bool = false
var multitouch: bool = false
var grab_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel_gesture())

func _process(delta: float) -> void:
	refresh += delta
	if mini and world.player != null:
		center = Vector2(world.player.position.x, world.player.position.z)
		metres_per_pixel = 16
	if refresh > 0.1:
		refresh = 0
		queue_redraw()

func world_to_map(point: Vector3) -> Vector2:
	return (Vector2(point.x, point.z) - center) / metres_per_pixel + size * 0.5

func map_to_world(point: Vector2) -> Vector3:
	var p: Vector2 = (point - size * 0.5) * metres_per_pixel + center
	return Vector3(p.x, 0, p.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1b2b"))
	var grid: float = 500.0 / metres_per_pixel
	var origin: Vector2 = world_to_map(Vector3.ZERO)
	for x: int in range(-20, 21):
		draw_line(Vector2(origin.x + x * grid, 0), Vector2(origin.x + x * grid, size.y), Color("173342"))
		draw_line(Vector2(0, origin.y + x * grid), Vector2(size.x, origin.y + x * grid), Color("173342"))
	if world == null:
		return
	if world.terrain.visible:
		for island: Dictionary in world.terrain.islands:
			var p: Vector2 = world_to_map(Vector3(island["x"], 0, island["z"]))
			draw_circle(p, float(island["radius"]) / metres_per_pixel, Color("3d5555"))
			draw_arc(p, float(island["radius"]) * 1.15 / metres_per_pixel, 0, TAU, 32, Color("6a7768"), 1)
		var port: Vector2 = world_to_map(world.terrain.port_position)
		draw_rect(Rect2(port - Vector2(4, 4), Vector2(8, 8)), Color("e8b76a"))
	if world.mission.active >= 0 and not world.mission.done:
		var marker: Vector2 = world_to_map(world.mission.marker)
		draw_arc(marker, 12, 0, TAU, 24, Color("e8b76a"), 2)
		draw_line(marker - Vector2(18, 0), marker + Vector2(18, 0), Color("e8b76a"))
	for i: int in world.ships.size():
		var ship: ShipController = world.ships[i]
		if not show_unit(ship):
			continue
		var p: Vector2 = world_to_map(ship.global_position)
		var col: Color = Color("55d4d0") if ship.team == 0 else Color("ee876d")
		var heading: float = -ship.rotation.y
		var forward: Vector2 = Vector2(sin(heading), -cos(heading))
		var right: Vector2 = Vector2(-forward.y, forward.x)
		var vertices: PackedVector2Array = PackedVector2Array([p + forward * 9, p - forward * 6 + right * 5, p - forward * 3, p - forward * 6 - right * 5])
		draw_colored_polygon(vertices, col)
		if ship.is_submarine():
			draw_arc(p, 12, 0, TAU, 18, col, 1)
		if ship == world.player or (world.editing and world.editor.selected == i) or ship == world.map_selected:
			draw_arc(p, 17, 0, TAU, 24, Color("e8b76a"), 2)
		if not mini:
			var text: String = ship.unit_name if metres_per_pixel < 4 else "%02d" % (i + 1)
			draw_string(ThemeDB.fallback_font, p + Vector2(15, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			if metres_per_pixel < 4:
				draw_string(ThemeDB.fallback_font, p + Vector2(15, 14), "%03d° · %.0f уз" % [ship.heading_degrees(), absf(ship.speed) * 1.944], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("99afb9"))
	if world.player != null and not world.editing:
		var previous: Vector2 = world_to_map(world.player.position)
		for waypoint: Vector3 in world.player.waypoints:
			var p: Vector2 = world_to_map(waypoint)
			draw_line(previous, p, Color("e8b76a"), 1.5)
			draw_arc(p, 7, 0, TAU, 16, Color("e8b76a"), 2)
			previous = p
	draw_rect(Rect2(Vector2.ZERO, size), Color("396175"), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), "N ↑  ·  %.0f м" % (100 * metres_per_pixel), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a4bdc9"))
	draw_line(Vector2(10, size.y - 16), Vector2(110, size.y - 16), Color("a4bdc9"), 2)

func show_unit(ship: ShipController) -> bool:
	return not ship.damage.sinking and (world.editing or world.spectator.active or world.can_detect(0, ship))

func nearest_unit(point: Vector2) -> int:
	var selected: int = -1
	var closest: float = 28
	for i: int in world.ships.size():
		if not show_unit(world.ships[i]):
			continue
		var distance: float = point.distance_to(world_to_map(world.ships[i].position))
		if distance < closest:
			closest = distance
			selected = i
	return selected

func _gui_input(event: InputEvent) -> void:
	if mini:
		if event is InputEventMouseButton and event.pressed:
			world.hud.toggle_map()
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMagnifyGesture:
		metres_per_pixel = clampf(metres_per_pixel / event.factor, 1.3, 25)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1 and not multitouch:
				begin_pointer(event.position, event.index)
			elif touches.size() >= 2:
				multitouch = true
				dragging = false
				pinch_distance = touch_distance()
				dragged_unit = -1
		else:
			touches.erase(event.index)
			if event.index == pointer_id and not multitouch:
				end_pointer(event.position, event.canceled)
			if touches.is_empty():
				cancel_gesture()
		accept_event()
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if multitouch and touches.size() == 2:
			var next: float = touch_distance()
			if next > 0 and pinch_distance > 0:
				metres_per_pixel = clampf(metres_per_pixel * pinch_distance / next, 1.3, 25)
			pinch_distance = next
		elif dragging and not multitouch and event.index == pointer_id:
			drag_pointer(event.position, event.relative)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			metres_per_pixel = maxf(1.3, metres_per_pixel * 0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			metres_per_pixel = minf(25, metres_per_pixel * 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				begin_pointer(event.position)
			else:
				end_pointer(event.position)
	elif event is InputEventMouseMotion and dragging and pointer_id == -1:
		drag_pointer(event.position, event.relative)
	queue_redraw()

func begin_pointer(point: Vector2, id: int = -1) -> void:
	dragging = true
	pointer_id = id
	pointer_moved = false
	press_position = point
	last_position = point
	dragged_unit = nearest_unit(point) if world.editing and world.editor.tool == "select" else -1
	grab_offset = world.ships[dragged_unit].position - map_to_world(point) if dragged_unit >= 0 else Vector3.ZERO

func end_pointer(point: Vector2, canceled: bool = false) -> void:
	var should_tap: bool = dragging and not pointer_moved and not multitouch and not canceled
	should_tap = should_tap and press_position.distance_to(point) < DRAG_THRESHOLD
	should_tap = should_tap and Rect2(Vector2.ZERO, size).has_point(point)
	dragging = false
	pointer_id = -2
	dragged_unit = -1
	if should_tap:
		tapped.emit(map_to_world(point), nearest_unit(point))
	queue_redraw()

func drag_pointer(point: Vector2, _relative: Vector2) -> void:
	if not dragging or multitouch:
		return
	var relative: Vector2 = point - last_position
	if not pointer_moved:
		if press_position.distance_to(point) < DRAG_THRESHOLD:
			return
		pointer_moved = true
		relative = point - press_position
	last_position = point
	if dragged_unit >= 0:
		unit_moved.emit(dragged_unit, map_to_world(point) + grab_offset)
	else:
		center -= relative * metres_per_pixel
	queue_redraw()

func cancel_gesture() -> void:
	touches.clear()
	dragging = false
	dragged_unit = -1
	pointer_id = -2
	pointer_moved = false
	multitouch = false
	pinch_distance = 0

func touch_distance() -> float:
	var values: Array = touches.values()
	return (values[0] as Vector2).distance_to(values[1]) if values.size() == 2 else 0.0
