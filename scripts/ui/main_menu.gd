extends Control

# 主菜单：
# - 新游戏（进入角色选择）
# - 继续游戏（直接开局，沿用上次角色）
# - 读取并展示存档统计
@onready var continue_btn: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var new_game_btn: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var save_info: Label = $CenterContainer/VBoxContainer/SaveInfo


func _ready() -> void:
	# 主菜单播放轻量合成 BGM，与战斗场景区分氛围。
	AudioManager.play_menu_bgm()
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	var save_data := SaveManager.load_game()
	var has := SaveManager.has_save()
	# 没有任何存档时禁用“继续游戏”。
	continue_btn.disabled = not has
	var last_run: Dictionary = save_data.get("last_run", {})
	# 成就数量仅做简报展示，详细列表可后续扩展独立页面。
	var achievement_count := int((save_data.get("achievements", []) as Array).size())
	save_info.text = "BestWave: %d  BestTime: %.1fs  TotalKills: %d\nLastRun: W%d K%d T%.1fs  Achievements: %d" % [
		int(save_data.get("best_wave", 0)),
		float(save_data.get("best_survival_time", 0.0)),
		int(save_data.get("total_kills", 0)),
		int(last_run.get("wave", 0)),
		int(last_run.get("kills", 0)),
		float(last_run.get("survival_time", 0.0)),
		achievement_count
	]


func _on_new_game_pressed() -> void:
	AudioManager.play_button()
	GameManager.open_character_select()


func _on_continue_pressed() -> void:
	AudioManager.play_button()
	GameManager.continue_game()


func _on_quit_pressed() -> void:
	AudioManager.play_button()
	get_tree().quit()
