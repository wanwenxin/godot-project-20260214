extends Node

# 结算/死亡/通关界面共享 UI 构建逻辑
# 供 pause_menu、game_over_screen、victory_screen 复用得分区与玩家信息区
static func build_score_block(wave: int, kills: int, time: float, best_wave: int, best_time: float) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var wave_flag := LocalizationManager.tr_key("hud.new_record") if wave >= best_wave else ""
	var time_flag := LocalizationManager.tr_key("hud.new_record") if time >= best_time else ""
	var score_text := LocalizationManager.tr_key("result.score_summary", {
		"wave": wave,
		"wave_flag": wave_flag,
		"kills": kills,
		"time": "%.1f" % time,
		"time_flag": time_flag
	})
	var lbl := Label.new()
	lbl.text = score_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl)
	return vbox


static func build_player_stats_block(hp_current: int, hp_max: int, speed: float, inertia: float, weapon_details: Array) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	# 玩家基础数据
	var player_section := _make_section_header(LocalizationManager.tr_key("pause.section_player"))
	vbox.add_child(player_section)
	var player_grid := GridContainer.new()
	player_grid.columns = 2
	player_grid.add_theme_constant_override("h_separation", 12)
	player_grid.add_theme_constant_override("v_separation", 6)
	_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_hp"), "%d / %d" % [hp_current, hp_max])
	_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_speed"), "%.0f" % speed)
	_add_stat_row(player_grid, LocalizationManager.tr_key("pause.stat_inertia"), "%.2f" % inertia)
	vbox.add_child(player_grid)
	# 武器区
	var weapon_section := _make_section_header(LocalizationManager.tr_key("pause.section_weapons"))
	vbox.add_child(weapon_section)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 12)
	if weapon_details.is_empty():
		var no_w := Label.new()
		no_w.text = LocalizationManager.tr_key("pause.no_weapons")
		no_w.add_theme_font_size_override("font_size", 13)
		weapon_row.add_child(no_w)
	else:
		for w in weapon_details:
			weapon_row.add_child(_make_weapon_card(w))
	vbox.add_child(weapon_row)
	return vbox


static func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	return lbl


static func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", 13)
	grid.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 13)
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
	name_lbl.add_theme_font_size_override("font_size", 14)
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
	inner.add_child(grid)
	card.add_child(inner)
	return card
