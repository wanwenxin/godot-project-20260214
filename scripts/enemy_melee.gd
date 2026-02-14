extends "res://scripts/enemy_base.gd"


func _ready() -> void:
	super._ready()
	set_enemy_texture(0)


func _physics_process(delta: float) -> void:
	_move_towards_player(delta, 1.0)
