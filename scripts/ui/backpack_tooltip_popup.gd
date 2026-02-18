extends PanelContainer
class_name BackpackTooltipPopup

# 背包悬浮提示：PanelContainer 实现，挂到 CanvasLayer 保证与暂停菜单同视口，文字可正常显示。
# 支持结构化展示（名称、词条 Chip、效果），词条 hover 显示独立悬浮面板（完整描述+数值）；延迟隐藏，鼠标移入 tooltip 不消失。
# 武器 tooltip 可含「合成」按钮，点击后发出 synthesize_requested 信号。

signal synthesize_requested(weapon_index: int)
signal sell_requested(weapon_index: int)
const TOOLTIP_FONT_SIZE := 17
const TOOLTIP_WIDTH := 340  # 主 tooltip 固定宽度
const TOOLTIP_MAX_HEIGHT := 280  # 主 tooltip 最大高度
const AFFIX_TOOLTIP_WIDTH := 200  # 词条二级面板宽度，缩小便于切换
const AFFIX_TOOLTIP_FONT_SIZE := 14  # 词条面板字体
const MARGIN := 8
const GAP := 4
const HIDE_DELAY := 0.5  # 槽位/面板 mouse_exited 后延迟隐藏，便于鼠标移入 tooltip
const AFFIX_HIDE_DELAY := 0.5  # 词条 chip 离开后延迟隐藏词条面板

var _content: Control  # 动态内容：Label（简单模式）或 VBoxContainer（结构化模式）
var _scroll: ScrollContainer
var _label: Label  # 简单模式用
var _last_tip: String = ""
var _last_data_hash: String = ""  # 结构化数据哈希，同物体不重生成
var _hide_timer: Timer = null
var _affix_hide_timer: Timer = null  # 词条面板延迟隐藏，chip 离开后给鼠标移入面板的时间
var _affix_tooltip: PanelContainer = null  # 词条独立悬浮面板（与主 tooltip 同级），显示完整描述+数值
var _affix_tooltip_desc: Label = null
var _affix_tooltip_value: Label = null


func _init() -> void:
	add_theme_stylebox_override("panel", _make_panel_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(margin)
	_scroll = ScrollContainer.new()
	var content_width := TOOLTIP_WIDTH - MARGIN * 2
	_scroll.custom_minimum_size = Vector2(content_width, 0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_scroll)
	# 简单模式：单 Label，文本区宽度为父级 90%
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = int(content_width * 0.9)
	_label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	_content = _label
	_scroll.add_child(_content)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 延迟隐藏 Timer
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(_hide_timer)
	# 词条面板延迟隐藏 Timer，chip 离开后给鼠标移入面板的时间
	_affix_hide_timer = Timer.new()
	_affix_hide_timer.one_shot = true
	_affix_hide_timer.timeout.connect(_on_affix_hide_timer_timeout)
	add_child(_affix_hide_timer)
	# 词条独立悬浮面板（首次显示时加入与主 tooltip 同级，屏幕坐标定位）
	_build_affix_tooltip()
	# 鼠标进入 tooltip 取消延迟隐藏；离开时隐藏
	mouse_entered.connect(_on_self_mouse_entered)
	mouse_exited.connect(_on_self_mouse_exited)


func _build_affix_tooltip() -> void:
	_affix_tooltip = PanelContainer.new()
	_affix_tooltip.add_theme_stylebox_override("panel", _make_panel_style())
	_affix_tooltip.visible = false
	_affix_tooltip.mouse_filter = Control.MOUSE_FILTER_STOP  # 可接收鼠标，便于移入时取消隐藏
	_affix_tooltip.mouse_entered.connect(_on_affix_tooltip_mouse_entered)
	_affix_tooltip.mouse_exited.connect(_on_affix_tooltip_mouse_exited)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", MARGIN)
	m.add_theme_constant_override("margin_right", MARGIN)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	_affix_tooltip.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_affix_tooltip_desc = Label.new()
	_affix_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_affix_tooltip_desc.custom_minimum_size.x = int((AFFIX_TOOLTIP_WIDTH - MARGIN * 2) * 0.9)
	_affix_tooltip_desc.add_theme_font_size_override("font_size", AFFIX_TOOLTIP_FONT_SIZE)
	_affix_tooltip_desc.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	v.add_child(_affix_tooltip_desc)
	_affix_tooltip_value = Label.new()
	_affix_tooltip_value.add_theme_font_size_override("font_size", AFFIX_TOOLTIP_FONT_SIZE)
	_affix_tooltip_value.add_theme_color_override("font_color", Color(0.7, 0.95, 0.85))
	v.add_child(_affix_tooltip_value)
	m.add_child(v)
	# 不 add_child 到自身；首次显示时加入与主 tooltip 同级（CanvasLayer），实现独立面板


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.12, 0.13, 0.16, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.48, 0.55, 1.0)
	return style


