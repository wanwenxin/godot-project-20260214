extends Node

# 结算/死亡/通关界面共享 UI 构建逻辑
const BASE_FONT_SIZE := 18  # 统一基准字号


# 供 pause_menu、game_over_screen、victory_screen 复用得分区与玩家信息区
# 提供 action_to_text 供 HUD、暂停菜单等按键提示复用


## [自定义] 将 InputMap 动作名数组转为按键字符串，如 "WASD" 或 "P"。
func action_to_text(actions: Array) -> String:
	var result: Array[String] = []
	for action in actions:
		var events := InputMap.action_get_events(StringName(str(action)))
		if events.is_empty():
			continue
		var event := events[0]
		if event is InputEventKey:
			result.append(OS.get_keycode_string(event.keycode))
	if result.is_empty():
		return "-"
	return "/".join(result)


## [自定义] 构建得分区。gold、total_damage 为可选，缺省时显示 0。
func build_score_block(wave: int, kills: int, time: float, best_wave: int, best_time: float, gold: int = 0, total_damage: int = 0) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var wave_flag := LocalizationManager.tr_key("hud.new_record") if wave >= best_wave else ""
	var time_flag := LocalizationManager.tr_key("hud.new_record") if time >= best_time else ""
	var score_text := LocalizationManager.tr_key("result.score_summary", {
		"wave": wave,
		"wave_flag": wave_flag,
		"kills": kills,
		"time": "%.1f" % time,
		"time_flag": time_flag,
		"gold": gold,
		"total_damage": total_damage
	})
	var lbl := Label.new()
	lbl.text = score_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	vbox.add_child(lbl)
	return vbox


