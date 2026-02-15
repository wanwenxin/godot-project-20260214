extends Node

# 轻量音频管理：通过 AudioStreamGenerator 运行时合成提示音，避免外部音频依赖。
const BUS_SFX := "Master"
const BUS_BGM := "Master"

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	# 预分配少量 SFX 通道，避免高频播放时反复 new/free。
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	add_child(_bgm_player)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)


func play_shoot() -> void:
	_play_tone(680.0, 0.04, 0.20)


func play_hit() -> void:
	_play_tone(220.0, 0.08, 0.30)


func play_kill() -> void:
	_play_tone(480.0, 0.06, 0.22)


func play_pickup() -> void:
	_play_tone(880.0, 0.05, 0.18)


func play_wave_start() -> void:
	_play_tone(520.0, 0.10, 0.20)


func play_button() -> void:
	_play_tone(360.0, 0.05, 0.16)


func play_menu_bgm() -> void:
	_play_bgm_loop(175.0, 0.15)


func play_game_bgm() -> void:
	_play_bgm_loop(130.0, 0.12)


func _play_bgm_loop(base_freq: float, volume: float) -> void:
	# 当前是“合成音”实现，后续替换真实 BGM 只需改这里。
	var stream := _create_tone_stream(base_freq, 0.8, volume)
	_bgm_player.stream = stream
	_bgm_player.pitch_scale = 1.0
	_bgm_player.stop()
	_bgm_player.play()


func _play_tone(freq: float, duration: float, volume: float) -> void:
	for player in _sfx_players:
		if not player.playing:
			player.stream = _create_tone_stream(freq, duration, volume)
			player.play()
			return
	# 找不到空闲通道时覆盖第一个。
	_sfx_players[0].stream = _create_tone_stream(freq, duration, volume)
	_sfx_players[0].play()


func _create_tone_stream(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	# 生成简单正弦波 PCM 数据，保持项目“无外部音频资源”。
	var sample_rate := 22050
	var sample_count := maxi(1, int(sample_rate * duration))
	var packed := PackedByteArray()
	packed.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var env := 1.0 - (float(i) / float(sample_count))
		var v := sin(TAU * freq * t) * env * volume
		var sample_i := int(clampf(v, -1.0, 1.0) * 32767.0)
		var u := sample_i & 0xFFFF
		packed[i * 2] = u & 0xFF
		packed[i * 2 + 1] = (u >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.mix_rate = sample_rate
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.data = packed
	return wav
