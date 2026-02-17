extends Node2D

# 区域施法选择覆盖层：显示圆形范围跟随鼠标，左键施放、右键/Esc 取消。
# 由 game.gd 挂载，player 请求进入 targeting 时显示。
signal cast_confirmed(world_pos: Vector2)
signal cast_cancelled

var _active := false
var _radius := 80.0
var _magic_def: Dictionary
var _magic_instance: MagicBase
var _caster: Node2D


## 进入 targeting 模式，等待玩家左键施放或右键/Esc 取消。
func start_targeting(magic_def: Dictionary, instance: MagicBase, caster: Node2D) -> void:
	_magic_def = magic_def
	_magic_instance = instance
	_caster = caster
	_radius = float(magic_def.get("area_radius", 80.0))
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
	if not _active:
		return
	var global_pos := get_global_mouse_position()
	var local_pos := to_local(global_pos)
	# 红边 + 半透明红填充
	var fill_color := Color(1.0, 0.2, 0.2, 0.35)
	var edge_color := Color(1.0, 0.3, 0.3, 1.0)
	var points := PackedVector2Array()
	for i in range(33):
		var a := float(i) * TAU / 32.0
		points.append(local_pos + Vector2(cos(a), sin(a)) * _radius)
	draw_colored_polygon(points, fill_color)
	draw_arc(local_pos, _radius, 0.0, TAU, 48, edge_color, 2.0)


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
			var world_pos := get_global_mouse_position()
			stop_targeting()
			cast_confirmed.emit(world_pos)
			get_viewport().set_input_as_handled()
