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
signal backpack_requested  # 商店内请求打开背包（可选全屏入口）
signal backpack_sell_requested(weapon_index: int)  # 商店背包 Tab 内售卖武器
signal backpack_merge_completed  # 商店背包 Tab 内合并完成，需刷新
signal mobile_move_changed(direction: Vector2)
signal pause_pressed

@onready var health_bar: ProgressBar = $Root/TopRow/HealthBox/HealthBar
@onready var health_label: Label = $Root/TopRow/HealthBox/HealthLabel
@onready var exp_bar: ProgressBar = $Root/TopRow/HealthBox/ExpBar
@onready var mana_bar: ProgressBar = $Root/TopRow/HealthBox/ManaBar
@onready var mana_label: Label = $Root/TopRow/HealthBox/ManaLabel
@onready var level_label: Label = $Root/TopRow/HealthBox/LevelLabel
@onready var armor_label: Label = $Root/TopRow/HealthBox/ArmorLabel
@onready var wave_label: Label = $Root/TopRow/WaveLabel
@onready var kill_label: Label = $Root/TopRow/KillLabel
@onready var timer_label: Label = $Root/TopRow/TimerLabel
@onready var pause_hint: Label = $Root/PauseHint

var _wave_countdown_label: Label  # 波次倒计时（中上）：预生成/间隔时「第X波-X.Xs」，波次进行中「第X波-剩余Xs」
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
var _shop_refresh_btn: Button  # 商店 Tab 内刷新按钮
var _shop_backpack_panel: VBoxContainer  # 背包 Tab 内嵌 BackpackPanel
var _shop_next_btn: Button
var _shop_tab_container: TabContainer  # 商店/背包/角色信息 Tab
var _shop_stats_container: Control  # 角色信息 Tab 内容容器，用于刷新
var _last_shop_stats_hash: String = ""  # 脏检查：stats 未变时跳过角色信息 Tab 重建
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
var _last_mana_current := 0.0
var _last_mana_max := 1.0
var _last_armor := 0
var _magic_panel: PanelContainer  # 左下角魔法面板
# 魔法冷却节流：remaining_cd 变化阈值（秒），低于此值不更新冷却遮罩
const MAGIC_CD_UPDATE_THRESHOLD := 0.05
var _last_magic_cd_per_slot: Array[float] = []  # 每槽上次显示的 remaining_cd
var _last_magic_current_index := -1  # 上次当前选中槽索引，用于切换时立即更新边框
var _magic_slots: Array = []  # 每项 {panel, icon, cd_overlay, name_label, affix_label}

const HUD_FONT_SIZE := 18  # 统一基准字号，便于阅读
const MAGIC_SLOT_SIZE := 72  # 魔法槽图标尺寸（放大便于阅读）
const MAGIC_SLOT_EXTRA_HEIGHT := 36  # 名称+词条区域高度


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
	set_mana(0, 1)
	set_armor(0)
	_wave_banner.visible = false
	_upgrade_panel.visible = false
	_weapon_panel.visible = false
	_modal_backdrop.visible = false
	_apply_hud_font_sizes()
	_apply_hud_module_backgrounds()


func _apply_hud_module_backgrounds() -> void:
	# TopRow 用 PanelContainer 包裹，半透明背景
	var top_row := $Root/TopRow
	var top_parent := top_row.get_parent()
	var idx := top_row.get_index()
	var top_panel := PanelContainer.new()
	top_panel.name = "TopRowPanel"
	top_panel.offset_left = 12
	top_panel.offset_top = 12
	top_panel.offset_right = 860
	top_panel.offset_bottom = 72
	top_panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	top_row.reparent(top_panel)  # 重父到新 Panel，不可用 reparent(null)
	top_parent.add_child(top_panel)
	top_parent.move_child(top_panel, idx)
	# 金币、波次倒计时、波次横幅、按键提示各自用 Panel 包裹（间隔倒计时已合并至中上）
	_wrap_label_in_panel(_currency_label, Vector2(900, 12), Vector2(120, 24))
	_wrap_label_in_panel(pause_hint, Vector2(12, 52), Vector2(248, 90))
	# _wave_countdown_label 和 _wave_banner 使用锚点，需单独处理
	_wrap_anchored_label_in_panel(_wave_countdown_label)
	_wrap_anchored_label_in_panel(_wave_banner)


