extends Control

# 图鉴菜单：按类型展示角色、敌人、道具、武器、魔法、词条及其详细信息。
# 主菜单入口打开，只读浏览，不修改游戏状态。

signal closed

@onready var _fullscreen_backdrop: ColorRect = $FullscreenBackdrop
@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/OuterMargin/CenterContainer/VBox/Title
@onready var _tabs: TabContainer = $Panel/OuterMargin/CenterContainer/VBox/Tabs
@onready var _close_button: Button = $Panel/OuterMargin/CenterContainer/VBox/CloseButton

var _weapons_sub: TabContainer = null  # 武器子 Tab（近战/远程），语言切换时更新标题
var _affixes_sub: TabContainer = null  # 词条子 Tab（五类），语言切换时更新标题

const FONT_SIZE := 16
const FONT_SIZE_SMALL := 14
const ITEM_SEP := 8
const ICON_SIZE := 48
const PLACEHOLDER_COLOR := Color(0.5, 0.55, 0.6, 1.0)
const TEXT_MIN_WIDTH := 400


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fullscreen_backdrop.color = UiThemeConfig.load_theme().modal_backdrop
	_apply_panel_style()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.pressed.connect(_on_close_pressed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_build_tabs()
	_tabs.add_theme_font_size_override("font_size", 20)  # Tab 标签字体放大
	_tabs.add_theme_constant_override("side_margin", 16)  # Tab 内容区左右间距
	_tabs.add_theme_constant_override("top_margin", 16)  # Tab 内容区顶部间距
	_apply_localized_texts()


func open_menu() -> void:
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	visible = true


func _apply_panel_style() -> void:
	_panel.add_theme_stylebox_override("panel", UiThemeConfig.load_theme().get_modal_panel_stylebox())


func _build_tabs() -> void:
	_build_characters_tab()
	_build_enemies_tab()
	_build_items_tab()
	_build_weapons_tab()
	_build_magic_tab()
	_build_affixes_tab()


func _make_scroll_vbox() -> VBoxContainer:
	return _make_scroll_vbox_for_parent(_tabs)


func _make_scroll_vbox_for_parent(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", ITEM_SEP)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	parent.add_child(scroll)
	return vbox


## 添加图鉴项：左侧图片 + 右侧名称与详情。icon_path 为空时使用占位色块。
func _add_entry(vbox: VBoxContainer, title: String, details: String, icon_path: String = "") -> void:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(4)
	card_style.bg_color = Color(0.15, 0.16, 0.19, 0.9)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(0.4, 0.42, 0.48, 1.0)
	card.add_theme_stylebox_override("panel", card_style)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	# 左侧图标
	var icon_rect := TextureRect.new()
	var tex: Texture2D = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	if tex == null:
		tex = VisualAssetRegistry.make_color_texture(PLACEHOLDER_COLOR, Vector2i(ICON_SIZE, ICON_SIZE))
	icon_rect.texture = tex
	icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)
	# 右侧文本区
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.custom_minimum_size.x = TEXT_MIN_WIDTH
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 0)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	text_vbox.add_child(m)
	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 4)
	m.add_child(inner_vbox)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner_vbox.add_child(title_lbl)
	if not details.is_empty():
		var detail_lbl := Label.new()
		detail_lbl.text = details
		detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_lbl.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
		detail_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		inner_vbox.add_child(detail_lbl)
	hbox.add_child(text_vbox)
	card.add_child(hbox)
	vbox.add_child(card)


