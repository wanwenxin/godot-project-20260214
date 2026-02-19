extends TabContainer

# TabContainer 扩展：移除内容区默认 panel 背景，避免与外层 Panel 重复叠加。
# 不再注入自定义 TabBar 脚本，使用引擎默认绘制，避免重复层、文字遮盖、标签尺寸不一等问题。


func _ready() -> void:
	# 移除内容区 panel 背景，避免与外层 Panel（如 WeaponPanel）重复
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