func _make_hud_panel_style() -> StyleBox:
	var tex := VisualAssetRegistry.make_panel_frame_texture(
		Vector2i(48, 48),
		Color(0.08, 0.09, 0.12, 0.85),
		Color(0.25, 0.26, 0.30, 0.9),
		2,
		6
	)
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.expand_margin_left = 6
	style.expand_margin_right = 6
	style.expand_margin_top = 6
	style.expand_margin_bottom = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _make_magic_slot_style(is_current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.bg_color = Color(0.15, 0.16, 0.2, 0.9)
	style.border_color = Color(0.22, 0.84, 0.37, 1.0) if is_current else Color(0.35, 0.37, 0.42, 0.9)
	style.set_border_width_all(2 if is_current else 1)
	return style


func _wrap_label_in_panel(lbl: Label, pos: Vector2, min_size: Vector2) -> void:
	if lbl == null:
		return
	var parent := lbl.get_parent()
	var idx := lbl.get_index()
	var panel := PanelContainer.new()
	panel.offset_left = pos.x
	panel.offset_top = pos.y
	panel.offset_right = pos.x + min_size.x
	panel.offset_bottom = pos.y + min_size.y
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	lbl.reparent(panel)  # 重父到新 Panel，不可用 reparent(null)
	parent.add_child(panel)
	parent.move_child(panel, idx)


func _wrap_anchored_label_in_panel(lbl: Label) -> void:
	if lbl == null:
		return
	var parent := lbl.get_parent()
	var idx := lbl.get_index()
	var panel := PanelContainer.new()
	panel.anchors_preset = lbl.anchors_preset
	panel.anchor_left = lbl.anchor_left
	panel.anchor_right = lbl.anchor_right
	panel.anchor_top = lbl.anchor_top
	panel.anchor_bottom = lbl.anchor_bottom
	panel.offset_left = lbl.offset_left
	panel.offset_right = lbl.offset_right
	panel.offset_top = lbl.offset_top
	panel.offset_bottom = lbl.offset_bottom
	panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	lbl.reparent(panel)  # 重父到新 Panel，不可用 reparent(null)
	parent.add_child(panel)
	parent.move_child(panel, idx)


func _apply_hud_font_sizes() -> void:
	for lbl in [health_label, mana_label, level_label, armor_label, wave_label, kill_label, timer_label, pause_hint]:
		if lbl is Label:
			lbl.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	if _currency_label:
		_currency_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	if _wave_countdown_label:
		_wave_countdown_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)


func set_health(current: int, max_value: int) -> void:
	# 脏检查：值未变则跳过，减少每帧 StyleBox 重建与 Label 赋值
	if current == _last_health_current and max_value == _last_health_max:
		return
	_last_health_current = current
	_last_health_max = max_value
	if health_bar:
		health_bar.min_value = 0.0
		health_bar.max_value = float(maxi(max_value, 1))
		health_bar.value = float(current)
		# 分段颜色：100%-50% 绿，50%-20% 橘黄，≤20% 红
		var ratio := float(current) / float(maxi(max_value, 1))
		var fill_color: Color
		if ratio > 0.5:
			fill_color = Color(0.29, 0.87, 0.5)  # #4ade80 绿
		elif ratio > 0.2:
			fill_color = Color(0.98, 0.58, 0.24)  # #fb923c 橘黄
		else:
			fill_color = Color(0.94, 0.27, 0.27)  # #ef4444 红
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.set_corner_radius_all(2)
		health_bar.add_theme_stylebox_override("fill", fill_style)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.22, 0.25, 0.32)  # #374151 空白/损失部分
		bg_style.set_corner_radius_all(2)
		health_bar.add_theme_stylebox_override("background", bg_style)
	health_label.text = "%d/%d" % [current, max_value]


func set_wave(value: int) -> void:
	if value == _last_wave:
		return
	_last_wave = value
	wave_label.text = LocalizationManager.tr_key("hud.wave", {"value": value})


func set_kills(value: int) -> void:
	if value == _last_kills:
		return
	_last_kills = value
	kill_label.text = LocalizationManager.tr_key("hud.kills", {"value": value})


