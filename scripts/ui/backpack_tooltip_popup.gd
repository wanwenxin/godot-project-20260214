extends PanelContainer
class_name BackpackTooltipPopup

# 背包悬浮提示：PanelContainer 实现，挂到 CanvasLayer 保证与暂停菜单同视口，文字可正常显示。
# 大字号、宽高限制、自动换行、超高滚动，紧贴鼠标，同物体悬浮移动不重生成。
const TOOLTIP_FONT_SIZE := 17
const TOOLTIP_MIN_WIDTH := 260
const TOOLTIP_MAX_WIDTH := 280
const TOOLTIP_MAX_HEIGHT := 200
const MARGIN := 8
const GAP := 4

var _label: Label
var _scroll: ScrollContainer
var _last_tip: String = ""  # 当前展示的 tip，同物体不重生成


func _init() -> void:
	add_theme_stylebox_override("panel", _make_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(TOOLTIP_MIN_WIDTH, 0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = TOOLTIP_MIN_WIDTH - MARGIN * 2
	_label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	_scroll.add_child(_label)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.12, 0.13, 0.16, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.48, 0.55, 1.0)
	return style


## 显示悬浮提示，紧贴鼠标。同一物体（tip 相同）悬浮移动时不重生成。
func show_tooltip(text: String) -> void:
	if text.is_empty():
		hide_tooltip()
		return
	if visible and _last_tip == text:
		# 同物体，仅更新位置，不重设文本
		_update_position()
		return
	_last_tip = text
	_label.text = text
	_scroll.scroll_vertical = 0
	_update_position()
	visible = true


func _update_position() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var mouse_pos := vp.get_mouse_position()
	var est_width := TOOLTIP_MAX_WIDTH + MARGIN * 2
	var est_height := TOOLTIP_MAX_HEIGHT + MARGIN * 2
	var pos := mouse_pos + Vector2(GAP, GAP)
	var viewport_rect := vp.get_visible_rect()
	if pos.x + est_width > viewport_rect.end.x:
		pos.x = mouse_pos.x - est_width - GAP
	if pos.x < viewport_rect.position.x:
		pos.x = viewport_rect.position.x
	if pos.y + est_height > viewport_rect.end.y:
		pos.y = mouse_pos.y - est_height - GAP
	if pos.y < viewport_rect.position.y:
		pos.y = viewport_rect.position.y
	position = pos
	custom_minimum_size = Vector2(est_width, est_height)


## 关闭悬浮提示（避免覆盖 CanvasItem.hide）。
func hide_tooltip() -> void:
	visible = false
	_last_tip = ""
