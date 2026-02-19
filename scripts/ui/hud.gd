extends CanvasLayer

# 战斗 HUD 与模态 UI 层：负责战斗中顶部状态、左下魔法槽、升级/商店/开局武器选择等界面。
# - 顶部：血量/魔力/护甲、波次、击杀数、生存时间、金币、预生成/波次倒计时、波次横幅、暂停按键提示
# - 左下：魔法槽（最多 3 个，图标+冷却遮罩+名称+词条），触控时显示虚拟移动键与暂停键
# - 模态：升级四选一面板（含刷新）、武器商店/开局选择面板（Tab：商店/背包/角色信息），全屏遮罩
# 运行时通过 _build_runtime_ui 创建金币/倒计时/横幅/升级/武器面板等节点，场景中仅保留 Root 与 TopRow 等基础结构。

# ---- 信号（由 game.gd 等连接） ----
signal upgrade_selected(upgrade_id: String)  # 玩家选择了某项升级或 skip
signal upgrade_refresh_requested  # 玩家点击刷新，消耗金币重新随机 4 项升级
signal start_weapon_selected(weapon_id: String)  # 开局武器选择完成
signal weapon_shop_selected(weapon_id: String)  # 商店内购买/选择武器或道具
signal weapon_shop_refresh_requested  # 商店 Tab 内点击刷新商品
signal weapon_shop_closed  # 点击「下一波」，关闭商店并进入下一波
signal backpack_requested  # 商店内请求打开背包（可选全屏入口）
signal backpack_sell_requested(weapon_index: int)  # 商店背包 Tab 内售卖指定索引武器
signal backpack_merge_completed  # 商店背包 Tab 内合并完成，需刷新背包与角色信息
signal mobile_move_changed(direction: Vector2)  # 触控移动键按下/抬起后，当前归一化方向
signal pause_pressed  # 触控暂停键按下

# ---- 场景节点引用（hud.tscn 中已存在） ----
@onready var health_bar: ProgressBar = $Root/TopRowPanel/TopRow/HealthBox/HPBlock/HealthBar
@onready var health_label: Label = $Root/TopRowPanel/TopRow/HealthBox/HPBlock/HealthLabel
@onready var mana_bar: ProgressBar = $Root/TopRowPanel/TopRow/HealthBox/MPBlock/ManaBar
@onready var mana_label: Label = $Root/TopRowPanel/TopRow/HealthBox/MPBlock/ManaLabel
@onready var wave_label: Label = $Root/TopRowPanel/TopRow/WaveLabel
@onready var kill_label: Label = $Root/TopRowPanel/TopRow/KillLabel
@onready var timer_label: Label = $Root/TopRowPanel/TopRow/TimerLabel
@onready var key_hints_label: Label = $Root/PauseHintPanel/PauseHint  # 按键提示标签
@onready var _modal_backdrop: ColorRect = $Root/ModalBackdrop
@onready var _currency_label: Label = $Root/CurrencyPanel/CurrencyLabel
@onready var _wave_countdown_label: Label = $Root/WaveCountdownPanel/WaveCountdownLabel
@onready var _wave_banner: Label = $Root/WaveBannerPanel/WaveBanner
@onready var _magic_panel: PanelContainer = $Root/MagicPanel
@onready var _upgrade_panel: Panel = $Root/UpgradePanel
@onready var _upgrade_title_label: Label = $Root/UpgradePanel/UpgradeMargin/CenterContainer/VBox/UpgradeTitleLabel
@onready var _upgrade_tip_label: Label = $Root/UpgradePanel/UpgradeMargin/CenterContainer/VBox/UpgradeTipLabel
@onready var _upgrade_refresh_btn: Button = $Root/UpgradePanel/UpgradeMargin/CenterContainer/VBox/BtnRow/UpgradeRefreshBtn
@onready var _weapon_panel: Panel = $Root/WeaponPanel
@onready var _weapon_title_label: Label = $Root/WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer/ShopTab/WeaponCenter/WeaponBox/WeaponTitleLabel
@onready var _weapon_tip_label: Label = $Root/WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer/ShopTab/WeaponCenter/WeaponBox/WeaponTipLabel
@onready var _shop_refresh_btn: Button = $Root/WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer/ShopTab/WeaponCenter/WeaponBox/ShopRefreshBtn
@onready var _shop_next_btn: Button = $Root/WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopNextBtn
@onready var _shop_tab_container: TabContainer = $Root/WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer
@onready var _shop_stats_container: Control = $Root/WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer/StatsScroll/ShopStatsContainer
@onready var _touch_panel: Control = $Root/TouchPanel
@onready var _pause_touch_btn: Button = $Root/PauseTouchBtn

