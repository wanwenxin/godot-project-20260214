extends CanvasLayer

# 暂停菜单层：全屏左右分栏布局；固定结构在 pause_menu.tscn，脚本仅引用、显隐与填充内容。
# - 系统 Tab：标题、按键提示、继续、主菜单
# - 背包 Tab：运行时加入 BackpackPanel 实例
# - 角色信息 Tab：StatsContainer 由 ResultPanelShared 填充
@onready var panel: Panel = $Root/Panel
@onready var root: Control = $Root
@onready var _fullscreen_backdrop: ColorRect = $Root/FullscreenBackdrop
@onready var _tab_container: TabContainer = $Root/Panel/OuterMargin/MainLayout/TabWrapper/PauseTabs
@onready var _stats_container: VBoxContainer = $Root/Panel/OuterMargin/MainLayout/TabWrapper/PauseTabs/StatsScroll/StatsContainer
@onready var _resume_btn: Button = $Root/Panel/OuterMargin/MainLayout/TabWrapper/PauseTabs/SystemTab/MarginContainer/InnerVBox/ResumeButton
@onready var _menu_btn: Button = $Root/Panel/OuterMargin/MainLayout/TabWrapper/PauseTabs/SystemTab/MarginContainer/InnerVBox/MainMenuButton
@onready var _key_hints_label: Label = $Root/Panel/OuterMargin/MainLayout/TabWrapper/PauseTabs/SystemTab/MarginContainer/InnerVBox/KeyHintsLabel

var _backpack_panel: VBoxContainer  # 背包面板，运行时创建并加入 BackpackScroll


func _ready() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fullscreen_backdrop.color = UiThemeConfig.load_theme().modal_backdrop
	_add_backpack_panel()
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


## [自定义] 创建背包面板并加入 BackpackScroll（BackpackPanel 为脚本类，需运行时实例化）。
func _add_backpack_panel() -> void:
	var backpack_scroll: ScrollContainer = _tab_container.get_node("BackpackScroll")
	_backpack_panel = (preload("res://scenes/ui/backpack_panel.tscn") as PackedScene).instantiate()
	_backpack_panel.name = "BackpackPanel"
	_backpack_panel.add_theme_constant_override("separation", 12)
	_backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backpack_scroll.add_child(_backpack_panel)


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
