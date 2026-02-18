extends Node

# 敌人 id -> PackedScene 映射，供 wave_manager 按 id 生成敌人。
# 作为 Autoload 注册为 EnemySceneRegistry，勿使用 class_name 避免与单例名冲突。
# 启动时从 EnemyDefs 加载各 scene_path。

var _scenes: Dictionary = {}  # id -> PackedScene


func _ready() -> void:
	_build_registry()


func _build_registry() -> void:
	# 先加载 base 场景（melee/ranged/tank/boss/aquatic/dasher）
	var base_ids := ["melee", "ranged", "tank", "boss", "aquatic", "dasher"]
	for bid in base_ids:
		var path := "res://scenes/enemies/enemy_%s.tscn" % bid
		if ResourceLoader.exists(path):
			_scenes[bid] = load(path) as PackedScene
	for e in EnemyDefs.ENEMY_DEFS:
		var eid: String = str(e.get("id", ""))
		var path: String = str(e.get("scene_path", ""))
		if eid.is_empty():
			continue
		if path != "" and ResourceLoader.exists(path):
			_scenes[eid] = load(path) as PackedScene
		else:
			var base_id: String = str(e.get("base_id", "melee"))
			if _scenes.has(base_id):
				_scenes[eid] = _scenes[base_id]


## 根据 id 获取 PackedScene，不存在则返回 null。
func get_scene(enemy_id: String) -> PackedScene:
	return _scenes.get(enemy_id, null)
