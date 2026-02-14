extends CanvasLayer

# 暂停菜单层：
# - Resume: 恢复游戏
# - MainMenu: 返回主菜单
@onready var panel: Panel = $Root/Panel
@onready var resume_btn: Button = $Root/Panel/VBoxContainer/ResumeButton
@onready var menu_btn: Button = $Root/Panel/VBoxContainer/MainMenuButton


func _ready() -> void:
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)


func set_visible_menu(value: bool) -> void:
	# 保持一个统一入口控制显隐，便于后续扩展动画。
	panel.visible = value


func _on_resume_pressed() -> void:
	get_tree().paused = false
	set_visible_menu(false)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	GameManager.open_main_menu()