func _build_characters_tab() -> void:
	var vbox := _make_scroll_vbox()
	for c in GameManager.characters:
		var name_str := LocalizationManager.tr_key("char_select.card_a") if c.get("id", 0) == 0 else LocalizationManager.tr_key("char_select.card_b")
		if c.has("name"):
			name_str = str(c.get("name", ""))
		var details := "%s: %d | %s: %.0f | %s: %.2f | %s: %d | %s: %.0f" % [
			LocalizationManager.tr_key("pause.stat_hp"), int(c.get("max_health", 100)),
			LocalizationManager.tr_key("pause.stat_speed"), float(c.get("speed", 150)),
			LocalizationManager.tr_key("pause.stat_fire_rate"), float(c.get("fire_rate", 0.3)),
			LocalizationManager.tr_key("pause.stat_damage"), int(c.get("bullet_damage", 10)),
			LocalizationManager.tr_key("pause.stat_bullet_speed"), float(c.get("bullet_speed", 500))
		]
		var scheme: int = int(c.get("color_scheme", 0))
		var icon_path: String = "res://assets/characters/player_scheme_0.png" if scheme == 0 else "res://assets/characters/player_scheme_1.png"
		_add_entry(vbox, name_str, details, icon_path)
	_tabs.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.tab_characters"))


func _build_enemies_tab() -> void:
	var vbox := _make_scroll_vbox()
	var last_tier := ""
	for e in EnemyDefs.ENEMY_DEFS:
		var tier: String = str(e.get("tier", "normal"))
		if tier != last_tier:
			last_tier = tier
			var tier_key := "encyclopedia.enemy_tier_normal" if tier == "normal" else ("encyclopedia.enemy_tier_elite" if tier == "elite" else "encyclopedia.enemy_tier_boss")
			var header := Label.new()
			header.text = "—— " + LocalizationManager.tr_key(tier_key) + " ——"
			header.add_theme_font_size_override("font_size", FONT_SIZE)
			header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1.0))
			vbox.add_child(header)
		var name_str := LocalizationManager.tr_key(str(e.get("name_key", "")))
		var details := "%s: %d | %s: %.0f | %s: %d | %s: %d" % [
			LocalizationManager.tr_key("pause.stat_hp"), int(e.get("max_health", 25)),
			LocalizationManager.tr_key("pause.stat_speed"), float(e.get("speed", 90)),
			LocalizationManager.tr_key("encyclopedia.stat_contact_damage"), int(e.get("contact_damage", 8)),
			LocalizationManager.tr_key("encyclopedia.stat_exp"), int(e.get("exp_value", 5))
		]
		var desc_key: String = str(e.get("desc_key", ""))
		if desc_key != "":
			details += "\n" + LocalizationManager.tr_key(desc_key)
		_add_entry(vbox, name_str, details, str(e.get("icon_path", "")))
	_tabs.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.tab_enemies"))


func _build_items_tab() -> void:
	var vbox := _make_scroll_vbox()
	for item in ShopItemDefs.ITEM_POOL:
		if str(item.get("type", "")) == "magic":
			continue
		var name_key: String = str(item.get("display_name_key", item.get("name_key", "")))
		var name_str := LocalizationManager.tr_key(name_key)
		var details := LocalizationManager.tr_key(str(item.get("desc_key", "")))
		var base_cost: int = int(item.get("base_cost", 0))
		if base_cost > 0:
			details = "%s: %d | %s" % [LocalizationManager.tr_key("encyclopedia.base_cost"), base_cost, details]
		_add_entry(vbox, name_str, details, str(item.get("icon_path", "")))
	_tabs.set_tab_title(2, LocalizationManager.tr_key("encyclopedia.tab_items"))


