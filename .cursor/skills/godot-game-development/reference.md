# 拓展接口与模式参考

## 新模块拓展接口模板

新建功能模块时，按以下结构预留拓展能力。

### 模板：带虚方法的基类

```gdscript
class_name MyModuleBase
extends Node

# 模块说明：...
# 拓展点：子类 override 下方虚方法；外部连接下方信号

## 拓展信号：关键事件供外部监听
signal initialized
signal state_changed(new_state: String)
signal error_occurred(message: String)

## 拓展虚方法：子类 override
func _setup() -> void:
	pass

func _on_before_action() -> void:
	pass

func _on_after_action(result: Variant) -> void:
	pass

## 内部逻辑调用拓展点
func do_action() -> void:
	_on_before_action()
	var result := _internal_do_action()
	_on_after_action(result)
	emit_signal("state_changed", "done")
```

### 模板：可挂接的回调字典

```gdscript
# 允许运行时注册多个回调，无需修改脚本
var _callbacks: Dictionary = {}  # key: String, value: Callable

func register_callback(key: String, callback: Callable) -> void:
	_callbacks[key] = callback

func _invoke_callbacks(key: String, args: Array = []) -> void:
	if _callbacks.has(key):
		_callbacks[key].callv(args)
```

## 注释规范示例

```gdscript
# 波次管理器：
# - 控制波次推进与敌人生成
# - 发出清场、击杀、间隔等信号
# - 拓展：继承后 override _choose_enemy_for_wave() 可自定义刷怪策略
extends Node

signal wave_started(wave: int)
signal wave_cleared(wave: int)

@export var intermission_time := 5.0  # 波次间隔秒数
```

## 常见拓展场景

| 场景       | 拓展方式                         |
|------------|----------------------------------|
| 新敌类型   | 继承基类 + 新场景 + 注册到管理器 |
| 新升级项   | 池中加条目 + apply_upgrade 分支   |
| 新地形效果 | terrain_zone 新字段 + 生成逻辑   |
| 新音效     | audio_manager 新方法，保持对外 API |
