extends EnemyBase

## 冲刺攻击敌人：平时慢速靠近；蓄力后向玩家方向高速冲刺，冲刺命中造成伤害。

enum State { IDLE, WIND_UP, DASH, RECOVER }

@export var dash_cooldown := GameConstants.DASH_COOLDOWN_DEFAULT
@export var dash_speed := GameConstants.DASH_SPEED_DEFAULT
@export var dash_duration := GameConstants.DASH_DURATION_DEFAULT
@export var wind_up_duration := GameConstants.WIND_UP_DURATION_DEFAULT
@export var recover_duration := GameConstants.RECOVER_DURATION_DEFAULT

var _state := State.IDLE
var _state_timer := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_distance_remaining := 0.0
var _cooldown_remaining := 0.0


func _ready() -> void:
	super._ready()
	set_enemy_texture(enemy_type)


func _physics_process(delta: float) -> void:
	_cooldown_remaining -= delta

	match _state:
		State.IDLE:
			_move_towards_player(delta, GameConstants.DASHER_IDLE_MOVE_SCALE)
			if _cooldown_remaining <= 0.0 and is_instance_valid(player_ref):
				_dash_dir = (player_ref.global_position - global_position).normalized()
				if _dash_dir.length_squared() < 0.001:
					_dash_dir = Vector2.RIGHT
				else:
					_dash_dir = _dash_dir.normalized()
				_state = State.WIND_UP
				_state_timer = wind_up_duration
		State.WIND_UP:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_dash_distance_remaining = _compute_max_dash_distance()
				_state = State.DASH
		State.DASH:
			var move_dist := minf(
				dash_speed * _terrain_speed_multiplier * delta,
				_dash_distance_remaining
			)
			velocity = _dash_dir * (move_dist / delta)
			move_and_slide()
			_dash_distance_remaining -= move_dist
			if _dash_distance_remaining <= 0.0:
				_state = State.RECOVER
				_state_timer = recover_duration
				_cooldown_remaining = dash_cooldown
		State.RECOVER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.IDLE


func _compute_max_dash_distance() -> float:
	var game_node = get_tree().current_scene
	if game_node == null or not game_node.has_method("get_playable_bounds"):
		return dash_speed * dash_duration
	var bounds: Rect2 = game_node.get_playable_bounds()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return dash_speed * dash_duration
	var inset := 16.0
	var inner := Rect2(bounds.position + Vector2(inset, inset), bounds.size - Vector2(inset * 2.0, inset * 2.0))
	if inner.size.x <= 0 or inner.size.y <= 0:
		return dash_speed * dash_duration
	var theoretical := dash_speed * dash_duration * _terrain_speed_multiplier
	var pos := global_position
	var dir := _dash_dir
	# 射线 pos + t*dir 与矩形边界的交点，取最小正 t
	var t_min := INF
	if abs(dir.x) > 0.0001:
		if dir.x > 0:
			var t_right := (inner.end.x - pos.x) / dir.x
			if t_right > 0:
				t_min = minf(t_min, t_right)
		else:
			var t_left := (inner.position.x - pos.x) / dir.x
			if t_left > 0:
				t_min = minf(t_min, t_left)
	if abs(dir.y) > 0.0001:
		if dir.y > 0:
			var t_bottom := (inner.end.y - pos.y) / dir.y
			if t_bottom > 0:
				t_min = minf(t_min, t_bottom)
		else:
			var t_top := (inner.position.y - pos.y) / dir.y
			if t_top > 0:
				t_min = minf(t_min, t_top)
	if t_min == INF:
		return theoretical
	return minf(theoretical, t_min)
