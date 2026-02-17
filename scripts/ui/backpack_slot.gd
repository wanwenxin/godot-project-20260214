extends VBoxContainer
class_name BackpackSlot

# 背包槽：图标 + 名称（按品级着色），鼠标悬浮时立即显示自定义 Tooltip。
# 缺图时使用 make_color_texture 生成占位图。
const SLOT_SIZE := 48
const PLACEHOLDER_COLOR := Color(0.5, 0.55, 0.6, 1.0)
const NAME_FONT_SIZE := 12

var _icon_rect: TextureRect
var _name_label: Label
var _tip_text: String = ""
var _tooltip_popup: BackpackTooltipPopup = null


## 配置槽位：icon_path、color 用于图标，tip 用于悬浮提示，display_name、name_color 用于图标下名称。
func configure(icon_path: String, color: Color, tip: String, tooltip_popup: BackpackTooltipPopup = null, display_name: String = "", name_color: Color = Color(0.85, 0.85, 0.9)) -> void:
	for c in get_children():
		c.queue_free()
	_tip_text = tip
	_tooltip_popup = tooltip_popup
	# 图标
	_icon_rect = TextureRect.new()
	var tex: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	if tex == null:
		tex = VisualAssetRegistry.make_color_texture(color, Vector2i(SLOT_SIZE, SLOT_SIZE))
	_icon_rect.texture = tex
	_icon_rect.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	# 名称
	_name_label = Label.new()
	_name_label.text = display_name
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_color_override("font_color", name_color)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if _tooltip_popup != null and _tip_text != "":
		_tooltip_popup.show_tooltip(_tip_text)


func _on_mouse_exited() -> void:
	if _tooltip_popup != null:
		_tooltip_popup.hide_tooltip()
