extends Node2D

# 敌人出生预警：
# - 闪烁警示圈
# - 倒计时文本
# 到时后发出 telegraph_finished，实际敌人再落地。
signal telegraph_finished

@export var duration := 0.9
@export var show_ring := true
@export var show_countdown := true
@export var ring_radius := 22.0
@export var ring_color := Color(1.0, 0.30, 0.30, 0.90)
@export var text_color := Color(1.0, 0.95, 0.95, 1.0)

var _remaining := 0.0
var _finished := false
var _ring: Line2D
var _label: Label


func _ready() -> void:
	_remaining = maxf(0.05, duration)
	_ring = Line2D.new()
	_ring.width = 2.5
	_ring.default_color = ring_color
	_ring.closed = true
	_ring.z_index = 30
	_ring.visible = show_ring
	_build_ring_points()
	add_child(_ring)

	_label = Label.new()
	_label.text = ""
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(52, 24)
	_label.position = Vector2(-26, -12)
	_label.modulate = text_color
	_label.z_index = 31
	_label.visible = show_countdown
	add_child(_label)


func _process(delta: float) -> void:
	if _finished:
		return
	_remaining -= delta
	if show_ring and _ring:
		var pulse := 0.55 + 0.45 * (sin(Time.get_ticks_msec() / 110.0) * 0.5 + 0.5)
		_ring.modulate = Color(1.0, 1.0, 1.0, pulse)
	if show_countdown and _label:
		_label.text = "%.1f" % maxf(_remaining, 0.0)
	if _remaining <= 0.0:
		_finished = true
		emit_signal("telegraph_finished")


func _build_ring_points() -> void:
	var points: PackedVector2Array = []
	var steps := 24
	for i in range(steps):
		var t := float(i) / float(steps)
		var angle := t * TAU
		points.append(Vector2(cos(angle), sin(angle)) * ring_radius)
	_ring.points = points
