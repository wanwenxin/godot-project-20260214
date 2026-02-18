extends VBoxContainer

# 背包面板：按武器、魔法、道具分栏展示，每项为图标槽，悬浮显示名称、词条、效果。
# 接收 stats 字典（weapon_details、magic_details、item_ids），构建三区。
# 武器支持手动合成、售卖；售卖/合并按钮仅在 shop_context 时显示（商店内打开背包）。
signal sell_requested(weapon_index: int)
signal merge_completed  # 合并成功后发出，供商店覆盖层刷新
const BASE_FONT_SIZE := 18
const SEP := "────"  # 分割线，无空行

var _tooltip_popup: BackpackTooltipPopup = null
var _merge_mode: bool = false
var _merge_base_index: int = -1
var _merge_weapon_id: String = ""
var _merge_weapon_tier: int = -1
var _weapon_grid: HFlowContainer = null
var _cancel_btn: Button = null
var _slot_style: StyleBoxFlat = null  # 槽位边框样式缓存，复用减少分配


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


var _shop_context := false  # 是否从商店打开，仅此时显示售卖/合并按钮
var _shop_wave := 0  # 商店模式下当前波次，用于计算售卖价
var _last_stats_hash: String = ""  # 脏检查：stats 未变时跳过重建

## 轻量哈希：weapon_details/magic_details/item_ids 的关键字段及 wave，用于脏检查。
func _hash_stats(stats: Dictionary) -> String:
	var w: Array = stats.get("weapon_details", [])
	var m: Array = stats.get("magic_details", [])
	var i: Array = stats.get("item_ids", [])
	var wave: int = int(stats.get("wave", 0))
	var parts: Array[String] = []
	for x in w:
		parts.append(str(x.get("id", "")) + ":" + str(x.get("tier", 0)))
	for x in m:
		parts.append(str(x.get("id", "")))
	for x in i:
		parts.append(str(x))
	return "%d|%d|%d|%d|%s" % [w.size(), m.size(), i.size(), wave, "|".join(parts)]

## 根据 stats 刷新背包内容。shop_context=true 时显示售卖/合并按钮。
func set_stats(stats: Dictionary, shop_context: bool = false) -> void:
	var new_hash := _hash_stats(stats)
	if new_hash == _last_stats_hash and shop_context == _shop_context:
		return
	_last_stats_hash = new_hash
	_shop_context = shop_context
	_shop_wave = int(stats.get("wave", 0))
	_exit_merge_mode()
	if _tooltip_popup == null:
		_tooltip_popup = BackpackTooltipPopup.new()
		_tooltip_popup.synthesize_requested.connect(_on_synthesize_requested)
		_tooltip_popup.sell_requested.connect(_on_sell_requested)
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
	# 武器区（含取消按钮容器，合并模式时显示取消）
	var weapon_header := HBoxContainer.new()
	weapon_header.add_theme_constant_override("separation", 8)
	var w_label := Label.new()
	w_label.text = LocalizationManager.tr_key("backpack.section_weapons")
	w_label.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	w_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	weapon_header.add_child(w_label)
	_cancel_btn = Button.new()
	_cancel_btn.text = LocalizationManager.tr_key("backpack.synthesize_cancel")
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_exit_merge_mode)
	weapon_header.add_child(_cancel_btn)
	var w_sep := HSeparator.new()
	add_child(w_sep)
	add_child(weapon_header)
	_weapon_grid = HFlowContainer.new()
	_weapon_grid.name = "WeaponGrid"
	_weapon_grid.add_theme_constant_override("h_separation", 8)
	_weapon_grid.add_theme_constant_override("v_separation", 8)
	for i in weapon_details.size():
		var w: Dictionary = weapon_details[i]
		var slot := _make_weapon_slot(w, weapon_upgrades, i, weapon_details)
		_weapon_grid.add_child(slot)
	add_child(_weapon_grid)
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