# ---- 由场景节点组装的数组（_ready 中填充） ----
var _upgrade_buttons: Array[Button] = []
var _upgrade_icons: Array[TextureRect] = []
var _weapon_buttons: Array[Button] = []
var _weapon_icons: Array[TextureRect] = []
var _shop_backpack_panel: VBoxContainer  # 背包 Tab 内嵌的 BackpackPanel 实例，运行时加入 BackpackScroll
var _last_shop_stats_hash: String = ""
var _weapon_mode := ""
var _move_state := {  # 触控方向键按下状态，用于合成 mobile_move_changed 的 direction
	"left": false,
	"right": false,
	"up": false,
	"down": false
}

# ---- 脏检查缓存（避免每帧重复赋值与 StyleBox 重建；语言切换时用于重绘） ----
var _last_health_current := 0
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

# ---- 魔法面板 ----
const MAGIC_CD_UPDATE_THRESHOLD := 0.05  # 魔法冷却 remaining_cd 变化超过此值（秒）才刷新遮罩，节流
var _last_magic_cd_per_slot: Array[float] = []  # 每槽上次显示的 remaining_cd，用于节流
var _last_magic_current_index := -1  # 上次当前选中槽索引，切换时立即更新边框
var _magic_slots: Array = []  # 每项 {panel, icon, cd_overlay, name_label, affix_label}

# ---- 按键提示面板 ----
var _key_hints_expanded: bool = false  # 是否展开显示全部按键提示

# ---- 样式与布局常量 ----
const HUD_FONT_SIZE := 18  # 顶部标签统一字号
const MAGIC_SLOT_SIZE := 92  # 魔法槽图标区域边长（像素）
const MAGIC_SLOT_EXTRA_HEIGHT := 46  # 魔法槽名称+词条区域高度


## [系统] 节点入树时调用：应用样式、组装引用数组、连接信号、加入背包面板，初始化各 set_* 并控制显隐。
func _ready() -> void:
	LocalizationManager.language_changed.connect(_on_language_changed)
	_apply_runtime_styles_and_refs()
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


## [自定义] 为场景中已有的 TopRowPanel、CurrencyPanel、PauseHintPanel、WaveCountdownPanel、WaveBannerPanel 应用 HUD 面板样式（不创建新节点）。
func _apply_hud_module_backgrounds() -> void:
	var style := _make_hud_panel_style()
	$Root/TopRowPanel.add_theme_stylebox_override("panel", style)
	$Root/CurrencyPanel.add_theme_stylebox_override("panel", style)
	$Root/PauseHintPanel.add_theme_stylebox_override("panel", style)  # 保持场景节点名不变
	$Root/WaveCountdownPanel.add_theme_stylebox_override("panel", style)
	$Root/WaveBannerPanel.add_theme_stylebox_override("panel", style)


## [自定义] 返回 HUD 用 Panel 的 StyleBox（圆角边框+半透明背景），供 TopRow、金币等复用。
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


## [自定义] 返回魔法槽 Panel 的 StyleBox；is_current 时边框加粗并高亮绿色。
func _make_magic_slot_style(is_current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.bg_color = Color(0.15, 0.16, 0.2, 0.9)
	style.border_color = Color(0.22, 0.84, 0.37, 1.0) if is_current else Color(0.35, 0.37, 0.42, 0.9)
	style.set_border_width_all(2 if is_current else 1)
	return style


## [自定义] 为顶部各 Label 与金币/波次倒计时标签统一设置 HUD_FONT_SIZE。
func _apply_hud_font_sizes() -> void:
	for lbl in [health_label, mana_label, wave_label, kill_label, timer_label, key_hints_label]:
		if lbl is Label:
			lbl.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	if _currency_label:
		_currency_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	if _wave_countdown_label:
		_wave_countdown_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)


