extends VBoxContainer

# 背包面板：按武器、魔法、道具分栏展示，每项为图标槽，悬浮显示名称、词条、效果。
# 接收 stats 字典（weapon_details、magic_details、item_ids），构建三区。
const BASE_FONT_SIZE := 18
const SEP := "────"  # 分割线，无空行

var _tooltip_popup: BackpackTooltipPopup = null


## 向上查找 CanvasLayer（暂停菜单），用于挂载 tooltip 保证同视口显示。
func _find_canvas_layer() -> CanvasLayer:
	var node: Node = self
	while node:
		if node is CanvasLayer:
			return node as CanvasLayer
		node = node.get_parent()
	return null


## 关闭悬浮提示（暂停菜单关闭时调用）。
func hide_tooltip() -> void:
	if _tooltip_popup != null:
		_tooltip_popup.hide_tooltip()


## 根据 stats 刷新背包内容。
func set_stats(stats: Dictionary) -> void:
	if _tooltip_popup == null:
		_tooltip_popup = BackpackTooltipPopup.new()
		var layer := _find_canvas_layer()
		if layer != null:
			layer.add_child(_tooltip_popup)
		else:
			get_tree().root.add_child(_tooltip_popup)
	for c in get_children():
		if c != _tooltip_popup:
			c.queue_free()
	var weapon_details: Array = stats.get("weapon_details", [])
	var magic_details: Array = stats.get("magic_details", [])
	var item_ids: Array = stats.get("item_ids", [])
	var weapon_upgrades: Array = GameManager.get_run_weapon_upgrades()
	_build_all_sections(weapon_details, magic_details, item_ids, weapon_upgrades)


func _build_all_sections(weapon_details: Array, magic_details: Array, item_ids: Array, weapon_upgrades: Array) -> void:
	# 武器区
	var w_sep := HSeparator.new()
	add_child(w_sep)
	var w_label := Label.new()
	w_label.text = LocalizationManager.tr_key("backpack.section_weapons")
	w_label.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	w_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	add_child(w_label)
	var w_grid := HFlowContainer.new()
	w_grid.add_theme_constant_override("h_separation", 8)
	w_grid.add_theme_constant_override("v_separation", 8)
	for w in weapon_details:
		var slot := _make_weapon_slot(w as Dictionary, weapon_upgrades)
		w_grid.add_child(slot)
	add_child(w_grid)
	# 魔法区
	var m_sep := HSeparator.new()
	add_child(m_sep)
	var m_label := Label.new()
	m_label.text = LocalizationManager.tr_key("backpack.section_magics")
	m_label.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	m_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	add_child(m_label)
	var m_grid := HFlowContainer.new()
	m_grid.add_theme_constant_override("h_separation", 8)
	m_grid.add_theme_constant_override("v_separation", 8)
	for m in magic_details:
		var slot := _make_magic_slot(m as Dictionary)
		m_grid.add_child(slot)
	add_child(m_grid)
	# 道具区
	var i_sep := HSeparator.new()
	add_child(i_sep)
	var i_label := Label.new()
	i_label.text = LocalizationManager.tr_key("backpack.section_items")
	i_label.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	i_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	add_child(i_label)
	var i_grid := HFlowContainer.new()
	i_grid.add_theme_constant_override("h_separation", 8)
	i_grid.add_theme_constant_override("v_separation", 8)
	for iid in item_ids:
		var slot := _make_item_slot(str(iid))
		i_grid.add_child(slot)
	add_child(i_grid)


func _make_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.48, 0.55, 1.0)
	style.bg_color = Color(0.08, 0.09, 0.1, 0.6)
	return style


func _wrap_slot_in_panel(slot: BackpackSlot) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_slot_style())
	panel.add_child(slot)
	return panel


func _make_weapon_slot(w: Dictionary, weapon_upgrades: Array) -> PanelContainer:
	var slot := BackpackSlot.new()
	var icon_path: String = str(w.get("icon_path", ""))
	var color_hint: Color = w.get("color_hint", Color(0.8, 0.8, 0.8, 1.0))
	if not (color_hint is Color):
		color_hint = Color(0.8, 0.8, 0.8, 1.0)
	var tier_color: Color = w.get("tier_color", TierConfig.get_tier_color(int(w.get("tier", 0))))
	if not (tier_color is Color):
		tier_color = TierConfig.get_tier_color(int(w.get("tier", 0)))
	var display_name := LocalizationManager.tr_key("weapon.%s.name" % str(w.get("id", "")))
	var tip := _build_weapon_tooltip(w, weapon_upgrades)
	slot.configure(icon_path, color_hint, tip, _tooltip_popup, display_name, tier_color)
	return _wrap_slot_in_panel(slot)


