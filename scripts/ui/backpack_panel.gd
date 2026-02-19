extends HBoxContainer

# 背包面板：固定结构在 backpack_panel.tscn（左：ContentPanel 背包内容，右：DetailPanel 物品详情，双独立面板），脚本只填槽位内容。
# 接收 stats 字典（weapon_details、magic_details、item_ids），向 WeaponGrid/MagicGrid/ItemGrid 填充槽位。
# 点击或悬浮槽位时在右侧 DetailPanel 显示详情，替代原 BackpackTooltipPopup 悬浮。
signal sell_requested(weapon_index: int)
signal merge_completed  # 合并成功后发出，供商店覆盖层刷新
const BASE_FONT_SIZE := 18
const SEP := "────"  # 分割线，无空行

@onready var _weapon_grid: HFlowContainer = $ContentPanel/ContentMargin/LeftVBox/WeaponGrid
@onready var _magic_grid: HFlowContainer = $ContentPanel/ContentMargin/LeftVBox/MagicGrid
@onready var _item_grid: HFlowContainer = $ContentPanel/ContentMargin/LeftVBox/ItemGrid
@onready var _cancel_btn: Button = $ContentPanel/ContentMargin/LeftVBox/WeaponHeader/CancelButton
@onready var _weapon_label: Label = $ContentPanel/ContentMargin/LeftVBox/WeaponHeader/WeaponLabel
@onready var _magic_label: Label = $ContentPanel/ContentMargin/LeftVBox/MagicLabel
@onready var _item_label: Label = $ContentPanel/ContentMargin/LeftVBox/ItemLabel
@onready var _detail_content: VBoxContainer = $DetailPanel/DetailMargin/DetailScroll/DetailContent

var _selected_slot: Dictionary = {}  # 点击选中的槽位 {type, index, tip_data}，非空时优先显示
var _merge_mode: bool = false
var _merge_base_index: int = -1
var _merge_weapon_id: String = ""
var _merge_weapon_tier: int = -1
var _slot_style: StyleBoxFlat = null  # 槽位边框样式缓存，复用减少分配
# 点击交换模式：第一次点击选中，第二次点击同类型另一槽交换，右键取消
var _swap_mode: bool = false
var _swap_first_index: int = -1
var _swap_slot_type: String = ""
var _swap_panel_ref: PanelContainer = null  # 当前选中槽位的父 Panel，用于绿色描边


## [系统] 应用 ContentPanel/DetailPanel 背景区分样式，强化视觉层次。
func _ready() -> void:
	var theme_cfg := UiThemeConfig.load_theme()
	$ContentPanel.add_theme_stylebox_override("panel", theme_cfg.get_panel_stylebox_for_bg(theme_cfg.content_panel_bg))
	$DetailPanel.add_theme_stylebox_override("panel", theme_cfg.get_panel_stylebox_for_bg(theme_cfg.detail_panel_bg))


## [系统] 右键取消交换模式。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var ev := event as InputEventMouseButton
		if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed and _swap_mode:
			_exit_swap_mode()
			get_viewport().set_input_as_handled()


## 向上查找 CanvasLayer（暂停菜单），用于挂载 tooltip 保证同视口显示。
func _find_canvas_layer() -> CanvasLayer:
	var node: Node = self
	while node:
		if node is CanvasLayer:
			return node as CanvasLayer
		node = node.get_parent()
	return null


## 关闭详情面板选中状态（暂停菜单关闭时调用），显示占位文案。
func hide_tooltip() -> void:
	_selected_slot = {}
	_show_detail_placeholder()


var _shop_context := false  # 是否从商店打开，仅此时显示售卖/合并按钮
var _shop_wave := 0  # 商店模式下当前波次，用于计算售卖价
var _last_stats_hash: String = ""  # 脏检查：stats 未变时跳过重建

# ---- 排序与过滤 ----
var _current_sort_mode := 0  # 0=默认 1=品级高到低 2=品级低到高 3=类型分组
var _current_filter_type := ""  # ""=全部 "melee"=近战 "ranged"=远程
const SORT_MODES := ["backpack.sort_default", "backpack.sort_tier_desc", "backpack.sort_tier_asc", "backpack.sort_type"]

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
	_exit_swap_mode()
	_selected_slot = {}
	for c in _weapon_grid.get_children():
		c.queue_free()
	for c in _magic_grid.get_children():
		c.queue_free()
	for c in _item_grid.get_children():
		c.queue_free()
	var weapon_details: Array = stats.get("weapon_details", [])
	var magic_details: Array = stats.get("magic_details", [])
	var item_ids: Array = stats.get("item_ids", [])
	var weapon_upgrades: Array = GameManager.get_run_weapon_upgrades()
	_build_all_sections(weapon_details, magic_details, item_ids, weapon_upgrades)


