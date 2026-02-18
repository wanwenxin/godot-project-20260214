extends Control

signal closed

# 窗口模式：百分比为屏幕比例，Fullscreen 为全屏
const WINDOW_MODES := ["50%", "75%", "100%", "Fullscreen"]
const KEY_CHOICES := ["Escape", "P", "H", "Tab", "F1", "F2"]
const BINDABLE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"pause", "toggle_enemy_hp", "camera_zoom_in", "camera_zoom_out",
	"cast_magic", "magic_prev", "magic_next"
]
const ACTION_NAME_KEYS := {
	"move_left": "settings.key.move_left",
	"move_right": "settings.key.move_right",
	"move_up": "settings.key.move_up",
	"move_down": "settings.key.move_down",
	"pause": "settings.key.pause",
	"toggle_enemy_hp": "settings.key.toggle_hp",
	"camera_zoom_in": "settings.key.camera_zoom_in",
	"camera_zoom_out": "settings.key.camera_zoom_out",
	"cast_magic": "settings.key.cast_magic",
	"magic_prev": "settings.key.magic_prev",
	"magic_next": "settings.key.magic_next"
}

# 设置页：全屏展示，与暂停页类似布局（外层边距 + 内容居中）
@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/OuterMargin/CenterContainer/VBox/Title
@onready var tabs: TabContainer = $Panel/OuterMargin/CenterContainer/VBox/Tabs
@onready var close_button: Button = $Panel/OuterMargin/CenterContainer/VBox/CloseButton

@onready var volume_label: Label = $Panel/OuterMargin/CenterContainer/VBox/Tabs/SystemTab/SystemVBox/VolumeLabel
@onready var volume_slider: HSlider = $Panel/OuterMargin/CenterContainer/VBox/Tabs/SystemTab/SystemVBox/VolumeSlider
@onready var resolution_label: Label = $Panel/OuterMargin/CenterContainer/VBox/Tabs/SystemTab/SystemVBox/ResolutionLabel
@onready var resolution_option: OptionButton = $Panel/OuterMargin/CenterContainer/VBox/Tabs/SystemTab/SystemVBox/ResolutionOption

@onready var move_inertia_label: Label = $Panel/OuterMargin/CenterContainer/VBox/Tabs/GameTab/GameVBox/MoveInertiaLabel
@onready var move_inertia_slider: HSlider = $Panel/OuterMargin/CenterContainer/VBox/Tabs/GameTab/GameVBox/MoveInertiaSlider
@onready var toggle_hp_key_label: Label = $Panel/OuterMargin/CenterContainer/VBox/Tabs/GameTab/GameVBox/ToggleHpKeyLabel
@onready var toggle_hp_key_option: OptionButton = $Panel/OuterMargin/CenterContainer/VBox/Tabs/GameTab/GameVBox/ToggleHpKeyOption
@onready var enemy_hp_check: CheckBox = $Panel/OuterMargin/CenterContainer/VBox/Tabs/GameTab/GameVBox/EnemyHpCheck

var _settings: Dictionary = {}  # 当前设置副本，修改后写回 SaveManager
var _silent := false  # 防重入：_reload_from_save 时忽略控件回调
var _fullscreen_backdrop: ColorRect
var _key_binding_rows: Dictionary = {}  # action -> {key_label, rebind_btn}
var _waiting_for_action: String = ""  # 等待按键时的 action


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_fullscreen_backdrop()
	_apply_panel_style()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_on_close_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	move_inertia_slider.value_changed.connect(_on_move_inertia_changed)
	toggle_hp_key_option.item_selected.connect(_on_toggle_hp_selected)
	enemy_hp_check.toggled.connect(_on_enemy_hp_toggled)
	LocalizationManager.language_changed.connect(_on_language_changed)

	_build_static_options()
	_build_key_bindings_tab()
	tabs.add_theme_font_size_override("font_size", 20)  # Tab 标签字体放大
	tabs.add_theme_constant_override("side_margin", 16)  # Tab 内容区左右间距
	tabs.add_theme_constant_override("top_margin", 16)  # Tab 内容区顶部间距
	_apply_localized_texts()
	_reload_from_save()
	set_process_unhandled_input(false)


func open_menu() -> void:
	_reload_from_save()
	# 置于最顶层，确保全屏覆盖
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	visible = true


func _build_static_options() -> void:
	_silent = true
	resolution_option.clear()
	for i in range(WINDOW_MODES.size()):
		var value: String = WINDOW_MODES[i]
		var display: String
		if value == "Fullscreen":
			display = LocalizationManager.tr_key("settings.window_mode.fullscreen")
		else:
			display = value
		resolution_option.add_item(display)
		resolution_option.set_item_metadata(i, value)
	toggle_hp_key_option.clear()
	for value in KEY_CHOICES:
		toggle_hp_key_option.add_item(value)
	_silent = false


