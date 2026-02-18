extends EnemyBase


func _ready() -> void:
	super._ready()
	set_enemy_texture(enemy_type)


func _physics_process(delta: float) -> void:
	_move_towards_player(delta, 0.75)