## [自定义] 构建玩家信息区。stats 为 Dictionary 时用完整格式；stats_only 为 true 时仅构建角色属性区。
func build_player_stats_block(stats_or_hp, hp_max_param = null, speed_param = null, inertia_param = null, weapon_details_param = null, stats_only: bool = false) -> Control:
	var stats: Dictionary
	if stats_or_hp is Dictionary:
		stats = stats_or_hp
	else:
		stats = {
			"hp_current": int(stats_or_hp),
			"hp_max": int(hp_max_param) if hp_max_param != null else 0,
			"speed": float(speed_param) if speed_param != null else 0.0,
			"inertia": float(inertia_param) if inertia_param != null else 0.0,
			"weapon_details": weapon_details_param if weapon_details_param is Array else [],
			"magic_details": [],
			"item_ids": []
		}
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	# 玩家属性区
	var player_section := _make_section_header(LocalizationManager.tr_key("pause.section_player"))
	vbox.add_child(player_section)
	var player_grid := GridContainer.new()
	player_grid.columns = 2
	player_grid.add_theme_constant_override("h_separation", 12)
	player_grid.add_theme_constant_override("v_separation", 6)
	var hp_cur: int = int(stats.get("hp_current", 0))
	var hp_mx: int = int(stats.get("hp_max", 0))
	_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_hp"), "%d / %d" % [hp_cur, hp_mx])
	if stats.has("max_mana"):
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_mana"), "%d" % int(stats.get("max_mana", 0)))
	if stats.has("armor"):
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_armor"), "%d" % int(stats.get("armor", 0)))
	_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_speed"), "%.0f" % float(stats.get("speed", 0)))
	_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_inertia"), "%.2f" % float(stats.get("inertia", 0)))
	if stats.has("attack_speed"):
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_attack_speed"), "%.2f" % float(stats.get("attack_speed", 1.0)))
	if stats.has("melee_bonus"):
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_melee_bonus"), "%d" % int(stats.get("melee_bonus", 0)))
	if stats.has("ranged_bonus"):
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_ranged_bonus"), "%d" % int(stats.get("ranged_bonus", 0)))
	if stats.has("health_regen") and float(stats.get("health_regen", 0)) > 0:
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_health_regen"), "%.2f/s" % float(stats.get("health_regen", 0)))
	if stats.has("mana_regen"):
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_mana_regen"), "%.2f/s" % float(stats.get("mana_regen", 0)))
	if stats.has("lifesteal_chance") and float(stats.get("lifesteal_chance", 0)) > 0:
		_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_lifesteal"), "%.0f%%" % (float(stats.get("lifesteal_chance", 0)) * 100.0))
	vbox.add_child(player_grid)
	if stats_only:
		return vbox
	# 武器区
	var weapon_details: Array = stats.get("weapon_details", [])
	var weapon_section := _make_section_header(LocalizationManager.tr_key("pause.section_weapons"))
	vbox.add_child(weapon_section)
	var weapon_row := HFlowContainer.new()
	weapon_row.add_theme_constant_override("h_separation", 12)
	weapon_row.add_theme_constant_override("v_separation", 12)
	if weapon_details.is_empty():
		var no_w := Label.new()
		no_w.text = LocalizationManager.tr_key("pause.no_weapons")
		no_w.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
		weapon_row.add_child(no_w)
	else:
		for w in weapon_details:
			weapon_row.add_child(_make_weapon_card(w))
	vbox.add_child(weapon_row)
	# 道具区
	var item_ids: Array = stats.get("item_ids", [])
	if item_ids.size() > 0:
		var item_section := _make_section_header(LocalizationManager.tr_key("pause.section_items"))
		vbox.add_child(item_section)
		var item_row := HFlowContainer.new()
		item_row.add_theme_constant_override("h_separation", 8)
		item_row.add_theme_constant_override("v_separation", 8)
		for iid in item_ids:
			item_row.add_child(_make_item_chip(str(iid)))
		vbox.add_child(item_row)
	# 可见词条区
	var visible_affixes: Array = stats.get("visible_affixes", [])
	if visible_affixes.size() > 0:
		var affix_section := _make_section_header(LocalizationManager.tr_key("pause.section_affixes"))
		vbox.add_child(affix_section)
		var affix_row := HFlowContainer.new()
		affix_row.add_theme_constant_override("h_separation", 8)
		affix_row.add_theme_constant_override("v_separation", 8)
		for affix in visible_affixes:
			if affix is AffixBase:
				affix_row.add_child(_make_affix_chip(affix as AffixBase))
		vbox.add_child(affix_row)
	# 套装效果区
	var set_bonus_info: Array = stats.get("set_bonus_info", [])
	if set_bonus_info.size() > 0:
		var set_section := _make_section_header(LocalizationManager.tr_key("pause.section_set_bonus"))
		vbox.add_child(set_section)
		var set_row := HFlowContainer.new()
		set_row.add_theme_constant_override("h_separation", 8)
		set_row.add_theme_constant_override("v_separation", 8)
		for sb in set_bonus_info:
			set_row.add_child(_make_set_bonus_chip(sb))
		vbox.add_child(set_row)
	# 魔法区
	var magic_details: Array = stats.get("magic_details", [])
	if magic_details.size() > 0:
		var magic_section := _make_section_header(LocalizationManager.tr_key("pause.section_magics"))
		vbox.add_child(magic_section)
		var magic_row := HFlowContainer.new()
		magic_row.add_theme_constant_override("h_separation", 8)
		magic_row.add_theme_constant_override("v_separation", 8)
		for m in magic_details:
			magic_row.add_child(_make_magic_chip(m))
		vbox.add_child(magic_row)
	return vbox


static func _make_item_chip(item_id: String) -> Control:
	var lbl := Label.new()
	var name_key := "item.unknown.name"
	for it in ShopItemDefs.ITEM_POOL:
		if str(it.get("id", "")) == item_id:
			name_key = str(it.get("name_key", name_key))
			break
	lbl.text = LocalizationManager.tr_key(name_key)
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1.0))
	return lbl


static func _make_affix_chip(affix: AffixBase) -> Control:
	var lbl := Label.new()
	lbl.text = affix.get_display_name()
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.85, 1.0))
	return lbl


