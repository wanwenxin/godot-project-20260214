extends CanvasLayer

# HUD 与结算层：
# - 战斗中显示 HP/波次/击杀/时间/金币
# - 升级三选一、武器商店、开局武器选择（运行时构建）
# - 触控虚拟按键（移动 + 暂停）
signal upgrade_selected(upgrade_id: String)
signal upgrade_refresh_requested  # 玩家点击刷新，消耗金币重新随机 4 项
signal start_weapon_selected(weapon_id: String)
signal weapon_shop_selected(weapon_id: String)
signal weapon_shop_refresh_requested  # 商店刷新
signal weapon_shop_closed  # 下一波，关闭商店
signal mobile_move_changed(direction: Vector2)
signal pause_pressed

@onready var health_label: Label = $Root/TopRow/HealthBox/HealthLabel
@onready var exp_bar: ProgressBar = $Root/TopRow/HealthBox/ExpBar
@onready var level_label: Label = $Root/TopRow/HealthBox/LevelLabel
@onready var wave_label: Label = $Root/TopRow/WaveLabel
@onready var kill_label: Label = $Root/TopRow/KillLabel
@onready var timer_label: Label = $Root/TopRow/TimerLabel
@onready var pause_hint: Label = $Root/PauseHint

var _intermission_label: Label  # 波次间隔倒计时
var _wave_countdown_label: Label  # 波次剩余时间（正上方）
var _currency_label: Label  # 金币
var _wave_banner: Label  # 波次横幅（淡出动画）
var _upgrade_panel: Panel  # 升级三选一面板
var _upgrade_title_label: Label
var _upgrade_tip_label: Label
var _upgrade_buttons: Array[Button] = []
var _upgrade_icons: Array[TextureRect] = []
var _upgrade_refresh_btn: Button  # 刷新按钮
var _weapon_panel: Panel  # 武器商店/开局选择面板
var _weapon_title_label: Label
var _weapon_tip_label: Label
var _weapon_buttons: Array[Button] = []
var _weapon_icons: Array[TextureRect] = []
var _shop_refresh_btn: Button
var _shop_next_btn: Button
var _modal_backdrop: ColorRect  # 全屏遮罩，升级/商店时显示
var _weapon_mode := ""  # "start" 或 "shop"，区分开局选择与波次商店
var _touch_panel: Control  # 触控按钮容器
var _pause_touch_btn: Button  # 触控暂停按钮
# 触控方向状态字典，组合成归一化向量后回传给 Player。
var _move_state := {
	"left": false,
	"right": false,
	"up": false,
	"down": false
}
var _last_health_current := 0  # 语言切换时重绘用
var _last_health_max := 0
var _last_exp_current := 0
var _last_exp_threshold := 50
var _last_level := 1
var _last_wave := 1
var _last_kills := 0
var _last_time := 0.0
var _last_currency := 0


func _ready() -> void:
	LocalizationManager.language_changed.connect(_on_language_changed)
	_build_runtime_ui()
	_setup_touch_controls()
	_apply_localized_static_texts()
	set_health(0, 0)
	set_wave(1)
	set_kills(0)
	set_survival_time(0.0)
	set_currency(0)
	set_experience(0, GameManager.get_level_up_threshold())
	set_level(GameManager.run_level)
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


func set_experience(current: int, threshold: int) -> void:
	_last_exp_current = current
	_last_exp_threshold = maxi(threshold, 1)
	if exp_bar:
		exp_bar.min_value = 0.0
		exp_bar.max_value = float(_last_exp_threshold)
		exp_bar.value = float(current)


func set_level(level: int) -> void:
	_last_level = level
	if level_label:
		level_label.text = LocalizationManager.tr_key("hud.level", {"value": level})


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