## [自定义] 应用运行时样式（遮罩色、面板样式）、组装升级/武器按钮与魔法槽数组、创建并加入背包面板、连接升级/武器按钮信号。
func _apply_runtime_styles_and_refs() -> void:
	var root := $Root
	var backdrop_color: Color = _get_ui_theme().modal_backdrop
	backdrop_color.a = 1.0
	_modal_backdrop.color = backdrop_color
	_magic_panel.add_theme_stylebox_override("panel", _make_hud_panel_style())
	_apply_modal_panel_style(_upgrade_panel)
	_add_opaque_backdrop_to_panel(_upgrade_panel)
	_apply_modal_panel_style(_weapon_panel)
	_add_opaque_backdrop_to_panel(_weapon_panel)
	# 升级：四个卡片按钮与图标
	for i in range(4):
		var card := root.get_node("UpgradePanel/UpgradeMargin/CenterContainer/VBox/UpgradeRow/Card%d" % i)
		_upgrade_icons.append(card.get_node("UpgradeIcon%d" % i))
		var btn: Button = card.get_node("UpgradeBtn%d" % i)
		btn.pressed.connect(_on_upgrade_button_pressed.bind(btn))
		_upgrade_buttons.append(btn)
	_upgrade_refresh_btn.pressed.connect(func() -> void: emit_signal("upgrade_refresh_requested"))
	# 武器：四个选项按钮与图标
	for i in range(4):
		var card := root.get_node("WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer/ShopTab/WeaponCenter/WeaponBox/WeaponRow/WeaponCard%d" % i)
		_weapon_icons.append(card.get_node("WeaponIcon%d" % i))
		var wbtn: Button = card.get_node("WeaponBtn%d" % i)
		wbtn.pressed.connect(_on_weapon_button_pressed.bind(wbtn))
		_weapon_buttons.append(wbtn)
	_shop_refresh_btn.pressed.connect(func() -> void: emit_signal("weapon_shop_refresh_requested"))
	_shop_next_btn.pressed.connect(func() -> void: emit_signal("weapon_shop_closed"))
	_shop_tab_container.set_tab_title(0, LocalizationManager.tr_key("shop.tab_shop"))
	_shop_tab_container.set_tab_title(1, LocalizationManager.tr_key("shop.tab_backpack"))
	_shop_tab_container.set_tab_title(2, LocalizationManager.tr_key("shop.tab_stats"))
	# 魔法槽：从场景 Slot0~5 组装 _magic_slots，支持最多 6 个槽位（由角色 usable_magic_count 决定实际显示数）
	for i in range(6):
		var slot := _magic_panel.get_node("MagicRow/Slot%d" % i)
		var vbox: VBoxContainer = slot.get_node("VBox")
		var icon_container: Control = vbox.get_node("IconContainer")
		_magic_slots.append({
			"panel": slot,
			"icon": icon_container.get_node("Icon"),
			"cd_overlay": icon_container.get_node("CdOverlay"),
			"name_label": vbox.get_node("NameLabel"),
			"affix_label": vbox.get_node("AffixLabel")
		})
	# 背包 Tab：运行时加入 BackpackPanel 场景实例
	var backpack_scroll: ScrollContainer = root.get_node("WeaponPanel/WeaponMargin/ShopCenter/MainVbox/ShopTabContainer/BackpackScroll")
	var packed: PackedScene = load("res://scenes/ui/backpack_panel.tscn") as PackedScene
	_shop_backpack_panel = packed.instantiate()
	if _shop_backpack_panel == null:
		push_error("HUD: 无法实例化 backpack_panel.tscn")
		return
	_shop_backpack_panel.name = "ShopBackpackPanel"
	_shop_backpack_panel.add_theme_constant_override("separation", 12)
	_shop_backpack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_backpack_panel.sell_requested.connect(_on_shop_backpack_sell_requested)
	_shop_backpack_panel.merge_completed.connect(_on_shop_backpack_merge_completed)
	backpack_scroll.add_child(_shop_backpack_panel)


