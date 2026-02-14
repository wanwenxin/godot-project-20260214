extends CanvasLayer

@onready var health_label: Label = $Root/TopRow/HealthLabel
@onready var wave_label: Label = $Root/TopRow/WaveLabel
@onready var kill_label: Label = $Root/TopRow/KillLabel
@onready var timer_label: Label = $Root/TopRow/TimerLabel
@onready var pause_hint: Label = $Root/PauseHint
@onready var game_over_panel: Panel = $Root/GameOverPanel
@onready var game_over_text: Label = $Root/GameOverPanel/VBoxContainer/GameOverText
@onready var retry_btn: Button = $Root/GameOverPanel/VBoxContainer/RetryButton
@onready var menu_btn: Button = $Root/GameOverPanel/VBoxContainer/MenuButton


func _ready() -> void:
	game_over_panel.visible = false
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)


func set_health(current: int, max_value: int) -> void:
	health_label.text = "HP: %d/%d" % [current, max_value]


func set_wave(value: int) -> void:
	wave_label.text = "Wave: %d" % value


func set_kills(value: int) -> void:
	kill_label.text = "Kills: %d" % value


func set_survival_time(value: float) -> void:
	timer_label.text = "Time: %.1fs" % value


func set_pause_hint(visible: bool) -> void:
	pause_hint.visible = visible


func show_game_over(wave: int, kills: int, survival_time: float) -> void:
	game_over_text.text = "Game Over\nWave: %d\nKills: %d\nTime: %.1fs" % [wave, kills, survival_time]
	game_over_panel.visible = true


func _on_retry_pressed() -> void:
	get_tree().current_scene.call("restart_game")


func _on_menu_pressed() -> void:
	get_tree().current_scene.call("go_main_menu")