func _build_all_sections(weapon_details: Array, magic_details: Array, item_ids: Array, weapon_upgrades: Array) -> void:
	# 武器区：设置场景内标题与取消按钮，仅向 _weapon_grid 填充槽位
	_weapon_label.text = LocalizationManager.tr_key("backpack.section_weapons")
	_cancel_btn.text = LocalizationManager.tr_key("backpack.synthesize_cancel")
	_cancel_btn.visible = _merge_mode
	if not _cancel_btn.pressed.is_connected(_exit_merge_mode):
		_cancel_btn.pressed.connect(_exit_merge_mode)
	
	# 应用排序和过滤
	var sorted_weapons := _sort_and_filter_weapons(weapon_details)
	
	for i in sorted_weapons.size():
		var w: Dictionary = sorted_weapons[i]
		# 找到原始索引用于操作
		var original_idx := weapon_details.find(w)
		var slot := _make_weapon_slot(w, weapon_upgrades, original_idx, weapon_details)
		_weapon_grid.add_child(slot)
	# 魔法区
	_magic_label.text = LocalizationManager.tr_key("backpack.section_magics")
	for i in range(magic_details.size()):
		var m: Dictionary = magic_details[i]
		var slot := _make_magic_slot(m, i)
		_magic_grid.add_child(slot)
	# 道具区
	_item_label.text = LocalizationManager.tr_key("backpack.section_items")
	for i in item_ids.size():
		var slot := _make_item_slot(str(item_ids[i]), i)
		_item_grid.add_child(slot)
	# 初始显示占位文案
	_show_detail_placeholder()


func _get_slot_style() -> StyleBoxFlat:
	if _slot_style == null:
		_slot_style = StyleBoxFlat.new()
		_slot_style.set_border_width_all(1)
		_slot_style.border_color = Color(0.45, 0.48, 0.55, 1.0)
		_slot_style.bg_color = Color(0.08, 0.09, 0.1, 0.6)
	return _slot_style


## 返回选中状态的槽位样式（绿色描边）。
func _get_selected_slot_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.set_border_width_all(2)
	s.border_color = Color(0.2, 0.9, 0.3, 1.0)
	s.bg_color = Color(0.08, 0.09, 0.1, 0.6)
	return s


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
	slot.configure(icon_path, color_hint, "", null, display_name, tier_color, tip_data, weapon_index, "weapon", weapon_index)
	slot.slot_clicked.connect(_on_weapon_slot_clicked)
	slot.slot_swap_clicked.connect(_on_slot_swap_clicked)
	slot.slot_swap_cancel_requested.connect(_exit_swap_mode)
	slot.slot_detail_requested.connect(_on_slot_detail_requested)
	slot.slot_hover_entered.connect(_on_slot_hover_entered)
	slot.slot_hover_exited.connect(_on_slot_hover_exited)
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
	# 套装效果：仅展示该武器所属套装（2/4/6 件，含生效档位）
	var equipped_weapons: Array = []
	for ow in weapon_details:
		equipped_weapons.append({"id": str(ow.get("id", "")), "tier": int(ow.get("tier", 0))})
	var weapon_id: String = str(w.get("id", ""))
	var set_bonus_info: Array = WeaponSetDefs.get_weapon_set_full_display_info_for_weapon(equipped_weapons, weapon_id)
	return {
		"title": LocalizationManager.tr_key(name_key),
		"affixes": affixes,
		"effect_parts": effect_parts,
		"show_sell": show_sell,
		"show_synthesize": show_synthesize,
		"weapon_index": weapon_index,
		"sell_price": sell_price,
		"set_bonus_info": set_bonus_info
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


func _make_magic_slot(m: Dictionary, magic_index: int) -> PanelContainer:
	var slot := BackpackSlot.new()
	var def := MagicDefs.get_magic_by_id(str(m.get("id", "")))
	var icon_path: String = str(m.get("icon_path", def.get("icon_path", "")))
	var tier_color: Color = m.get("tier_color", TierConfig.get_tier_color(int(m.get("tier", 0))))
	if not (tier_color is Color):
		tier_color = TierConfig.get_tier_color(int(m.get("tier", 0)))
	var display_name := LocalizationManager.tr_key("magic.%s.name" % str(m.get("id", "")))
	var tip_data: Dictionary = _build_magic_tooltip_data(m, def)
	slot.configure(icon_path, BackpackSlot.PLACEHOLDER_COLOR, "", null, display_name, tier_color, tip_data, -1, "magic", magic_index)
	slot.slot_swap_clicked.connect(_on_slot_swap_clicked)
	slot.slot_swap_cancel_requested.connect(_exit_swap_mode)
	slot.slot_detail_requested.connect(_on_slot_detail_requested)
	slot.slot_hover_entered.connect(_on_slot_hover_entered)
	slot.slot_hover_exited.connect(_on_slot_hover_exited)
	return _wrap_slot_in_panel(slot)


## 构建魔法 tooltip 结构化数据：威力/消耗/冷却 + 三类词条 Chip。
func _build_magic_tooltip_data(m: Dictionary, def: Dictionary) -> Dictionary:
	var title_key := "magic.%s.name" % str(m.get("id", ""))
	var effect_parts: Array[String] = []
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_power") + ": %d" % int(def.get("power", 0)))
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_mana") + ": %d" % int(def.get("mana_cost", 0)))
	effect_parts.append(LocalizationManager.tr_key("backpack.tooltip_cooldown") + ": %.1fs" % float(def.get("cooldown", 1.0)))
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
		"effect_parts": effect_parts
	}


