extends TabBar

# TabBar 扩展：当前选中标签整体放大（字号 + 标签尺寸）到 tab_selected_scale 倍。
# 倍率从 UiThemeConfig.tab_selected_scale 读取，常量化便于统一调整。


func _ready() -> void:
	tab_changed.connect(_on_tab_changed)


## [系统] tab 切换时重绘以更新选中标签样式。
func _on_tab_changed(_tab: int) -> void:
	queue_redraw()


func _draw() -> void:
	var theme_cfg := UiThemeConfig.load_theme()
	var scale_factor: float = theme_cfg.tab_selected_scale
	var base_font_size: int = get_theme_font_size("font_size", "TabBar")
	var font: Font = get_theme_font("font", "TabBar")
	if font == null:
		font = ThemeDB.fallback_font
	var h_sep: int = get_theme_constant("h_separation", "TabBar")
	var outline_size: int = get_theme_constant("outline_size", "TabBar")
	# 两遍绘制：先绘未选中，再绘选中，确保选中标签在最上层
	for pass_selected in [false, true]:
		for i in range(tab_count):
			if is_tab_hidden(i):
				continue
			var is_selected := (i == current_tab)
			if is_selected != pass_selected:
				continue
			var rect := get_tab_rect(i)
			var style: StyleBox = _get_tab_style(i, is_selected)
			# 选中标签：扩大绘制区域，使标签整体放大
			var tab_rect := rect
			if is_selected and scale_factor > 1.0:
				var extra_w: float = rect.size.x * (scale_factor - 1.0) * 0.5
				var extra_h: float = rect.size.y * (scale_factor - 1.0) * 0.5
				tab_rect = rect.grow_individual(extra_w, extra_h, extra_w, extra_h)
			if style != null:
				draw_style_box(style, tab_rect)
			var text_color: Color = _get_tab_text_color(i, is_selected)
			var used_font_size: int = int(base_font_size * scale_factor) if is_selected else base_font_size
			var title := get_tab_title(i)
			var icon: Texture2D = get_tab_icon(i)
			var icon_width: int = _get_icon_width(icon)
			var margin_left: float = float(style.get_margin(SIDE_LEFT)) if style != null else 0.0
			var margin_right: float = float(style.get_margin(SIDE_RIGHT)) if style != null else 0.0
			var content_min_x: float = tab_rect.position.x + margin_left
			var content_max_x: float = tab_rect.position.x + tab_rect.size.x - margin_right
			var text_width: float = content_max_x - content_min_x - icon_width - (h_sep if icon_width > 0 else 0)
			var text_pos := Vector2(content_min_x + (icon_width + h_sep if icon_width > 0 else 0), tab_rect.position.y + tab_rect.size.y / 2.0)
			if icon != null and icon_width > 0:
				var icon_pos := Vector2(content_min_x, tab_rect.position.y + (tab_rect.size.y - icon.get_height()) / 2.0)
				draw_texture_rect(icon, Rect2(icon_pos, Vector2(icon_width, icon.get_height())), false)
			if font != null and title != "":
				var str_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, used_font_size)
				text_pos.y += int(str_size.y / 2.0)
				if outline_size > 0:
					var outline_color: Color = get_theme_color("font_outline_color", "TabBar")
					draw_string_outline(font, text_pos, title, HORIZONTAL_ALIGNMENT_LEFT, int(text_width), used_font_size, outline_size, outline_color)
				draw_string(font, text_pos, title, HORIZONTAL_ALIGNMENT_LEFT, int(text_width), used_font_size, text_color)


## [自定义] 获取指定 tab 的 StyleBox。
func _get_tab_style(idx: int, is_selected: bool) -> StyleBox:
	if is_tab_disabled(idx):
		return get_theme_stylebox("tab_disabled", "TabBar")
	if is_selected:
		return get_theme_stylebox("tab_selected", "TabBar")
	return get_theme_stylebox("tab_unselected", "TabBar")


## [自定义] 获取指定 tab 的文本颜色。
func _get_tab_text_color(idx: int, is_selected: bool) -> Color:
	if is_tab_disabled(idx):
		return get_theme_color("font_disabled_color", "TabBar")
	if is_selected:
		return get_theme_color("font_selected_color", "TabBar")
	return get_theme_color("font_unselected_color", "TabBar")


## [自定义] 获取图标显示宽度（受 icon_max_width 约束）。
func _get_icon_width(icon: Texture2D) -> int:
	if icon == null:
		return 0
	var max_w: int = get_theme_constant("icon_max_width", "TabBar")
	if max_w > 0:
		return int(min(icon.get_width(), max_w))
	return int(icon.get_width())
