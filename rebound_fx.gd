extends Node
# Created by GameManager. No new autoload or editor nodes required.
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var riser: AudioStreamPlayer
var music_fade: Tween
var shake_strength := 0.0
var shake_left := 0.0
var shake_duration := 0.0
var original_transform := Transform2D.IDENTITY
var shaking := false

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	music.volume_db = -18.0
	music.finished.connect(func(): music.play())
	riser = AudioStreamPlayer.new()
	add_child(riser)
	_reload_audio()

func _reload_audio() -> void:
	var files: Array[String] = []
	_scan_audio("res://", files)
	var aliases := {
		"music": ["music", "8-bit_last_mission", "05. last mission"],
		"hit": ["hit", "impactwood_light_000"],
		"break": ["break", "impactglass_heavy_000"],
		"brick": ["brick", "impactglass_light_000"],
		"impact": ["impact", "impactmetal_heavy_000"],
		"jump": ["jump", "phasejump1"],
		"riser": ["riser", "cinematic_riser_1_reverb_subtle"]
	}
	for role: String in aliases:
		var selected := ""
		for alias: String in aliases[role]:
			for file: String in files:
				var stem := file.get_file().get_basename().to_lower()
				if stem == alias or (role in ["music", "riser"] and stem.contains(alias) and not stem.contains("intro")):
					selected = file
					break
			if not selected.is_empty():
				break
		if not selected.is_empty():
			var stream := load(selected) as AudioStream
			if stream:
				sounds[role] = stream
				print("AUDIO ", role, " -> ", selected)
		if not sounds.has(role):
			sounds[role] = _generated_sound(role)
			print("AUDIO ", role, " -> built-in generated fallback")

func _scan_audio(folder: String, files: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	var names := directory.get_files()
	names.sort()
	for filename: String in names:
		var actual := filename.trim_suffix(".remap")
		if actual.get_extension().to_lower() in ["ogg", "wav", "mp3"]:
			files.append(folder.path_join(actual))
	for child: String in directory.get_directories():
		if not child.begins_with("."):
			_scan_audio(folder.path_join(child), files)

# Original synthesized tones/noise. No recordings, libraries, or downloads.
func _generated_sound(role: String) -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.14
	if role == "music":
		duration = 8.0
	elif role == "riser":
		duration = 4.0
	elif role in ["impact", "break"]:
		duration = 0.65
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var notes := [220.0, 261.63, 329.63, 293.66, 220.0, 196.0, 261.63, 164.81]
	for i in count:
		var time := float(i) / rate
		var fraction := time / duration
		var frequency := 700.0
		var envelope := pow(1.0 - fraction, 2.0)
		var noise := 0.0
		if role == "music":
			frequency = notes[int(time * 2.0) % notes.size()]
			envelope = 0.35 * (1.0 - fmod(time, 0.5) / 0.5)
		elif role == "riser":
			frequency = lerpf(110.0, 1800.0, fraction * fraction)
			envelope = fraction * 0.6
			noise = randf_range(-0.15, 0.15)
		elif role in ["impact", "break", "brick"]:
			frequency = lerpf(150.0, 45.0, fraction)
			noise = randf_range(-0.4, 0.4)
		elif role == "jump":
			frequency = lerpf(300.0, 1000.0, fraction)
		phase += TAU * frequency / rate
		var sample := clampf((sin(phase) * 0.55 + noise) * envelope, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 24000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			print("AUDIO TEST: Master muted=", AudioServer.is_bus_mute(0), " volume dB=", AudioServer.get_bus_volume_db(0))
			play_sfx("hit", -4.0, false)
		elif event.keycode == KEY_F9:
			if music.playing:
				music.stop()
			else:
				play_music()

func play_sfx(role: String, volume := -8.0, vary_pitch := true) -> void:
	if not sounds.has(role):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = sounds[role]
	voice.volume_db = volume
	voice.pitch_scale = randf_range(0.94, 1.06) if vary_pitch else 1.0
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func play_music() -> void:
	if music_fade:
		music_fade.kill()
	if sounds.has("music"):
		music.stream = sounds["music"]
		music.volume_db = -18.0
		if not music.playing:
			music.play()

func buildup(seconds := 4.0) -> void:
	if music_fade:
		music_fade.kill()
	music_fade = create_tween()
	music_fade.tween_property(music, "volume_db", -36.0, 0.5)
	if sounds.has("riser"):
		riser.stream = sounds["riser"]
		# Fit the full source to the camera move, so its peak lands on the reveal.
		riser.pitch_scale = clampf(riser.stream.get_length() / seconds, 0.1, 4.0)
		riser.volume_db = -24.0
		riser.play()
		var swell := create_tween()
		swell.tween_property(riser, "volume_db", -8.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func reveal() -> void:
	riser.stop()
	play_sfx("impact", -7.0, false)
	if music_fade:
		music_fade.kill()
	music_fade = create_tween()
	music_fade.tween_property(music, "volume_db", -18.0, 0.8)

func shake(pixels := 8.0, duration := 0.3) -> void:
	if not shaking:
		original_transform = get_viewport().canvas_transform
		shaking = true
	shake_strength = maxf(shake_strength, pixels)
	shake_left = duration
	shake_duration = duration

func stop_shake() -> void:
	if shaking:
		get_viewport().canvas_transform = original_transform
	shaking = false
	shake_strength = 0.0
	shake_left = 0.0

func _process(delta: float) -> void:
	if not shaking:
		return
	shake_left = maxf(0.0, shake_left - delta)
	if shake_left <= 0.0:
		stop_shake()
		return
	var strength := shake_strength * pow(shake_left / shake_duration, 2.0)
	var transform := original_transform
	transform.origin += Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	get_viewport().canvas_transform = transform