func _build_weapons_tab() -> void:
	var weapons_sub := TabContainer.new()
	weapons_sub.custom_minimum_size = Vector2(0, 360)
	var vbox_melee := _make_scroll_vbox_for_parent(weapons_sub)
	var vbox_ranged := _make_scroll_vbox_for_parent(weapons_sub)
	for w in GameManager.weapon_defs:
		var wtype: String = str(w.get("type", ""))
		var target: VBoxContainer = vbox_melee if wtype == "melee" else vbox_ranged
		var name_str := LocalizationManager.tr_key(str(w.get("name_key", "")))
		var stats: Dictionary = w.get("stats", {})
		var details := LocalizationManager.tr_key(str(w.get("desc_key", "")))
		if not stats.is_empty():
			var dmg: int = int(stats.get("damage", 0))
			var cd: float = float(stats.get("cooldown", 0))
			var rng: float = float(stats.get("range", 0))
			details = "%s: %d | %s: %.2f | %s: %.0f\n%s" % [
				LocalizationManager.tr_key("pause.stat_damage"), dmg,
				LocalizationManager.tr_key("pause.stat_cooldown"), cd,
				LocalizationManager.tr_key("pause.stat_range"), rng,
				details
			]
		_add_entry(target, name_str, details, str(w.get("icon_path", "")))
	_weapons_sub = weapons_sub
	_weapons_sub.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.weapon_melee"))
	_weapons_sub.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.weapon_ranged"))
	_tabs.add_child(_weapons_sub)
	_tabs.set_tab_title(3, LocalizationManager.tr_key("encyclopedia.tab_weapons"))


func _build_magic_tab() -> void:
	var vbox := _make_scroll_vbox()
	for m in MagicDefs.MAGIC_POOL:
		var name_str := LocalizationManager.tr_key(str(m.get("name_key", "")))
		var details := LocalizationManager.tr_key(str(m.get("desc_key", "")))
		var mana: int = int(m.get("mana_cost", 0))
		var power: int = int(m.get("power", 0))
		var cd: float = float(m.get("cooldown", 0))
		# 从词条解析范围、效果、元素名称
		var range_affix := MagicAffixDefs.get_affix_def(str(m.get("range_affix_id", "")))
		var effect_affix := MagicAffixDefs.get_affix_def(str(m.get("effect_affix_id", "")))
		var elem_affix := MagicAffixDefs.get_affix_def(str(m.get("element_affix_id", "")))
		var range_name := LocalizationManager.tr_key(str(range_affix.get("name_key", ""))) if not range_affix.is_empty() else ""
		var effect_name := LocalizationManager.tr_key(str(effect_affix.get("name_key", ""))) if not effect_affix.is_empty() else ""
		var elem_name := LocalizationManager.tr_key(str(elem_affix.get("name_key", ""))) if not elem_affix.is_empty() else ""
		details = "%s: %d | %s: %d | %s: %.1fs\n%s: %s | %s: %s | %s: %s\n%s" % [
			LocalizationManager.tr_key("pause.stat_mana"), mana,
			LocalizationManager.tr_key("magic.stat_power"), power,
			LocalizationManager.tr_key("pause.stat_cooldown"), cd,
			LocalizationManager.tr_key("encyclopedia.magic_range"), range_name,
			LocalizationManager.tr_key("encyclopedia.magic_effect"), effect_name,
			LocalizationManager.tr_key("encyclopedia.stat_element"), elem_name,
			details
		]
		_add_entry(vbox, name_str, details, str(m.get("icon_path", "")))
	_tabs.set_tab_title(4, LocalizationManager.tr_key("encyclopedia.tab_magic"))


