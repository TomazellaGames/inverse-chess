class_name GameAudio
extends Node
## Game audio: background music plus procedurally synthesized sound effects.
## Every effect is rendered once at startup into an AudioStreamWAV, which plays
## reliably on web builds (unlike AudioStreamGenerator, which needs threads there).
## Effects and music get their own buses so each has an independent volume.

const RATE := 22050
const VOICES := 8
const PATH := "user://settings.cfg"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"
const MUSIC := preload("res://assets/zephiramusic-lofi-loop-589689.ogg")
const MUSIC_FADE_IN := 2.5

enum Wave { SINE, TRI, SQUARE, SAW }

## Per-sound loudness, so all sounds can be normalized to the same peak.
const VOLUME_DB := {
	"move": -5.0, "capture": -2.0, "castle": -5.0, "promote": -7.0,
	"check_good": -4.0, "check_bad": -6.0,
	"win": -3.0, "lose": -3.0, "draw": -4.0, "start": -7.0,
	"select": -14.0, "invalid": -11.0, "click": -12.0, "open": -9.0, "close": -10.0,
}

## Linear volumes, 0..1. Zero mutes the bus.
var sfx_volume := 0.8
var music_volume := 0.2

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	_add_bus(SFX_BUS)
	_add_bus(MUSIC_BUS)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	var stream := MUSIC.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	_music.stream = stream
	add_child(_music)
	_load_settings()
	_apply_volumes()
	# Synthesis takes a moment (slower on web); let the first frame render first.
	_build_all.call_deferred()


func play(sound: String, pitch_jitter := 0.0) -> void:
	if sfx_volume <= 0.0 or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.volume_db = VOLUME_DB.get(sound, 0.0)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Starts the music loop with a gentle fade-in. Browsers keep audio suspended
## until the first tap/click; Godot resumes it automatically at that point.
func start_music() -> void:
	if _music.playing:
		return
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", 0.0, MUSIC_FADE_IN)


func set_volumes(sfx: float, music: float) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	_apply_volumes()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # Keep other sections (e.g. colors) intact.
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
		music_volume = float(cfg.get_value("audio", "music_volume", music_volume))


