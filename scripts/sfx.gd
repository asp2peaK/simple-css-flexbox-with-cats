extends Node
# Звуки (автозагрузка Sfx). Все звуки синтезированы tools/synth_sfx.py — наши собственные.

const NAMES := ["thud1", "thud2", "thud3", "pickup", "whoosh", "bonk", "coin", "doorbell", "reject",
	"boing", "boom", "crack", "step1", "step2", "shift_end", "ambient", "music_game", "music_menu",
	"voice_witch", "voice_orc", "voice_skeleton", "voice_goblin",
	"angry_witch", "angry_orc", "angry_skeleton", "angry_goblin",
	"voice_vampire", "voice_dragon", "voice_ghost", "voice_dwarf",
	"angry_vampire", "angry_dragon", "angry_ghost", "angry_dwarf",
	"voice_thief", "voice_king", "voice_troll", "voice_werewolf", "voice_giant",
	"angry_thief", "angry_king", "angry_troll", "angry_werewolf", "angry_giant",
	"tick", "portal", "bite", "kick", "lid",
	"music_swamp", "music_crypt", "music_castle", "music_ice", "music_boss", "music_chaos",
	"rec_jazz", "rec_lofi", "rec_polka"]

var streams := {}
var ambient: AudioStreamPlayer
var music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for n in NAMES:
		streams[n] = load("res://assets/sfx/%s.wav" % n)
	var amb: AudioStreamSample = streams["ambient"]
	amb.loop_mode = AudioStreamSample.LOOP_FORWARD
	amb.loop_begin = 0
	amb.loop_end = amb.data.size() / 2
	ambient = AudioStreamPlayer.new()
	ambient.stream = amb
	ambient.volume_db = -10.0
	ambient.bus = "SFX"
	for m in NAMES:
		if not (m.begins_with("music_") or m.begins_with("rec_")):
			continue
		var ms: AudioStreamSample = streams[m]
		ms.loop_mode = AudioStreamSample.LOOP_FORWARD
		ms.loop_begin = 0
		ms.loop_end = ms.data.size() / 2
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -6.0
	add_child(music)
	add_child(ambient)


# гул зала: только в игре, не в меню
func set_ambient(on: bool) -> void:
	if on and not ambient.playing:
		ambient.play()
	elif not on:
		ambient.stop()


func play(name: String, pitch_var := 0.08, vol_db := 0.0) -> void:
	if not streams.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.pitch_scale = 1.0 + rand_range(-pitch_var, pitch_var)
	p.volume_db = vol_db
	p.bus = "SFX"
	add_child(p)
	p.play()
	p.connect("finished", p, "queue_free")


func play_at(name: String, pos: Vector3, pitch_var := 0.1, vol_db := 0.0) -> void:
	if not streams.has(name):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.pitch_scale = 1.0 + rand_range(-pitch_var, pitch_var)
	p.unit_db = vol_db
	p.bus = "SFX"
	p.unit_size = 3.0
	p.max_distance = 25.0
	scene.add_child(p)
	p.global_transform.origin = pos
	p.play()
	p.connect("finished", p, "queue_free")


func play_music(name: String) -> void:
	if _music_name == name and music.playing:
		return
	_music_name = name
	music.stream = streams[name]
	music.play()