func _build_affixes_tab() -> void:
	var affixes_sub := TabContainer.new()
	affixes_sub.custom_minimum_size = Vector2(0, 360)
	var magic_sub := TabContainer.new()
	magic_sub.custom_minimum_size = Vector2(0, 320)
	var vbox_magic_range := _make_scroll_vbox_for_parent(magic_sub)
	var vbox_magic_effect := _make_scroll_vbox_for_parent(magic_sub)
	var vbox_magic_element := _make_scroll_vbox_for_parent(magic_sub)
	for a in MagicAffixDefs.RANGE_AFFIX_POOL:
		_add_magic_affix_entry(vbox_magic_range, a)
	for a in MagicAffixDefs.EFFECT_AFFIX_POOL:
		_add_magic_affix_entry(vbox_magic_effect, a)
	for a in MagicAffixDefs.ELEMENT_AFFIX_POOL:
		_add_magic_affix_entry(vbox_magic_element, a)
	magic_sub.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.magic_affix_range"))
	magic_sub.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.magic_affix_effect"))
	magic_sub.set_tab_title(2, LocalizationManager.tr_key("encyclopedia.magic_affix_element"))
	affixes_sub.add_child(magic_sub)
	var vbox_item := _make_scroll_vbox_for_parent(affixes_sub)
	var vbox_weapon_both := _make_scroll_vbox_for_parent(affixes_sub)
	var vbox_weapon_melee := _make_scroll_vbox_for_parent(affixes_sub)
	var vbox_weapon_ranged := _make_scroll_vbox_for_parent(affixes_sub)
	var vbox_weapon_type := _make_scroll_vbox_for_parent(affixes_sub)
	var vbox_weapon_theme := _make_scroll_vbox_for_parent(affixes_sub)
	var melee_type_ids := ["type_blade", "type_spear"]
	var ranged_type_ids := ["type_firearm", "type_staff"]
	for a in ItemAffixDefs.ITEM_AFFIX_POOL:
		_add_affix_entry(vbox_item, a)
	for a in WeaponAffixDefs.WEAPON_AFFIX_POOL:
		var wt: String = str(a.get("weapon_type", ""))
		var target: VBoxContainer = vbox_weapon_both if wt == "both" else (vbox_weapon_melee if wt == "melee" else vbox_weapon_ranged)
		_add_affix_entry(target, a)
	for a in WeaponAffixDefs.WEAPON_ELEMENT_AFFIX_POOL:
		_add_affix_entry(vbox_weapon_both, a)
	for a in WeaponTypeAffixDefs.WEAPON_TYPE_AFFIX_POOL:
		var tid: String = str(a.get("id", ""))
		var target_melee_ranged: VBoxContainer = vbox_weapon_melee if tid in melee_type_ids else vbox_weapon_ranged
		_add_affix_entry(target_melee_ranged, a)
		_add_affix_entry(vbox_weapon_type, a)
	for a in WeaponThemeAffixDefs.WEAPON_THEME_AFFIX_POOL:
		_add_affix_entry(vbox_weapon_both, a)
		_add_affix_entry(vbox_weapon_theme, a)
	_affixes_sub = affixes_sub
	_affixes_sub.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.affix_magic"))
	_affixes_sub.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.affix_item"))
	_affixes_sub.set_tab_title(2, LocalizationManager.tr_key("encyclopedia.affix_weapon_both"))
	_affixes_sub.set_tab_title(3, LocalizationManager.tr_key("encyclopedia.affix_weapon_melee"))
	_affixes_sub.set_tab_title(4, LocalizationManager.tr_key("encyclopedia.affix_weapon_ranged"))
	_affixes_sub.set_tab_title(5, LocalizationManager.tr_key("encyclopedia.affix_weapon_type"))
	_affixes_sub.set_tab_title(6, LocalizationManager.tr_key("encyclopedia.affix_weapon_theme"))
	_tabs.add_child(_affixes_sub)
	_tabs.set_tab_title(5, LocalizationManager.tr_key("encyclopedia.tab_affixes"))


## 魔法词条展示：名称、描述、数值（范围词条含 value_default）。
func _add_magic_affix_entry(vbox: VBoxContainer, a: Dictionary) -> void:
	var name_str := LocalizationManager.tr_key(str(a.get("name_key", "")))
	var details := LocalizationManager.tr_key(str(a.get("desc_key", "")))
	if a.has("value_default"):
		var v: float = float(a.get("value_default", 0))
		var vk: String = str(a.get("value_key", ""))
		if vk == "size":
			details = "%s: %.0f\n%s" % [LocalizationManager.tr_key("encyclopedia.magic_affix_size"), v, details]
		elif vk == "radius":
			details = "%s: %.0f\n%s" % [LocalizationManager.tr_key("encyclopedia.magic_affix_radius"), v, details]
	_add_entry(vbox, name_str, details, "")


