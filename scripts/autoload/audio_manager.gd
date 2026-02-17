extends Node

# 轻量音频管理：通过 AudioStreamGenerator 运行时合成提示音，避免外部音频依赖。
const BUS_SFX := "Master"
const BUS_BGM := "Master"

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _hit_player: AudioStreamPlayer  # 受击音效专用通道，播放中不重叠
var _master_volume := 0.70


func _ready() -> void:
	# 预分配少量 SFX 通道，避免高频播放时反复 new/free。
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	add_child(_bgm_player)
	_hit_player = AudioStreamPlayer.new()
	_hit_player.bus = BUS_SFX
	add_child(_hit_player)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	var settings := SaveManager.get_settings()
	_master_volume = float(settings.get("system", {}).get("master_volume", 0.70))
	set_master_volume(_master_volume)


func play_shoot() -> void:
	_play_tone(680.0, 0.04, 0.20)


func play_shoot_by_type(bullet_type: String) -> void:
	# 按子弹类型播放差异化射击音效：手枪清脆、霰弹浑厚、机枪锐利、激光科幻
	match bullet_type:
		"pistol":
			_play_tone(720.0, 0.03, 0.18)
		"shotgun":
			_play_tone(420.0, 0.08, 0.28)
		"rifle":
			_play_tone(900.0, 0.025, 0.16)
		"laser":
			_play_tone(1200.0, 0.02, 0.14)
		_:
			play_shoot()


func play_hit() -> void:
	# 受击音效不重叠：播放中则跳过，避免同帧多次受击时音效堆叠。
	if _hit_player != null and _hit_player.playing:
		return
	_hit_player.stream = _create_tone_stream(220.0, 0.08, 0.30)
	_hit_player.volume_db = linear_to_db(maxf(0.0001, _master_volume))
	_hit_player.play()


func play_kill() -> void:
	_play_tone(480.0, 0.06, 0.22)


func play_pickup() -> void:
	_play_tone(880.0, 0.05, 0.18)


func play_magic_cast() -> void:
	_play_tone(600.0, 0.06, 0.22)


func play_wave_start() -> void:
	_play_tone(520.0, 0.10, 0.20)


func play_button() -> void:
	_play_tone(360.0, 0.05, 0.16)


func play_menu_bgm() -> void:
	_play_bgm_loop(175.0, 0.15)


func play_game_bgm() -> void:
	_play_bgm_loop(130.0, 0.12)


func set_master_volume(volume_01: float) -> void:
	_master_volume = clampf(volume_01, 0.0, 1.0)
	var normalized := _master_volume
	var db := linear_to_db(maxf(0.0001, normalized))
	if _bgm_player == null:
		return
	_bgm_player.volume_db = db
	if _hit_player != null:
		_hit_player.volume_db = db
	for player in _sfx_players:
		player.volume_db = db


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
