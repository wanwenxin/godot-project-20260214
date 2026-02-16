extends EnemyBase

## 水中专属敌人：仅在水域中生成与存活，离开水面则持续扣血死亡。
## 在水中时朝玩家移动，且只在水域边界内移动。

var _water_bounds := Rect2()


func set_water_bounds(rect: Rect2) -> void:
	_water_bounds = rect


func is_water_only() -> bool:
	return true


func _ready() -> void:
	super._ready()
	set_enemy_texture(4)


func _physics_process(delta: float) -> void:
	if _is_in_water():
		if _water_bounds.size.x > 0 and _water_bounds.size.y > 0:
			var inset := 12.0
			var inner := Rect2(
				_water_bounds.position + Vector2(inset, inset),
				_water_bounds.size - Vector2(inset * 2.0, inset * 2.0)
			)
			if inner.size.x > 0 and inner.size.y > 0:
				_move_towards_player_clamped(delta, 1.0, inner)
			else:
				_move_towards_player(delta, 1.0)
		else:
			_move_towards_player(delta, 1.0)
	# 离水时由 enemy_base._process 处理扣血，此处不移动
