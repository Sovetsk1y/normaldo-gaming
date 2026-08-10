extends Node2D

const RING_COLOR   := Color(1.0, 1.0, 1.0, 0.55)
const CENTER_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const KNOB_COLOR   := Color(1.0, 1.0, 1.0, 0.80)
const RING_RADIUS  := 95.0
const CENTER_RADIUS := 6.0
const KNOB_RADIUS  := 22.0

var _origin : Vector2
var _knob   : Vector2

func _draw() -> void:
	draw_arc(_origin, RING_RADIUS, 0.0, TAU, 64, RING_COLOR, 2.0, true)
	draw_circle(_origin, CENTER_RADIUS, CENTER_COLOR)
	draw_circle(_knob, KNOB_RADIUS, KNOB_COLOR)

func show_at(origin: Vector2) -> void:
	_origin = origin
	_knob   = origin
	visible  = true
	queue_redraw()

func update_origin(new_origin: Vector2) -> void:
	_origin = new_origin
	queue_redraw()

func move_knob(pos: Vector2) -> void:
	_knob = pos
	queue_redraw()

func hide_joystick() -> void:
	visible = false