func _get_slot_style() -> StyleBoxFlat:
	if _slot_style == null:
		_slot_style = StyleBoxFlat.new()
		_slot_style.set_border_width_all(1)
		_slot_style.border_color = Color(0.45, 0.48, 0.55, 1.0)
		_slot_style.bg_color = Color(0.08, 0.09, 0.1, 0.6)
	return _slot_style


func _wrap_slot_in_panel(slot: BackpackSlot) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _get_slot_style())
	panel.add_child(slot)
	return panel


func _make_weapon_slot(w: Dictionary, weapon_upgrades: Array, weapon_index: int, weapon_details: Array) -> PanelContainer:
	var slot := BackpackSlot.new()
	var icon_path: String = str(w.get("icon_path", ""))
	var color_hint: Color = w.get("color_hint", Color(0.8, 0.8, 0.8, 1.0))
	if not (color_hint is Color):
		color_hint = Color(0.8, 0.8, 0.8, 1.0)
	var tier_color: Color = w.get("tier_color", TierConfig.get_tier_color(int(w.get("tier", 0))))
	if not (tier_color is Color):
		tier_color = TierConfig.get_tier_color(int(w.get("tier", 0)))
	var display_name := LocalizationManager.tr_key("weapon.%s.name" % str(w.get("id", "")))
	var tip_data: Dictionary = _build_weapon_tooltip_data(w, weapon_upgrades, weapon_index, weapon_details)
	slot.configure(icon_path, color_hint, "", _tooltip_popup, display_name, tier_color, tip_data, weapon_index)
	slot.slot_clicked.connect(_on_weapon_slot_clicked)
	return _wrap_slot_in_panel(slot)


