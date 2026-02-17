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
	"last_character_id": 0,
	"language": "zh-CN",
	"last_run": {
		"wave": 0,
		"kills": 0,
		"survival_time": 0.0
	},
	"best_wave_per_character": {},
	"total_kills_per_character": {},
	"achievements": [],
	"settings": {
		"system": {
			"master_volume": 0.70,
			"resolution": "100%"
		},
		"game": {
			"key_preset": "wasd",
			"pause_key": "Escape",
			"toggle_enemy_hp_key": "H",
			"key_bindings": {},
			"show_enemy_health_bar": true,
			"show_key_hints_in_pause": true,
			"move_inertia": 0.0
		}
	},
	"weapon_meta": {
		"unlocked": [],
		"favorites": []
	}
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

	# 以 default_data 为模板合并：老存档缺字段时用默认值，新字段自动兼容。
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
	data["last_run"] = {
		"wave": wave,
		"kills": kills,
		"survival_time": survival_time
	}

	var best_wave_map: Dictionary = data.get("best_wave_per_character", {})
	var total_kills_map: Dictionary = data.get("total_kills_per_character", {})
	var key := str(character_id)
	best_wave_map[key] = max(int(best_wave_map.get(key, 0)), wave)
	total_kills_map[key] = int(total_kills_map.get(key, 0)) + kills
	data["best_wave_per_character"] = best_wave_map
	data["total_kills_per_character"] = total_kills_map

	var achievements: Array = data.get("achievements", [])
	# 轻量成就：本地布尔解锁，不依赖服务端状态。
	_try_unlock_achievement(achievements, "reach_wave_5", wave >= 5)
	_try_unlock_achievement(achievements, "reach_wave_10", wave >= 10)
	_try_unlock_achievement(achievements, "kill_100_one_run", kills >= 100)
	_try_unlock_achievement(achievements, "survive_300s", survival_time >= 300.0)
	data["achievements"] = achievements

	save_game(data)
	return data


func set_language(language_code: String) -> Dictionary:
	var data := load_game()
	data["language"] = language_code
	save_game(data)
	return data


func get_settings() -> Dictionary:
	var data := load_game()
	return data.get("settings", default_data["settings"]).duplicate(true)


func set_settings(settings: Dictionary) -> Dictionary:
	var data := load_game()
	data["settings"] = settings.duplicate(true)
	save_game(data)
	return data


func get_weapon_meta() -> Dictionary:
	var data := load_game()
	return data.get("weapon_meta", default_data["weapon_meta"]).duplicate(true)


func set_weapon_meta(meta: Dictionary) -> Dictionary:
	var data := load_game()
	data["weapon_meta"] = meta.duplicate(true)
	save_game(data)
	return data


func _try_unlock_achievement(list_ref: Array, id: String, condition: bool) -> void:
	if not condition:
		return
	if list_ref.has(id):
		return
	list_ref.append(id)
