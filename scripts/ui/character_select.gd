extends Control

@onready var card_a: Button = $CenterContainer/VBoxContainer/Characters/CharacterA
@onready var card_b: Button = $CenterContainer/VBoxContainer/Characters/CharacterB
@onready var detail: Label = $CenterContainer/VBoxContainer/Detail
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

var selected_character_id := 0


func _ready() -> void:
	card_a.pressed.connect(func() -> void: _select_character(0))
	card_b.pressed.connect(func() -> void: _select_character(1))
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_select_character(GameManager.selected_character_id)


func _select_character(character_id: int) -> void:
	selected_character_id = character_id
	var data := GameManager.get_character_data(character_id)
	var text := "Name: %s\nHP: %d\nSpeed: %.0f\nFireRate: %.2f\nDamage: %d" % [
		String(data.get("name", "Unknown")),
		int(data.get("max_health", 100)),
		float(data.get("speed", 0.0)),
		float(data.get("fire_rate", 0.3)),
		int(data.get("bullet_damage", 0))
	]
	detail.text = text
	card_a.text = "RapidShooter" + (" [Selected]" if selected_character_id == 0 else "")
	card_b.text = "HeavyGunner" + (" [Selected]" if selected_character_id == 1 else "")


func _on_start_pressed() -> void:
	GameManager.start_new_game(selected_character_id)


func _on_back_pressed() -> void:
	GameManager.open_main_menu()
