extends CanvasLayer

# 通关结算界面：展示得分与玩家信息，布局与死亡界面一致
@onready var root: Control = $Root

var _backdrop: ColorRect
var _panel: Panel
var _tab_container: TabContainer
var _score_tab_container: VBoxContainer
var _backpack_tab_container: Control  # 背包 Tab 内容
var _stats_tab_container: Control
var _menu_btn: Button


## [系统] 节点入树时调用，构建 UI 并默认隐藏。
func _ready() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false


## [自定义] 显示通关结算：得分、背包、角色信息三 Tab。动态加载：load(backpack_panel.gd) 运行时实例化 BackpackPanel。
func show_result(wave: int, kills: int, time: float, player_node: Node) -> void:
	# 清空旧内容并重建（保留 _menu_btn 引用，不销毁）
	if _menu_btn.get_parent():
		_menu_btn.get_parent().remove_child(_menu_btn)
	for child in _score_tab_container.get_children():
		child.queue_free()
	for child in _backpack_tab_container.get_children():
		child.queue_free()
	for child in _stats_tab_container.get_children():
		child.queue_free()
	var save_data := SaveManager.load_game()
	var best_wave := int(save_data.get("best_wave", 0))
	var best_time := float(save_data.get("best_survival_time", 0.0))
	# 得分 Tab：标题 + 得分区 + 返回主菜单
	var title := Label.new()
	title.text = LocalizationManager.tr_key("result.title_victory")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	_score_tab_container.add_child(title)
	var gold := GameManager.run_currency
	var total_damage := GameManager.run_total_damage
	var score_block: Control = ResultPanelShared.build_score_block(wave, kills, time, best_wave, best_time, gold, total_damage)
	_score_tab_container.add_child(score_block)
	_score_tab_container.add_child(_menu_btn)
	# 背包 Tab：复用 BackpackPanel，shop_context=false
	var stats: Dictionary = {}
	if is_instance_valid(player_node) and player_node.has_method("get_full_stats_for_pause"):
		stats = player_node.get_full_stats_for_pause()
	else:
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
		stats = {"hp_current": hp_current, "hp_max": hp_max, "speed": speed, "inertia": inertia, "weapon_details": weapon_details, "magic_details": [], "item_ids": []}
	stats["wave"] = wave
	var backpack_panel: VBoxContainer = (load("res://scripts/ui/backpack_panel.gd") as GDScript).new()
	backpack_panel.name = "BackpackPanel"
	backpack_panel.add_theme_constant_override("separation", 12)
	backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_tab_container.add_child(backpack_panel)
	backpack_panel.set_stats(stats, false)
	# 角色信息 Tab
	var player_block: Control = ResultPanelShared.build_player_stats_block(stats)
	_stats_tab_container.add_child(player_block)
	visible = true


## [自定义] 构建全屏遮罩、居中面板、三 Tab（得分/背包/角色信息）、返回主菜单按钮。
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
	_tab_container = TabContainer.new()
	_tab_container.tabs_position = TabContainer.TabPosition.POSITION_TOP  # Tab 标签置于顶部
	_tab_container.add_theme_font_size_override("font_size", 20)  # Tab 标签字体放大
	_tab_container.add_theme_constant_override("side_margin", 16)  # Tab 内容区左右间距
	_tab_container.add_theme_constant_override("top_margin", 16)  # Tab 内容区顶部间距
	margin.add_child(_tab_container)
	# Tab 0：得分
	var score_tab := ScrollContainer.new()
	score_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	score_tab.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_score_tab_container = VBoxContainer.new()
	_score_tab_container.add_theme_constant_override("separation", 16)
	_score_tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_score_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_tab.add_child(_score_tab_container)
	_tab_container.add_child(score_tab)
	_tab_container.set_tab_title(0, LocalizationManager.tr_key("result.tab_score"))
	# Tab 1：背包
	var backpack_scroll := ScrollContainer.new()
	backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backpack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_backpack_tab_container = VBoxContainer.new()
	_backpack_tab_container.add_theme_constant_override("separation", 12)
	_backpack_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_scroll.add_child(_backpack_tab_container)
	_tab_container.add_child(backpack_scroll)
	_tab_container.set_tab_title(1, LocalizationManager.tr_key("result.tab_backpack"))
	# Tab 2：角色信息
	var stats_scroll := ScrollContainer.new()
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_stats_tab_container = VBoxContainer.new()
	_stats_tab_container.add_theme_constant_override("separation", 12)
	_stats_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(_stats_tab_container)
	_tab_container.add_child(stats_scroll)
	_tab_container.set_tab_title(2, LocalizationManager.tr_key("result.tab_stats"))
	_menu_btn = Button.new()
	_menu_btn.name = "MenuButton"
	_menu_btn.text = LocalizationManager.tr_key("hud.back_to_menu")
	_menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)


func _apply_panel_style() -> void:
	_panel.add_theme_stylebox_override("panel", UiThemeConfig.load_theme().get_modal_panel_stylebox())


func _on_menu_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	GameManager.open_main_menu()


func _on_language_changed(_code: String) -> void:
	if _menu_btn:
		_menu_btn.text = LocalizationManager.tr_key("hud.back_to_menu")
	if _tab_container:
		_tab_container.set_tab_title(0, LocalizationManager.tr_key("result.tab_score"))
		_tab_container.set_tab_title(1, LocalizationManager.tr_key("result.tab_backpack"))
		_tab_container.set_tab_title(2, LocalizationManager.tr_key("result.tab_stats"))