func _add_affix_entry(vbox: VBoxContainer, a: Dictionary) -> void:
	var name_str := LocalizationManager.tr_key(str(a.get("name_key", "")))
	var details := LocalizationManager.tr_key(str(a.get("desc_key", "")))
	var effect_type: String = str(a.get("effect_type", ""))
	var base_val = a.get("base_value", 0)
	var weapon_type: String = str(a.get("weapon_type", ""))
	var bonus: Variant = a.get("bonus_per_count", 0)
	if effect_type != "":
		var eff_tr: String = LocalizationManager.tr_key("pause.stat_%s" % effect_type)
		details = "%s: %s" % [LocalizationManager.tr_key("encyclopedia.effect"), eff_tr]
		if base_val != 0:
			details += " | %s: %s" % [LocalizationManager.tr_key("encyclopedia.base"), str(base_val)]
		if weapon_type != "":
			var wt_tr: String = LocalizationManager.tr_key("encyclopedia.weapon_type_%s" % weapon_type)
			details += " | %s: %s" % [LocalizationManager.tr_key("encyclopedia.applicable"), wt_tr]
		if bonus != 0:
			details += " | %s: %s" % [LocalizationManager.tr_key("encyclopedia.per_item"), str(bonus)]
		if a.get("desc_key", ""):
			details += "\n" + LocalizationManager.tr_key(str(a.get("desc_key", "")))
	_add_entry(vbox, name_str, details, "")


func _apply_localized_texts() -> void:
	_title_label.text = LocalizationManager.tr_key("encyclopedia.title")
	_close_button.text = LocalizationManager.tr_key("common.close")
	for i in range(6):
		var keys := ["encyclopedia.tab_characters", "encyclopedia.tab_enemies", "encyclopedia.tab_items", "encyclopedia.tab_weapons", "encyclopedia.tab_magic", "encyclopedia.tab_affixes"]
		if i < keys.size():
			_tabs.set_tab_title(i, LocalizationManager.tr_key(keys[i]))
	if _weapons_sub != null:
		_weapons_sub.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.weapon_melee"))
		_weapons_sub.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.weapon_ranged"))
	if _affixes_sub != null:
		_affixes_sub.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.affix_magic"))
		var magic_sub: Control = _affixes_sub.get_child(0) if _affixes_sub.get_child_count() > 0 else null
		if magic_sub is TabContainer:
			magic_sub.set_tab_title(0, LocalizationManager.tr_key("encyclopedia.magic_affix_range"))
			magic_sub.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.magic_affix_effect"))
			magic_sub.set_tab_title(2, LocalizationManager.tr_key("encyclopedia.magic_affix_element"))
		_affixes_sub.set_tab_title(1, LocalizationManager.tr_key("encyclopedia.affix_item"))
		_affixes_sub.set_tab_title(2, LocalizationManager.tr_key("encyclopedia.affix_weapon_both"))
		_affixes_sub.set_tab_title(3, LocalizationManager.tr_key("encyclopedia.affix_weapon_melee"))
		_affixes_sub.set_tab_title(4, LocalizationManager.tr_key("encyclopedia.affix_weapon_ranged"))
		_affixes_sub.set_tab_title(5, LocalizationManager.tr_key("encyclopedia.affix_weapon_type"))
		_affixes_sub.set_tab_title(6, LocalizationManager.tr_key("encyclopedia.affix_weapon_theme"))


func _on_close_pressed() -> void:
	visible = false
	emit_signal("closed")


func _on_language_changed(_code: String) -> void:
	# 清空 Tab 内容并重建，确保图鉴条目随当前语言刷新
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_weapons_sub = null
	_affixes_sub = null
	_build_tabs()
	_apply_localized_texts()