func _make_item_slot(item_id: String, item_index: int) -> PanelContainer:
	var slot := BackpackSlot.new()
	var def := _get_item_def(item_id)
	var icon_path: String = str(def.get("icon_path", ""))
	var display_key: String = str(def.get("display_name_key", def.get("name_key", "item.unknown.name")))
	var display_name := LocalizationManager.tr_key(display_key)
	var tip_data: Dictionary = _build_item_tooltip_data(item_id, def)
	slot.configure(icon_path, BackpackSlot.PLACEHOLDER_COLOR, "", null, display_name, Color(0.85, 0.85, 0.9), tip_data, -1, "item", item_index)
	slot.slot_detail_requested.connect(_on_slot_detail_requested)
	slot.slot_hover_entered.connect(_on_slot_hover_entered)
	slot.slot_hover_exited.connect(_on_slot_hover_exited)
	return _wrap_slot_in_panel(slot)


func _get_item_def(item_id: String) -> Dictionary:
	for it in ShopItemDefs.ITEM_POOL:
		if str(it.get("id", "")) == item_id:
			return it
	return {}


## 构建道具 tooltip 结构化数据：仅展示最终效果加成，不展示词条与数值。
## 魔法类道具无 attr/base_value，仅展示名称；attribute 类展示数值效果。
func _build_item_tooltip_data(_item_id: String, def: Dictionary) -> Dictionary:
	var display_key: String
	if def.is_empty():
		display_key = "item.%s.name" % _item_id
	else:
		display_key = str(def.get("display_name_key", def.get("name_key", "item.%s.name" % _item_id)))
	var base_val: Variant = def.get("base_value", 0) if not def.is_empty() else 0
	var attr: String = str(def.get("attr", "")) if not def.is_empty() else ""
	var effect_str := _format_item_effect(attr, base_val)
	var effect_parts: Array[String] = []
	if not effect_str.is_empty():
		effect_parts.append(effect_str)
	return {
		"title": LocalizationManager.tr_key(display_key),
		"affixes": [],
		"effect_parts": effect_parts
	}


func _attr_to_affix_id(attr: String) -> String:
	var m := {"max_health": "item_max_health", "max_mana": "item_max_mana", "armor": "item_armor",
		"speed": "item_speed", "melee_damage_bonus": "item_melee", "ranged_damage_bonus": "item_ranged",
		"health_regen": "item_regen", "lifesteal_chance": "item_lifesteal",
		"mana_regen": "item_mana_regen", "spell_speed": "item_spell_speed"}
	return m.get(attr, "item_%s" % attr)