func show_upgrade_options(options: Array[Dictionary], current_gold: int, refresh_cost: int = 2) -> void:
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
		btn.disabled = false  # 升级选择免费，不再因金币不足禁用
		var option: Dictionary = options[i]
		var title_text := LocalizationManager.tr_key(str(option.get("title_key", "upgrade.skip.title")))
		var desc_text := LocalizationManager.tr_key(str(option.get("desc_key", "upgrade.skip.desc")))
		var reward_text := str(option.get("reward_text", ""))
		var icon_path := str(option.get("icon_path", ""))
		var tex: Texture2D = null
		if icon_path != "" and ResourceLoader.exists(icon_path):
			tex = load(icon_path) as Texture2D
		if tex == null:
			tex = VisualAssetRegistry.make_color_texture(Color(0.68, 0.68, 0.74, 1.0), Vector2i(96, 96))
		_upgrade_icons[i].texture = tex
		_upgrade_icons[i].visible = true
		btn.text = LocalizationManager.tr_key("hud.upgrade_button_free", {
			"title": title_text,
			"desc": desc_text,
			"reward": reward_text
		})
		btn.set_meta("upgrade_id", str(option.get("id", "")))
		btn.set_meta("upgrade_value", option.get("reward_value"))
	if _upgrade_refresh_btn:
		_upgrade_refresh_btn.visible = true
		_upgrade_refresh_btn.disabled = current_gold < refresh_cost
		_upgrade_refresh_btn.text = LocalizationManager.tr_key("hud.upgrade_refresh", {"cost": refresh_cost})


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
	if _shop_refresh_btn:
		_shop_refresh_btn.visible = false
	if _shop_next_btn:
		_shop_next_btn.visible = false


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
	if _shop_refresh_btn:
		_shop_refresh_btn.visible = true
	if _shop_next_btn:
		_shop_next_btn.visible = true


func hide_weapon_panel() -> void:
	_weapon_mode = ""
	_weapon_panel.visible = false
	_show_modal_backdrop(false)


# 运行时构建：金币、间隔/波次倒计时、波次横幅、升级面板、武器面板、全屏遮罩。
func _build_runtime_ui() -> void:
	var root := $Root
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	_modal_backdrop.color = _get_ui_theme().modal_backdrop
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_modal_backdrop)
	# 置于最底层，避免遮挡结算/升级/商店等面板的按钮
	root.move_child(_modal_backdrop, 0)
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

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	_upgrade_panel.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

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

	for i in range(4):
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(180, 200)
		card.add_theme_constant_override("separation", 8)
		upgrade_row.add_child(card)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(icon)
		_upgrade_icons.append(icon)
		var btn := Button.new()
		btn.text = "Upgrade"
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 120)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_upgrade_button_pressed.bind(btn))
		card.add_child(btn)
		_upgrade_buttons.append(btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(100, 40)
	refresh_btn.pressed.connect(func() -> void: emit_signal("upgrade_refresh_requested"))
	btn_row.add_child(refresh_btn)
	_upgrade_refresh_btn = refresh_btn
	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(100, 40)
	skip_btn.pressed.connect(func() -> void: emit_signal("upgrade_selected", "skip"))
	btn_row.add_child(skip_btn)
	box.add_child(btn_row)

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

	var weapon_margin := MarginContainer.new()
	weapon_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	weapon_margin.add_theme_constant_override("margin_left", 0)
	weapon_margin.add_theme_constant_override("margin_top", 0)
	weapon_margin.add_theme_constant_override("margin_right", 0)
	weapon_margin.add_theme_constant_override("margin_bottom", 0)
	_weapon_panel.add_child(weapon_margin)
	var weapon_center := CenterContainer.new()
	weapon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_margin.add_child(weapon_center)
	var weapon_box := VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 14)
	weapon_center.add_child(weapon_box)

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
		weapon_card.custom_minimum_size = Vector2(200, 240)
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

	var shop_btn_row := HBoxContainer.new()
	shop_btn_row.add_theme_constant_override("separation", 12)
	var shop_refresh := Button.new()
	shop_refresh.text = "Refresh"
	shop_refresh.pressed.connect(func() -> void: emit_signal("weapon_shop_refresh_requested"))
	shop_btn_row.add_child(shop_refresh)
	_shop_refresh_btn = shop_refresh
	var shop_next := Button.new()
	shop_next.text = "Next Wave"
	shop_next.pressed.connect(func() -> void: emit_signal("weapon_shop_closed"))
	shop_btn_row.add_child(shop_next)
	_shop_next_btn = shop_next
	weapon_box.add_child(shop_btn_row)