## [自定义] 设置血量显示。脏检查：值未变则跳过；否则更新进度条与分段颜色（绿/橘黄/红）及 "当前/最大" 文本。
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


## [自定义] 设置当前波次显示。脏检查后更新 wave_label 的本地化文案。
func set_wave(value: int) -> void:
	if value == _last_wave:
		return
	_last_wave = value
	wave_label.text = LocalizationManager.tr_key("hud.wave", {"value": value})


## [自定义] 设置本局击杀数显示。脏检查后更新 kill_label 的本地化文案。
func set_kills(value: int) -> void:
	if value == _last_kills:
		return
	_last_kills = value
	kill_label.text = LocalizationManager.tr_key("hud.kills", {"value": value})


## [自定义] 设置生存时间显示（秒）。脏检查后更新 timer_label 的本地化文案。
func set_survival_time(value: float) -> void:
	if is_equal_approx(value, _last_time):
		return
	_last_time = value
	timer_label.text = LocalizationManager.tr_key("hud.time", {"value": "%.1f" % value})


## [自定义] 控制左下角暂停/按键提示的显隐（如进入商店后隐藏）。
func set_key_hints_visible(show_hint: bool) -> void:
	key_hints_label.visible = show_hint


## [自定义] 设置暂停提示文本的显隐，显示/隐藏左下角的暂停按键提示。
func set_pause_hint(visible: bool) -> void:
	if key_hints_label:
		key_hints_label.visible = visible


## [自定义] 设置金币显示。脏检查后更新 _currency_label 的本地化文案。
func set_currency(value: int) -> void:
	if value == _last_currency:
		return
	_last_currency = value
	_currency_label.text = LocalizationManager.tr_key("hud.gold", {"value": value})


## [自定义] 更新经验缓存（战斗 HUD 已无经验条，仅供语言切换时重绘与内部一致）。
func set_experience(current: int, threshold: int) -> void:
	# 战斗 HUD 已移除经验条，仅更新缓存供语言切换等使用
	var th := maxi(threshold, 1)
	if current == _last_exp_current and th == _last_exp_threshold:
		return
	_last_exp_current = current
	_last_exp_threshold = th


## [自定义] 更新等级缓存（战斗 HUD 已无等级展示，仅供语言切换等一致）。
func set_level(level: int) -> void:
	if level == _last_level:
		return
	_last_level = level
	# 战斗 HUD 已移除等级展示，仅保留缓存


## [自定义] 设置魔力条与魔力数值。脏检查后更新 mana_bar 的 fill/background 样式与 mana_label 文本。
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


## [自定义] 更新护甲缓存（战斗 HUD 已无护甲展示，仅供语言切换等一致）。
func set_armor(value: int) -> void:
	if value == _last_armor:
		return
	_last_armor = value
	# 战斗 HUD 已移除护甲展示，仅保留缓存


## [自定义] 更新左下角魔法面板：magic_data 为 Player.get_magic_ui_data() 返回的数组；刷新图标、冷却遮罩、名称与词条。冷却按 MAGIC_CD_UPDATE_THRESHOLD 节流，当前槽切换时立即更新边框。
func set_magic_ui(magic_data: Array) -> void:
	if _magic_panel == null:
		return
	# 魔法面板始终显示，无论是否有魔法
	_magic_panel.visible = true
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

