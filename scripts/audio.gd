extends Node
var music: AudioStreamPlayer
var streams: Dictionary = {}
var muted := false
var last_sound: Dictionary = {}

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -15
	add_child(music)

func track(floor_index: int, ending: bool = false) -> void:
	var id: String = "music-ending" if ending else ["music-approach","music-temple-1","music-temple-2","music-temple-3","music-temple-3","music-boss"][floor_index]
	var stream: AudioStreamMP3 = load("res://assets/audio/%s.mp3" % id)
	stream.loop = true
	if music.stream == stream: return
	music.stream = stream
	music.play()

func play(id: String, volume: float = -11) -> void:
	if muted or DisplayServer.get_name()=="headless": return
	var now := Time.get_ticks_msec()
	if now-int(last_sound.get(id,0))<80: return
	last_sound[id] = now
	if not streams.has(id): streams[id] = load("res://assets/audio/%s.mp3" % id)
	var sound := AudioStreamPlayer.new()
	add_child(sound)
	sound.stream = streams[id]
	sound.volume_db = volume
	sound.pitch_scale = randf_range(.94,1.06)
	sound.finished.connect(sound.queue_free)
	sound.play()

func toggle() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0,muted)
