extends CanvasLayer

# 暂停菜单层：全屏左右分栏布局
# - 左侧：系统信息（标题、按键提示、继续、主菜单）
# - 右侧：玩家信息（HP、移速、惯性、装备武器横向排布）
@onready var panel: Panel = $Root/Panel
@onready var root: Control = $Root

var _fullscreen_backdrop: ColorRect
var _stats_container: VBoxContainer
var _backpack_panel: VBoxContainer  # 背包面板，Tab 2 内容
var _tab_container: TabContainer  # 属性/背包标签容器，用于语言切换时更新标题
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
	else:
		if _backpack_panel != null and _backpack_panel.has_method("hide_tooltip"):
			_backpack_panel.hide_tooltip()


func _on_resume_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	set_visible_menu(false)


func _on_menu_pressed() -> void:
	AudioManager.play_button()
	get_tree().paused = false
	GameManager.open_main_menu()


func _apply_localized_texts() -> void:
	var title := panel.get_node_or_null("OuterMargin/MainLayout/TabWrapper/PauseTabs/SystemTab/MarginContainer/InnerVBox/TitleLabel")
	if title is Label:
		title.text = LocalizationManager.tr_key("pause.title")
	_resume_btn.text = LocalizationManager.tr_key("pause.resume")
	_menu_btn.text = LocalizationManager.tr_key("pause.main_menu")
	if _tab_container != null:
		_tab_container.set_tab_title(0, LocalizationManager.tr_key("pause.tab_system"))
		_tab_container.set_tab_title(1, LocalizationManager.tr_key("pause.tab_backpack"))
		_tab_container.set_tab_title(2, LocalizationManager.tr_key("pause.tab_stats"))
	_refresh_key_hints()


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_texts()


# 清空右侧玩家区并填充 ResultPanelShared 构建的完整属性/武器/道具/魔法。
func set_player_stats_full(stats: Dictionary) -> void:
	if _stats_container == null:
		return
	for child in _stats_container.get_children():
		child.queue_free()
	var block: Control = ResultPanelShared.build_player_stats_block(stats, null, null, null, null, true)
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
	# TabContainer：系统 / 背包 / 角色信息，Tab 置于底部
	var tab_wrapper := CenterContainer.new()
	tab_wrapper.name = "TabWrapper"
	tab_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(tab_wrapper)
	_tab_container = TabContainer.new()
	_tab_container.name = "PauseTabs"
	_tab_container.tabs_position = TabContainer.TabPosition.POSITION_TOP  # Tab 标签置于顶部
	_tab_container.custom_minimum_size = Vector2(320, 400)
	_tab_container.add_theme_font_size_override("font_size", 20)  # Tab 标签字体放大
	_tab_container.add_theme_constant_override("side_margin", 16)  # Tab 内容区左右间距
	_tab_container.add_theme_constant_override("top_margin", 16)  # Tab 内容区顶部间距
	tab_wrapper.add_child(_tab_container)
	# Tab 0：系统（标题、按键提示、继续、主菜单）
	var system_tab := _build_system_tab()
	_tab_container.add_child(system_tab)
	_tab_container.set_tab_title(0, LocalizationManager.tr_key("pause.tab_system"))
	# Tab 1：背包
	var backpack_scroll := ScrollContainer.new()
	backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backpack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_backpack_panel = (preload("res://scripts/ui/backpack_panel.gd") as GDScript).new()
	_backpack_panel.name = "BackpackPanel"
	_backpack_panel.add_theme_constant_override("separation", 12)
	_backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_scroll.add_child(_backpack_panel)
	_tab_container.add_child(backpack_scroll)
	_tab_container.set_tab_title(1, LocalizationManager.tr_key("pause.tab_backpack"))
	# Tab 2：角色信息
	var stats_scroll := ScrollContainer.new()
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 12)
	_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(_stats_container)
	_tab_container.add_child(stats_scroll)
	_tab_container.set_tab_title(2, LocalizationManager.tr_key("pause.tab_stats"))


func _build_system_tab() -> VBoxContainer:
	var system_tab := VBoxContainer.new()
	system_tab.name = "SystemTab"
	system_tab.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 32)
	system_tab.add_child(margin)
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
	_key_hints_label.add_theme_font_size_override("font_size", 18)
	_key_hints_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	inner.add_child(_key_hints_label)
	_resume_btn = Button.new()
	_resume_btn.name = "ResumeButton"
	inner.add_child(_resume_btn)
	_menu_btn = Button.new()
	_menu_btn.name = "MainMenuButton"
	inner.add_child(_menu_btn)
	return system_tab


func _refresh_stats_from_game() -> void:
	var game := get_tree().current_scene
	if game == null or not game.has_method("get_player_for_pause"):
		return
	var p = game.get_player_for_pause()
	if p == null or not is_instance_valid(p):
		return
	var stats: Dictionary = {}
	if p.has_method("get_full_stats_for_pause"):
		stats = p.get_full_stats_for_pause()
	else:
		var weapon_details: Array = []
		if p.has_method("get_equipped_weapon_details"):
			weapon_details = p.get_equipped_weapon_details()
		stats = {
			"hp_current": int(p.current_health),
			"hp_max": int(p.max_health),
			"speed": p.base_speed,
			"inertia": p.inertia_factor,
			"weapon_details": weapon_details,
			"magic_details": [],
			"item_ids": []
		}
	set_player_stats_full(stats)
	if _backpack_panel != null and _backpack_panel.has_method("set_stats"):
		_backpack_panel.set_stats(stats)


func _refresh_key_hints() -> void:
	var settings := SaveManager.get_settings()
	var show_hints := bool(settings.get("game", {}).get("show_key_hints_in_pause", true))
	if not show_hints:
		_key_hints_label.text = ""
		return
	_key_hints_label.text = "\n".join([
		LocalizationManager.tr_key("pause.key_hint.move", {"keys": ResultPanelShared.action_to_text(["move_up", "move_down", "move_left", "move_right"])}),
		LocalizationManager.tr_key("pause.key_hint.pause", {"key": ResultPanelShared.action_to_text(["pause"])}),
		LocalizationManager.tr_key("pause.key_hint.camera_zoom", {"keys": ResultPanelShared.action_to_text(["camera_zoom_in", "camera_zoom_out"])}),
		LocalizationManager.tr_key("pause.key_hint.magic", {"keys": ResultPanelShared.action_to_text(["cast_magic", "magic_prev", "magic_next"])}),
		LocalizationManager.tr_key("pause.key_hint.enemy_hp", {"key": ResultPanelShared.action_to_text(["toggle_enemy_hp"])})
	])


func _apply_panel_style() -> void:
	panel.add_theme_stylebox_override("panel", UiThemeConfig.load_theme().get_modal_panel_stylebox())


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
	_fullscreen_backdrop.color = UiThemeConfig.load_theme().modal_backdrop
	root.add_child(_fullscreen_backdrop)
	root.move_child(_fullscreen_backdrop, 0)
