extends EnemyBase


func _ready() -> void:
	super._ready()
	set_enemy_texture(enemy_type)


func _physics_process(delta: float) -> void:
	# 近战行为：直接追玩家。
	_move_towards_player(delta, 1.0)
