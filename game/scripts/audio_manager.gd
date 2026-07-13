extends Node

var _music:  AudioStreamPlayer
var _sfx:    Array = []
var _idx:    int   = 0
var _sounds: Dictionary = {}

func _ready():
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(_loop_music)

	for i in range(5):
		var p = AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

	_build_sounds()
	_apply_volumes()

	if SettingsManager:
		SettingsManager.settings_changed.connect(_apply_volumes)

	call_deferred("_loop_music")

func _build_sounds():
	_sounds["click"]     = _tone(920.0,  0.055, 0.32)
	_sounds["hover"]     = _tone(680.0,  0.038, 0.14)
	_sounds["correct"]   = _arp([523.25, 659.25, 783.99], 0.10, 0.42)
	_sounds["wrong"]     = _tone(115.0,  0.32,  0.50, "square")
	_sounds["level_up"]  = _arp([261.63, 329.63, 392.0, 523.25], 0.10, 0.44)
	_sounds["game_over"] = _arp([220.0,  185.0,  146.83, 110.0],  0.14, 0.38)
	_sounds["combo"]     = _arp([440.0,  880.0,  1320.0],          0.07, 0.48)
	_sounds["tick"]      = _tone(440.0,  0.04,  0.18)
	_sounds["warning"]   = _tone(320.0,  0.14,  0.38, "square")
	_sounds["shield"]    = _arp([660.0,  880.0],                   0.08, 0.40)

func _apply_volumes():
	var mv = max(SettingsManager.music_volume if SettingsManager else 0.5, 0.001)
	var sv = max(SettingsManager.sfx_volume   if SettingsManager else 0.8, 0.001)
	_music.volume_db = linear_to_db(mv)
	for p in _sfx:
		p.volume_db = linear_to_db(sv)

func set_music_volume(vol: float):
	_music.volume_db = linear_to_db(max(vol, 0.001))

func set_sfx_volume(vol: float):
	for p in _sfx:
		p.volume_db = linear_to_db(max(vol, 0.001))

func play(snd: String):
	if not _sounds.has(snd):
		return
	# Round-robin through SFX players so overlapping sounds work
	var player: AudioStreamPlayer = _sfx[_idx % _sfx.size()]
	_idx += 1
	player.stream = _sounds[snd]
	player.play()

func _loop_music():
	if not _sounds.has("bg"):
		_sounds["bg"] = _gen_ambient()
	_music.stream = _sounds["bg"]
	_music.play()

# ─────────────────────────────────────────────────────────────────────────────
#  PCM generation helpers — all static, work without scene context
# ─────────────────────────────────────────────────────────────────────────────

static func _tone(freq: float, dur: float, vol: float = 0.5,
				  wave: String = "sine") -> AudioStreamWAV:
	var sr  = 22050
	var n   = int(sr * dur)
	var wav = AudioStreamWAV.new()
	wav.format    = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo    = false
	wav.mix_rate  = sr
	var data = PackedByteArray()
	data.resize(n * 2)
	var atk = max(1, int(n * 0.06))
	var rel = int(n * 0.62)
	for i in range(n):
		var t   = float(i) / sr
		var env: float
		if i < atk:
			env = float(i) / atk
		elif i > rel:
			env = clampf(float(n - i) / max(1, n - rel), 0.0, 1.0)
		else:
			env = 1.0
		var s: float
		match wave:
			"square": s = 1.0 if fmod(freq * t, 1.0) < 0.5 else -1.0
			"tri":    s = 2.0 * abs(2.0 * fmod(freq * t + 0.25, 1.0) - 1.0) - 1.0
			_:        s = sin(TAU * freq * t)
		var v = clamp(int(s * env * vol * 32767), -32767, 32767)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav

static func _arp(freqs: Array, note_dur: float, vol: float = 0.5) -> AudioStreamWAV:
	var sr  = 22050
	var ns  = int(sr * note_dur)
	var tot = ns * freqs.size()
	var wav = AudioStreamWAV.new()
	wav.format   = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo   = false
	wav.mix_rate = sr
	var data = PackedByteArray()
	data.resize(tot * 2)
	for ni in range(freqs.size()):
		var freq = float(freqs[ni])
		var off  = ni * ns
		var atk  = max(1, int(ns * 0.10))
		var rel  = int(ns * 0.62)
		for i in range(ns):
			var t   = float(off + i) / sr
			var env: float
			if i < atk:
				env = float(i) / atk
			elif i > rel:
				env = clampf(float(ns - i) / max(1, ns - rel), 0.0, 1.0)
			else:
				env = 1.0
			var v   = clamp(int(sin(TAU * freq * t) * env * vol * 32767), -32767, 32767)
			var idx = (off + i) * 2
			data[idx]     = v & 0xFF
			data[idx + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav

static func _gen_ambient() -> AudioStreamWAV:
	var sr  = 22050
	var n   = int(sr * 5.0)   # 5-second loop
	var wav = AudioStreamWAV.new()
	wav.format     = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo     = false
	wav.mix_rate   = sr
	wav.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end   = n - 1   # must be n-1, not n
	var freqs = [55.0, 82.5, 110.0, 165.0]
	var vols  = [0.22, 0.09, 0.06,  0.03]
	var data  = PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t   = float(i) / sr
		var lfo = sin(TAU * 0.35 * t) * 0.30 + 0.70
		var s   = 0.0
		for j in range(freqs.size()):
			s += sin(TAU * freqs[j] * t) * vols[j]
		s *= lfo * 0.38
		var v = clamp(int(s * 32767), -32767, 32767)
		data[i * 2]     = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav
