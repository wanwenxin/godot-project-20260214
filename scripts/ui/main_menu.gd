extends Control

# 主菜单：
# - 新游戏（进入角色选择）
# - 继续游戏（直接开局，沿用上次角色）
# - 读取并展示存档统计
@onready var continue_btn: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var new_game_btn: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var save_info: Label = $CenterContainer/VBoxContainer/SaveInfo
@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var language_label: Label = $CenterContainer/VBoxContainer/LanguageRow/LanguageLabel
@onready var language_option: OptionButton = $CenterContainer/VBoxContainer/LanguageRow/LanguageOption
@onready var settings_menu: Control = $SettingsMenu

var _is_updating_option := false


func _ready() -> void:
	# 主菜单播放轻量合成 BGM，与战斗场景区分氛围。
	AudioManager.play_menu_bgm()
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	language_option.item_selected.connect(_on_language_item_selected)
	LocalizationManager.language_changed.connect(_on_language_changed)

	_refresh_language_options()
	_apply_localized_texts()


func _apply_localized_texts() -> void:
	title_label.text = LocalizationManager.tr_key("menu.title")
	language_label.text = LocalizationManager.tr_key("menu.language")
	new_game_btn.text = LocalizationManager.tr_key("menu.new_game")
	continue_btn.text = LocalizationManager.tr_key("menu.continue")
	settings_btn.text = LocalizationManager.tr_key("menu.settings")
	quit_btn.text = LocalizationManager.tr_key("menu.quit")

	var save_data := SaveManager.load_game()
	var has := SaveManager.has_save()
	# 没有任何存档时禁用“继续游戏”。
	continue_btn.disabled = not has
	var last_run: Dictionary = save_data.get("last_run", {})
	# 成就数量仅做简报展示，详细列表可后续扩展独立页面。
	var achievement_count := int((save_data.get("achievements", []) as Array).size())
	var line1 := LocalizationManager.tr_key("menu.save_info_line1", {
		"best_wave": int(save_data.get("best_wave", 0)),
		"best_time": "%.1f" % float(save_data.get("best_survival_time", 0.0)),
		"total_kills": int(save_data.get("total_kills", 0))
	})
	var line2 := LocalizationManager.tr_key("menu.save_info_line2", {
		"wave": int(last_run.get("wave", 0)),
		"kills": int(last_run.get("kills", 0)),
		"time": "%.1f" % float(last_run.get("survival_time", 0.0)),
		"achievement_count": achievement_count
	})
	save_info.text = line1 + "\n" + line2


func _on_new_game_pressed() -> void:
	AudioManager.play_button()
	GameManager.open_character_select()


func _on_continue_pressed() -> void:
	AudioManager.play_button()
	GameManager.continue_game()


func _on_quit_pressed() -> void:
	AudioManager.play_button()
	get_tree().quit()


func _on_settings_pressed() -> void:
	AudioManager.play_button()
	if settings_menu.has_method("open_menu"):
		settings_menu.call("open_menu")


func _refresh_language_options() -> void:
	_is_updating_option = true
	language_option.clear()
	var options := LocalizationManager.get_language_options()
	var selected_idx := 0
	for i in range(options.size()):
		var option: Dictionary = options[i]
		language_option.add_item(str(option.get("name", "")))
		language_option.set_item_metadata(i, str(option.get("code", "")))
		if str(option.get("code", "")) == LocalizationManager.current_language:
			selected_idx = i
	language_option.select(selected_idx)
	_is_updating_option = false


func _on_language_item_selected(index: int) -> void:
	if _is_updating_option:
		return
	var code := str(language_option.get_item_metadata(index))
	LocalizationManager.set_language(code)


func _on_language_changed(_language_code: String) -> void:
	_refresh_language_options()
	_apply_localized_texts()