## 显示悬浮提示（纯文本，用于魔法等无词条项）。同一物体悬浮移动时不重生成。
func show_tooltip(text: String) -> void:
	if text.is_empty():
		hide_tooltip()
		return
	if visible and _last_tip == text:
		_update_position()
		return
	_hide_tooltip_affix()
	_cancel_affix_hide()
	_cancel_scheduled_hide()
	_last_tip = text
	_last_data_hash = ""
	_switch_to_simple_mode()
	_label.text = text
	_scroll.scroll_vertical = 0
	_update_position()
	visible = true


## 显示结构化悬浮提示（名称、词条 Chip、效果）。词条 hover 显示独立悬浮面板（完整描述+数值）。
## data: {title, affixes: [{id, type, name_key, desc_key, value, value_fmt}], effects}
func show_structured_tooltip(data: Dictionary) -> void:
	if data.is_empty():
		hide_tooltip()
		return
	var h := _hash_tooltip_data(data)
	if visible and _last_data_hash == h:
		_update_position()
		return
	_hide_tooltip_affix()
	_cancel_affix_hide()
	_cancel_scheduled_hide()
	_last_tip = ""
	_last_data_hash = h
	_build_structured_content(data)
	_scroll.scroll_vertical = 0
	_update_position()
	visible = true


## 轻量哈希：仅拼接 title、weapon_index、affixes id、effects 等关键字段，避免 JSON.stringify 开销。
func _hash_tooltip_data(data: Dictionary) -> String:
	var parts: Array[String] = [str(data.get("title", "")), str(data.get("weapon_index", -1)), str(data.get("effects", ""))]
	parts.append("%s" % bool(data.get("show_sell", false)))
	parts.append("%d" % int(data.get("sell_price", 0)))
	parts.append("%s" % bool(data.get("show_synthesize", false)))
	for a in data.get("affixes", []):
		if a is Dictionary:
			parts.append(str(a.get("id", "")))
	return "|".join(parts)


func _switch_to_simple_mode() -> void:
	if _content != _label:
		_content.queue_free()
	_content = _label
	if _label.get_parent() != _scroll:
		_scroll.add_child(_label)