## 格式化道具数值效果；attr 为空（魔法类）或无有效数值时返回空串。
func _format_item_effect(attr: String, val: Variant) -> String:
	if attr.is_empty():
		return ""
	# 安全处理 null 或非数值类型
	if val == null:
		return ""
	if val is float:
		if attr == "lifesteal_chance":
			return "+%.0f%%" % (float(val) * 100.0)
		return "+%.1f" % float(val)
	if val is int:
		return "+%d" % int(val)
	# String 需先验证再转换，避免 float("invalid") 抛错
	if val is String:
		if not str(val).is_valid_float():
			return ""
		var as_float := float(val)
		if is_nan(as_float) or is_inf(as_float):
			return ""
		if attr == "lifesteal_chance":
			return "+%.0f%%" % (as_float * 100.0)
		if abs(as_float - int(as_float)) > 0.0001:
			return "+%.1f" % as_float
		return "+%d" % int(as_float)
	return ""


func _on_synthesize_requested(weapon_index: int) -> void:
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
				var weapon_idx: int = bs.get_slot_index()
				var selectable: bool = false
				if weapon_idx != _merge_base_index and weapon_idx < weapon_details.size():
					var w: Dictionary = weapon_details[weapon_idx]
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


## 退出点击交换模式，移除选中槽位的绿色描边。
func _exit_swap_mode() -> void:
	if _swap_panel_ref != null:
		_swap_panel_ref.add_theme_stylebox_override("panel", _get_slot_style())
		_swap_panel_ref = null
	_swap_mode = false
	_swap_first_index = -1
	_swap_slot_type = ""


## [自定义] 点击槽位：选中并刷新详情面板；若为武器/魔法则同时进入交换流程。
func _on_slot_detail_requested(slot_type: String, slot_index: int, tip_data: Dictionary) -> void:
	_selected_slot = {"type": slot_type, "index": slot_index, "tip_data": tip_data}
	_refresh_detail_panel(tip_data)


## [自定义] 悬浮进入槽位：若无选中则用当前槽位 tip_data 刷新详情。
func _on_slot_hover_entered(tip_data: Dictionary) -> void:
	if _selected_slot.is_empty():
		_refresh_detail_panel(tip_data)


## [自定义] 悬浮离开槽位：若无选中则显示占位文案。
func _on_slot_hover_exited() -> void:
	if _selected_slot.is_empty():
		_show_detail_placeholder()


## [自定义] 刷新右侧详情面板内容，复用 BackpackTooltipPopup 的结构化展示逻辑。
func _refresh_detail_panel(tip_data: Dictionary) -> void:
	if _detail_content == null:
		return
	if tip_data.is_empty():
		_show_detail_placeholder()
		return
	_build_detail_content(tip_data)


## [自定义] 无选中且无悬浮时显示占位文案。
func _show_detail_placeholder() -> void:
	if _detail_content == null:
		return
	for c in _detail_content.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = LocalizationManager.tr_key("backpack.detail_placeholder")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_detail_content.add_child(lbl)


