extends CanvasLayer

# 死亡结算界面：固定结构在 game_over_screen.tscn，脚本只填内容与 visible。
@onready var root: Control = $Root
@onready var _backdrop: ColorRect = $Root/Backdrop
@onready var _panel: Panel = $Root/Panel
@onready var _tab_container: TabContainer = $Root/Panel/Margin/VBox/TabContainer
@onready var _score_tab_container: VBoxContainer = $Root/Panel/Margin/VBox/TabContainer/ScoreTabContainer
@onready var _backpack_tab_container: Control = $Root/Panel/Margin/VBox/TabContainer/BackpackTabContainer
@onready var _stats_tab_container: Control = $Root/Panel/Margin/VBox/TabContainer/StatsTabContainer
@onready var _menu_btn: Button = $Root/Panel/Margin/VBox/MenuButton


## [系统] 节点入树时调用，应用样式与信号，默认隐藏。
func _ready() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.color = UiThemeConfig.load_theme().modal_backdrop
	_apply_panel_style()
	_tab_container.set_tab_title(0, LocalizationManager.tr_key("result.tab_score"))
	_tab_container.set_tab_title(1, LocalizationManager.tr_key("result.tab_backpack"))
	_tab_container.set_tab_title(2, LocalizationManager.tr_key("result.tab_stats"))
	_menu_btn.text = LocalizationManager.tr_key("hud.back_to_menu")
	_menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	visible = false


## [自定义] 显示死亡结算：得分、背包、角色信息三 Tab。动态加载：load(backpack_panel.gd) 运行时实例化 BackpackPanel。
func show_result(wave: int, kills: int, time: float, player_node: Node) -> void:
	# 清空旧内容并重建（保留 _menu_btn 引用，不销毁）
	if _menu_btn.get_parent():
		_menu_btn.get_parent().remove_child(_menu_btn)
	for child in _score_tab_container.get_children():
		child.queue_free()
	# 背包 Tab：清空后由 set_stats 重建
	for child in _backpack_tab_container.get_children():
		child.queue_free()
	for child in _stats_tab_container.get_children():
		child.queue_free()
	var save_data := SaveManager.load_game()
	var best_wave := int(save_data.get("best_wave", 0))
	var best_time := float(save_data.get("best_survival_time", 0.0))
	# 得分 Tab：标题 + 得分区 + 返回主菜单
	var title := Label.new()
	title.text = LocalizationManager.tr_key("result.title_game_over")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
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
	var backpack_panel: Control = (load("res://scenes/ui/backpack_panel.tscn") as PackedScene).instantiate() as Control
	backpack_panel.name = "BackpackPanel"
	backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_tab_container.add_child(backpack_panel)
	backpack_panel.set_stats(stats, false)
	# 角色信息 Tab
	var player_block: Control = ResultPanelShared.build_player_stats_block(stats)
	_stats_tab_container.add_child(player_block)
	visible = true


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