## [自定义] 预生成倒计时：地图刷新后、敌人生成前，中上显示「第 X 波 - X.Xs」；seconds_left<=0 时隐藏。
func set_pre_spawn_countdown(wave: int, seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_pre_spawn_mode = false
		_wave_countdown_label.visible = false
		return
	_pre_spawn_mode = true
	_wave_countdown_label.visible = true
	_wave_countdown_label.text = LocalizationManager.tr_key("hud.wave_pre_spawn", {"wave": wave, "value": "%.1f" % seconds_left})


## [自定义] 波次剩余倒计时：敌人生成后，中上显示「第 X 波 - 剩余 Xs」；脏检查与 _pre_spawn_mode 区分预生成。
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


## [自定义] 为波次横幅与倒计时 Label 应用描边（outline_size=4）与字号 22，使更醒目。
func _apply_wave_label_effects(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 22)


## [自定义] 显示波次横幅（如「第 N 波」），播放缩放+淡出动画，动画结束后隐藏。
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


## [自定义] 显示升级四选一面板：填充 options 的标题/描述/图标/upgrade_id，显示遮罩与刷新按钮（refresh_cost 控制禁用）。
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


## [自定义] 隐藏升级面板并关闭模态遮罩。
func hide_upgrade_options() -> void:
	_upgrade_panel.visible = false
	_show_modal_backdrop(false)


## [自定义] 显示开局武器选择：仅商店 Tab 可见，隐藏刷新与下一波按钮，填充 options。
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


## [自定义] 显示波次后武器商店：三 Tab 可见，刷新/下一波显示，填充选项、背包与角色信息 Tab（stats 脏检查）。
func show_weapon_shop(options: Array[Dictionary], current_gold: int, capacity_left: int, completed_wave: int = 0, stats: Dictionary = {}) -> void:
	_weapon_mode = "shop"
	_show_modal_backdrop(true)
	_weapon_panel.visible = true
	if completed_wave > 0:
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title_wave", {"wave": completed_wave})
	else:
		_weapon_title_label.text = LocalizationManager.tr_key("weapon.shop_title")
	var capacity_str := "∞" if capacity_left <= 0 else str(capacity_left)
	_weapon_tip_label.text = "  " + LocalizationManager.tr_key("weapon.shop_tip", {"gold": current_gold, "capacity": capacity_str})  # 首行缩进 2 格
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


## [自定义] 隐藏武器/商店面板并关闭模态遮罩。
func hide_weapon_panel() -> void:
	_weapon_mode = ""
	_weapon_panel.visible = false
	_show_modal_backdrop(false)


## [自定义] 更新商店 Tab 内刷新按钮的文案（消耗金币）与可用状态（金币是否足够）。
func _update_shop_refresh_btn(wave: int) -> void:
	if not _shop_refresh_btn:
		return
	var cost: int = GameManager.get_shop_refresh_cost(wave)
	var can_afford: bool = GameManager.run_currency >= cost
	_shop_refresh_btn.text = LocalizationManager.tr_key("shop.refresh_cost", {"cost": cost})
	_shop_refresh_btn.disabled = not can_afford


## [自定义] 商店背包 Tab 内售卖/合并后刷新。由 game 在完成售卖或合并后调用，更新背包与角色信息 Tab。
func refresh_shop_backpack(stats: Dictionary) -> void:
	if _shop_backpack_panel and _shop_backpack_panel.has_method("set_stats"):
		_shop_backpack_panel.set_stats(stats, true)
	_update_shop_stats_tab(stats)


## [系统] 背包 Tab 内售卖按钮按下时转发 backpack_sell_requested(weapon_index)。
func _on_shop_backpack_sell_requested(weapon_index: int) -> void:
	emit_signal("backpack_sell_requested", weapon_index)


## [系统] 背包 Tab 内合并完成时转发 backpack_merge_completed。
func _on_shop_backpack_merge_completed() -> void:
	emit_signal("backpack_merge_completed")


## [自定义] 对 stats（武器/魔法/道具/波次/血量等）做轻量哈希，用于角色信息 Tab 脏检查，避免无变化时重建。
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


## [自定义] 更新角色信息 Tab 内容：若 stats 哈希变化则清空容器并由 ResultPanelShared.build_player_stats_block 重建。
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


## [自定义] 触控设备下显示 TouchPanel 与 PauseTouchBtn 并连接信号；非触控时保持隐藏。
func _setup_touch_controls() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	_touch_panel.visible = true
	_pause_touch_btn.visible = true
	_pause_touch_btn.pressed.connect(func() -> void: emit_signal("pause_pressed"))
	var btn_left: Button = _touch_panel.get_node("BtnLeft")
	var btn_right: Button = _touch_panel.get_node("BtnRight")
	var btn_up: Button = _touch_panel.get_node("BtnUp")
	var btn_down: Button = _touch_panel.get_node("BtnDown")
	btn_left.pressed.connect(func() -> void: _move_state["left"] = true; _emit_mobile_move())
	btn_left.released.connect(func() -> void: _move_state["left"] = false; _emit_mobile_move())
	btn_right.pressed.connect(func() -> void: _move_state["right"] = true; _emit_mobile_move())
	btn_right.released.connect(func() -> void: _move_state["right"] = false; _emit_mobile_move())
	btn_up.pressed.connect(func() -> void: _move_state["up"] = true; _emit_mobile_move())
	btn_up.released.connect(func() -> void: _move_state["up"] = false; _emit_mobile_move())
	btn_down.pressed.connect(func() -> void: _move_state["down"] = true; _emit_mobile_move())
	btn_down.released.connect(func() -> void: _move_state["down"] = false; _emit_mobile_move())


## [自定义] 根据 _move_state 合成归一化方向向量并发射 mobile_move_changed。
func _emit_mobile_move() -> void:
	var x := int(_move_state["right"]) - int(_move_state["left"])
	var y := int(_move_state["down"]) - int(_move_state["up"])
	var direction := Vector2(x, y).normalized()
	emit_signal("mobile_move_changed", direction)


## [系统] 升级选项按钮按下：读取 meta upgrade_id 并发射 upgrade_selected。
func _on_upgrade_button_pressed(btn: Button) -> void:
	if not btn.has_meta("upgrade_id"):
		return
	if btn.disabled:
		return
	var upgrade_id := str(btn.get_meta("upgrade_id"))
	emit_signal("upgrade_selected", upgrade_id)


## [系统] 武器/商店选项按钮按下：根据 _weapon_mode 发射 start_weapon_selected 或 weapon_shop_selected(weapon_id)。
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


## [自定义] 应用当前语言的静态文案：按键提示、升级/武器标题与说明、Tab 标题、暂停按钮等。
func _apply_localized_static_texts() -> void:
	key_hints_label.text = _build_key_hints_text(_key_hints_expanded)
	if _upgrade_title_label:
		_upgrade_title_label.text = LocalizationManager.tr_key("hud.upgrade_title")
	_apply_upgrade_weapon_tip_texts()


## [自定义] 构建多行按键提示文本，供 HUD 左下角 key_hints_label 显示。
## expanded: false 时仅显示 2 行（移动+暂停），true 时显示全部按键。
func _build_key_hints_text(expanded: bool = false) -> String:
	if expanded:
		# 展开模式：显示全部按键
		return "\n".join([
			LocalizationManager.tr_key("pause.key_hint.move", {"keys": ResultPanelShared.action_to_text(["move_up", "move_down", "move_left", "move_right"])}),
			LocalizationManager.tr_key("pause.key_hint.pause", {"key": ResultPanelShared.action_to_text(["pause"])}),
			LocalizationManager.tr_key("pause.key_hint.camera_zoom", {"keys": ResultPanelShared.action_to_text(["camera_zoom_in", "camera_zoom_out"])}),
			LocalizationManager.tr_key("pause.key_hint.magic", {"keys": ResultPanelShared.action_to_text(["cast_magic", "magic_prev", "magic_next"])}),
			LocalizationManager.tr_key("pause.key_hint.enemy_hp", {"key": ResultPanelShared.action_to_text(["toggle_enemy_hp"])}),
			LocalizationManager.tr_key("hud.key_hints.toggle", {"key": ResultPanelShared.action_to_text(["toggle_key_hints"])})
		])
	else:
		# 收起模式：仅显示 2 行核心按键
		return "\n".join([
			LocalizationManager.tr_key("pause.key_hint.move", {"keys": ResultPanelShared.action_to_text(["move_up", "move_down", "move_left", "move_right"])}),
			LocalizationManager.tr_key("pause.key_hint.pause", {"key": ResultPanelShared.action_to_text(["pause"])}),
			LocalizationManager.tr_key("hud.key_hints.toggle_short", {"key": ResultPanelShared.action_to_text(["toggle_key_hints"])})
		])


## [自定义] 切换按键提示展开/收起状态。
func toggle_key_hints_expanded() -> void:
	_key_hints_expanded = not _key_hints_expanded
	key_hints_label.text = _build_key_hints_text(_key_hints_expanded)


## [自定义] 更新升级说明、武器标题与商店 Tab/下一波/暂停按钮的本地化文案（依赖 _last_currency、_weapon_mode）。
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


## [系统] 语言切换时重应用静态文案并按缓存重设血量/经验/等级/魔力/护甲/波次/击杀/时间/金币显示。
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


## [自定义] 填充商店/开局四个选项按钮：图标、标题、stats 文案、价格与禁用状态；支持 weapon/attribute/magic，is_shop 时武器检查金币与容量。
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


## [自定义] 构建商店魔法卡片 stats 文案：威力、魔力消耗、冷却 + 范围/效果/元素词条名称（来自 MagicDefs/MagicAffixDefs）。
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


## [自定义] 构建道具（attribute）卡片的 stats 文案：描述 + 数值（lifesteal 等为百分比）。
func _build_item_stats_text(option: Dictionary) -> String:
	var desc := LocalizationManager.tr_key(str(option.get("desc_key", "")))
	var val = option.get("base_value")
	if val is float:
		if option.get("attr", "") == "lifesteal_chance":
			return "%s +%.0f%%" % [desc, val * 100.0]
		return "%s +%.1f" % [desc, val]
	return "%s +%d" % [desc, int(val)]


## [自定义] 为升级/武器等模态 Panel 应用主题中的 modal 样式（来自 UiThemeConfig）。
func _apply_modal_panel_style(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", _get_ui_theme().get_modal_panel_stylebox())


## [自定义] 为模态面板添加全屏不透明背景色；pass_input=true 时鼠标穿透（如结算面板按钮可点）。
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


## [自定义] 控制全屏模态遮罩的显隐（升级/商店打开时 true，关闭时 false）。
func _show_modal_backdrop(backdrop_visible: bool) -> void:
	if not _modal_backdrop:
		return
	_modal_backdrop.visible = backdrop_visible


## [自定义] 返回当前 UI 主题配置（模态背景色、模态 Panel 样式等）。
func _get_ui_theme() -> UiThemeConfig:
	return UiThemeConfig.load_theme()


## [自定义] 构建武器卡片的 stats 文案：伤害、冷却、射程/弹速/扩散/穿透等；若有 random_affix_ids 则追加词条名称行。
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


# ---- UI 动画过渡系统 ----

## [自定义] 动画显示面板（带淡入和缩放效果）。
func _animate_panel_in(panel: Control, duration := 0.25) -> void:
	if panel == null:
		return
	panel.visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.95, 0.95)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(panel, "modulate:a", 1.0, duration)
	tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), duration)


