extends CanvasLayer

# HUD 与结算层：
# - 战斗中显示 HP/波次/击杀/时间
# - 死亡后展示结算面板并提供重开/回主菜单入口
signal upgrade_selected(upgrade_id: String)
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
var _currency_label: Label
var _wave_banner: Label
var _upgrade_panel: Panel
var _upgrade_buttons: Array[Button] = []
var _touch_panel: Control
# 触控方向状态字典，组合成归一化向量后回传给 Player。
var _move_state := {
	"left": false,
	"right": false,
	"up": false,
	"down": false
}


func _ready() -> void:
	# 启动时默认不显示结算面板。
	game_over_panel.visible = false
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	_build_runtime_ui()
	_setup_touch_controls()
	_currency_label.text = "Gold: 0"
	_intermission_label.visible = false
	_wave_banner.visible = false
	_upgrade_panel.visible = false


func set_health(current: int, max_value: int) -> void:
	health_label.text = "HP: %d/%d" % [current, max_value]


func set_wave(value: int) -> void:
	wave_label.text = "Wave: %d" % value


func set_kills(value: int) -> void:
	kill_label.text = "Kills: %d" % value


func set_survival_time(value: float) -> void:
	timer_label.text = "Time: %.1fs" % value


func set_pause_hint(show_hint: bool) -> void:
	pause_hint.visible = show_hint


func set_currency(value: int) -> void:
	_currency_label.text = "Gold: %d" % value


func set_intermission_countdown(seconds_left: float) -> void:
	if seconds_left <= 0.0:
		_intermission_label.visible = false
		return
	_intermission_label.visible = true
	_intermission_label.text = "Next Wave: %.1fs" % seconds_left


func show_wave_banner(wave: int) -> void:
	_wave_banner.visible = true
	_wave_banner.text = "WAVE %d" % wave
	var tween := create_tween()
	_wave_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tween.tween_property(_wave_banner, "modulate", Color(1.0, 1.0, 1.0, 0.0), 1.0)
	tween.finished.connect(func() -> void: _wave_banner.visible = false)


func show_upgrade_options(options: Array[Dictionary], current_gold: int) -> void:
	_upgrade_panel.visible = true
	_currency_label.text = "Gold: %d" % current_gold
	for i in range(_upgrade_buttons.size()):
		var btn := _upgrade_buttons[i]
		if i >= options.size():
			btn.visible = false
			continue
		btn.visible = true
		var option: Dictionary = options[i]
		var cost := int(option.get("cost", 0))
		var affordable := current_gold >= cost
		# 金币不足直接置灰，仍保留文案给玩家决策反馈。
		btn.disabled = not affordable
		btn.text = "%s (+%s)  Cost:%d%s" % [
			String(option.get("title", "Upgrade")),
			String(option.get("desc", "")),
			cost,
			"" if affordable else " [Need Gold]"
		]
		btn.set_meta("upgrade_id", String(option.get("id", "")))
		btn.set_meta("upgrade_cost", cost)


func hide_upgrade_options() -> void:
	_upgrade_panel.visible = false


func show_game_over(wave: int, kills: int, survival_time: float) -> void:
	# 游戏结束后仅显示 UI，不直接切场，便于玩家选择后续操作。
	var save_data := SaveManager.load_game()
	var best_wave := int(save_data.get("best_wave", 0))
	var best_time := float(save_data.get("best_survival_time", 0.0))
	var wave_flag := "NEW" if wave >= best_wave else ""
	var time_flag := "NEW" if survival_time >= best_time else ""
	game_over_text.text = "Game Over\nWave: %d %s\nKills: %d\nTime: %.1fs %s" % [wave, wave_flag, kills, survival_time, time_flag]
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
	_currency_label = Label.new()
	_currency_label.position = Vector2(900, 12)
	root.add_child(_currency_label)

	_intermission_label = Label.new()
	_intermission_label.position = Vector2(12, 82)
	_intermission_label.text = "Next Wave: 0.0s"
	root.add_child(_intermission_label)

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
	_upgrade_panel.anchors_preset = Control.PRESET_CENTER
	_upgrade_panel.anchor_left = 0.5
	_upgrade_panel.anchor_top = 0.5
	_upgrade_panel.anchor_right = 0.5
	_upgrade_panel.anchor_bottom = 0.5
	_upgrade_panel.offset_left = -220
	_upgrade_panel.offset_top = -130
	_upgrade_panel.offset_right = 220
	_upgrade_panel.offset_bottom = 130
	root.add_child(_upgrade_panel)

	var box := VBoxContainer.new()
	box.anchors_preset = Control.PRESET_FULL_RECT
	box.offset_left = 14
	box.offset_top = 14
	box.offset_right = -14
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 8)
	_upgrade_panel.add_child(box)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "Choose Upgrade"
	box.add_child(title)

	for i in range(3):
		var btn := Button.new()
		btn.text = "Upgrade"
		btn.pressed.connect(_on_upgrade_button_pressed.bind(btn))
		box.add_child(btn)
		_upgrade_buttons.append(btn)


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
	var upgrade_id := String(btn.get_meta("upgrade_id"))
	emit_signal("upgrade_selected", upgrade_id)
