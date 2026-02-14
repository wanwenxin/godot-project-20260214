extends Node

const SAVE_DIR := "user://savegame"
const SAVE_PATH := SAVE_DIR + "/save.json"

var default_data := {
	"best_wave": 0,
	"best_survival_time": 0.0,
	"total_kills": 0,
	"last_character_id": 0
}


func _ready() -> void:
	_ensure_save_dir()


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> Dictionary:
	if not has_save():
		return default_data.duplicate(true)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_data.duplicate(true)

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_data.duplicate(true)

	var merged := default_data.duplicate(true)
	for key in parsed.keys():
		merged[key] = parsed[key]
	return merged


func save_game(data: Dictionary) -> void:
	_ensure_save_dir()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open save file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))


func update_run_result(wave: int, survival_time: float, kills: int, character_id: int) -> Dictionary:
	var data := load_game()
	data["best_wave"] = max(int(data.get("best_wave", 0)), wave)
	data["best_survival_time"] = max(float(data.get("best_survival_time", 0.0)), survival_time)
	data["total_kills"] = int(data.get("total_kills", 0)) + kills
	data["last_character_id"] = character_id
	save_game(data)
	return data
