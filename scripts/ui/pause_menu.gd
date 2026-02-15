extends CanvasLayer

# 暂停菜单层：
# - Resume: 恢复游戏
# - MainMenu: 返回主菜单
@onready var panel: Panel = $Root/Panel
@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBoxContainer/ResumeButton
@onready var menu_btn: Button = $Root/Panel/VBoxContainer/MainMenuButton


func _ready() -> void:
	# Root 全屏容器默认不拦截输入，避免在面板隐藏时吞掉 HUD 点击。
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 仅可见的暂停面板负责接收点击。
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_apply_localized_texts()


func set_visible_menu(value: bool) -> void:
	# 保持一个统一入口控制显隐，便于后续扩展动画。
	panel.visible = value


func _on_resume_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	set_visible_menu(false)


func _on_menu_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	GameManager.open_main_menu()


func _apply_localized_texts() -> void:
	resume_btn.text = LocalizationManager.tr_key("pause.resume")
	menu_btn.text = LocalizationManager.tr_key("pause.main_menu")


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_texts()
