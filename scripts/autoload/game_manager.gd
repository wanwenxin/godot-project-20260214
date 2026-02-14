extends Node

# 全局场景路径，统一由 GameManager 控制切场，避免在各处硬编码。
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"

# 角色配置表。
# 说明：
# - id: 角色唯一标识
# - fire_rate: 数值越小射速越快（每发间隔秒数）
# - color_scheme: 像素生成器的配色索引
var characters := [
	{
		"id": 0,
		"name": "RapidShooter",
		"max_health": 100,
		"speed": 180.0,
		"fire_rate": 0.18,
		"bullet_damage": 8,
		"bullet_speed": 520.0,
		"color_scheme": 0
	},
	{
		"id": 1,
		"name": "HeavyGunner",
		"max_health": 130,
		"speed": 130.0,
		"fire_rate": 0.42,
		"bullet_damage": 18,
		"bullet_speed": 430.0,
		"color_scheme": 1
	}
]

var selected_character_id := 0
# 最近一局战斗结果，当前主要用于运行期查看，持久化统计由 SaveManager 负责。
var last_run_result := {
	"wave": 0,
	"kills": 0,
	"survival_time": 0.0
}


func _ready() -> void:
	# 启动时读取上次选择的角色，保证“继续游戏”体验一致。
	var save_data := SaveManager.load_game()
	selected_character_id = int(save_data.get("last_character_id", 0))


func get_character_data(character_id: int = -1) -> Dictionary:
	# character_id < 0 时返回当前选中角色。
	var target_id := selected_character_id if character_id < 0 else character_id
	for character in characters:
		if int(character["id"]) == target_id:
			# 深拷贝，防止调用方修改原始配置。
			return character.duplicate(true)
	return characters[0].duplicate(true)


func set_selected_character(character_id: int) -> void:
	selected_character_id = character_id


func start_new_game(character_id: int) -> void:
	# 新游戏前先落当前角色选择。
	set_selected_character(character_id)
	get_tree().change_scene_to_file(SCENE_GAME)


func continue_game() -> void:
	get_tree().change_scene_to_file(SCENE_GAME)


func open_character_select() -> void:
	get_tree().change_scene_to_file(SCENE_CHARACTER_SELECT)


func open_main_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func save_run_result(wave: int, kills: int, survival_time: float) -> void:
	# 同时更新内存中的最近战绩和本地存档统计。
	last_run_result = {
		"wave": wave,
		"kills": kills,
		"survival_time": survival_time
	}
	SaveManager.update_run_result(wave, survival_time, kills, selected_character_id)