# 触控设备下创建 L/R/U/D 移动键与暂停键，通过 mobile_move_changed 回传方向。
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
	set_experience(_last_exp_current, _last_exp_threshold)
	set_level(_last_level)
	set_wave(_last_wave)
	set_kills(_last_kills)
	set_survival_time(_last_time)
	set_currency(_last_currency)


# 填充商店/开局按钮：支持武器与道具；is_shop 时道具不检查槽位，武器检查 capacity_left。
func _fill_weapon_buttons(options: Array[Dictionary], is_shop: bool, current_gold: int, capacity_left: int) -> void:
	var button_index := 0
	for option in options:
		if button_index >= _weapon_buttons.size():
			break
		var btn := _weapon_buttons[button_index]
		btn.visible = true
		var item_id := str(option.get("id", ""))
		var item_type := str(option.get("type", "weapon"))
		var icon_path := str(option.get("icon_path", ""))
		var tex: Texture2D = null
		if icon_path != "" and ResourceLoader.exists(icon_path):
			tex = load(icon_path) as Texture2D
		if tex == null:
			tex = VisualAssetRegistry.make_color_texture(option.get("color", Color(0.8, 0.8, 0.8, 1.0)), Vector2i(96, 96))
		_weapon_icons[button_index].texture = tex
		_weapon_icons[button_index].visible = true
		var cost := int(option.get("cost", 0))
		var can_buy := true
		if is_shop:
			if item_type == "weapon":
				can_buy = current_gold >= cost and GameManager.can_add_run_weapon(item_id)
			else:
				can_buy = current_gold >= cost
		btn.disabled = not can_buy
		var title_text := LocalizationManager.tr_key(str(option.get("name_key", "weapon.unknown.name")))
		var stats_text: String
		if item_type == "attribute":
			stats_text = _build_item_stats_text(option)
		elif item_type == "magic":
			var def := MagicDefs.get_magic_by_id(item_id)
			stats_text = LocalizationManager.tr_key(str(option.get("desc_key", ""))) if def.is_empty() else "%d 伤害 · %d 魔力" % [def.get("power", 0), def.get("mana_cost", 0)]
		else:
			stats_text = _build_weapon_stats_text(option)
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
		btn.set_meta("weapon_id", item_id)
		btn.set_meta("item_type", item_type)
		btn.set_meta("option", option)
		button_index += 1

	for i in range(button_index, _weapon_buttons.size()):
		_weapon_buttons[i].visible = false
		_weapon_icons[i].visible = false


func _build_item_stats_text(option: Dictionary) -> String:
	var desc := LocalizationManager.tr_key(str(option.get("desc_key", "")))
	var val = option.get("base_value")
	if val is float:
		if option.get("attr", "") == "lifesteal_chance":
			return "%s +%.0f%%" % [desc, val * 100.0]
		return "%s +%.1f" % [desc, val]
	return "%s +%d" % [desc, int(val)]


func _apply_modal_panel_style(panel: Panel) -> void:
	var theme := _get_ui_theme()
	var style := StyleBoxFlat.new()
	style.bg_color = theme.modal_panel_bg
	style.border_color = theme.modal_panel_border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)


func _add_opaque_backdrop_to_panel(panel: Control, pass_input := false) -> void:
	# 为操作面板添加全屏不透明背景色，确保遮住下层游戏画面
	# pass_input=true 时使用 IGNORE，让点击穿透到下层按钮（如结算面板的重试/回主菜单）
	var backdrop := ColorRect.new()
	backdrop.name = "OpaqueBackdrop"
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.offset_left = 0
	backdrop.offset_top = 0
	backdrop.offset_right = 0
	backdrop.offset_bottom = 0
	backdrop.color = _get_ui_theme().modal_backdrop
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE if pass_input else Control.MOUSE_FILTER_STOP
	panel.add_child(backdrop)
	panel.move_child(backdrop, 0)


func _show_modal_backdrop(backdrop_visible: bool) -> void:
	if not _modal_backdrop:
		return
	_modal_backdrop.visible = backdrop_visible


func _get_ui_theme() -> UiThemeConfig:
	return UiThemeConfig.load_theme()


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