func _build_weapon_tooltip(w: Dictionary, weapon_upgrades: Array) -> String:
	var name_key := "weapon.%s.name" % str(w.get("id", ""))
	var lines: Array[String] = [LocalizationManager.tr_key(name_key)]
	if weapon_upgrades.size() > 0:
		lines.append(SEP)
		var affix_names: Array[String] = []
		for uid in weapon_upgrades:
			var def := UpgradeDefs.UPGRADE_POOL.filter(func(x): return str(x.get("id", "")) == uid)
			if def.size() > 0:
				affix_names.append(LocalizationManager.tr_key(str(def[0].get("title_key", uid))))
		lines.append(LocalizationManager.tr_key("backpack.tooltip_affixes") + ": " + ", ".join(affix_names))
	lines.append(SEP)
	var effect_parts: Array[String] = []
	effect_parts.append(LocalizationManager.tr_key("pause.stat_damage") + ": %d" % int(w.get("damage", 0)))
	effect_parts.append(LocalizationManager.tr_key("pause.stat_cooldown") + ": %.2fs" % float(w.get("cooldown", 0)))
	effect_parts.append(LocalizationManager.tr_key("pause.stat_range") + ": %.0f" % float(w.get("range", 0)))
	if str(w.get("type", "")) == "ranged":
		effect_parts.append(LocalizationManager.tr_key("pause.stat_bullet_speed") + ": %.0f" % float(w.get("bullet_speed", 0)))
		effect_parts.append(LocalizationManager.tr_key("pause.stat_pellets") + ": %d" % int(w.get("pellet_count", 1)))
		effect_parts.append(LocalizationManager.tr_key("pause.stat_pierce") + ": %d" % int(w.get("bullet_pierce", 0)))
	lines.append(LocalizationManager.tr_key("backpack.tooltip_effects") + ": " + ", ".join(effect_parts))
	return "\n".join(lines)


func _make_magic_slot(m: Dictionary) -> PanelContainer:
	var slot := BackpackSlot.new()
	var def := MagicDefs.get_magic_by_id(str(m.get("id", "")))
	var icon_path: String = str(m.get("icon_path", def.get("icon_path", "")))
	var tier_color: Color = m.get("tier_color", TierConfig.get_tier_color(int(m.get("tier", 0))))
	if not (tier_color is Color):
		tier_color = TierConfig.get_tier_color(int(m.get("tier", 0)))
	var display_name := LocalizationManager.tr_key("magic.%s.name" % str(m.get("id", "")))
	var tip := _build_magic_tooltip(m, def)
	slot.configure(icon_path, BackpackSlot.PLACEHOLDER_COLOR, tip, _tooltip_popup, display_name, tier_color)
	return _wrap_slot_in_panel(slot)


func _build_magic_tooltip(m: Dictionary, def: Dictionary) -> String:
	var name_key := "magic.%s.name" % str(m.get("id", ""))
	var lines: Array[String] = [LocalizationManager.tr_key(name_key)]
	lines.append(SEP)
	var effect_parts: Array[String] = []
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_power") + ": %d" % int(def.get("power", 0)))
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_mana") + ": %d" % int(def.get("mana_cost", 0)))
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_cooldown") + ": %.1fs" % float(def.get("cooldown", 1.0)))
	lines.append(LocalizationManager.tr_key("backpack.tooltip_effects") + ": " + ", ".join(effect_parts))
	return "\n".join(lines)


func _make_item_slot(item_id: String) -> PanelContainer:
	var slot := BackpackSlot.new()
	var def := _get_item_def(item_id)
	var icon_path: String = str(def.get("icon_path", ""))
	var display_name := LocalizationManager.tr_key(str(def.get("name_key", "item.unknown.name")))
	var tip := _build_item_tooltip(item_id, def)
	slot.configure(icon_path, BackpackSlot.PLACEHOLDER_COLOR, tip, _tooltip_popup, display_name, Color(0.85, 0.85, 0.9))
	return _wrap_slot_in_panel(slot)


func _get_item_def(item_id: String) -> Dictionary:
	for it in ShopItemDefs.ITEM_POOL:
		if str(it.get("id", "")) == item_id:
			return it
	return {}


func _build_item_tooltip(item_id: String, def: Dictionary) -> String:
	var name_key: String = str(def.get("name_key", "item.unknown.name"))
	var lines: Array[String] = [LocalizationManager.tr_key(name_key)]
	var affix_ids: Array = def.get("affix_ids", [])
	if affix_ids.is_empty() and def.has("attr"):
		affix_ids = [_attr_to_affix_id(str(def.get("attr", "")))]
	if affix_ids.size() > 0:
		lines.append(SEP)
		var affix_names: Array[String] = []
		for aid in affix_ids:
			var adef := ItemAffixDefs.get_affix_def(str(aid))
			if not adef.is_empty():
				affix_names.append(LocalizationManager.tr_key(str(adef.get("name_key", aid))))
		lines.append(LocalizationManager.tr_key("backpack.tooltip_affixes") + ": " + ", ".join(affix_names))
	lines.append(SEP)
	var base_val = def.get("base_value", 0)
	var attr: String = str(def.get("attr", ""))
	var effect_str := _format_item_effect(attr, base_val)
	lines.append(LocalizationManager.tr_key("backpack.tooltip_effects") + ": " + effect_str)
	return "\n".join(lines)


func _attr_to_affix_id(attr: String) -> String:
	var m := {"max_health": "item_max_health", "max_mana": "item_max_mana", "armor": "item_armor",
		"speed": "item_speed", "melee_damage_bonus": "item_melee", "ranged_damage_bonus": "item_ranged",
		"health_regen": "item_regen", "lifesteal_chance": "item_lifesteal",
		"mana_regen": "item_mana_regen", "spell_speed": "item_spell_speed"}
	return m.get(attr, "item_%s" % attr)


func _format_item_effect(attr: String, val: Variant) -> String:
	if attr == "lifesteal_chance" and val is float:
		return "+%.0f%%" % (float(val) * 100.0)
	if val is float:
		return "+%.1f" % float(val)
	return "+%d" % int(val)
