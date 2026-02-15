class_name LevelPreset
extends Resource

## 关卡预设：组合多个 LevelConfig，定义本局关卡顺序。

@export var preset_name: String = ""
@export var preset_desc: String = ""
@export var level_configs: Array[Resource] = []  # LevelConfig 数组，顺序即关卡顺序
