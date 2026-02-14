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
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	var save_data := SaveManager.load_game()
	var has := SaveManager.has_save()
	# 没有任何存档时禁用“继续游戏”。
	continue_btn.disabled = not has
	save_info.text = "BestWave: %d  BestTime: %.1fs  TotalKills: %d" % [
		int(save_data.get("best_wave", 0)),
		float(save_data.get("best_survival_time", 0.0)),
		int(save_data.get("total_kills", 0))
	]


func _on_new_game_pressed() -> void:
	GameManager.open_character_select()


func _on_continue_pressed() -> void:
	GameManager.continue_game()


func _on_quit_pressed() -> void:
	get_tree().quit()