## 构建武器 tooltip 结构化数据：含 type/theme/random 词条及升级项；可含合成按钮。
func _build_weapon_tooltip_data(w: Dictionary, weapon_upgrades: Array, weapon_index: int, weapon_details: Array) -> Dictionary:
	var name_key := "weapon.%s.name" % str(w.get("id", ""))
	var affixes: Array[Dictionary] = []
	# 升级项（weapon_upgrades）
	for uid in weapon_upgrades:
		var defs := UpgradeDefs.UPGRADE_POOL.filter(func(x): return str(x.get("id", "")) == uid)
		if defs.size() > 0:
			var def: Dictionary = defs[0]
			var val = UpgradeDefs.get_reward_value(def, 1)
			var value_fmt := _format_upgrade_value(str(def.get("id", "")), val)
			affixes.append({
				"id": uid,
				"type": "upgrade",
				"name_key": str(def.get("title_key", uid)),
				"desc_key": str(def.get("desc_key", "")),
				"value": val,
				"value_fmt": value_fmt
			})
	# 类型词条
	var type_id: String = str(w.get("type_affix_id", ""))
	if type_id != "":
		var tdef := WeaponTypeAffixDefs.get_affix_def(type_id)
		if not tdef.is_empty():
			var bonus = tdef.get("bonus_per_count", 0)
			var value_fmt := _format_set_bonus(str(tdef.get("effect_type", "")), bonus)
			affixes.append({
				"id": type_id,
				"type": "weapon_type",
				"name_key": str(tdef.get("name_key", "")),
				"effect_type": str(tdef.get("effect_type", "")),
				"bonus_per_count": bonus,
				"value_fmt": value_fmt
			})
	# 主题词条
	var theme_id: String = str(w.get("theme_affix_id", ""))
	if theme_id != "":
		var thdef := WeaponThemeAffixDefs.get_affix_def(theme_id)
		if not thdef.is_empty():
			var bonus = thdef.get("bonus_per_count", 0)
			var value_fmt := _format_set_bonus(str(thdef.get("effect_type", "")), bonus)
			affixes.append({
				"id": theme_id,
				"type": "weapon_theme",
				"name_key": str(thdef.get("name_key", "")),
				"effect_type": str(thdef.get("effect_type", "")),
				"bonus_per_count": bonus,
				"value_fmt": value_fmt
			})
	# 随机词条
	for aid in w.get("random_affix_ids", []):
		var adef := WeaponAffixDefs.get_affix_def(str(aid))
		if not adef.is_empty():
			var base_val = adef.get("base_value", 0)
			var value_fmt := _format_weapon_affix_value(str(adef.get("effect_type", "")), base_val)
			affixes.append({
				"id": str(aid),
				"type": "weapon_random",
				"name_key": str(adef.get("name_key", aid)),
				"desc_key": str(adef.get("desc_key", "")),
				"value": base_val,
				"value_fmt": value_fmt
			})
	# 售卖/合成按钮：仅在 shop_context 时显示
	var show_sell: bool = _shop_context
	var show_synthesize: bool = false
	if _shop_context:
		var wid: String = str(w.get("id", ""))
		var wtier: int = int(w.get("tier", 0))
		var max_tier: int = TierConfig.TIER_COLORS.size() - 1
		var candidate_count: int = 0
		for j in weapon_details.size():
			if j != weapon_index:
				var ow: Dictionary = weapon_details[j]
				if str(ow.get("id", "")) == wid and int(ow.get("tier", 0)) == wtier:
					candidate_count += 1
		show_synthesize = wtier < max_tier and candidate_count > 0
	# 效果区
	var effect_parts: Array[String] = []
	effect_parts.append(LocalizationManager.tr_key("pause.stat_damage") + ": %d" % int(w.get("damage", 0)))
	effect_parts.append(LocalizationManager.tr_key("pause.stat_cooldown") + ": %.2fs" % float(w.get("cooldown", 0)))
	effect_parts.append(LocalizationManager.tr_key("pause.stat_range") + ": %.0f" % float(w.get("range", 0)))
	if str(w.get("type", "")) == "ranged":
		effect_parts.append(LocalizationManager.tr_key("pause.stat_bullet_speed") + ": %.0f" % float(w.get("bullet_speed", 0)))
		effect_parts.append(LocalizationManager.tr_key("pause.stat_pellets") + ": %d" % int(w.get("pellet_count", 1)))
		effect_parts.append(LocalizationManager.tr_key("pause.stat_pierce") + ": %d" % int(w.get("bullet_pierce", 0)))
	# 售卖价：base_cost * tier_coef * wave_coef * 0.3
	var sell_price: int = 0
	if show_sell:
		var def := GameManager.get_weapon_def_by_id(str(w.get("id", "")))
		var base_cost: int = int(def.get("base_cost", 5))
		var tier_coef: float = TierConfig.get_damage_multiplier(int(w.get("tier", 0)))
		var wave_coef: float = 1.0 + float(_shop_wave) * 0.15
		sell_price = maxi(1, int(float(base_cost) * tier_coef * wave_coef * 0.3))
	return {
		"title": LocalizationManager.tr_key(name_key),
		"affixes": affixes,
		"effects": ", ".join(effect_parts),
		"show_sell": show_sell,
		"show_synthesize": show_synthesize,
		"weapon_index": weapon_index,
		"sell_price": sell_price
	}


func _format_upgrade_value(upgrade_id: String, val: Variant) -> String:
	if upgrade_id in ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed", "spell_speed"]:
		if upgrade_id == "lifesteal_chance":
			return "+%.0f%%" % (float(val) * 100.0)
		return "+%.2f" % float(val)
	return "+%d" % int(val)


func _format_set_bonus(effect_type: String, bonus: Variant) -> String:
	if effect_type in ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed", "spell_speed", "speed"]:
		if effect_type == "lifesteal_chance":
			return "+%.0f%%" % (float(bonus) * 100.0)
		return "+%.2f" % float(bonus)
	return "+%d" % int(bonus)


func _format_weapon_affix_value(effect_type: String, base_val: Variant) -> String:
	if effect_type in ["fire_rate"]:
		return "+%d" % int(base_val)
	if effect_type in ["bullet_speed", "attack_range", "damage", "multi_shot", "pierce"]:
		return "+%d" % int(base_val)
	return "+%d" % int(base_val)


