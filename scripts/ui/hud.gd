extends CanvasLayer

# HUD 与结算层：
# - 战斗中显示 HP/波次/击杀/时间
# - 死亡后展示结算面板并提供重开/回主菜单入口
signal upgrade_selected(upgrade_id: String)
signal start_weapon_selected(weapon_id: String)
signal weapon_shop_selected(weapon_id: String)
signal mobile_move_changed(direction: Vector2)
signal pause_pressed

@onready var health_label: Label = $Root/TopRow/HealthLabel
@onready var wave_label: Label = $Root/TopRow/WaveLabel
@onready var kill_label: Label = $Root/TopRow/KillLabel
@onready var timer_label: Label = $Root/TopRow/TimerLabel
@onready var pause_hint: Label = $Root/PauseHint
@onready var game_over_panel: Panel = $Root/GameOverPanel
@onready var game_over_text: Label = $Root/GameOverPanel/VBoxContainer/GameOverText
@onready var retry_btn: Button = $Root/GameOverPanel/VBoxContainer/RetryButton
@onready var menu_btn: Button = $Root/GameOverPanel/VBoxContainer/MenuButton

var _intermission_label: Label
var _wave_countdown_label: Label
var _currency_label: Label
var _wave_banner: Label
var _upgrade_panel: Panel
var _upgrade_title_label: Label
var _upgrade_tip_label: Label
var _upgrade_buttons: Array[Button] = []
var _upgrade_icons: Array[TextureRect] = []
var _weapon_panel: Panel
var _weapon_title_label: Label
var _weapon_tip_label: Label
var _weapon_buttons: Array[Button] = []
var _weapon_icons: Array[TextureRect] = []
var _modal_backdrop: ColorRect
var _weapon_mode := ""
var _touch_panel: Control
var _pause_touch_btn: Button
# 触控方向状态字典，组合成归一化向量后回传给 Player。
var _move_state := {
	"left": false,
	"right": false,
	"up": false,
	"down": false
}
var _last_health_current := 0
var _last_health_max := 0
var _last_wave := 1
var _last_kills := 0
var _last_time := 0.0
var _last_currency := 0


func _ready() -> void:
	# 启动时默认不显示结算面板。
	game_over_panel.visible = false
	game_over_panel.anchors_preset = Control.PRESET_FULL_RECT
	game_over_panel.offset_left = 0
	game_over_panel.offset_top = 0
	game_over_panel.offset_right = 0
	game_over_panel.offset_bottom = 0
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_build_runtime_ui()
	_setup_touch_controls()
	_apply_localized_static_texts()
	set_health(0, 0)
	set_wave(1)
	set_kills(0)
	set_survival_time(0.0)
	set_currency(0)
	_intermission_label.visible = false
	_wave_banner.visible = false
	_upgrade_panel.visible = false
	_weapon_panel.visible = false
	_modal_backdrop.visible = false


func set_health(current: int, max_value: int) -> void:
	_last_health_current = current
	_last_health_max = max_value
	health_label.text = LocalizationManager.tr_key("hud.hp", {"current": current, "max": max_value})


func set_wave(value: int) -> void:
	_last_wave = value
	wave_label.text = LocalizationManager.tr_key("hud.wave", {"value": value})


func set_kills(value: int) -> void:
	_last_kills = value
	kill_label.text = LocalizationManager.tr_key("hud.kills", {"value": value})


func set_survival_time(value: float) -> void:
	_last_time = value
	timer_label.text = LocalizationManager.tr_key("hud.time", {"value": "%.1f" % value})


func set_pause_hint(show_hint: bool) -> void:
	pause_hint.visible = show_hint


func set_currency(value: int) -> void:
	_last_currency = value
	_currency_label.text = LocalizationManager.tr_key("hud.gold", {"value": value})


