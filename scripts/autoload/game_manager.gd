extends Node

const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/character_select.tscn"
const SCENE_GAME := "res://scenes/game.tscn"

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
var last_run_result := {
	"wave": 0,
	"kills": 0,
	"survival_time": 0.0
}


func _ready() -> void:
	var save_data := SaveManager.load_game()
	selected_character_id = int(save_data.get("last_character_id", 0))


func get_character_data(character_id: int = -1) -> Dictionary:
	var target_id := selected_character_id if character_id < 0 else character_id
	for character in characters:
		if int(character["id"]) == target_id:
			return character.duplicate(true)
	return characters[0].duplicate(true)


func set_selected_character(character_id: int) -> void:
	selected_character_id = character_id


func start_new_game(character_id: int) -> void:
	set_selected_character(character_id)
	get_tree().change_scene_to_file(SCENE_GAME)


func continue_game() -> void:
	get_tree().change_scene_to_file(SCENE_GAME)


func open_character_select() -> void:
	get_tree().change_scene_to_file(SCENE_CHARACTER_SELECT)


func open_main_menu() -> void:
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func save_run_result(wave: int, kills: int, survival_time: float) -> void:
	last_run_result = {
		"wave": wave,
		"kills": kills,
		"survival_time": survival_time
	}
	SaveManager.update_run_result(wave, survival_time, kills, selected_character_id)
