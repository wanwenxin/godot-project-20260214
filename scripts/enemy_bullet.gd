extends "res://scripts/bullet.gd"

# 敌人子弹：独立类，个头更大、速度更慢，使用专用像素图。
# 与玩家子弹区分，便于识别与平衡调整。

func _ready() -> void:
	hit_player = true
	speed = GameConstants.ENEMY_BULLET_SPEED
	collision_radius = 6.0
	texture_path = "res://assets/bullets/enemy_bullet.png"
	super._ready()