func set_survival_time(value: float) -> void:
	if is_equal_approx(value, _last_time):
		return
	_last_time = value
	timer_label.text = LocalizationManager.tr_key("hud.time", {"value": "%.1f" % value})


func set_pause_hint(show_hint: bool) -> void:
	pause_hint.visible = show_hint


func set_currency(value: int) -> void:
	if value == _last_currency:
		return
	_last_currency = value
	_currency_label.text = LocalizationManager.tr_key("hud.gold", {"value": value})


func set_experience(current: int, threshold: int) -> void:
	var th := maxi(threshold, 1)
	if current == _last_exp_current and th == _last_exp_threshold:
		return
	_last_exp_current = current
	_last_exp_threshold = th
	if exp_bar:
		exp_bar.min_value = 0.0
		exp_bar.max_value = float(_last_exp_threshold)
		exp_bar.value = float(current)


func set_level(level: int) -> void:
	if level == _last_level:
		return
	_last_level = level
	if level_label:
		level_label.text = LocalizationManager.tr_key("hud.level", {"value": level})


func set_mana(current: float, max_value: float) -> void:
	var max_val := maxf(max_value, 1.0)
	# 脏检查：魔力变化频率低，值未变则跳过
	if is_equal_approx(current, _last_mana_current) and is_equal_approx(max_val, _last_mana_max):
		return
	_last_mana_current = current
	_last_mana_max = max_val
	if mana_bar:
		mana_bar.min_value = 0.0
		mana_bar.max_value = _last_mana_max
		mana_bar.value = current
		# 魔力条固定深蓝 #1e40af
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.12, 0.25, 0.69)  # #1e40af 深蓝
		fill_style.set_corner_radius_all(2)
		mana_bar.add_theme_stylebox_override("fill", fill_style)
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.22, 0.25, 0.32)
		bg_style.set_corner_radius_all(2)
		mana_bar.add_theme_stylebox_override("background", bg_style)
	if mana_label:
		mana_label.text = "%d/%d" % [int(current), int(_last_mana_max)]


func set_armor(value: int) -> void:
	if value == _last_armor:
		return
	_last_armor = value
	if armor_label:
		armor_label.text = LocalizationManager.tr_key("hud.armor", {"value": value})


