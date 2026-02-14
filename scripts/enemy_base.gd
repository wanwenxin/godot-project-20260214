extends CharacterBody2D

signal died(enemy: Node)

@export var max_health := 25
@export var speed := 90.0
@export var contact_damage := 8
@export var contact_damage_interval := 0.6

var current_health := 25
var player_ref: Node2D
var _can_contact_damage := true

@onready var sprite: Sprite2D = $Sprite2D
@onready var contact_timer: Timer = $ContactDamageTimer
@onready var hurt_area: Area2D = $HurtArea


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	current_health = max_health
	if hurt_area:
		hurt_area.body_entered.connect(_on_hurt_area_body_entered)
	if contact_timer:
		contact_timer.wait_time = contact_damage_interval
		contact_timer.timeout.connect(_on_contact_timer_timeout)


func set_player(node: Node2D) -> void:
	player_ref = node


func set_enemy_texture(enemy_type: int) -> void:
	if sprite:
		sprite.texture = PixelGenerator.generate_enemy_sprite(enemy_type)


func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		emit_signal("died", self)
		queue_free()


func _move_towards_player(_delta: float, move_scale: float = 1.0) -> void:
	if not is_instance_valid(player_ref):
		return
	var dir := (player_ref.global_position - global_position).normalized()
	velocity = dir * speed * move_scale
	move_and_slide()


func _on_hurt_area_body_entered(body: Node) -> void:
	if not _can_contact_damage:
		return
	if body.is_in_group("players") and body.has_method("take_damage"):
		body.take_damage(contact_damage)
		_can_contact_damage = false
		contact_timer.start()


func _on_contact_timer_timeout() -> void:
	_can_contact_damage = true