func _make_magic_slot(m: Dictionary) -> PanelContainer:
	var slot := BackpackSlot.new()
	var def := MagicDefs.get_magic_by_id(str(m.get("id", "")))
	var icon_path: String = str(m.get("icon_path", def.get("icon_path", "")))
	var tier_color: Color = m.get("tier_color", TierConfig.get_tier_color(int(m.get("tier", 0))))
	if not (tier_color is Color):
		tier_color = TierConfig.get_tier_color(int(m.get("tier", 0)))
	var display_name := LocalizationManager.tr_key("magic.%s.name" % str(m.get("id", "")))
	var tip_data: Dictionary = _build_magic_tooltip_data(m, def)
	slot.configure(icon_path, BackpackSlot.PLACEHOLDER_COLOR, "", _tooltip_popup, display_name, tier_color, tip_data)
	return _wrap_slot_in_panel(slot)


## 构建魔法 tooltip 结构化数据：威力/消耗/冷却 + 三类词条 Chip。
func _build_magic_tooltip_data(m: Dictionary, def: Dictionary) -> Dictionary:
	var title_key := "magic.%s.name" % str(m.get("id", ""))
	var effect_parts: Array[String] = []
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_power") + ": %d" % int(def.get("power", 0)))
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_mana") + ": %d" % int(def.get("mana_cost", 0)))
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_cooldown") + ": %.1fs" % float(def.get("cooldown", 1.0)))
	var effects_str := ", ".join(effect_parts)
	var affixes: Array[Dictionary] = []
	for affix_id_key in ["range_affix_id", "effect_affix_id", "element_affix_id"]:
		var aid: String = str(def.get(affix_id_key, ""))
		if aid.is_empty():
			continue
		var affix_def := MagicAffixDefs.get_affix_def(aid)
		if affix_def.is_empty():
			continue
		var value_fmt := ""
		if affix_def.has("value_default"):
			var v: float = float(affix_def.get("value_default", 0))
			var vk: String = str(affix_def.get("value_key", ""))
			if vk == "size":
				value_fmt = "%.0f" % v
			elif vk == "radius":
				value_fmt = "%.0f" % v
		affixes.append({
			"id": aid,
			"name_key": str(affix_def.get("name_key", "")),
			"desc_key": str(affix_def.get("desc_key", "")),
			"value_fmt": value_fmt
		})
	return {
		"title": LocalizationManager.tr_key(title_key),
		"affixes": affixes,
		"effects": effects_str
	}


func _make_item_slot(item_id: String) -> PanelContainer:
	var slot := BackpackSlot.new()
	var def := _get_item_def(item_id)
	var icon_path: String = str(def.get("icon_path", ""))
	var display_key: String = str(def.get("display_name_key", def.get("name_key", "item.unknown.name")))
	var display_name := LocalizationManager.tr_key(display_key)
	var tip_data: Dictionary = _build_item_tooltip_data(item_id, def)
	slot.configure(icon_path, BackpackSlot.PLACEHOLDER_COLOR, "", _tooltip_popup, display_name, Color(0.85, 0.85, 0.9), tip_data)
	return _wrap_slot_in_panel(slot)


func _get_item_def(item_id: String) -> Dictionary:
	for it in ShopItemDefs.ITEM_POOL:
		if str(it.get("id", "")) == item_id:
			return it
	return {}


## 构建道具 tooltip 结构化数据：仅展示最终效果加成，不展示词条与数值。
func _build_item_tooltip_data(item_id: String, def: Dictionary) -> Dictionary:
	var display_key: String = str(def.get("display_name_key", def.get("name_key", "item.unknown.name")))
	var base_val = def.get("base_value", 0)
	var attr: String = str(def.get("attr", ""))
	var effect_str := _format_item_effect(attr, base_val)
	return {
		"title": LocalizationManager.tr_key(display_key),
		"affixes": [],
		"effects": effect_str
	}


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