func set_intermission_countdown(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_intermission_label.visible = false
		return
	_intermission_label.visible = true
	_intermission_label.text = LocalizationManager.tr_key("hud.next_wave", {"value": "%.1f" % seconds_left})


func set_wave_countdown(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_wave_countdown_label.visible = false
		return
	_wave_countdown_label.visible = true
	_wave_countdown_label.text = LocalizationManager.tr_key("hud.wave_countdown", {"value": "%.0f" % seconds_left})


func show_wave_banner(wave: int) -> void:
	_wave_banner.visible = true
	_wave_banner.text = LocalizationManager.tr_key("hud.wave_banner", {"wave": wave})
	var tween := create_tween()
	_wave_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_property(_wave_banner, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	tween.finished.connect(func() -> void: _wave_banner.visible = false)


func show_upgrade_options(options: Array[Dictionary], current_gold: int) -> void:
	_show_modal_backdrop(true)
	_upgrade_panel.visible = true
	_currency_label.text = LocalizationManager.tr_key("hud.gold", {"value": current_gold})
	_upgrade_title_label.text = LocalizationManager.tr_key("hud.upgrade_title")
	_upgrade_tip_label.text = LocalizationManager.tr_key("hud.upgrade_tip", {"gold": current_gold})
	for i in range(_upgrade_buttons.size()):
		var btn := _upgrade_buttons[i]
		if i >= options.size():
			btn.visible = false
			_upgrade_icons[i].visible = false
			continue
		btn.visible = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 58)
		var option: Dictionary = options[i]
		var cost := int(option.get("cost", 0))
		var affordable := current_gold >= cost
		# 金币不足直接置灰，仍保留文案给玩家决策反馈。
		btn.disabled = not affordable
		var title_text := LocalizationManager.tr_key(str(option.get("title_key", "upgrade.skip.title")))
		var desc_text := LocalizationManager.tr_key(str(option.get("desc_key", "upgrade.skip.desc")))
		var icon_key := "upgrade.icon." + str(option.get("id", ""))
		var fallback_upgrade_icon := func() -> Texture2D:
			return VisualAssetRegistry.make_color_texture(icon_key, Color(0.68, 0.68, 0.74, 1.0), Vector2i(96, 96))
		_upgrade_icons[i].texture = VisualAssetRegistry.get_texture(icon_key, fallback_upgrade_icon)
		_upgrade_icons[i].visible = true
		btn.text = LocalizationManager.tr_key("hud.upgrade_button", {
			"title": title_text,
			"desc": desc_text,
			"cost": cost,
			"need": "" if affordable else LocalizationManager.tr_key("hud.need_gold")
		})
		btn.set_meta("upgrade_id", str(option.get("id", "")))
		btn.set_meta("upgrade_cost", cost)


func hide_upgrade_options() -> void:
	_upgrade_panel.visible = false
	_show_modal_backdrop(false)


func show_start_weapon_pick(options: Array[Dictionary]) -> void:
	_weapon_mode = "start"
	_show_modal_backdrop(true)
	_weapon_panel.visible = true
	_weapon_title_label.text = LocalizationManager.tr_key("weapon.pick_start_title")
	_weapon_tip_label.text = LocalizationManager.tr_key("weapon.pick_start_tip")
	_fill_weapon_buttons(options, false, 0, 0)


func show_weapon_shop(options: Array[Dictionary], current_gold: int, capacity_left: int, completed_wave: int = 0) -> void:
	_weapon_mode = "shop"
	_show_modal_backdrop(true)
	_weapon_panel.visible = true
	if completed_wave > 0:
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title_wave", {"wave": completed_wave})
	else:
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title")
	_weapon_tip_label.text = LocalizationManager.tr_key("weapon.shop_tip", {"gold": current_gold, "capacity": capacity_left})
	_fill_weapon_buttons(options, true, current_gold, capacity_left)


func hide_weapon_panel() -> void:
	_weapon_mode = ""
	_weapon_panel.visible = false
	_show_modal_backdrop(false)


func show_game_over(wave: int, kills: int, survival_time: float) -> void:
	# 游戏结束后仅显示 UI，不直接切场，便于玩家选择后续操作。
	var save_data := SaveManager.load_game()
	var best_wave := int(save_data.get("best_wave", 0))
	var best_time := float(save_data.get("best_survival_time", 0.0))
	var wave_flag := LocalizationManager.tr_key("hud.new_record") if wave >= best_wave else ""
	var time_flag := LocalizationManager.tr_key("hud.new_record") if survival_time >= best_time else ""
	game_over_text.text = LocalizationManager.tr_key("hud.game_over", {
		"wave": wave,
		"wave_flag": wave_flag,
		"kills": kills,
		"time": "%.1f" % survival_time,
		"time_flag": time_flag
	})
	_show_modal_backdrop(true)
	game_over_panel.visible = true


func _on_retry_pressed() -> void:
	AudioManager.play_button()
	get_tree().current_scene.restart_game()


func _on_menu_pressed() -> void:
	AudioManager.play_button()
	get_tree().current_scene.go_main_menu()


func _build_runtime_ui() -> void:
	# HUD 运行时扩展层：避免频繁改动 tscn 布局文件。
	var root := $Root
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_modal_backdrop.color = VisualAssetRegistry.get_color("ui.modal_backdrop", Color(0.08, 0.09, 0.11, 1.0))
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_modal_backdrop)
	_currency_label = Label.new()
	_currency_label.position = Vector2(900, 12)
	root.add_child(_currency_label)

	_intermission_label = Label.new()
	_intermission_label.position = Vector2(12, 82)
	_intermission_label.text = "Next Wave: 0.0s"
	root.add_child(_intermission_label)

	_wave_countdown_label = Label.new()
	_wave_countdown_label.anchors_preset = Control.PRESET_TOP_WIDE
	_wave_countdown_label.anchor_left = 0.5
	_wave_countdown_label.anchor_right = 0.5
	_wave_countdown_label.offset_left = -60
	_wave_countdown_label.offset_right = 60
	_wave_countdown_label.offset_top = 14
	_wave_countdown_label.offset_bottom = 36
	_wave_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_countdown_label.text = ""
	_wave_countdown_label.visible = false
	root.add_child(_wave_countdown_label)

	_wave_banner = Label.new()
	_wave_banner.anchors_preset = Control.PRESET_CENTER_TOP
	_wave_banner.anchor_left = 0.5
	_wave_banner.anchor_right = 0.5
	_wave_banner.offset_left = -90
	_wave_banner.offset_right = 90
	_wave_banner.offset_top = 80
	_wave_banner.offset_bottom = 120
	_wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_banner.text = "WAVE 1"
	root.add_child(_wave_banner)

	_upgrade_panel = Panel.new()
	_upgrade_panel.anchors_preset = Control.PRESET_FULL_RECT
	_upgrade_panel.offset_left = 0
	_upgrade_panel.offset_top = 0
	_upgrade_panel.offset_right = 0
	_upgrade_panel.offset_bottom = 0
	_upgrade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_modal_panel_style(_upgrade_panel)
	root.add_child(_upgrade_panel)

	_add_opaque_backdrop_to_panel(_upgrade_panel)

	var box := VBoxContainer.new()
	box.anchors_preset = Control.PRESET_FULL_RECT
	box.offset_left = 14
	box.offset_top = 24
	box.offset_right = -14
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 14)
	_upgrade_panel.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Choose Upgrade"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_upgrade_title_label = title
	var tip := Label.new()
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = ""
	box.add_child(tip)
	_upgrade_tip_label = tip

	var upgrade_row := HBoxContainer.new()
	upgrade_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrade_row.add_theme_constant_override("separation", 16)
	box.add_child(upgrade_row)

	for i in range(3):
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(280, 260)
		card.add_theme_constant_override("separation", 8)
		upgrade_row.add_child(card)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(96, 96)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(icon)
		_upgrade_icons.append(icon)
		var btn := Button.new()
		btn.text = "Upgrade"
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 140)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_upgrade_button_pressed.bind(btn))
		card.add_child(btn)
		_upgrade_buttons.append(btn)

	_weapon_panel = Panel.new()
	_weapon_panel.anchors_preset = Control.PRESET_FULL_RECT
	_weapon_panel.offset_left = 0
	_weapon_panel.offset_top = 0
	_weapon_panel.offset_right = 0
	_weapon_panel.offset_bottom = 0
	_weapon_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_modal_panel_style(_weapon_panel)
	root.add_child(_weapon_panel)

	_add_opaque_backdrop_to_panel(_weapon_panel)

	var weapon_box := VBoxContainer.new()
	weapon_box.anchors_preset = Control.PRESET_FULL_RECT
	weapon_box.offset_left = 14
	weapon_box.offset_top = 24
	weapon_box.offset_right = -14
	weapon_box.offset_bottom = -24
	weapon_box.add_theme_constant_override("separation", 14)
	_weapon_panel.add_child(weapon_box)

	var weapon_title := Label.new()
	weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_title.text = "Weapon"
	weapon_title.add_theme_font_size_override("font_size", 20)
	weapon_box.add_child(weapon_title)
	_weapon_title_label = weapon_title

	var weapon_tip := Label.new()
	weapon_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_tip.text = ""
	weapon_box.add_child(weapon_tip)
	_weapon_tip_label = weapon_tip

	var weapon_row := HBoxContainer.new()
	weapon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_row.add_theme_constant_override("separation", 16)
	weapon_box.add_child(weapon_row)

	for i in range(4):
		var weapon_card := VBoxContainer.new()
		weapon_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_card.custom_minimum_size = Vector2(280, 280)
		weapon_card.add_theme_constant_override("separation", 8)
		weapon_row.add_child(weapon_card)
		var weapon_icon := TextureRect.new()
		weapon_icon.custom_minimum_size = Vector2(96, 96)
		weapon_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		weapon_card.add_child(weapon_icon)
		_weapon_icons.append(weapon_icon)
		var weapon_btn := Button.new()
		weapon_btn.text = "WeaponOption"
		weapon_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		weapon_btn.custom_minimum_size = Vector2(0, 160)
		weapon_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		weapon_btn.pressed.connect(_on_weapon_button_pressed.bind(weapon_btn))
		weapon_card.add_child(weapon_btn)
		_weapon_buttons.append(weapon_btn)

	_apply_modal_panel_style(game_over_panel)
	_add_opaque_backdrop_to_panel(game_over_panel)