func _reload_from_save() -> void:
	_silent = true
	_settings = SaveManager.get_settings()
	var system_cfg: Dictionary = _settings.get("system", {})
	var game_cfg: Dictionary = _settings.get("game", {})
	volume_slider.value = float(system_cfg.get("master_volume", 0.70)) * 100.0
	_select_option_by_value(resolution_option, str(system_cfg.get("resolution", WINDOW_MODES[2])))
	move_inertia_slider.value = clampf(float(game_cfg.get("move_inertia", 0.0)), 0.0, 0.9)
	_select_option_text(toggle_hp_key_option, str(game_cfg.get("toggle_enemy_hp_key", "H")))
	enemy_hp_check.button_pressed = bool(game_cfg.get("show_enemy_health_bar", true))
	_refresh_key_binding_display()
	_silent = false


func _select_option_text(option: OptionButton, text: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i) == text:
			option.select(i)
			return
	option.select(0)


func _select_option_by_value(option: OptionButton, value: String) -> void:
	for i in range(option.item_count):
		var meta = option.get_item_metadata(i)
		if meta != null and str(meta) == value:
			option.select(i)
			return
		if meta == null and option.get_item_text(i) == value:
			option.select(i)
			return
	# 旧格式 "1280x720" 等视为 100%
	var fallback_index := 2
	if value == "50%" or value.begins_with("50"):
		fallback_index = 0
	elif value == "75%" or value.begins_with("75"):
		fallback_index = 1
	elif value == "Fullscreen" or value.to_lower() == "fullscreen":
		fallback_index = 3
	option.select(fallback_index)


func _save_and_apply() -> void:
	SaveManager.set_settings(_settings)
	GameManager.apply_saved_settings()


func _on_volume_changed(value: float) -> void:
	if _silent:
		return
	var system_cfg: Dictionary = _settings.get("system", {})
	system_cfg["master_volume"] = clampf(value / 100.0, 0.0, 1.0)
	_settings["system"] = system_cfg
	_save_and_apply()


func _on_resolution_selected(index: int) -> void:
	if _silent:
		return
	var system_cfg: Dictionary = _settings.get("system", {})
	var meta = resolution_option.get_item_metadata(index)
	system_cfg["resolution"] = str(meta) if meta != null else resolution_option.get_item_text(index)
	_settings["system"] = system_cfg
	_save_and_apply()


func _on_move_inertia_changed(value: float) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["move_inertia"] = clampf(value, 0.0, 0.9)
	_settings["game"] = game_cfg
	_save_and_apply()


func _on_toggle_hp_selected(index: int) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["toggle_enemy_hp_key"] = toggle_hp_key_option.get_item_text(index)
	_settings["game"] = game_cfg
	_save_and_apply()


func _on_enemy_hp_toggled(value: bool) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["show_enemy_health_bar"] = value
	_settings["game"] = game_cfg
	_save_and_apply()


func _on_close_pressed() -> void:
	visible = false
	emit_signal("closed")


func _apply_localized_texts() -> void:
	title_label.text = LocalizationManager.tr_key("settings.title")
	tabs.set_tab_title(0, LocalizationManager.tr_key("settings.tab.system"))
	tabs.set_tab_title(1, LocalizationManager.tr_key("settings.tab.game"))
	close_button.text = LocalizationManager.tr_key("common.close")
	volume_label.text = LocalizationManager.tr_key("settings.system.volume")
	resolution_label.text = LocalizationManager.tr_key("settings.system.window_mode")
	move_inertia_label.text = LocalizationManager.tr_key("settings.game.move_inertia")
	toggle_hp_key_label.text = LocalizationManager.tr_key("settings.game.toggle_hp_key")
	enemy_hp_check.text = LocalizationManager.tr_key("settings.game.enemy_hp")


func _build_key_bindings_tab() -> void:
	var keys_tab := VBoxContainer.new()
	keys_tab.name = "KeysTab"
	keys_tab.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys_tab.add_child(scroll)
	for action in BINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(140, 0)
		var name_key: String = ACTION_NAME_KEYS.get(action, action)
		name_lbl.text = LocalizationManager.tr_key(name_key)
		row.add_child(name_lbl)
		var key_lbl := Label.new()
		key_lbl.custom_minimum_size = Vector2(60, 0)
		key_lbl.text = "+"
		row.add_child(key_lbl)
		var rebind_btn := Button.new()
		rebind_btn.text = LocalizationManager.tr_key("settings.key.rebind")
		rebind_btn.pressed.connect(_on_rebind_pressed.bind(action))
		row.add_child(rebind_btn)
		vbox.add_child(row)
		_key_binding_rows[action] = {"key_label": key_lbl, "rebind_btn": rebind_btn}
	tabs.add_child(keys_tab)
	tabs.set_tab_title(2, LocalizationManager.tr_key("settings.tab.keys"))


