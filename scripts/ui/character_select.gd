extends Control

# 角色选择界面：
# - 切换两个角色模板
# - 实时展示当前角色属性
# - 确认后进入游戏场景
@onready var card_a: Button = $CenterContainer/VBoxContainer/Characters/CharacterA
@onready var card_b: Button = $CenterContainer/VBoxContainer/Characters/CharacterB
@onready var detail: Label = $CenterContainer/VBoxContainer/Detail
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/Title

var selected_character_id := 0


func _ready() -> void:
	AudioManager.play_menu_bgm()
	card_a.pressed.connect(func() -> void: _select_character(0))
	card_b.pressed.connect(func() -> void: _select_character(1))
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)

	_apply_localized_static_text()
	_select_character(GameManager.selected_character_id)


func _select_character(character_id: int) -> void:
	selected_character_id = character_id
	var data := GameManager.get_character_data(character_id)
	var save_data := SaveManager.load_game()
	var best_map: Dictionary = save_data.get("best_wave_per_character", {})
	var kill_map: Dictionary = save_data.get("total_kills_per_character", {})
	var key := str(character_id)
	# 属性文本与按钮选中态同步刷新。
	# 角色页同步展示“该角色历史战绩”，便于 build 选择。
	var text := LocalizationManager.tr_key("char_select.detail", {
		"name": _get_character_display_name(character_id, data),
		"hp": int(data.get("max_health", 100)),
		"speed": "%.0f" % float(data.get("speed", 0.0)),
		"fire_rate": "%.2f" % float(data.get("fire_rate", 0.3)),
		"damage": int(data.get("bullet_damage", 0)),
		"best_wave": int(best_map.get(key, 0)),
		"char_kills": int(kill_map.get(key, 0))
	})
	detail.text = text
	var suffix := LocalizationManager.tr_key("char_select.selected_suffix")
	card_a.text = LocalizationManager.tr_key("char_select.card_a") + (suffix if selected_character_id == 0 else "")
	card_b.text = LocalizationManager.tr_key("char_select.card_b") + (suffix if selected_character_id == 1 else "")


func _on_start_pressed() -> void:
	AudioManager.play_button()
	GameManager.start_new_game(selected_character_id)


func _on_back_pressed() -> void:
	AudioManager.play_button()
	GameManager.open_main_menu()


func _apply_localized_static_text() -> void:
	title_label.text = LocalizationManager.tr_key("char_select.title")
	start_button.text = LocalizationManager.tr_key("char_select.start")
	back_button.text = LocalizationManager.tr_key("char_select.back")


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_static_text()
	_select_character(selected_character_id)


func _get_character_display_name(character_id: int, data: Dictionary) -> String:
	match character_id:
		0:
			return LocalizationManager.tr_key("char_select.card_a")
		1:
			return LocalizationManager.tr_key("char_select.card_b")
	return str(data.get("name", "Unknown"))