func _setup_touch_controls() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	var root := $Root
	_touch_panel = Control.new()
	_touch_panel.anchors_preset = Control.PRESET_FULL_RECT
	# 仅作为触控按钮容器，不能吞掉整个 HUD 的鼠标事件。
	_touch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_touch_panel)

	var mk_button := func(txt: String, pos: Vector2, key: String) -> void:
		var b := Button.new()
		b.text = txt
		b.position = pos
		b.custom_minimum_size = Vector2(52, 52)
		b.pressed.connect(func() -> void:
			_move_state[key] = true
			_emit_mobile_move()
		)
		b.released.connect(func() -> void:
			_move_state[key] = false
			_emit_mobile_move()
		)
		_touch_panel.add_child(b)

	mk_button.call("L", Vector2(70, 620), "left")
	mk_button.call("R", Vector2(170, 620), "right")
	mk_button.call("U", Vector2(120, 570), "up")
	mk_button.call("D", Vector2(120, 670), "down")

	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.position = Vector2(1120, 620)
	pause_btn.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	root.add_child(pause_btn)
	_pause_touch_btn = pause_btn


func _emit_mobile_move() -> void:
	var x := int(_move_state["right"]) - int(_move_state["left"])
	var y := int(_move_state["down"]) - int(_move_state["up"])
	var direction := Vector2(x, y).normalized()
	emit_signal("mobile_move_changed", direction)


