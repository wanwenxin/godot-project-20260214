extends EnemyBase


func _ready() -> void:
	super._ready()
	# 坦克敌人：耐久高、移动慢、接触伤害高。
	set_enemy_texture(enemy_type)


func _physics_process(delta: float) -> void:
	_move_towards_player(delta, 0.75)