func _on_rebind_pressed(action: String) -> void:
	_waiting_for_action = action
	if _key_binding_rows.has(action):
		_key_binding_rows[action].key_label.text = "..."
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_action.is_empty():
		return
	if not event is InputEventKey:
		return
	var key_ev: InputEventKey = event
	if not key_ev.pressed or key_ev.echo:
		return
	# 排除仅修饰键；Escape 取消
	if key_ev.keycode == KEY_ESCAPE:
		set_process_unhandled_input(false)
		_waiting_for_action = ""
		_refresh_key_binding_display()
		get_viewport().set_input_as_handled()
		return
	if key_ev.keycode == KEY_CTRL or key_ev.keycode == KEY_ALT or key_ev.keycode == KEY_SHIFT or key_ev.keycode == KEY_META:
		return
	var key_name := OS.get_keycode_string(key_ev.keycode)
	if key_name.is_empty():
		return
	get_viewport().set_input_as_handled()
	set_process_unhandled_input(false)
	var action := _waiting_for_action
	_waiting_for_action = ""
	var game_cfg: Dictionary = _settings.get("game", {})
	var bindings: Dictionary = game_cfg.get("key_bindings", {})
	if bindings.is_empty():
		bindings = GameManager.get_key_bindings()
	var conflict_action: String = ""
	for act in BINDABLE_ACTIONS:
		if act != action and str(bindings.get(act, "")) == key_name:
			conflict_action = act
			break
	if not conflict_action.is_empty():
		var conflict_name: String = LocalizationManager.tr_key(ACTION_NAME_KEYS.get(conflict_action, conflict_action))
		var dlg := AcceptDialog.new()
		dlg.dialog_text = LocalizationManager.tr_key("settings.key.conflict", {"key": key_name, "action": conflict_name})
		dlg.ok_button_text = LocalizationManager.tr_key("common.yes")
		dlg.add_cancel_button(LocalizationManager.tr_key("common.no"))
		add_child(dlg)
		dlg.popup_centered()
		dlg.confirmed.connect(_on_conflict_confirmed.bind(action, key_name, conflict_action, bindings, game_cfg))
		dlg.canceled.connect(_refresh_key_binding_display)
		dlg.close_requested.connect(dlg.queue_free)
		dlg.confirmed.connect(dlg.queue_free)
		dlg.canceled.connect(dlg.queue_free)
	else:
		bindings[action] = key_name
		game_cfg["key_bindings"] = bindings
		_settings["game"] = game_cfg
		_save_and_apply()
		_refresh_key_binding_display()


func _on_conflict_confirmed(action: String, key_name: String, conflict_action: String, bindings: Dictionary, game_cfg: Dictionary) -> void:
	bindings[conflict_action] = ""
	bindings[action] = key_name
	game_cfg["key_bindings"] = bindings
	_settings["game"] = game_cfg
	_save_and_apply()
	_refresh_key_binding_display()


func _refresh_key_binding_display() -> void:
	var bindings: Dictionary = GameManager.get_key_bindings()
	for action in BINDABLE_ACTIONS:
		if _key_binding_rows.has(action):
			var key_str: String = str(bindings.get(action, "+"))
			_key_binding_rows[action].key_label.text = key_str
	if not _waiting_for_action.is_empty():
		_waiting_for_action = ""
		set_process_unhandled_input(false)


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_texts()
	if tabs.get_tab_count() >= 3:
		tabs.set_tab_title(2, LocalizationManager.tr_key("settings.tab.keys"))
	for action in BINDABLE_ACTIONS:
		if _key_binding_rows.has(action):
			_key_binding_rows[action].rebind_btn.text = LocalizationManager.tr_key("settings.key.rebind")


func _ensure_fullscreen_backdrop() -> void:
	# 设置页全屏纯色背景，避免透出底层场景。
	_fullscreen_backdrop = ColorRect.new()
	_fullscreen_backdrop.name = "FullscreenBackdrop"
	_fullscreen_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_fullscreen_backdrop.offset_left = 0
	_fullscreen_backdrop.offset_top = 0
	_fullscreen_backdrop.offset_right = 0
	_fullscreen_backdrop.offset_bottom = 0
	_fullscreen_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_fullscreen_backdrop.color = UiThemeConfig.load_theme().modal_backdrop
	add_child(_fullscreen_backdrop)
	move_child(_fullscreen_backdrop, 0)


func _apply_panel_style() -> void:
	# 设置菜单固定使用不透明背景，避免底层场景干扰阅读。
	panel.add_theme_stylebox_override("panel", UiThemeConfig.load_theme().get_modal_panel_stylebox())