## [自定义] 构建详情面板内容：标题、词条、效果、套装、售卖/合成按钮。
func _build_detail_content(data: Dictionary) -> void:
	if _detail_content == null:
		return
	for c in _detail_content.get_children():
		c.queue_free()
	# 标题
	var title_lbl := Label.new()
	title_lbl.text = str(data.get("title", ""))
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(title_lbl)
	var bullet: String = LocalizationManager.tr_key("common.bullet")
	# 词条区
	var affixes: Array = data.get("affixes", [])
	if affixes.size() > 0:
		var affix_label := Label.new()
		affix_label.text = LocalizationManager.tr_key("backpack.tooltip_affixes") + ":"
		affix_label.add_theme_font_size_override("font_size", 17)
		affix_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		_detail_content.add_child(affix_label)
		var affix_vbox := VBoxContainer.new()
		affix_vbox.add_theme_constant_override("separation", 2)
		for affix_data in affixes:
			var line := Label.new()
			var name_str := LocalizationManager.tr_key(str(affix_data.get("name_key", "")))
			var desc_key: String = str(affix_data.get("desc_key", ""))
			var value_fmt: String = str(affix_data.get("value_fmt", ""))
			var desc_str := ""
			if desc_key != "":
				desc_str = LocalizationManager.tr_key(desc_key)
			else:
				var et: String = str(affix_data.get("effect_type", ""))
				var bonus = affix_data.get("bonus_per_count", 0)
				if et != "":
					desc_str = _effect_type_to_desc(et, bonus)
			line.text = "  " + bullet + " " + name_str + ": " + (desc_str if desc_str != "" else value_fmt)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.add_theme_font_size_override("font_size", 16)
			line.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			affix_vbox.add_child(line)
		_detail_content.add_child(affix_vbox)
	# 效果区：分行 ul/li 风格展示
	var effect_parts: Array = data.get("effect_parts", [])
	if effect_parts.size() > 0:
		var eff_header := Label.new()
		eff_header.text = LocalizationManager.tr_key("backpack.tooltip_effects") + ":"
		eff_header.add_theme_font_size_override("font_size", 17)
		eff_header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		_detail_content.add_child(eff_header)
		var eff_vbox := VBoxContainer.new()
		eff_vbox.add_theme_constant_override("separation", 2)
		for part in effect_parts:
			var eff_line := Label.new()
			eff_line.text = "  " + bullet + " " + str(part)
			eff_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eff_line.add_theme_font_size_override("font_size", 16)
			eff_line.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			eff_vbox.add_child(eff_line)
		_detail_content.add_child(eff_vbox)
	# 套装效果区（2/4/6 件完整展示，高亮生效档位）
	var piece_str: String = LocalizationManager.tr_key("common.piece")
	var set_bonus_info: Array = data.get("set_bonus_info", [])
	if set_bonus_info.size() > 0:
		var set_header := Label.new()
		set_header.text = LocalizationManager.tr_key("backpack.tooltip_set_bonus")
		set_header.add_theme_font_size_override("font_size", 17)
		set_header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		_detail_content.add_child(set_header)
		for set_info in set_bonus_info:
			var name_str := LocalizationManager.tr_key(str(set_info.get("name_key", "")))
			var count: int = int(set_info.get("count", 0))
			var set_lbl := Label.new()
			set_lbl.text = "[%s] (%d%s)" % [name_str, count, piece_str]
			set_lbl.add_theme_font_size_override("font_size", 16)
			set_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			_detail_content.add_child(set_lbl)
			var thresholds: Array = set_info.get("thresholds", [])
			for th in thresholds:
				var n: int = int(th.get("n", 0))
				var desc: String = str(th.get("desc", ""))
				var active: bool = bool(th.get("active", false))
				var th_lbl := Label.new()
				th_lbl.text = "  " + LocalizationManager.tr_key("common.piece_threshold", {"value": n}) + " " + desc
				th_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				th_lbl.add_theme_font_size_override("font_size", 15)
				if active:
					th_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
				else:
					th_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
				_detail_content.add_child(th_lbl)
	# 售卖按钮
	var weapon_idx: int = int(data.get("weapon_index", -1))
	if bool(data.get("show_sell", false)) and weapon_idx >= 0:
		var sell_price: int = int(data.get("sell_price", 0))
		var price_lbl := Label.new()
		price_lbl.text = LocalizationManager.tr_key("backpack.sell_price", {"price": sell_price})
		price_lbl.add_theme_font_size_override("font_size", 17)
		price_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
		_detail_content.add_child(price_lbl)
		var sell_btn := Button.new()
		sell_btn.text = LocalizationManager.tr_key("backpack.sell")
		sell_btn.pressed.connect(func(): sell_requested.emit(weapon_idx))
		_detail_content.add_child(sell_btn)
	# 合成按钮
	if bool(data.get("show_synthesize", false)) and weapon_idx >= 0:
		var synth_btn := Button.new()
		synth_btn.text = LocalizationManager.tr_key("backpack.synthesize")
		synth_btn.pressed.connect(_on_synthesize_requested.bind(weapon_idx))
		_detail_content.add_child(synth_btn)


func _effect_type_to_desc(et: String, bonus: Variant) -> String:
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
	var effect_name := LocalizationManager.tr_key(key)
	var bonus_str := "+%d" % int(bonus)
	if et in ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed", "spell_speed", "speed"]:
		if et == "lifesteal_chance":
			bonus_str = "+%.0f%%" % (float(bonus) * 100.0)
		else:
			bonus_str = "+%.2f" % float(bonus)
	return LocalizationManager.tr_key("backpack.affix_set_bonus_desc") % [effect_name, bonus_str]


