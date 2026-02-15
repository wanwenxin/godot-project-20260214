extends Node

signal language_changed(language_code: String)

const DEFAULT_LANGUAGE := "zh-CN"
const FALLBACK_LANGUAGE := "en-US"
const LANGUAGE_FILES := {
	"zh-CN": "res://i18n/zh-CN.json",
	"en-US": "res://i18n/en-US.json"
}

var current_language := DEFAULT_LANGUAGE
var _dict_cache: Dictionary = {}  # 语言码 -> key->text 字典，启动时载入


func _ready() -> void:
	_load_all_languages()
	var save_data := SaveManager.load_game()
	var preferred := str(save_data.get("language", DEFAULT_LANGUAGE))
	set_language(preferred, false)


func set_language(language_code: String, persist: bool = true) -> void:
	var target := language_code if LANGUAGE_FILES.has(language_code) else FALLBACK_LANGUAGE
	current_language = target
	if persist:
		SaveManager.set_language(current_language)
	emit_signal("language_changed", current_language)


func get_language_options() -> Array[Dictionary]:
	return [
		{"code": "zh-CN", "name": tr_key("lang.zh_cn")},
		{"code": "en-US", "name": tr_key("lang.en_us")}
	]


# 根据 key 查找文案，params 替换 {key} 占位符；缺省时回退到 fallback 语言。
func tr_key(key: String, params: Dictionary = {}) -> String:
	var text := _lookup(current_language, key)
	if text == "":
		text = _lookup(FALLBACK_LANGUAGE, key)
	if text == "":
		text = key
	for param_key in params.keys():
		text = text.replace("{" + str(param_key) + "}", str(params[param_key]))
	return text


func _load_all_languages() -> void:
	for language_code in LANGUAGE_FILES.keys():
		_dict_cache[language_code] = _load_language_file(str(LANGUAGE_FILES[language_code]))


func _load_language_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _lookup(language_code: String, key: String) -> String:
	var dict: Dictionary = _dict_cache.get(language_code, {})
	return str(dict.get(key, ""))
