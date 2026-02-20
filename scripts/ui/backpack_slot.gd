extends VBoxContainer
class_name BackpackSlot

# 背包槽：图标 + 名称（按品级着色），鼠标悬浮时立即显示自定义 Tooltip。
# 缺图时使用 make_color_texture 生成占位图。武器槽支持合并模式点击。
# 支持点击交换：第一次点击选中（绿色描边），第二次点击同类型另一槽交换，右键取消。
const SLOT_SIZE := 48
const SLOT_SIZE_COMPACT := 44  # 紧凑模式槽位尺寸，可在 BackpackPanel 中配置使用以多显示几项
const PLACEHOLDER_COLOR := Color(0.5, 0.55, 0.6, 1.0)

signal slot_clicked(weapon_index: int)
signal slot_swap_clicked(slot_index: int, slot_type: String)
signal slot_swap_cancel_requested
## 左键点击（非合并/非交换模式）时发射，用于右侧详情面板展示。
signal slot_detail_requested(slot_type: String, slot_index: int, tip_data: Dictionary)
## 鼠标进入槽位时发射，用于无选中时的悬浮详情。
signal slot_hover_entered(tip_data: Dictionary)
## 鼠标离开槽位时发射。
signal slot_hover_exited

var _icon_rect: TextureRect
var _name_label: Label
var _tip_text: String = ""
var _tip_data: Dictionary = {}  # 结构化详情数据，用于右侧详情面板
var _weapon_index: int = -1  # 武器槽索引，-1 表示非武器
var _merge_selectable: bool = false  # 合并模式下是否可选为素材
var _slot_type: String = ""  # "weapon"、"magic" 或 "item"
var _slot_index: int = -1  # 在对应列表中的索引


## 配置槽位：icon_path、color 用于图标，tip 用于纯文本（已弃用，保留兼容），tip_data 用于右侧详情面板。
## weapon_index 为武器槽索引，>=0 时表示武器槽，合并模式可点击。
## slot_type 和 slot_index 用于交换与详情（"weapon"、"magic" 或 "item"）。
func configure(icon_path: String, color: Color, tip: String, _tooltip_popup = null, display_name: String = "", name_color: Color = Color(0.85, 0.85, 0.9), tip_data: Dictionary = {}, weapon_index: int = -1, slot_type: String = "", slot_index: int = -1) -> void:
	for c in get_children():
		c.queue_free()
	_tip_text = tip
	_tip_data = tip_data
	_weapon_index = weapon_index
	_slot_type = slot_type
	_slot_index = slot_index
	# 图标：使用纹理缓存；EXPAND_IGNORE_SIZE 使大图不会按纹理尺寸撑大槽位，与图鉴一致
	_icon_rect = TextureRect.new()
	var tex: Texture2D = null
	if icon_path != "":
		tex = VisualAssetRegistry.get_texture_cached(icon_path)
	if tex == null:
		tex = VisualAssetRegistry.make_color_texture(color, Vector2i(SLOT_SIZE, SLOT_SIZE))
	_icon_rect.texture = tex
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	# 名称
	_name_label = Label.new()
	_name_label.text = display_name
	var theme_cfg := UiThemeConfig.load_theme()
	_name_label.add_theme_font_size_override("font_size", theme_cfg.get_scaled_font_size(theme_cfg.font_size_hud_small))
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
	slot_hover_entered.emit(_tip_data)


func _on_mouse_exited() -> void:
	slot_hover_exited.emit()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var ev := event as InputEventMouseButton
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			if _merge_selectable and _weapon_index >= 0:
				slot_clicked.emit(_weapon_index)
			else:
				slot_detail_requested.emit(_slot_type, _slot_index, _tip_data)
				if _slot_type in ["weapon", "magic"]:
					slot_swap_clicked.emit(_slot_index, _slot_type)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed and _slot_type != "":
			slot_swap_cancel_requested.emit()


## 返回槽位索引，供背包面板查找对应 Panel 以设置选中描边。
func get_slot_index() -> int:
	return _slot_index


## 返回槽位类型（"weapon" 或 "magic"），供背包面板判断是否同类型可交换。
func get_slot_type() -> String:
	return _slot_type


## 设置合并模式下是否可选为素材；不可选时置灰。
func set_merge_selectable(selectable: bool) -> void:
	_merge_selectable = selectable
	modulate = Color(1, 1, 1, 1) if selectable else Color(0.5, 0.5, 0.5, 0.8)