static func _make_magic_chip(m: Dictionary) -> Control:
	var lbl := Label.new()
	var mid := str(m.get("id", ""))
	var name_key := "magic.%s.name" % mid
	lbl.text = LocalizationManager.tr_key(name_key)
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	var tier_color: Color = m.get("tier_color", Color(0.8, 0.85, 0.9, 1.0))
	if tier_color is Color:
		lbl.add_theme_color_override("font_color", tier_color)
	return lbl


static func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	return lbl


static func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	grid.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	val.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	grid.add_child(val)


static func _make_weapon_card(w: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 150
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(0.35, 0.36, 0.40, 1.0)
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 10
	card_style.content_margin_right = 10
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", card_style)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	var name_lbl := Label.new()
	var name_key := "weapon.%s.name" % str(w.get("id", ""))
	name_lbl.text = LocalizationManager.tr_key(name_key)
	name_lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	var tier_color: Color = w.get("tier_color", Color(0.95, 0.9, 0.7))
	if tier_color is Color:
		name_lbl.add_theme_color_override("font_color", tier_color)
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	inner.add_child(name_lbl)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_damage"), str(w.get("damage", 0)))
	_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_cooldown"), "%.2fs" % float(w.get("cooldown", 0)))
	_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_range"), "%.0f" % float(w.get("range", 0)))
	if str(w.get("type", "")) == "melee":
		_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_touch_interval"), "%.2fs" % float(w.get("touch_interval", 0)))
		_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_swing"), "%.0f° / %.0f" % [float(w.get("swing_degrees", 0)), float(w.get("swing_reach", 0))])
	else:
		_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_bullet_speed"), "%.0f" % float(w.get("bullet_speed", 0)))
		_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_pellets"), str(w.get("pellet_count", 1)))
		_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_spread"), "%.1f°" % float(w.get("spread_degrees", 0)))
		_add_stat_row(grid, LocalizationManager.tr_key("pause.stat_pierce"), str(w.get("bullet_pierce", 0)))
	# 类型/主题/随机词条标签
	var tags: Array[String] = []
	var type_id: String = str(w.get("type_affix_id", ""))
	if type_id != "":
		var tdef := WeaponTypeAffixDefs.get_affix_def(type_id)
		if not tdef.is_empty():
			tags.append(LocalizationManager.tr_key(str(tdef.get("name_key", ""))))
	var theme_id: String = str(w.get("theme_affix_id", ""))
	if theme_id != "":
		var thdef := WeaponThemeAffixDefs.get_affix_def(theme_id)
		if not thdef.is_empty():
			tags.append(LocalizationManager.tr_key(str(thdef.get("name_key", ""))))
	for aid in w.get("random_affix_ids", []):
		var adef := WeaponAffixDefs.get_affix_def(str(aid))
		if not adef.is_empty():
			tags.append(LocalizationManager.tr_key(str(adef.get("name_key", aid))))
	if tags.size() > 0:
		var tag_lbl := Label.new()
		tag_lbl.text = " | ".join(tags)
		tag_lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE - 2)
		tag_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8, 1.0))
		inner.add_child(tag_lbl)
	inner.add_child(grid)
	card.add_child(inner)
	return card


static func _make_set_bonus_chip(sb: Dictionary) -> Control:
	var lbl := Label.new()
	var name_str := LocalizationManager.tr_key(str(sb.get("name_key", "")))
	var count: int = int(sb.get("count", 0))
	var bonus = sb.get("bonus", 0)
	var et: String = str(sb.get("effect_type", ""))
	var bonus_str := ""
	if et in ["health_regen", "lifesteal_chance", "mana_regen", "attack_speed", "spell_speed", "speed"]:
		if et == "lifesteal_chance":
			bonus_str = "+%.0f%%" % (float(bonus) * 100.0)
		else:
			bonus_str = "+%.2f" % float(bonus)
	else:
		bonus_str = "+%d" % int(bonus)
	lbl.text = "%s x%d: %s" % [name_str, count, bonus_str]
	lbl.add_theme_font_size_override("font_size", BASE_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 0.85, 1.0))
	return lbl
