extends CanvasLayer

@onready var panel: Panel = $Root/Panel
@onready var resume_btn: Button = $Root/Panel/VBoxContainer/ResumeButton
@onready var menu_btn: Button = $Root/Panel/VBoxContainer/MainMenuButton


func _ready() -> void:
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)


func set_visible_menu(value: bool) -> void:
	panel.visible = value


func _on_resume_pressed() -> void:
	get_tree().paused = false
	set_visible_menu(false)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.open_main_menu()
