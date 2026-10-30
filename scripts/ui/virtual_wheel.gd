class_name VirtualWheel
extends Control

var axis: float = 0
var free_axis: Vector2 = Vector2.ZERO
var active: bool = false
var pointer: int = -2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_circle(c, size.x * 0.46, Color(0.03, 0.08, 0.13, 0.85))
	draw_arc(c, size.x * 0.42, 0, TAU, 48, Color("55808c"), 3)
	draw_arc(c, size.x * 0.30, 0, TAU, 40, Color("203e4d"), 2)
	for i: int in 6:
		var angle: float = i * TAU / 6 + axis * 1.6
		draw_line(c + Vector2(cos(angle), sin(angle)) * 10, c + Vector2(cos(angle), sin(angle)) * size.x * 0.4, Color("bdd3d6"), 4)
	draw_circle(c, 12, Color("e8b76a"))

func set_pointer(point: Vector2) -> void:
	free_axis = (point - size * 0.5) / (size * 0.42)
	free_axis = free_axis.limit_length(1)
	free_axis.y = -free_axis.y
	axis = clampf(free_axis.x, -1, 1)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not active:
			pointer = event.index
			active = true
			set_pointer(event.position)
		elif not event.pressed and event.index == pointer:
			release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer:
		set_pointer(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		active = event.pressed
		pointer = -1
		if active:
			set_pointer(event.position)
		else:
			release()
	elif event is InputEventMouseMotion and active and pointer == -1:
		set_pointer(event.position)

func release() -> void:
	active = false
	axis = 0
	free_axis = Vector2.ZERO
	pointer = -2
	queue_redraw()
