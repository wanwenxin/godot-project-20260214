extends CanvasLayer

# 通关结算界面：展示得分与玩家信息，布局与死亡界面一致
@onready var root: Control = $Root

var _backdrop: ColorRect
var _panel: Panel
var _content_container: VBoxContainer
var _menu_btn: Button


func _ready() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false


func show_result(wave: int, kills: int, time: float, player_node: Node) -> void:
	# 清空旧内容并重建（保留 _menu_btn 引用，不销毁）
	if _menu_btn.get_parent():
		_menu_btn.get_parent().remove_child(_menu_btn)
	for child in _content_container.get_children():
		child.queue_free()
	var save_data := SaveManager.load_game()
	var best_wave := int(save_data.get("best_wave", 0))
	var best_time := float(save_data.get("best_survival_time", 0.0))
	# 标题
	var title := Label.new()
	title.text = LocalizationManager.tr_key("result.title_victory")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	_content_container.add_child(title)
	# 得分区
	var score_block: Control = ResultPanelShared.build_score_block(wave, kills, time, best_wave, best_time)
	_content_container.add_child(score_block)
	# 玩家信息区
	var hp_current := 0
	var hp_max := 0
	var speed := 0.0
	var inertia := 0.0
	var weapon_details: Array = []
	if is_instance_valid(player_node):
		hp_current = int(player_node.current_health)
		hp_max = int(player_node.max_health)
		speed = float(player_node.base_speed)
		inertia = float(player_node.inertia_factor)
		if player_node.has_method("get_equipped_weapon_details"):
			weapon_details = player_node.get_equipped_weapon_details()
	var player_block: Control = ResultPanelShared.build_player_stats_block(hp_current, hp_max, speed, inertia, weapon_details)
	_content_container.add_child(player_block)
	# 返回主菜单按钮
	_content_container.add_child(_menu_btn)
	visible = true


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.offset_left = 0
	_backdrop.offset_top = 0
	_backdrop.offset_right = 0
	_backdrop.offset_bottom = 0
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.color = UiThemeConfig.load_theme().modal_backdrop
	root.add_child(_backdrop)
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -280
	_panel.offset_top = -220
	_panel.offset_right = 280
	_panel.offset_bottom = 220
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)
	_apply_panel_style()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)
	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 16)
	_content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_content_container)
	_menu_btn = Button.new()
	_menu_btn.name = "MenuButton"
	_menu_btn.text = LocalizationManager.tr_key("hud.back_to_menu")
	_menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	var theme := UiThemeConfig.load_theme()
	style.bg_color = theme.modal_panel_bg
	style.border_color = theme.modal_panel_border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)


func _on_menu_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	GameManager.open_main_menu()


func _on_language_changed(_code: String) -> void:
	if _menu_btn:
		_menu_btn.text = LocalizationManager.tr_key("hud.back_to_menu")
