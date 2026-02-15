extends CanvasLayer

# 暂停菜单层：全屏左右分栏布局
# - 左侧：系统信息（标题、按键提示、继续、主菜单）
# - 右侧：玩家信息（HP、移速、惯性、装备武器横向排布）
@onready var panel: Panel = $Root/Panel
@onready var root: Control = $Root

var _fullscreen_backdrop: ColorRect
var _stats_container: VBoxContainer
var _resume_btn: Button
var _menu_btn: Button
var _key_hints_label: Label


func _ready() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_fullscreen_backdrop()
	_build_main_layout()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_panel_style()
	_resume_btn.pressed.connect(_on_resume_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_apply_localized_texts()


func set_visible_menu(value: bool) -> void:
	panel.visible = value
	if _fullscreen_backdrop:
		_fullscreen_backdrop.visible = value
	if value:
		_refresh_key_hints()
		_refresh_stats_from_game()


func _on_resume_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	set_visible_menu(false)


func _on_menu_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	GameManager.open_main_menu()


func _apply_localized_texts() -> void:
	var title := panel.get_node_or_null("OuterMargin/MainLayout/LeftWrapper/LeftColumn/MarginContainer/InnerVBox/TitleLabel")
	if title is Label:
		title.text = LocalizationManager.tr_key("pause.title")
	_resume_btn.text = LocalizationManager.tr_key("pause.resume")
	_menu_btn.text = LocalizationManager.tr_key("pause.main_menu")
	_refresh_key_hints()


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_texts()


# 清空右侧玩家区并填充 ResultPanelShared 构建的 HP/移速/惯性/武器卡片。
func set_player_stats_full(hp_current: int, hp_max: int, speed: float, inertia: float, weapon_details: Array) -> void:
	if _stats_container == null:
		return
	for child in _stats_container.get_children():
		child.queue_free()
	var block: Control = ResultPanelShared.build_player_stats_block(hp_current, hp_max, speed, inertia, weapon_details)
	_stats_container.add_child(block)


func _build_main_layout() -> void:
	# 外层填满画布，仅保留适度边距
	var outer := MarginContainer.new()
	outer.name = "OuterMargin"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	outer.add_theme_constant_override("margin_left", 32)
	outer.add_theme_constant_override("margin_top", 32)
	outer.add_theme_constant_override("margin_right", 32)
	outer.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(outer)
	var main := HBoxContainer.new()
	main.name = "MainLayout"
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 32)
	outer.add_child(main)
	# 左侧：系统信息水平居中
	var left_wrapper := CenterContainer.new()
	left_wrapper.name = "LeftWrapper"
	left_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_wrapper.custom_minimum_size.x = 280
	main.add_child(left_wrapper)
	var left := _build_left_column()
	left_wrapper.add_child(left)
	# 右侧：占满剩余空间，内容居中，无需滚动
	var right_wrapper := CenterContainer.new()
	right_wrapper.name = "RightWrapper"
	right_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right_wrapper)
	right_wrapper.add_child(_build_right_column())


func _build_left_column() -> VBoxContainer:
	var left := VBoxContainer.new()
	left.name = "LeftColumn"
	left.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 32)
	left.add_child(margin)
	var inner := VBoxContainer.new()
	inner.name = "InnerVBox"
	inner.add_theme_constant_override("separation", 16)
	margin.add_child(inner)
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = LocalizationManager.tr_key("pause.title")
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	inner.add_child(title_lbl)
	_key_hints_label = Label.new()
	_key_hints_label.name = "KeyHintsLabel"
	_key_hints_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key_hints_label.add_theme_font_size_override("font_size", 13)
	_key_hints_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	inner.add_child(_key_hints_label)
	_resume_btn = Button.new()
	_resume_btn.name = "ResumeButton"
	inner.add_child(_resume_btn)
	_menu_btn = Button.new()
	_menu_btn.name = "MainMenuButton"
	inner.add_child(_menu_btn)
	return left


func _build_right_column() -> Control:
	# 右侧占满剩余空间，内容在 CenterContainer 中居中，无滚动条
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(right_vbox)
	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 12)
	right_vbox.add_child(_stats_container)
	return margin


func _refresh_stats_from_game() -> void:
	var game := get_tree().current_scene
	if game == null or not game.has_method("get_player_for_pause"):
		return
	var p = game.get_player_for_pause()
	if p == null or not is_instance_valid(p):
		return
	var weapon_details: Array = []
	if p.has_method("get_equipped_weapon_details"):
		weapon_details = p.get_equipped_weapon_details()
	set_player_stats_full(int(p.current_health), int(p.max_health), p.base_speed, p.inertia_factor, weapon_details)


func _refresh_key_hints() -> void:
	var settings := SaveManager.get_settings()
	var show_hints := bool(settings.get("game", {}).get("show_key_hints_in_pause", true))
	if not show_hints:
		_key_hints_label.text = ""
		return
	_key_hints_label.text = "\n".join([
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