## 更新左下角魔法面板：magic_data 为 get_magic_ui_data() 返回的数组。
## 魔法冷却遮罩按 remaining_cd 变化阈值（0.05s）节流；is_current 变化时立即更新边框。
func set_magic_ui(magic_data: Array) -> void:
	if _magic_panel == null:
		return
	_magic_panel.visible = not magic_data.is_empty()
	var need_update := false
	var current_index := -1
	for idx in range(magic_data.size()):
		if magic_data[idx].get("is_current", false):
			current_index = idx
			break
	if current_index != _last_magic_current_index:
		need_update = true
		_last_magic_current_index = current_index
	if magic_data.size() != _last_magic_cd_per_slot.size():
		need_update = true
		_last_magic_cd_per_slot.resize(magic_data.size())
		_last_magic_cd_per_slot.fill(-1.0)
	if not need_update:
		for i in range(mini(_magic_slots.size(), magic_data.size())):
			var data: Dictionary = magic_data[i]
			var remaining: float = float(data.get("remaining_cd", 0.0))
			var last_cd: float = _last_magic_cd_per_slot[i] if i < _last_magic_cd_per_slot.size() else -1.0
			if abs(remaining - last_cd) > MAGIC_CD_UPDATE_THRESHOLD:
				need_update = true
				break
	if not need_update:
		return
	for i in range(_magic_slots.size()):
		var slot: Dictionary = _magic_slots[i]
		var panel: Panel = slot.panel
		var icon: TextureRect = slot.icon
		var cd_overlay: ColorRect = slot.cd_overlay
		var name_label: Label = slot.get("name_label")
		var affix_label: Label = slot.get("affix_label")
		if i >= magic_data.size():
			panel.visible = false
			continue
		panel.visible = true
		var data: Dictionary = magic_data[i]
		var is_current: bool = data.get("is_current", false)
		panel.add_theme_stylebox_override("panel", _make_magic_slot_style(is_current))
		var icon_path: String = str(data.get("icon_path", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path) as Texture2D
		else:
			icon.texture = VisualAssetRegistry.make_color_texture(Color(0.5, 0.5, 0.55, 1.0), Vector2i(32, 32))
		var remaining: float = float(data.get("remaining_cd", 0.0))
		var total: float = float(data.get("total_cd", 1.0))
		if total > 0.0 and remaining > 0.0:
			cd_overlay.visible = true
			var ratio: float = remaining / total
			cd_overlay.offset_bottom = 4 + (MAGIC_SLOT_SIZE - 8) * ratio
		else:
			cd_overlay.visible = false
		if name_label != null:
			name_label.text = LocalizationManager.tr_key(str(data.get("name_key", "")))
		if affix_label != null:
			var keys: Array = data.get("affix_name_keys", [])
			var parts: Array[String] = []
			for k in keys:
				parts.append(LocalizationManager.tr_key(str(k)))
			affix_label.text = " · ".join(parts)
		if i >= _last_magic_cd_per_slot.size():
			_last_magic_cd_per_slot.resize(i + 1)
			_last_magic_cd_per_slot.fill(-1.0)
		_last_magic_cd_per_slot[i] = remaining


var _last_wave_countdown := -1.0  # 波次倒计时脏检查缓存
var _pre_spawn_mode := false  # 是否处于预生成倒计时（与波次剩余区分）

## 预生成倒计时：地图刷新后、敌人生成前，中上显示「第 X 波 - X.Xs」。
func set_pre_spawn_countdown(wave: int, seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_pre_spawn_mode = false
		_wave_countdown_label.visible = false
		return
	_pre_spawn_mode = true
	_wave_countdown_label.visible = true
	_wave_countdown_label.text = LocalizationManager.tr_key("hud.wave_pre_spawn", {"wave": wave, "value": "%.1f" % seconds_left})


## 波次剩余倒计时：敌人生成后，中上显示「第 X 波 - 剩余 Xs」。
func set_wave_countdown(wave: int, seconds_left: float) -> void:
	if seconds_left <= 0.0:
		if _last_wave_countdown > 0.0:
			_last_wave_countdown = 0.0
			_wave_countdown_label.visible = false
		_pre_spawn_mode = false
		return
	if is_equal_approx(seconds_left, _last_wave_countdown) and not _pre_spawn_mode:
		return
	_pre_spawn_mode = false
	_last_wave_countdown = seconds_left
	_wave_countdown_label.visible = true
	_wave_countdown_label.text = LocalizationManager.tr_key("hud.wave_countdown", {"wave": wave, "value": "%.0f" % seconds_left})


## 为波次横幅与倒计时 Label 应用描边与字号，使更醒目。
func _apply_wave_label_effects(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 22)


func show_wave_banner(wave: int) -> void:
	_wave_banner.visible = true
	_wave_banner.text = LocalizationManager.tr_key("hud.wave_banner", {"wave": wave})
	_wave_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_wave_banner.scale = Vector2(1.2, 1.2)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_wave_banner, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	tween.tween_property(_wave_banner, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)
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
	_weapon_tip_label.text = "  " + LocalizationManager.tr_key("weapon.pick_start_tip")  # 首行缩进 2 格
	_fill_weapon_buttons(options, false, 0, 0)
	if _shop_tab_container:
		_shop_tab_container.set_tab_hidden(1, true)
		_shop_tab_container.set_tab_hidden(2, true)
	if _shop_refresh_btn:
		_shop_refresh_btn.visible = false
	if _shop_next_btn:
		_shop_next_btn.visible = false
	if _shop_tab_container:
		_shop_tab_container.current_tab = 0


func show_weapon_shop(options: Array[Dictionary], current_gold: int, capacity_left: int, completed_wave: int = 0, stats: Dictionary = {}) -> void:
	_weapon_mode = "shop"
	_show_modal_backdrop(true)
	_weapon_panel.visible = true
	if completed_wave > 0:
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title_wave", {"wave": completed_wave})
	else:
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title")
	_weapon_tip_label.text = "  " + LocalizationManager.tr_key("weapon.shop_tip", {"gold": current_gold, "capacity": capacity_left})  # 首行缩进 2 格
	_fill_weapon_buttons(options, true, current_gold, capacity_left)
	if _shop_tab_container:
		_shop_tab_container.set_tab_hidden(1, false)
		_shop_tab_container.set_tab_hidden(2, false)
	if _shop_refresh_btn:
		_shop_refresh_btn.visible = true
		_update_shop_refresh_btn(completed_wave)
	if _shop_next_btn:
		_shop_next_btn.visible = true
		_shop_next_btn.text = LocalizationManager.tr_key("weapon.shop_next_wave")
	if _shop_backpack_panel and _shop_backpack_panel.has_method("set_stats"):
		_shop_backpack_panel.set_stats(stats, true)
	_update_shop_stats_tab(stats)
	if _shop_tab_container:
		_shop_tab_container.current_tab = 0


func hide_weapon_panel() -> void:
	_weapon_mode = ""
	_weapon_panel.visible = false
	_show_modal_backdrop(false)


## 更新商店 Tab 内刷新按钮的文案与可用状态。
func _update_shop_refresh_btn(wave: int) -> void:
	if not _shop_refresh_btn:
		return
	var cost: int = GameManager.get_shop_refresh_cost(wave)
	var can_afford: bool = GameManager.run_currency >= cost
	_shop_refresh_btn.text = LocalizationManager.tr_key("shop.refresh_cost", {"cost": cost})
	_shop_refresh_btn.disabled = not can_afford


## 商店背包 Tab 内售卖/合并后刷新。由 game 在完成售卖或合并后调用。
func refresh_shop_backpack(stats: Dictionary) -> void:
	if _shop_backpack_panel and _shop_backpack_panel.has_method("set_stats"):
		_shop_backpack_panel.set_stats(stats, true)
	_update_shop_stats_tab(stats)


func _on_shop_backpack_sell_requested(weapon_index: int) -> void:
	emit_signal("backpack_sell_requested", weapon_index)


func _on_shop_backpack_merge_completed() -> void:
	emit_signal("backpack_merge_completed")


## 轻量哈希：stats 关键字段，用于角色信息 Tab 脏检查。
func _hash_shop_stats(stats: Dictionary) -> String:
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
	# 角色属性区也依赖 hp/armor 等
	var hp: String = "%d/%d" % [int(stats.get("hp_current", 0)), int(stats.get("hp_max", 0))]
	var extra: String = "%d|%d|%.0f" % [int(stats.get("max_mana", 0)), int(stats.get("armor", 0)), float(stats.get("speed", 0))]
	return "%d|%d|%d|%d|%s|%s|%s" % [w.size(), m.size(), i.size(), wave, "|".join(parts), hp, extra]


## 更新角色信息 Tab 内容。
func _update_shop_stats_tab(stats: Dictionary) -> void:
	if not _shop_stats_container:
		return
	var new_hash := _hash_shop_stats(stats)
	if new_hash == _last_shop_stats_hash:
		return
	_last_shop_stats_hash = new_hash
	for c in _shop_stats_container.get_children():
		c.queue_free()
	var block: Control = ResultPanelShared.build_player_stats_block(stats, null, null, null, null, true)
	_shop_stats_container.add_child(block)


# 运行时构建：金币、间隔/波次倒计时、波次横幅、升级面板、武器面板、全屏遮罩。
func _build_runtime_ui() -> void:
	var root := $Root
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.anchors_preset = Control.PRESET_FULL_RECT
	var backdrop_color: Color = _get_ui_theme().modal_backdrop
	backdrop_color.a = 1.0  # 强制不透明，避免半透明穿透
	_modal_backdrop.color = backdrop_color
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_modal_backdrop)
	# 置于最底层，避免遮挡结算/升级/商店等面板的按钮
	root.move_child(_modal_backdrop, 0)
	_currency_label = Label.new()
	_currency_label.position = Vector2(900, 12)
	root.add_child(_currency_label)

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
	_apply_wave_label_effects(_wave_countdown_label)
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
	_apply_wave_label_effects(_wave_banner)
	root.add_child(_wave_banner)

	# 魔法面板：左下角，横向排列最多 3 个魔法槽
	_magic_panel = PanelContainer.new()
	_magic_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_magic_panel.anchor_left = 0.0
	_magic_panel.anchor_top = 1.0
	_magic_panel.anchor_right = 0.0
	_magic_panel.anchor_bottom = 1.0
	_magic_panel.offset_left = 12
	_magic_panel.offset_top = -(MAGIC_SLOT_SIZE + MAGIC_SLOT_EXTRA_HEIGHT) - 24
	_magic_panel.offset_right = 12 + (MAGIC_SLOT_SIZE + 8) * 3 + 16
	_magic_panel.offset_bottom = -12
	_magic_panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	root.add_child(_magic_panel)
	var magic_row := HBoxContainer.new()
	magic_row.add_theme_constant_override("separation", 8)
	_magic_panel.add_child(magic_row)
	for i in range(3):
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(MAGIC_SLOT_SIZE + 8, MAGIC_SLOT_SIZE + MAGIC_SLOT_EXTRA_HEIGHT)
		slot_panel.add_theme_stylebox_override("panel", _make_magic_slot_style(false))
		magic_row.add_child(slot_panel)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		slot_panel.add_child(vbox)
		var icon_container := Control.new()
		icon_container.custom_minimum_size = Vector2(MAGIC_SLOT_SIZE, MAGIC_SLOT_SIZE)
		vbox.add_child(icon_container)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(icon)
		var cd_overlay := ColorRect.new()
		cd_overlay.anchor_left = 0.0
		cd_overlay.anchor_right = 1.0
		cd_overlay.anchor_top = 0.0
		cd_overlay.anchor_bottom = 0.0
		cd_overlay.offset_left = 4
		cd_overlay.offset_top = 4
		cd_overlay.offset_right = -4
		cd_overlay.offset_bottom = 4
		cd_overlay.color = Color(0, 0, 0, 0.6)
		cd_overlay.visible = false
		icon_container.add_child(cd_overlay)
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(name_label)
		var affix_label := Label.new()
		affix_label.add_theme_font_size_override("font_size", 10)
		affix_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		affix_label.clip_text = true
		affix_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(affix_label)
		_magic_slots.append({"panel": slot_panel, "icon": icon, "cd_overlay": cd_overlay, "name_label": name_label, "affix_label": affix_label})
	_magic_panel.visible = false

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
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_upgrade_title_label = title
	var tip := Label.new()
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = ""
	tip.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	box.add_child(tip)
	_upgrade_tip_label = tip

	var upgrade_row := HBoxContainer.new()
	upgrade_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrade_row.add_theme_constant_override("separation", 24)
	box.add_child(upgrade_row)

	for i in range(4):
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(160, 200)
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
		btn.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
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
	refresh_btn.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	refresh_btn.custom_minimum_size = Vector2(100, 40)
	refresh_btn.pressed.connect(func() -> void: emit_signal("upgrade_refresh_requested"))
	btn_row.add_child(refresh_btn)
	_upgrade_refresh_btn = refresh_btn
	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
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
	var shop_center := CenterContainer.new()
	shop_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_margin.add_child(shop_center)
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport_size := get_viewport().get_visible_rect().size
	main_vbox.custom_minimum_size = viewport_size * 0.7  # 设计 1280×720 下约 896×504
	shop_center.add_child(main_vbox)

	# TabContainer：商店 / 背包 / 角色信息，Tab 置于顶部
	_shop_tab_container = TabContainer.new()
	_shop_tab_container.tabs_position = TabContainer.TabPosition.POSITION_TOP
	_shop_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_tab_container.custom_minimum_size = Vector2(896, 400)  # 与 main_vbox 70% 一致，保证 Tab 内容区可见
	_shop_tab_container.add_theme_font_size_override("font_size", 20)  # Tab 标签字体放大
	_shop_tab_container.add_theme_constant_override("side_margin", 16)  # Tab 内容区左右间距
	_shop_tab_container.add_theme_constant_override("top_margin", 16)  # Tab 内容区顶部间距
	main_vbox.add_child(_shop_tab_container)

	# Tab 0 - 商店：武器选项 + 刷新按钮
	var shop_tab := VBoxContainer.new()
	shop_tab.add_theme_constant_override("separation", 14)
	var weapon_center := CenterContainer.new()
	weapon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_tab.add_child(weapon_center)
	var weapon_box := VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 14)
	weapon_center.add_child(weapon_box)

	var weapon_title := Label.new()
	weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_title.text = "Weapon"
	weapon_title.add_theme_font_size_override("font_size", 22)
	weapon_box.add_child(weapon_title)
	_weapon_title_label = weapon_title

	var weapon_tip := Label.new()
	weapon_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # 描述左对齐，首行缩进由文案前空格实现
	weapon_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_tip.text = ""
	weapon_tip.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	weapon_box.add_child(weapon_tip)
	_weapon_tip_label = weapon_tip

	var weapon_row := HBoxContainer.new()
	weapon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_row.add_theme_constant_override("separation", 24)
	weapon_box.add_child(weapon_row)

	for i in range(4):
		var weapon_card := VBoxContainer.new()
		weapon_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_card.custom_minimum_size = Vector2(180, 240)
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
		weapon_btn.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
		weapon_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		weapon_btn.custom_minimum_size = Vector2(0, 160)
		weapon_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		weapon_btn.pressed.connect(_on_weapon_button_pressed.bind(weapon_btn))
		weapon_card.add_child(weapon_btn)
		_weapon_buttons.append(weapon_btn)

	var shop_refresh := Button.new()
	shop_refresh.pressed.connect(func() -> void: emit_signal("weapon_shop_refresh_requested"))
	weapon_box.add_child(shop_refresh)
	_shop_refresh_btn = shop_refresh

	# Tab 1 - 背包：内嵌 BackpackPanel，shop_context=true 时显示售卖/合并
	var backpack_scroll := ScrollContainer.new()
	backpack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backpack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_shop_backpack_panel = (load("res://scripts/ui/backpack_panel.gd") as GDScript).new()
	_shop_backpack_panel.name = "ShopBackpackPanel"
	_shop_backpack_panel.add_theme_constant_override("separation", 12)
	_shop_backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_backpack_panel.sell_requested.connect(_on_shop_backpack_sell_requested)
	_shop_backpack_panel.merge_completed.connect(_on_shop_backpack_merge_completed)
	backpack_scroll.add_child(_shop_backpack_panel)

	# Tab 2 - 角色信息
	var stats_scroll := ScrollContainer.new()
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_shop_stats_container = VBoxContainer.new()
	_shop_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(_shop_stats_container)

	_shop_tab_container.add_child(shop_tab)
	_shop_tab_container.add_child(backpack_scroll)
	_shop_tab_container.add_child(stats_scroll)
	_shop_tab_container.set_tab_title(0, LocalizationManager.tr_key("shop.tab_shop"))
	_shop_tab_container.set_tab_title(1, LocalizationManager.tr_key("shop.tab_backpack"))
	_shop_tab_container.set_tab_title(2, LocalizationManager.tr_key("shop.tab_stats"))

	# 下一波按钮，始终在底部
	var shop_next := Button.new()
	shop_next.pressed.connect(func() -> void: emit_signal("weapon_shop_closed"))
	main_vbox.add_child(shop_next)
	_shop_next_btn = shop_next


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
	pause_hint.text = _build_key_hints_text()
	if _upgrade_title_label:
		_upgrade_title_label.text = LocalizationManager.tr_key("hud.upgrade_title")
	_apply_upgrade_weapon_tip_texts()


