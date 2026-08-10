extends Node2D

const RADIUS       := 44.0
const LINE_WIDTH   := 4.0
const COLOR_FULL   := Color(0.25, 0.85, 1.0, 0.85)
const COLOR_LOW    := Color(1.0, 0.35, 0.1, 0.85)
const ARC_POINTS   := 64
const FADE_IN_TIME := 0.15

var _progress: float = 0.0
var _visible: bool   = false

func _ready() -> void:
	modulate.a = 0.0

func fade_in() -> void:
	_visible   = true
	modulate.a = 0.0
	var tween  := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	queue_redraw()

func show_gauge(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	queue_redraw()

func hide_gauge() -> void:
	_visible   = false
	modulate.a = 0.0
	queue_redraw()

func _draw() -> void:
	if not _visible or _progress <= 0.0:
		return
	var color := COLOR_FULL.lerp(COLOR_LOW, 1.0 - _progress)
	var start  := -PI * 0.5
	var end    := start + TAU * _progress
	draw_arc(Vector2.ZERO, RADIUS, start, end, ARC_POINTS, color, LINE_WIDTH, true)