func _on_upgrade_button_pressed(btn: Button) -> void:
	if not btn.has_meta("upgrade_id"):
		return
	if btn.disabled:
		return
	var upgrade_id := str(btn.get_meta("upgrade_id"))
	emit_signal("upgrade_selected", upgrade_id)


func _on_weapon_button_pressed(btn: Button) -> void:
	if not btn.has_meta("weapon_id"):
		return
	if btn.disabled:
		return
	var weapon_id := str(btn.get_meta("weapon_id"))
	if _weapon_mode == "start":
		emit_signal("start_weapon_selected", weapon_id)
	elif _weapon_mode == "shop":
		emit_signal("weapon_shop_selected", weapon_id)


func _apply_localized_static_texts() -> void:
	pause_hint.text = LocalizationManager.tr_key("hud.pause_hint")
	retry_btn.text = LocalizationManager.tr_key("hud.retry")
	menu_btn.text = LocalizationManager.tr_key("hud.back_to_menu")
	if _upgrade_title_label:
		_upgrade_title_label.text = LocalizationManager.tr_key("hud.upgrade_title")
	if _upgrade_tip_label:
		_upgrade_tip_label.text = LocalizationManager.tr_key("hud.upgrade_tip", {"gold": _last_currency})
	if _weapon_title_label and _weapon_mode == "":
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title")
	if _pause_touch_btn:
		_pause_touch_btn.text = LocalizationManager.tr_key("hud.pause_button")


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_static_texts()
	set_health(_last_health_current, _last_health_max)
	set_wave(_last_wave)
	set_kills(_last_kills)
	set_survival_time(_last_time)
	set_currency(_last_currency)


