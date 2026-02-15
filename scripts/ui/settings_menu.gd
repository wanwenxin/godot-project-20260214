extends Control

signal closed

const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080"]
const PRESETS := ["wasd", "arrows"]
const KEY_CHOICES := ["P", "Escape", "H", "Tab", "F1", "F2"]

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var tabs: TabContainer = $Panel/VBox/Tabs
@onready var close_button: Button = $Panel/VBox/CloseButton

@onready var volume_label: Label = $Panel/VBox/Tabs/SystemTab/SystemVBox/VolumeLabel
@onready var volume_slider: HSlider = $Panel/VBox/Tabs/SystemTab/SystemVBox/VolumeSlider
@onready var resolution_label: Label = $Panel/VBox/Tabs/SystemTab/SystemVBox/ResolutionLabel
@onready var resolution_option: OptionButton = $Panel/VBox/Tabs/SystemTab/SystemVBox/ResolutionOption

@onready var preset_label: Label = $Panel/VBox/Tabs/GameTab/GameVBox/PresetLabel
@onready var preset_option: OptionButton = $Panel/VBox/Tabs/GameTab/GameVBox/PresetOption
@onready var move_inertia_label: Label = $Panel/VBox/Tabs/GameTab/GameVBox/MoveInertiaLabel
@onready var move_inertia_slider: HSlider = $Panel/VBox/Tabs/GameTab/GameVBox/MoveInertiaSlider
@onready var pause_key_label: Label = $Panel/VBox/Tabs/GameTab/GameVBox/PauseKeyLabel
@onready var pause_key_option: OptionButton = $Panel/VBox/Tabs/GameTab/GameVBox/PauseKeyOption
@onready var toggle_hp_key_label: Label = $Panel/VBox/Tabs/GameTab/GameVBox/ToggleHpKeyLabel
@onready var toggle_hp_key_option: OptionButton = $Panel/VBox/Tabs/GameTab/GameVBox/ToggleHpKeyOption
@onready var enemy_hp_check: CheckBox = $Panel/VBox/Tabs/GameTab/GameVBox/EnemyHpCheck
@onready var pause_hint_check: CheckBox = $Panel/VBox/Tabs/GameTab/GameVBox/PauseHintCheck

var _settings: Dictionary = {}
var _silent := false
var _fullscreen_backdrop: ColorRect


func _ready() -> void:
	visible = false
	_ensure_fullscreen_backdrop()
	_apply_panel_style()
	close_button.pressed.connect(_on_close_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	resolution_option.item_selected.connect(_on_resolution_selected)
	preset_option.item_selected.connect(_on_preset_selected)
	move_inertia_slider.value_changed.connect(_on_move_inertia_changed)
	pause_key_option.item_selected.connect(_on_pause_key_selected)
	toggle_hp_key_option.item_selected.connect(_on_toggle_hp_selected)
	enemy_hp_check.toggled.connect(_on_enemy_hp_toggled)
	pause_hint_check.toggled.connect(_on_pause_hint_toggled)
	LocalizationManager.language_changed.connect(_on_language_changed)

	_build_static_options()
	_apply_localized_texts()
	_reload_from_save()


func open_menu() -> void:
	_reload_from_save()
	visible = true


func _build_static_options() -> void:
	_silent = true
	resolution_option.clear()
	for value in RESOLUTIONS:
		resolution_option.add_item(value)
	preset_option.clear()
	for value in PRESETS:
		preset_option.add_item(value)
	pause_key_option.clear()
	toggle_hp_key_option.clear()
	for value in KEY_CHOICES:
		pause_key_option.add_item(value)
		toggle_hp_key_option.add_item(value)
	_silent = false


func _reload_from_save() -> void:
	_silent = true
	_settings = SaveManager.get_settings()
	var system_cfg: Dictionary = _settings.get("system", {})
	var game_cfg: Dictionary = _settings.get("game", {})
	volume_slider.value = float(system_cfg.get("master_volume", 0.70)) * 100.0
	_select_option_text(resolution_option, str(system_cfg.get("resolution", RESOLUTIONS[0])))
	_select_option_text(preset_option, str(game_cfg.get("key_preset", "wasd")))
	move_inertia_slider.value = clampf(float(game_cfg.get("move_inertia", 0.0)), 0.0, 0.9)
	_select_option_text(pause_key_option, str(game_cfg.get("pause_key", "P")))
	_select_option_text(toggle_hp_key_option, str(game_cfg.get("toggle_enemy_hp_key", "H")))
	enemy_hp_check.button_pressed = bool(game_cfg.get("show_enemy_health_bar", true))
	pause_hint_check.button_pressed = bool(game_cfg.get("show_key_hints_in_pause", true))
	_silent = false


func _select_option_text(option: OptionButton, text: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i) == text:
			option.select(i)
			return
	option.select(0)


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
	system_cfg["resolution"] = resolution_option.get_item_text(index)
	_settings["system"] = system_cfg
	_save_and_apply()


func _on_preset_selected(index: int) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["key_preset"] = preset_option.get_item_text(index)
	_settings["game"] = game_cfg
	_save_and_apply()


func _on_move_inertia_changed(value: float) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["move_inertia"] = clampf(value, 0.0, 0.9)
	_settings["game"] = game_cfg
	_save_and_apply()


func _on_pause_key_selected(index: int) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["pause_key"] = pause_key_option.get_item_text(index)
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


func _on_pause_hint_toggled(value: bool) -> void:
	if _silent:
		return
	var game_cfg: Dictionary = _settings.get("game", {})
	game_cfg["show_key_hints_in_pause"] = value
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
	resolution_label.text = LocalizationManager.tr_key("settings.system.resolution")
	preset_label.text = LocalizationManager.tr_key("settings.game.preset")
	move_inertia_label.text = LocalizationManager.tr_key("settings.game.move_inertia")
	pause_key_label.text = LocalizationManager.tr_key("settings.game.pause_key")
	toggle_hp_key_label.text = LocalizationManager.tr_key("settings.game.toggle_hp_key")
	enemy_hp_check.text = LocalizationManager.tr_key("settings.game.enemy_hp")
	pause_hint_check.text = LocalizationManager.tr_key("settings.game.pause_hints")


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_texts()


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
	_fullscreen_backdrop.color = VisualAssetRegistry.get_color("ui.modal_backdrop", Color(0.08, 0.09, 0.11, 1.0))
	add_child(_fullscreen_backdrop)
	move_child(_fullscreen_backdrop, 0)


func _apply_panel_style() -> void:
	# 设置菜单固定使用不透明背景，避免底层场景干扰阅读。
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
