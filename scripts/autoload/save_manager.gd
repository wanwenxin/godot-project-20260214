extends Node

# 存档目录与文件（Godot 的 user:// 会映射到系统用户数据目录）。
const SAVE_DIR := "user://savegame"
const SAVE_PATH := SAVE_DIR + "/save.json"

# 存档默认结构。
# 保持字段稳定可降低版本升级时的不兼容风险。
var default_data := {
	"best_wave": 0,
	"best_survival_time": 0.0,
	"total_kills": 0,
	"last_character_id": 0
}


func _ready() -> void:
	_ensure_save_dir()


func _ensure_save_dir() -> void:
	# 首次启动可能没有目录，提前创建避免后续写文件失败。
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> Dictionary:
	# 无存档时返回默认结构，保证上层逻辑永远拿到有效字典。
	if not has_save():
		return default_data.duplicate(true)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_data.duplicate(true)

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		# 数据损坏时回退默认值，不让游戏因存档异常崩溃。
		return default_data.duplicate(true)

	# 以 default_data 为模板合并，兼容未来新增字段。
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
	# 对累计数据做聚合更新：
	# - best_* 取历史最大
	# - total_kills 累加
	# - last_character_id 覆盖为最近选择
	var data := load_game()
	data["best_wave"] = max(int(data.get("best_wave", 0)), wave)
	data["best_survival_time"] = max(float(data.get("best_survival_time", 0.0)), survival_time)
	data["total_kills"] = int(data.get("total_kills", 0)) + kills
	data["last_character_id"] = character_id
	save_game(data)
	return data