func _fill_weapon_buttons(options: Array[Dictionary], is_shop: bool, current_gold: int, capacity_left: int) -> void:
	var button_index := 0
	for option in options:
		if button_index >= _weapon_buttons.size():
			break
		var btn := _weapon_buttons[button_index]
		btn.visible = true
		var weapon_id := str(option.get("id", ""))
		var icon_key := "weapon.icon." + weapon_id
		var fallback_icon := func() -> Texture2D:
			return VisualAssetRegistry.make_color_texture(icon_key, option.get("color", Color(0.8, 0.8, 0.8, 1.0)), Vector2i(96, 96))
		_weapon_icons[button_index].texture = VisualAssetRegistry.get_texture(icon_key, fallback_icon)
		_weapon_icons[button_index].visible = true
		var cost := int(option.get("cost", 0))
		var can_buy := true
		if is_shop:
			can_buy = current_gold >= cost and capacity_left > 0
		btn.disabled = not can_buy
		var title_text := LocalizationManager.tr_key(str(option.get("name_key", "weapon.unknown.name")))
		var stats_text := _build_weapon_stats_text(option)
		if is_shop:
			btn.text = LocalizationManager.tr_key("weapon.shop_button", {
				"name": title_text,
				"stats": stats_text,
				"cost": cost,
				"status": "" if can_buy else LocalizationManager.tr_key("weapon.shop_not_affordable")
			})
		else:
			btn.text = LocalizationManager.tr_key("weapon.start_button", {
				"name": title_text,
				"stats": stats_text
			})
		btn.set_meta("weapon_id", weapon_id)
		button_index += 1

	if is_shop and button_index < _weapon_buttons.size():
		var skip_btn := _weapon_buttons[button_index]
		skip_btn.visible = true
		skip_btn.disabled = false
		skip_btn.text = LocalizationManager.tr_key("weapon.shop_skip")
		skip_btn.set_meta("weapon_id", "skip")
		_weapon_icons[button_index].texture = VisualAssetRegistry.make_color_texture("weapon.icon.skip", Color(0.45, 0.45, 0.45, 1.0), Vector2i(96, 96))
		_weapon_icons[button_index].visible = true
		button_index += 1

	for i in range(button_index, _weapon_buttons.size()):
		_weapon_buttons[i].visible = false
		_weapon_icons[i].visible = false


func _apply_modal_panel_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = VisualAssetRegistry.get_color("ui.modal_panel_bg", Color(0.16, 0.17, 0.20, 1.0))
	style.border_color = VisualAssetRegistry.get_color("ui.modal_panel_border", Color(0.82, 0.84, 0.90, 1.0))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)


func _add_opaque_backdrop_to_panel(panel: Control) -> void:
	# 为操作面板添加全屏不透明背景色，确保遮住下层游戏画面
	var backdrop := ColorRect.new()
	backdrop.name = "OpaqueBackdrop"
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.offset_left = 0
	backdrop.offset_top = 0
	backdrop.offset_right = 0
	backdrop.offset_bottom = 0
	backdrop.color = VisualAssetRegistry.get_color("ui.modal_backdrop", Color(0.08, 0.09, 0.11, 1.0))
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(backdrop)
	panel.move_child(backdrop, 0)


func _show_modal_backdrop(backdrop_visible: bool) -> void:
	if not _modal_backdrop:
		return
	_modal_backdrop.visible = backdrop_visible


func _build_weapon_stats_text(option: Dictionary) -> String:
	var stats: Dictionary = option.get("stats", {})
	var lines: Array[String] = []
	lines.append(LocalizationManager.tr_key("weapon.stat.damage", {"value": int(stats.get("damage", 0))}))
	lines.append(LocalizationManager.tr_key("weapon.stat.cooldown", {"value": "%.2f" % float(stats.get("cooldown", 0.0))}))
	if str(option.get("type", "")) == "melee":
		lines.append(LocalizationManager.tr_key("weapon.stat.range", {"value": "%.0f" % float(stats.get("range", 0.0))}))
	else:
		lines.append(LocalizationManager.tr_key("weapon.stat.bullet_speed", {"value": "%.0f" % float(stats.get("bullet_speed", 0.0))}))
		lines.append(LocalizationManager.tr_key("weapon.stat.pellet_count", {"value": int(stats.get("pellet_count", 1))}))
		lines.append(LocalizationManager.tr_key("weapon.stat.spread", {"value": "%.1f" % float(stats.get("spread_degrees", 0.0))}))
		lines.append(LocalizationManager.tr_key("weapon.stat.pierce", {"value": int(stats.get("bullet_pierce", 0))}))
	return "\n".join(lines)