func _on_synthesize_requested(weapon_index: int) -> void:
	_tooltip_popup.hide_tooltip()
	var weapon_details: Array = []
	var game = get_tree().current_scene
	if game != null and game.has_method("get_player_for_pause"):
		var p = game.get_player_for_pause()
		if p != null and p.has_method("get_equipped_weapon_details"):
			weapon_details = p.get_equipped_weapon_details()
	if weapon_index < 0 or weapon_index >= weapon_details.size():
		return
	var w: Dictionary = weapon_details[weapon_index]
	_merge_mode = true
	_merge_base_index = weapon_index
	_merge_weapon_id = str(w.get("id", ""))
	_merge_weapon_tier = int(w.get("tier", 0))
	_cancel_btn.visible = true
	_update_weapon_slots_merge_state(weapon_details)
	# 若仅 1 个可选素材，自动合并
	var candidate_indices: Array[int] = []
	for j in weapon_details.size():
		if j != weapon_index:
			var ow: Dictionary = weapon_details[j]
			if str(ow.get("id", "")) == _merge_weapon_id and int(ow.get("tier", 0)) == _merge_weapon_tier:
				candidate_indices.append(j)
	if candidate_indices.size() == 1:
		_do_merge(weapon_index, candidate_indices[0])


func _on_sell_requested(weapon_index: int) -> void:
	sell_requested.emit(weapon_index)


func _on_weapon_slot_clicked(weapon_index: int) -> void:
	if not _merge_mode or _merge_base_index < 0:
		return
	if weapon_index == _merge_base_index:
		return
	var weapon_details: Array = []
	var game = get_tree().current_scene
	if game != null and game.has_method("get_player_for_pause"):
		var p = game.get_player_for_pause()
		if p != null and p.has_method("get_equipped_weapon_details"):
			weapon_details = p.get_equipped_weapon_details()
	if weapon_index >= weapon_details.size():
		return
	var w: Dictionary = weapon_details[weapon_index]
	if str(w.get("id", "")) == _merge_weapon_id and int(w.get("tier", 0)) == _merge_weapon_tier:
		_do_merge(_merge_base_index, weapon_index)


func _do_merge(base_index: int, material_index: int) -> void:
	if GameManager.merge_run_weapons(base_index, material_index):
		var game = get_tree().current_scene
		if game != null and game.has_method("get_player_for_pause"):
			var p = game.get_player_for_pause()
			if p != null and p.has_method("sync_weapons_from_run"):
				p.sync_weapons_from_run(GameManager.get_run_weapons())
		_exit_merge_mode()
		merge_completed.emit()
		# 刷新暂停菜单显示
		var pause = _find_pause_menu()
		if pause != null and pause.has_method("_refresh_stats_from_game"):
			pause._refresh_stats_from_game()


func _update_weapon_slots_merge_state(weapon_details: Array) -> void:
	if _weapon_grid == null:
		return
	for i in _weapon_grid.get_child_count():
		var panel: Control = _weapon_grid.get_child(i)
		if panel.get_child_count() > 0:
			var slot: Control = panel.get_child(0)
			if slot is BackpackSlot:
				var bs: BackpackSlot = slot as BackpackSlot
				var selectable: bool = false
				if i != _merge_base_index:
					var w: Dictionary = weapon_details[i] if i < weapon_details.size() else {}
					if str(w.get("id", "")) == _merge_weapon_id and int(w.get("tier", 0)) == _merge_weapon_tier:
						selectable = true
				bs.set_merge_selectable(selectable)


func _find_pause_menu() -> Node:
	var node: Node = self
	while node:
		if node.has_method("_refresh_stats_from_game"):
			return node
		node = node.get_parent()
	return null


func _exit_merge_mode() -> void:
	_merge_mode = false
	_merge_base_index = -1
	_merge_weapon_id = ""
	_merge_weapon_tier = -1
	if _cancel_btn != null:
		_cancel_btn.visible = false
	if _weapon_grid != null:
		for i in _weapon_grid.get_child_count():
			var panel: Control = _weapon_grid.get_child(i)
			if panel.get_child_count() > 0:
				var slot: Control = panel.get_child(0)
				if slot is BackpackSlot:
					(slot as BackpackSlot).set_merge_selectable(false)
