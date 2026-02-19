extends TabContainer

# TabContainer 扩展：在 _ready 时将内部 TabBar 替换为 TabBarSelectedScale 脚本，
# 使当前选中标签放大到 tab_selected_scale 倍（由 UiThemeConfig 配置）。
# 同时移除 TabContainer 内容区默认 panel 背景，避免与外层 Panel 重复叠加。


func _ready() -> void:
	# 移除内容区 panel 背景，避免与外层 Panel（如 WeaponPanel）重复
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var tab_bar: TabBar = get_tab_bar()
	if tab_bar != null:
		tab_bar.set_script(preload("res://scripts/ui/tab_bar_selected_scale.gd"))