func _build_structured_content(data: Dictionary) -> void:
	if _content == _label:
		_scroll.remove_child(_label)
	else:
		_content.queue_free()
	var content_width := TOOLTIP_WIDTH - MARGIN * 2
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = int(content_width * 0.9)  # 文本区宽度为父级 90%
	vbox.add_theme_constant_override("separation", 4)
	# 名称
	var title_lbl := Label.new()
	title_lbl.text = str(data.get("title", ""))
	title_lbl.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)
	# 词条区
	var affixes: Array = data.get("affixes", [])
	if affixes.size() > 0:
		var affix_label := Label.new()
		affix_label.text = LocalizationManager.tr_key("backpack.tooltip_affixes") + ":"
		affix_label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE - 1)
		affix_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		vbox.add_child(affix_label)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		for affix_data in affixes:
			var chip := _make_affix_chip(affix_data)
			hbox.add_child(chip)
		vbox.add_child(hbox)
	# 效果区
	var effects: String = str(data.get("effects", ""))
	if not effects.is_empty():
		var eff_lbl := Label.new()
		eff_lbl.text = LocalizationManager.tr_key("backpack.tooltip_effects") + ": " + effects
		eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff_lbl.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE - 1)
		eff_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		vbox.add_child(eff_lbl)
	# 售卖按钮（仅 show_sell 时，显示价格 + 按钮）
	var weapon_idx: int = int(data.get("weapon_index", -1))
	if bool(data.get("show_sell", false)) and weapon_idx >= 0:
		var sell_price: int = int(data.get("sell_price", 0))
		var price_lbl := Label.new()
		price_lbl.text = LocalizationManager.tr_key("backpack.sell_price", {"price": sell_price})
		price_lbl.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE - 1)
		price_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		vbox.add_child(price_lbl)
		var sell_btn := Button.new()
		sell_btn.text = LocalizationManager.tr_key("backpack.sell")
		sell_btn.pressed.connect(_on_sell_pressed.bind(weapon_idx))
		vbox.add_child(sell_btn)
	# 合成按钮（仅武器且 show_synthesize 为 true 时）
	if bool(data.get("show_synthesize", false)) and weapon_idx >= 0:
		var synth_btn := Button.new()
		synth_btn.text = LocalizationManager.tr_key("backpack.synthesize")
		synth_btn.pressed.connect(_on_synthesize_pressed.bind(weapon_idx))
		vbox.add_child(synth_btn)
	_content = vbox
	_scroll.add_child(_content)


func _make_affix_chip(affix_data: Dictionary) -> Control:
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.set_corner_radius_all(4)
	chip_style.bg_color = Color(0.2, 0.25, 0.3, 0.9)
	chip_style.set_border_width_all(1)
	chip_style.border_color = Color(0.5, 0.55, 0.6, 1.0)
	chip.add_theme_stylebox_override("panel", chip_style)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 6)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	chip.add_child(m)
	var lbl := Label.new()
	lbl.text = LocalizationManager.tr_key(str(affix_data.get("name_key", "")))
	lbl.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE - 2)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(lbl)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_entered.connect(_on_affix_chip_entered.bind(affix_data, chip))
	chip.mouse_exited.connect(_on_affix_chip_exited)
	return chip


func _on_affix_chip_entered(affix_data: Dictionary, chip: Control) -> void:
	_cancel_affix_hide()
	# 首次显示时，将词条面板加入与主 tooltip 同级（CanvasLayer），实现独立面板
	if get_parent() != null and _affix_tooltip.get_parent() == null:
		get_parent().add_child(_affix_tooltip)
	var desc_key: String = str(affix_data.get("desc_key", ""))
	var value_fmt: String = str(affix_data.get("value_fmt", ""))
	var desc_text := ""
	if desc_key != "":
		desc_text = LocalizationManager.tr_key(desc_key)
	else:
		# 武器类型/主题：无 desc_key，用 effect_type + bonus_per_count 拼
		var et: String = str(affix_data.get("effect_type", ""))
		var bonus = affix_data.get("bonus_per_count", 0)
		if et != "":
			var effect_name := _effect_type_to_name(et)
			var bonus_str := _format_bonus(et, bonus)
			desc_text = LocalizationManager.tr_key("backpack.affix_set_bonus_desc") % [effect_name, bonus_str]
	_affix_tooltip_desc.text = desc_text
	_affix_tooltip_value.text = value_fmt
	# 类型/主题词条描述已含数值，不单独显示 value 行
	_affix_tooltip_value.visible = not value_fmt.is_empty() and desc_key != ""
	_affix_tooltip.visible = true
	_position_affix_tooltip(chip)


func _effect_type_to_name(et: String) -> String:
	var m := {
		"melee_damage_bonus": "pause.stat_melee_bonus",
		"ranged_damage_bonus": "pause.stat_ranged_bonus",
		"health_regen": "pause.stat_health_regen",
		"mana_regen": "pause.stat_mana_regen",
		"lifesteal_chance": "pause.stat_lifesteal",
		"max_health": "pause.stat_hp",
		"armor": "pause.stat_armor",
		"attack_speed": "pause.stat_attack_speed",
		"speed": "pause.stat_speed"
	}
	var key: String = m.get(et, "pause.stat_%s" % et)
	return LocalizationManager.tr_key(key)