func _add_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func _apply_volumes() -> void:
	for pair in [[SFX_BUS, sfx_volume], [MUSIC_BUS, music_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v: float = pair[1]
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


# --- Sound design -----------------------------------------------------------

static func _note(semitones_from_a4: float) -> float:
	return 440.0 * pow(2.0, semitones_from_a4 / 12.0)


## A short wooden "tock": a falling sine body plus a tiny noise click.
func _tock(b: PackedFloat32Array, at: float, pitch: float, weight: float) -> void:
	_noise(b, at, 0.015, 0.5 * weight, 4000.0, 1500.0, 0.0005, 250.0)
	_tone(b, at, 0.14, pitch, pitch * 0.62, 0.7 * weight, Wave.SINE, 0.001, 40.0)
	_tone(b, at, 0.07, pitch * 2.1, pitch * 1.4, 0.15 * weight, Wave.SINE, 0.001, 80.0)


func _build_all() -> void:
	var b: PackedFloat32Array

	b = _buf(0.15)
	_tock(b, 0.0, 520.0, 1.0)
	_add("move", b)

	b = _buf(0.25)
	_noise(b, 0.0, 0.08, 0.9, 5000.0, 700.0, 0.0005, 45.0)
	_tone(b, 0.0, 0.22, 300.0, 150.0, 0.9, Wave.SINE, 0.001, 22.0)
	_tock(b, 0.0, 620.0, 0.6)
	_add("capture", b)

	b = _buf(0.26)
	_tock(b, 0.0, 520.0, 1.0)
	_tock(b, 0.1, 440.0, 0.9)
	_add("castle", b)

	# Your king is in check — good news here, so a sly descending minor figure.
	b = _buf(0.95)
	for i in 3:
		var n := _note([7.0, 3.0, 0.0][i])
		_tone(b, i * 0.12, 0.6, n, n, 0.45, Wave.TRI, 0.005, 5.0)
		_tone(b, i * 0.12, 0.4, n * 2.005, n * 2.005, 0.08, Wave.SINE, 0.005, 9.0)
	_tone(b, 0.0, 0.9, _note(-12.0), _note(-12.0), 0.25, Wave.SINE, 0.06, 3.0)
	_add("check_good", b)

	# The rival is in check — careful, you might accidentally win the wrong way.
	b = _buf(0.3)
	_tone(b, 0.0, 0.09, 988.0, 988.0, 0.3, Wave.SQUARE, 0.003, 12.0)
	_tone(b, 0.12, 0.14, 740.0, 740.0, 0.3, Wave.SQUARE, 0.003, 12.0)
	_add("check_bad", b)

	# Victory: a minor start that resolves into a bright major chord.
	b = _buf(1.7)
	var run := [0.0, 3.0, 7.0, 12.0]
	for i in run.size():
		var n := _note(run[i])
		_tone(b, i * 0.09, 0.3, n, n, 0.4, Wave.TRI, 0.003, 9.0)
	for s in [0.0, 4.0, 7.0, 12.0, 16.0]:
		var n := _note(s)
		_tone(b, 0.4, 1.3, n, n, 0.22, Wave.TRI, 0.01, 2.2)
		_tone(b, 0.4, 1.0, n * 2.0, n * 2.0, 0.05, Wave.SINE, 0.01, 3.5)
	_add("win", b)

	# Defeat: comedic "wah wah wah waaah".
	b = _buf(1.9)
	var drops := [-2.0, -3.0, -4.0]
	for i in drops.size():
		var n := _note(drops[i] - 12.0)
		_tone(b, i * 0.3, 0.28, n, n * 0.97, 0.45, Wave.TRI, 0.03, 3.0)
		_tone(b, i * 0.3, 0.28, n, n * 0.97, 0.08, Wave.SQUARE, 0.03, 3.0)
	var last := _note(-17.0)
	_tone(b, 0.9, 1.0, last, last * 0.94, 0.5, Wave.TRI, 0.03, 1.8, 0.025, 6.0)
	_tone(b, 0.9, 1.0, last, last * 0.94, 0.09, Wave.SQUARE, 0.03, 1.8, 0.025, 6.0)
	_add("lose", b)

	b = _buf(0.8)
	_tone(b, 0.0, 0.5, _note(3.0), _note(3.0), 0.4, Wave.SINE, 0.005, 5.0)
	_tone(b, 0.2, 0.6, _note(-2.0), _note(-2.0), 0.4, Wave.SINE, 0.005, 5.0)
	_add("draw", b)

	b = _buf(0.75)
	_tone(b, 0.0, 0.5, _note(3.0), _note(3.0), 0.4, Wave.TRI, 0.004, 6.0)
	_tone(b, 0.12, 0.6, _note(10.0), _note(10.0), 0.4, Wave.TRI, 0.004, 5.0)
	_add("start", b)

	# Promotion: quick ascending pentatonic shimmer.
	b = _buf(0.65)
	var steps := [12.0, 14.0, 16.0, 19.0, 21.0, 24.0]
	for i in steps.size():
		var n := _note(steps[i])
		_tone(b, i * 0.045, 0.32, n, n, 0.25, Wave.SINE, 0.002, 9.0)
		_tone(b, i * 0.045, 0.2, n * 3.0, n * 3.0, 0.05, Wave.SINE, 0.002, 14.0)
	_add("promote", b)

	b = _buf(0.05)
	_tone(b, 0.0, 0.04, 1500.0, 1300.0, 0.4, Wave.SINE, 0.001, 110.0)
	_add("select", b)

	b = _buf(0.13)
	_tone(b, 0.0, 0.12, 170.0, 130.0, 0.3, Wave.SQUARE, 0.002, 25.0)
	_tone(b, 0.0, 0.12, 170.0, 130.0, 0.4, Wave.TRI, 0.002, 25.0)
	_add("invalid", b)

	b = _buf(0.05)
	_tone(b, 0.0, 0.04, 950.0, 700.0, 0.5, Wave.SINE, 0.001, 90.0)
	_noise(b, 0.0, 0.006, 0.2, 6000.0, 3000.0, 0.0005, 400.0)
	_add("click", b)

	b = _buf(0.3)
	_noise(b, 0.0, 0.28, 0.9, 300.0, 3500.0, 0.12, 9.0)
	_add("open", b)

	b = _buf(0.25)
	_noise(b, 0.0, 0.24, 0.9, 3500.0, 300.0, 0.02, 13.0)
	_add("close", b)


# --- Synthesis primitives ---------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Adds an enveloped oscillator (attack, exponential decay) with optional pitch
## glide from f0 to f1 and vibrato.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float,
		wave: Wave, attack: float, decay: float, vib_depth := 0.0, vib_rate := 0.0) -> void:
	var s0 := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - s0)
	var fade := 0.005 * RATE
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, float(i) / n)
		if vib_depth > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib_rate * t)
		phase = fposmod(phase + f / RATE, 1.0)
		var x: float
		match wave:
			Wave.SINE:
				x = sin(TAU * phase)
			Wave.TRI:
				x = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SQUARE:
				x = 1.0 if phase < 0.5 else -1.0
			_:
				x = 2.0 * phase - 1.0
		var env := minf(1.0, t / attack) * exp(-decay * t) * minf(1.0, (n - i) / fade)
		b[s0 + i] += x * amp * env


## Adds white noise through a one-pole low-pass whose cutoff sweeps fc0 → fc1.
func _noise(b: PackedFloat32Array, start: float, dur: float, amp: float, fc0: float, fc1: float,
		attack: float, decay: float) -> void:
	var s0 := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - s0)
	var fade := 0.005 * RATE
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var fc := lerpf(fc0, fc1, float(i) / n)
		y += (1.0 - exp(-TAU * fc / RATE)) * (randf_range(-1.0, 1.0) - y)
		var env := minf(1.0, t / attack) * exp(-decay * t) * minf(1.0, (n - i) / fade)
		b[s0 + i] += y * amp * env


## Normalizes to a common peak and packs into a 16-bit mono AudioStreamWAV.
func _add(sound: String, b: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in b:
		peak = maxf(peak, absf(v))
	var gain := 0.85 / peak if peak > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	_streams[sound] = w