## 查找指定 slot_index 和 slot_type 的槽位所在 Panel。
func _find_panel_for_slot(slot_index: int, slot_type: String) -> PanelContainer:
	var grid: HFlowContainer = _weapon_grid if slot_type == "weapon" else _magic_grid
	if grid == null:
		return null
	for i in grid.get_child_count():
		var panel: Node = grid.get_child(i)
		if panel.get_child_count() > 0:
			var slot: Node = panel.get_child(0)
			if slot is BackpackSlot and (slot as BackpackSlot).get_slot_index() == slot_index and (slot as BackpackSlot).get_slot_type() == slot_type:
				return panel as PanelContainer
	return null


## [自定义] 点击交换：第一次点击选中，第二次点击同类型另一槽交换。
func _on_slot_swap_clicked(slot_index: int, slot_type: String) -> void:
	if _merge_mode:
		return
	if not _swap_mode:
		# 进入交换模式，选中当前槽位
		_swap_mode = true
		_swap_first_index = slot_index
		_swap_slot_type = slot_type
		var panel := _find_panel_for_slot(slot_index, slot_type)
		if panel != null:
			if _swap_panel_ref != null:
				_swap_panel_ref.add_theme_stylebox_override("panel", _get_slot_style())
			_swap_panel_ref = panel
			panel.add_theme_stylebox_override("panel", _get_selected_slot_style())
	else:
		# 已在交换模式，点击另一槽位则交换
		if slot_type != _swap_slot_type or slot_index == _swap_first_index:
			return
		var game = get_tree().current_scene
		var p = game.get_player_for_pause() if game != null and game.has_method("get_player_for_pause") else null
		if _swap_slot_type == "weapon":
			if GameManager.reorder_run_weapons(_swap_first_index, slot_index):
				if p != null and p.has_method("sync_weapons_from_run"):
					p.sync_weapons_from_run(GameManager.get_run_weapons())
				_last_stats_hash = ""
				if p != null and p.has_method("get_full_stats_for_pause"):
					set_stats(p.get_full_stats_for_pause(), _shop_context)
		else:
			if p != null and p.has_method("reorder_magics") and p.reorder_magics(_swap_first_index, slot_index):
				_last_stats_hash = ""
				if p.has_method("get_full_stats_for_pause"):
					set_stats(p.get_full_stats_for_pause(), _shop_context)
		_exit_swap_mode()


## [自定义] 设置武器排序模式并刷新显示。
func set_sort_mode(mode_index: int) -> void:
	_current_sort_mode = clampi(mode_index, 0, SORT_MODES.size() - 1)
	# 触发重建
	_last_stats_hash = ""


## [自定义] 设置武器过滤类型并刷新显示。
func set_filter_type(weapon_type: String) -> void:
	_current_filter_type = weapon_type
	# 触发重建
	_last_stats_hash = ""


## [自定义] 对武器列表进行排序和过滤。
func _sort_and_filter_weapons(weapon_details: Array) -> Array:
	var result := weapon_details.duplicate(true)
	
	# 过滤
	if _current_filter_type != "":
		var filtered: Array = []
		for w in result:
			var wtype: String = str(w.get("type", ""))
			if wtype == _current_filter_type:
				filtered.append(w)
		result = filtered
	
	# 排序
	match _current_sort_mode:
		1:  # 品级高到低
			result.sort_custom(func(a, b): return int(a.get("tier", 0)) > int(b.get("tier", 0)))
		2:  # 品级低到高
			result.sort_custom(func(a, b): return int(a.get("tier", 0)) < int(b.get("tier", 0)))
		3:  # 类型分组
			result.sort_custom(func(a, b): 
				var type_a: String = str(a.get("type", ""))
				var type_b: String = str(b.get("type", ""))
				if type_a != type_b:
					return type_a < type_b
				return int(a.get("tier", 0)) > int(b.get("tier", 0))
			)
	
	return result


## [自定义] 批量售卖指定品级以下的武器。
func batch_sell_by_tier(max_tier: int) -> Array[int]:
	var sold_indices: Array[int] = []
	if not _shop_context:
		return sold_indices
	
	var game = get_tree().current_scene
	if game == null or not game.has_method("get_player_for_pause"):
		return sold_indices
	
	var p = game.get_player_for_pause()
	if p == null or not p.has_method("get_equipped_weapon_details"):
		return sold_indices
	
	var weapon_details: Array = p.get_equipped_weapon_details()
	for i in range(weapon_details.size() - 1, -1, -1):
		var w: Dictionary = weapon_details[i]
		if int(w.get("tier", 0)) <= max_tier:
			sold_indices.append(i)
	
	return sold_indices