## [自定义] 动画隐藏面板（带淡出和缩放效果）。
func _animate_panel_out(panel: Control, duration := 0.2) -> void:
	if panel == null or not panel.visible:
		return
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(panel, "scale", Vector2(0.95, 0.95), duration)
	tween.finished.connect(func() -> void:
		panel.visible = false
		panel.scale = Vector2(1.0, 1.0)
	)


## [自定义] 动画显示升级面板（带入场效果）。
func show_upgrade_options_animated(options: Array[Dictionary], current_gold: int, refresh_cost: int = 2) -> void:
	show_upgrade_options(options, current_gold, refresh_cost)
	_animate_panel_in(_upgrade_panel)


## [自定义] 动画隐藏升级面板。
func hide_upgrade_options_animated() -> void:
	_animate_panel_out(_upgrade_panel)
	_show_modal_backdrop(false)


## [自定义] 动画显示武器商店面板。
func show_weapon_shop_animated(options: Array[Dictionary], current_gold: int, capacity_left: int) -> void:
	show_weapon_shop(options, current_gold, capacity_left)
	_animate_panel_in(_weapon_panel)


## [自定义] 动画隐藏武器商店面板。
func hide_weapon_panel_animated() -> void:
	_animate_panel_out(_weapon_panel)
	_show_modal_backdrop(false)
