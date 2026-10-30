class_name CameraManager
extends Node3D

const MODES: Array[String] = ["Внешняя", "Мостик", "Перископ", "Свободная", "Тактическая", "Снаряд", "Кино"]
var camera: Camera3D
var follow: ShipController
var projectile: ProjectileController
var mode: int = 0
var yaw: float = 0.45
var pitch: float = 0.32
var distance: float = 180.0
var free_position: Vector3 = Vector3(0, 180, 500)
var shake: float = 0.0
var touch_id: int = -1
var last_touch: Vector2
var free_axis: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var cinematic_clock: float = 0.0
var framing_offset: Vector3 = Vector3.ZERO
var touch_positions: Dictionary = {}
var pinch_distance: float = 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.5
	camera.far = 6500
	camera.fov = 62
	add_child(camera)
	camera.current = true
	camera.position = Vector3(160, 120, 260)

func _process(delta: float) -> void:
	if not is_instance_valid(follow):
		return
	var origin: Vector3 = follow.global_position
	var point: Vector3 = origin + Vector3.UP * 6 + framing_offset
	var desired: Vector3
	var hull_length: float = follow.stats["length"]
	if mode == 1:
		desired = origin + follow.basis * Vector3(0, 12 if not follow.is_submarine() else 7, -hull_length * 0.08)
		point = desired - follow.basis.z * 120 + Vector3(sin(yaw) * 80, -pitch * 15, 0)
	elif mode == 2:
		desired = Vector3(origin.x, maxf(2.5, origin.y + 9) if follow.get_depth() <= 10 else origin.y + 9, origin.z)
		point = desired + Vector3(-sin(yaw), -pitch * 0.08, -cos(yaw)) * 200
	elif mode == 3:
		var forward: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
		var right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
		free_position += (forward * free_axis.y + right * free_axis.x) * delta * 180
		if Input.is_physical_key_pressed(KEY_Q):
			free_position.y += delta * 100
		if Input.is_physical_key_pressed(KEY_E):
			free_position.y -= delta * 100
		desired = free_position
		point = desired + Vector3(-sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch)) * 200
	elif mode == 4:
		desired = origin + Vector3(0, 1800 * zoom, 80)
	elif mode == 5 and is_instance_valid(projectile) and projectile.active:
		point = projectile.global_position
		desired = point - projectile.direction * (30 if projectile.kind == "missile" else 16) + Vector3(5, 6, 5)
	elif mode == 6:
		cinematic_clock += delta
		desired = origin + Vector3(sin(cinematic_clock * 0.08) * hull_length * 1.8, hull_length * 0.55, cos(cinematic_clock * 0.08) * hull_length * 1.8)
	else:
		desired = origin + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * (distance + hull_length * 0.55) * zoom
	shake = move_toward(shake, 0, delta * 2)
	desired += Vector3(sin(Time.get_ticks_msec() * 0.057), cos(Time.get_ticks_msec() * 0.073), 0) * shake
	camera.global_position = camera.global_position.lerp(desired, 1 - exp(-delta * 6))
	if camera.global_position.distance_to(point) > 0.1:
		camera.look_at(point, Vector3.UP)

func set_mode(index: int) -> void:
	mode = clampi(index, 0, MODES.size() - 1)
	if mode == 3:
		free_position = camera.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_positions[event.index] = event.position
			if touch_positions.size() == 2:
				var values: Array = touch_positions.values()
				pinch_distance = (values[0] as Vector2).distance_to(values[1])
		else:
			touch_positions.erase(event.index)
		if event.pressed and touch_id == -1:
			touch_id = event.index
			last_touch = event.position
		elif not event.pressed and touch_id == event.index:
			touch_id = -1
	elif event is InputEventScreenDrag:
		touch_positions[event.index] = event.position
		if touch_positions.size() == 2:
			var values: Array = touch_positions.values()
			var next_distance: float = (values[0] as Vector2).distance_to(values[1])
			if pinch_distance > 0 and next_distance > 0:
				zoom = clampf(zoom * pinch_distance / next_distance, 0.35, 3)
			pinch_distance = next_distance
		elif event.index == touch_id:
			orbit(event.relative)
	elif event is InputEventMagnifyGesture:
		zoom = clampf(zoom / event.factor, 0.35, 3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(0.35, zoom * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(3, zoom * 1.1)

func orbit(delta: Vector2) -> void:
	yaw -= delta.x * 0.005
	pitch = clampf(pitch + delta.y * 0.004, -0.35, 1.35)
