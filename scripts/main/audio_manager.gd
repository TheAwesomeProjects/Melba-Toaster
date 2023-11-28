extends Node

@onready var voice_bus := AudioServer.get_bus_index("Voice")

@onready var cancel_sound: AudioStreamPlayer = $CancelSound
@onready var speech_player: AudioStreamPlayer = $SpeechPlayer
@onready var song_player: AudioStreamPlayer = $SongPlayer

var speech_duration := 0.0
var song_duration := 0.0

func _ready() -> void:
	Globals.start_speech.connect(_on_start_speech)
	Globals.stop_singing.connect(_on_stop_singing)

# region PUBLIC FUNCTIONS

func play_cancel_sound() -> void:
	Globals.is_speaking = true
	cancel_sound.play()
	await cancel_sound.finished
	Globals.is_speaking = false

func prepare_speech(message: PackedByteArray) -> void:
	var stream = AudioStreamMP3.new()
	stream.data = message
	speech_player.stream = stream
	speech_duration = stream.get_length()

func play_speech() -> void:
	assert(speech_player.stream, "There is no stream in speech_player")

	Globals.is_speaking = true
	speech_player.play()

func reset_speech_player() -> void:
	speech_player.stop()
	speech_player.stream = null
	speech_duration = 0.0

func prepare_song(song: Dictionary) -> void:
	AudioServer.set_bus_mute(voice_bus, song.mute_voice)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, song.reverb)

	var song_track := _load_mp3(song, "song")
	song_player.stream = song_track

	var voice_track := _load_mp3(song, "voice")
	speech_player.stream = voice_track

	song_duration = song_track.get_length()

func play_song(seek_time := 0.0) -> void:
	Globals.is_singing = true
	song_player.play(seek_time)
	speech_player.play(seek_time)

func reset_song_player() -> void:
	song_player.stop()
	song_player.stream = null
	song_duration = 0.0

func get_pos() -> float:
	return song_player.get_playback_position() \
		+ AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency() \
		+ (1 / Engine.get_frames_per_second()) * 2

func beats_counter_data() -> Array:
	var pos := get_pos()
	var beat := pos * Globals.dancing_bpm / 60.0
	var seconds := int(pos)

	return [
		seconds / 60.0,
		seconds % 60,
		get_pos(),
		song_duration / 60.0,
		int(song_duration) % 60,
		song_duration,
		Globals.dancing_bpm,
		int(beat) % 4 + 1,
	]

# endregion

# region SIGNALS CALLBACK

func _on_start_speech() -> void:
	play_speech()

func _on_stop_singing() -> void:
	finish_song()

func _on_song_player_finished() -> void:
	Globals.stop_singing.emit()

func _on_speech_player_finished() -> void:
	Globals.is_speaking = false
	reset_speech_player()

	Globals.speech_done.emit()

# endregion

# region PRIVATE FUNCTIONS

func finish_song() -> void:
	Globals.is_singing = false

	reset_speech_player()
	reset_song_player()

	AudioServer.set_bus_mute(voice_bus, false)
	AudioServer.set_bus_effect_enabled(voice_bus, 1, false)

func _load_mp3(song: Dictionary, type: String) -> AudioStreamMP3:
	var path: String = song.path % type

	assert(ResourceLoader.exists(path), "No audio file %s" % path)
	return ResourceLoader.load(path)

# endregion