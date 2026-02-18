extends Node2D

# 魔法施法选择覆盖层：按 range_type 显示施法范围（直线/鼠标圆心圆/角色圆心圆），左键施放、右键/Esc 取消。
# 由 game.gd 挂载，player 请求进入 targeting 时显示。
signal cast_confirmed(world_pos: Vector2)
signal cast_cancelled

var _active := false
var _radius := 80.0
var _width := 40.0  # line 时的宽度
var _range_type := "mouse_circle"
var _magic_def: Dictionary
var _magic_instance: MagicBase
var _caster: Node2D


## 进入 targeting 模式，等待玩家左键施放或右键/Esc 取消。
func start_targeting(magic_def: Dictionary, instance: MagicBase, caster: Node2D) -> void:
	_magic_def = magic_def
	_magic_instance = instance
	_caster = caster
	if instance != null:
		_radius = float(instance.range_size)
		_width = float(instance.range_size)
		_range_type = str(instance.range_type)
	else:
		_radius = 80.0
		_width = 40.0
		_range_type = "mouse_circle"
	_active = true
	visible = true
	set_process_input(true)


## 退出 targeting 模式。
func stop_targeting() -> void:
	_active = false
	visible = false
	set_process_input(false)


func _process(_delta: float) -> void:
	if _active:
		queue_redraw()


func _draw() -> void:
	if not _active or not is_instance_valid(_caster):
		return
	var fill_color := Color(1.0, 0.2, 0.2, 0.35)
	var edge_color := Color(1.0, 0.3, 0.3, 1.0)
	var mouse_global := get_global_mouse_position()
	var mouse_local := to_local(mouse_global)
	var caster_local := to_local(_caster.global_position)
	match _range_type:
		"line":
			_draw_line_range(caster_local, mouse_local, fill_color, edge_color)
		"mouse_circle":
			_draw_circle_range(mouse_local, _radius, fill_color, edge_color)
		"char_circle", _:
			_draw_circle_range(caster_local, _radius, fill_color, edge_color)


## 绘制直线范围：从角色到鼠标的矩形，宽度为 _width。
func _draw_line_range(from: Vector2, to: Vector2, fill_color: Color, edge_color: Color) -> void:
	var diff := to - from
	var len := diff.length()
	if len < 1.0:
		return
	var dir := diff.normalized()
	var perp := Vector2(-dir.y, dir.x) * (_width * 0.5)
	var p0 := from + perp
	var p1 := from - perp
	var p2 := to - perp
	var p3 := to + perp
	var points := PackedVector2Array([p0, p1, p2, p3])
	draw_colored_polygon(points, fill_color)
	draw_line(p0, p1, edge_color)
	draw_line(p1, p2, edge_color)
	draw_line(p2, p3, edge_color)
	draw_line(p3, p0, edge_color)


## 绘制圆形范围。
func _draw_circle_range(center: Vector2, rad: float, fill_color: Color, edge_color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(33):
		var a := float(i) * TAU / 32.0
		points.append(center + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(points, fill_color)
	draw_arc(center, rad, 0.0, TAU, 48, edge_color, 2.0)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		stop_targeting()
		cast_cancelled.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			stop_targeting()
			cast_cancelled.emit()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos: Vector2
			if _range_type == "char_circle" and is_instance_valid(_caster):
				world_pos = _caster.global_position
			else:
				world_pos = get_global_mouse_position()
			stop_targeting()
			cast_confirmed.emit(world_pos)
			get_viewport().set_input_as_handled()
