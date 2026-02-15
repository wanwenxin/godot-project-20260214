extends CanvasLayer

# 暂停菜单层：
# - Resume: 恢复游戏
# - MainMenu: 返回主菜单
@onready var panel: Panel = $Root/Panel
@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBoxContainer/ResumeButton
@onready var menu_btn: Button = $Root/Panel/VBoxContainer/MainMenuButton
@onready var key_hints_label: Label = $Root/Panel/VBoxContainer/KeyHintsLabel

var _fullscreen_backdrop: ColorRect


func _ready() -> void:
	# Root 全屏容器默认不拦截输入，避免在面板隐藏时吞掉 HUD 点击。
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_fullscreen_backdrop()
	# 仅可见的暂停面板负责接收点击。
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style()
	resume_btn.pressed.connect(_on_resume_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_apply_localized_texts()


func set_visible_menu(value: bool) -> void:
	# 保持一个统一入口控制显隐，便于后续扩展动画。
	panel.visible = value
	if _fullscreen_backdrop:
		_fullscreen_backdrop.visible = value
	if value:
		_refresh_key_hints()


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
	_refresh_key_hints()


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_texts()


func _refresh_key_hints() -> void:
	var settings := SaveManager.get_settings()
	var show_hints := bool(settings.get("game", {}).get("show_key_hints_in_pause", true))
	if not show_hints:
		key_hints_label.text = ""
		return
	key_hints_label.text = "\n".join([
		LocalizationManager.tr_key("pause.key_hint.move", {"keys": _action_to_text(["move_up", "move_down", "move_left", "move_right"])}),
		LocalizationManager.tr_key("pause.key_hint.pause", {"key": _action_to_text(["pause"])}),
		LocalizationManager.tr_key("pause.key_hint.enemy_hp", {"key": _action_to_text(["toggle_enemy_hp"])})
	])


func _action_to_text(actions: Array[StringName]) -> String:
	var result: Array[String] = []
	for action in actions:
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue
		var event := events[0]
		if event is InputEventKey:
			result.append(OS.get_keycode_string(event.keycode))
	if result.is_empty():
		return "-"
	return "/".join(result)


func _apply_panel_style() -> void:
	# 暂停菜单使用不透明面板，确保战斗背景不会干扰可读性。
	var style := StyleBoxFlat.new()
	style.bg_color = VisualAssetRegistry.get_color("ui.modal_panel_bg", Color(0.16, 0.17, 0.20, 1.0))
	style.border_color = VisualAssetRegistry.get_color("ui.modal_panel_border", Color(0.82, 0.84, 0.90, 1.0))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)


func _ensure_fullscreen_backdrop() -> void:
	# 暂停页全屏纯色背景，保证暂停菜单整体是完整弹层。
	_fullscreen_backdrop = ColorRect.new()
	_fullscreen_backdrop.name = "FullscreenBackdrop"
	_fullscreen_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_fullscreen_backdrop.offset_left = 0
	_fullscreen_backdrop.offset_top = 0
	_fullscreen_backdrop.offset_right = 0
	_fullscreen_backdrop.offset_bottom = 0
	_fullscreen_backdrop.visible = false
	_fullscreen_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_fullscreen_backdrop.color = VisualAssetRegistry.get_color("ui.modal_backdrop", Color(0.08, 0.09, 0.11, 1.0))
	root.add_child(_fullscreen_backdrop)
	root.move_child(_fullscreen_backdrop, 0)
