extends VBoxContainer
class_name BackpackSlot

# 背包槽：图标 + 名称（按品级着色），鼠标悬浮时立即显示自定义 Tooltip。
# 缺图时使用 make_color_texture 生成占位图。武器槽支持合并模式点击。
# 支持拖拽换位。
const SLOT_SIZE := 48
const PLACEHOLDER_COLOR := Color(0.5, 0.55, 0.6, 1.0)
const NAME_FONT_SIZE := 12

signal slot_clicked(weapon_index: int)
signal slot_dropped(from_index: int, to_index: int, slot_type: String)

var _icon_rect: TextureRect
var _name_label: Label
var _tip_text: String = ""
var _tip_data: Dictionary = {}  # 结构化 tooltip 数据，非空时用 show_structured_tooltip
var _tooltip_popup: BackpackTooltipPopup = null
var _weapon_index: int = -1  # 武器槽索引，-1 表示非武器
var _merge_selectable: bool = false  # 合并模式下是否可选为素材
var _slot_type: String = ""  # "weapon" 或 "magic"
var _slot_index: int = -1  # 在对应列表中的索引


## 配置槽位：icon_path、color 用于图标，tip 用于纯文本悬浮（魔法等），tip_data 用于结构化悬浮（武器/道具）。
## weapon_index 为武器槽索引，>=0 时表示武器槽，合并模式可点击。
## slot_type 和 slot_index 用于拖拽换位（"weapon" 或 "magic"）。
func configure(icon_path: String, color: Color, tip: String, tooltip_popup: BackpackTooltipPopup = null, display_name: String = "", name_color: Color = Color(0.85, 0.85, 0.9), tip_data: Dictionary = {}, weapon_index: int = -1, slot_type: String = "", slot_index: int = -1) -> void:
	for c in get_children():
		c.queue_free()
	_tip_text = tip
	_tip_data = tip_data
	_tooltip_popup = tooltip_popup
	_weapon_index = weapon_index
	_slot_type = slot_type
	_slot_index = slot_index
	# 图标：使用纹理缓存避免重复 load
	_icon_rect = TextureRect.new()
	var tex: Texture2D = null
	if icon_path != "":
		tex = VisualAssetRegistry.get_texture_cached(icon_path)
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
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func _on_mouse_entered() -> void:
	if _tooltip_popup == null:
		return
	if not _tip_data.is_empty():
		_tooltip_popup.show_structured_tooltip(_tip_data)
	elif _tip_text != "":
		_tooltip_popup.show_tooltip(_tip_text)


func _on_mouse_exited() -> void:
	if _tooltip_popup != null:
		_tooltip_popup.schedule_hide()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var ev := event as InputEventMouseButton
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and _merge_selectable and _weapon_index >= 0:
			slot_clicked.emit(_weapon_index)


## 设置合并模式下是否可选为素材；不可选时置灰。
func set_merge_selectable(selectable: bool) -> void:
	_merge_selectable = selectable
	modulate = Color(1, 1, 1, 1) if selectable else Color(0.5, 0.5, 0.5, 0.8)


# ---- 拖拽支持 ----

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _slot_index < 0 or _slot_type == "":
		return null
	var data := {
		"from_index": _slot_index,
		"slot_type": _slot_type
	}
	# 创建拖拽预览
	var preview := TextureRect.new()
	if _icon_rect and _icon_rect.texture:
		preview.texture = _icon_rect.texture
	preview.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	preview.modulate.a = 0.7
	set_drag_preview(preview)
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var d: Dictionary = data
	# 只能同类型槽位之间拖拽
	return d.get("slot_type", "") == _slot_type and _slot_index >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var d: Dictionary = data
	var from_index: int = int(d.get("from_index", -1))
	if from_index < 0 or from_index == _slot_index:
		return
	slot_dropped.emit(from_index, _slot_index, _slot_type)