## 构建多行按键提示文本，供 HUD 左下角显示。
func _build_key_hints_text() -> String:
	return "\n".join([
		LocalizationManager.tr_key("pause.key_hint.move", {"keys": ResultPanelShared.action_to_text(["move_up", "move_down", "move_left", "move_right"])}),
		LocalizationManager.tr_key("pause.key_hint.pause", {"key": ResultPanelShared.action_to_text(["pause"])}),
		LocalizationManager.tr_key("pause.key_hint.camera_zoom", {"keys": ResultPanelShared.action_to_text(["camera_zoom_in", "camera_zoom_out"])}),
		LocalizationManager.tr_key("pause.key_hint.magic", {"keys": ResultPanelShared.action_to_text(["cast_magic", "magic_prev", "magic_next"])}),
		LocalizationManager.tr_key("pause.key_hint.enemy_hp", {"key": ResultPanelShared.action_to_text(["toggle_enemy_hp"])})
	])


func _apply_upgrade_weapon_tip_texts() -> void:
	if _upgrade_tip_label:
		_upgrade_tip_label.text = LocalizationManager.tr_key("hud.upgrade_tip", {"gold": _last_currency})
	if _weapon_title_label and _weapon_mode == "":
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title")
	if _pause_touch_btn:
		_pause_touch_btn.text = LocalizationManager.tr_key("hud.pause_button")
	if _shop_tab_container:
		_shop_tab_container.set_tab_title(0, LocalizationManager.tr_key("shop.tab_shop"))
		_shop_tab_container.set_tab_title(1, LocalizationManager.tr_key("shop.tab_backpack"))
		_shop_tab_container.set_tab_title(2, LocalizationManager.tr_key("shop.tab_stats"))
	if _shop_next_btn:
		_shop_next_btn.text = LocalizationManager.tr_key("weapon.shop_next_wave")