func _format_bonus(et: String, bonus: Variant) -> String:
	if et in ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed", "spell_speed", "speed"]:
		if et == "lifesteal_chance":
			return "+%.0f%%" % (float(bonus) * 100.0)
		return "+%.2f" % float(bonus)
	return "+%d" % int(bonus)


func _position_affix_tooltip(_chip: Control) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var affix_size := _affix_tooltip.get_combined_minimum_size()
	var viewport_rect := vp.get_visible_rect()
	var pos := vp.get_mouse_position() + Vector2(GAP, GAP)
	# 边界裁剪
	pos.x = clamp(pos.x, viewport_rect.position.x, viewport_rect.end.x - affix_size.x)
	pos.y = clamp(pos.y, viewport_rect.position.y, viewport_rect.end.y - affix_size.y)
	# 词条面板与主 tooltip 同级，使用屏幕绝对坐标
	_affix_tooltip.position = pos
	_affix_tooltip.custom_minimum_size = affix_size


func _on_affix_chip_exited() -> void:
	# 延迟隐藏，便于鼠标移入词条面板
	_schedule_affix_hide()


func _hide_tooltip_affix() -> void:
	if _affix_tooltip != null:
		_affix_tooltip.visible = false


func _on_synthesize_pressed(weapon_index: int) -> void:
	synthesize_requested.emit(weapon_index)


func _on_sell_pressed(weapon_index: int) -> void:
	sell_requested.emit(weapon_index)


func _on_self_mouse_entered() -> void:
	_cancel_scheduled_hide()


func _on_self_mouse_exited() -> void:
	# 若鼠标仍在词条面板上，不调度关闭（词条面板在父 rect 外时可能触发主 tooltip mouse_exited）
	if _affix_tooltip != null and _affix_tooltip.visible:
		var vp := get_viewport()
		if vp != null:
			var mouse_pos := vp.get_mouse_position()
			if _affix_tooltip.get_global_rect().has_point(mouse_pos):
				return
	schedule_hide()


func _on_affix_tooltip_mouse_entered() -> void:
	_cancel_affix_hide()
	_cancel_scheduled_hide()


func _on_affix_tooltip_mouse_exited() -> void:
	_schedule_affix_hide()
	schedule_hide()


func _cancel_scheduled_hide() -> void:
	if _hide_timer != null and _hide_timer.time_left > 0:
		_hide_timer.stop()


func _schedule_affix_hide() -> void:
	if _affix_hide_timer != null:
		_affix_hide_timer.start(AFFIX_HIDE_DELAY)


func _cancel_affix_hide() -> void:
	if _affix_hide_timer != null and _affix_hide_timer.time_left > 0:
		_affix_hide_timer.stop()


func _on_affix_hide_timer_timeout() -> void:
	_hide_tooltip_affix()


## 槽位 mouse_exited 时调用：延迟隐藏，便于鼠标移入 tooltip。
func schedule_hide() -> void:
	if _hide_timer != null:
		_hide_timer.start(HIDE_DELAY)


## 是否正在延迟关闭（主 tooltip 的 hide timer 未结束）。用于「同类不重复打开」：关闭期间不响应新槽位。
func is_scheduled_to_hide() -> bool:
	return _hide_timer != null and _hide_timer.time_left > 0


func _on_hide_timer_timeout() -> void:
	_hide_tooltip_affix()
	visible = false
	_last_tip = ""
	_last_data_hash = ""


func _update_position() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var mouse_pos := vp.get_mouse_position()
	var est_width := TOOLTIP_WIDTH + MARGIN * 2
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
	_cancel_scheduled_hide()
	_cancel_affix_hide()
	_hide_tooltip_affix()
	visible = false
	_last_tip = ""
	_last_data_hash = ""
