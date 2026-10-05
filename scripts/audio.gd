extends Node
var music: AudioStreamPlayer
var streams: Dictionary = {}
var muted := false
# When each sound last began, its latest few: up to TOGETHER copies of one
# sound may start at once (statues crumbling together each heard), and no
# more, so a burst of hits does not pile up into a roar.
var recent_sounds: Dictionary = {}
const TOGETHER = 4
const TOGETHER_MS = 80
# Every sound is pitched a little differently each time it plays (PITCH);
# these vary more, in pitch and in loudness (dB), so that heard over and over
# they never sound like one recording: [pitch, loudness].
const PITCH = .06
const VARIED = {"sword-hit-flesh":[.12,2.0]}

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
	var started: Array = recent_sounds.get(id,[]).filter(func(at): return now-int(at)<TOGETHER_MS)
	if started.size()>=TOGETHER: return
	started.append(now)
	recent_sounds[id] = started
	if not streams.has(id):
		var path = "res://assets/audio/%s.mp3" % id
		# A few effects were decoded to WAV from the original game's m4a files.
		if not ResourceLoader.exists(path): path = "res://assets/audio/%s.wav" % id
		streams[id] = load(path)
	var sound := AudioStreamPlayer.new()
	add_child(sound)
	sound.stream = streams[id]
	var vary: Array = VARIED.get(id,[PITCH,0.0])
	sound.volume_db = volume+randf_range(-vary[1],vary[1])
	sound.pitch_scale = randf_range(1.0-vary[0],1.0+vary[0])
	sound.finished.connect(sound.queue_free)
	sound.play()

func toggle() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0,muted)
