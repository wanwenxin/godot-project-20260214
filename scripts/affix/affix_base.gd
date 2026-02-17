extends RefCounted
class_name AffixBase

# 词条基类：
# - 附着于武器/魔法/道具的效果标签
# - 用于限定范围、批量应用效果，使效果与具体物体解耦
# - visible 控制是否对玩家展示
var id := ""  # 词条唯一标识
var visible := true  # 是否对玩家可见
var params: Dictionary = {}  # 效果参数，如 base_value、effect_type 等


## 从定义字典创建词条实例。def 中除 id、visible 外的字段会进入 params。
func configure_from_def(def: Dictionary) -> void:
	id = str(def.get("id", id))
	visible = bool(def.get("visible", true))
	params = def.get("params", {}).duplicate()
	# 将 def 中效果相关字段合并到 params（排除 id、visible）
	for key in def.keys():
		if key != "id" and key != "visible":
			params[key] = def[key]


## 获取展示用名称，供 UI 显示。
func get_display_name() -> String:
	var name_key: String = params.get("name_key", "affix.%s" % id)
	if LocalizationManager:
		return LocalizationManager.tr_key(name_key)
	return name_key


## 获取效果描述，供 UI 显示。
func get_display_desc() -> String:
	var desc_key: String = params.get("desc_key", "")
	if desc_key != "" and LocalizationManager:
		return LocalizationManager.tr_key(desc_key)
	return ""