func _on_language_changed(_language_code: String) -> void:
	_apply_localized_static_texts()
	set_health(_last_health_current, _last_health_max)
	set_experience(_last_exp_current, _last_exp_threshold)
	set_level(_last_level)
	set_mana(_last_mana_current, _last_mana_max)
	set_armor(_last_armor)
	set_wave(_last_wave)
	set_kills(_last_kills)
	set_survival_time(_last_time)
	set_currency(_last_currency)


# 填充商店/开局按钮：支持武器与道具；is_shop 时道具不检查槽位，武器检查 capacity_left。
func _fill_weapon_buttons(options: Array[Dictionary], is_shop: bool, current_gold: int, _capacity_left: int) -> void:
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
			stats_text = _build_magic_shop_stats_text(item_id, option)
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


## 商店魔法卡片：威力、消耗、冷却 + 三类词条名称。
func _build_magic_shop_stats_text(item_id: String, option: Dictionary) -> String:
	var def := MagicDefs.get_magic_by_id(item_id)
	if def.is_empty():
		return LocalizationManager.tr_key(str(option.get("desc_key", "")))
	var parts: Array[String] = []
	parts.append("%s %d" % [LocalizationManager.tr_key("magic.stat_power"), int(def.get("power", 0))])
	parts.append("%s %d" % [LocalizationManager.tr_key("pause.stat_mana"), int(def.get("mana_cost", 0))])
	parts.append("%s %.1fs" % [LocalizationManager.tr_key("pause.stat_cooldown"), float(def.get("cooldown", 1.0))])
	for affix_id_key in ["range_affix_id", "effect_affix_id", "element_affix_id"]:
		var aid: String = str(def.get(affix_id_key, ""))
		if aid.is_empty():
			continue
		var affix_def := MagicAffixDefs.get_affix_def(aid)
		if not affix_def.is_empty():
			parts.append(LocalizationManager.tr_key(str(affix_def.get("name_key", ""))))
	return " · ".join(parts)


func _build_item_stats_text(option: Dictionary) -> String:
	var desc := LocalizationManager.tr_key(str(option.get("desc_key", "")))
	var val = option.get("base_value")
	if val is float:
		if option.get("attr", "") == "lifesteal_chance":
			return "%s +%.0f%%" % [desc, val * 100.0]
		return "%s +%.1f" % [desc, val]
	return "%s +%d" % [desc, int(val)]


func _apply_modal_panel_style(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", _get_ui_theme().get_modal_panel_stylebox())


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
	var bcolor: Color = _get_ui_theme().modal_backdrop
	bcolor.a = 1.0  # 强制不透明
	backdrop.color = bcolor
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
	var affix_ids: Array = option.get("random_affix_ids", [])
	if affix_ids.size() > 0:
		var affix_names: Array[String] = []
		for aid in affix_ids:
			var adef := WeaponAffixDefs.get_affix_def(str(aid))
			if not adef.is_empty():
				affix_names.append(LocalizationManager.tr_key(str(adef.get("name_key", aid))))
		if affix_names.size() > 0:
			lines.append(LocalizationManager.tr_key("backpack.tooltip_affixes") + ": " + ", ".join(affix_names))
	return "\n".join(lines)
