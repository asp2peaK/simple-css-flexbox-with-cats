extends Node
# Настройки (автозагрузка Settings): громкость, экран, чувствительность мыши.

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080)]

var music := 0.7
var sfx := 0.9
var fullscreen := false
var res_idx := 1
var sens := 1.0
var vsync := true
const KEY_NAMES := {"move_forward": "Вперёд", "move_back": "Назад", "move_left": "Влево",
	"move_right": "Вправо", "interact": "Взять / поставить", "restart": "Переиграть смену"}
const DEFAULT_KEYS := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
	"move_right": KEY_D, "interact": KEY_E, "restart": KEY_R}
var keys := DEFAULT_KEYS.duplicate()
var sharp := true  # чёткая картинка (рендер в размер окна) или пиксельная 640x360
var lang := "ru"
var twitch := ""  # канал Twitch для голосования чата
var reopen_settings := false
# внешний вид игрока (зеркало) и купленные вещи — общие для всех режимов
var look := {"nick": "", "race": "human", "skin": 0, "apron": 0, "hat": "", "face": ""}
var owned := ["human", "postal", "beanie", "glasses"]  # после смены языка снова открыть настройки


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_ensure_buses()
	_load_translation()
	load_cfg()
	for a in OS.get_cmdline_args():
		if a.begins_with("--lang="):
			lang = a.substr(7)
	apply()
	apply_keys()


# английский перевод: ключ — русская строка, значение — английская (res://lang/en.json)
func _load_translation() -> void:
	var f := File.new()
	if f.open("res://lang/en.json", File.READ) != OK:
		return
	var d = parse_json(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	var t := Translation.new()
	t.locale = "en"
	for k in d:
		t.add_message(k, d[k])
	TranslationServer.add_translation(t)


func apply_keys() -> void:
	var arrows := {"move_forward": KEY_UP, "move_back": KEY_DOWN, "move_left": KEY_LEFT, "move_right": KEY_RIGHT}
	for a in DEFAULT_KEYS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		var ev := InputEventKey.new()
		ev.physical_scancode = int(keys.get(a, DEFAULT_KEYS[a]))  # физические клавиши: работает на любой раскладке
		InputMap.action_add_event(a, ev)
		if arrows.has(a):
			var ev2 := InputEventKey.new()
			ev2.physical_scancode = arrows[a]
			InputMap.action_add_event(a, ev2)


func _ensure_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")


func apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(max(music, 0.001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music <= 0.01)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(max(sfx, 0.001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx <= 0.01)
	OS.vsync_enabled = vsync
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D if sharp else SceneTree.STRETCH_MODE_VIEWPORT,
		SceneTree.STRETCH_ASPECT_KEEP, Vector2(640, 360))
	TranslationServer.set_locale(lang)
	if OS.has_feature("standalone") or not OS.has_feature("editor"):
		OS.window_fullscreen = fullscreen
		if not fullscreen:
			OS.window_size = RESOLUTIONS[res_idx]
			OS.center_window()


func save_cfg() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "music", music)
	c.set_value("audio", "sfx", sfx)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("video", "res_idx", res_idx)
	c.set_value("video", "vsync", vsync)
	c.set_value("video", "sharp", sharp)
	c.set_value("game", "lang", lang)
	c.set_value("game", "twitch", twitch)
	c.set_value("input", "sens", sens)
	c.set_value("input", "keys", keys)
	c.set_value("player", "look", look)
	c.set_value("player", "owned", owned)
	c.save(PATH)


func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	music = c.get_value("audio", "music", music)
	sfx = c.get_value("audio", "sfx", sfx)
	fullscreen = c.get_value("video", "fullscreen", fullscreen)
	res_idx = int(clamp(c.get_value("video", "res_idx", res_idx), 0, RESOLUTIONS.size() - 1))
	vsync = c.get_value("video", "vsync", vsync)
	sharp = c.get_value("video", "sharp", sharp)
	lang = c.get_value("game", "lang", lang)
	twitch = str(c.get_value("game", "twitch", twitch))
	sens = c.get_value("input", "sens", sens)
	var lk = c.get_value("player", "look", {})
	if typeof(lk) == TYPE_DICTIONARY:
		for key in lk:
			look[key] = lk[key]
	var ow = c.get_value("player", "owned", [])
	if typeof(ow) == TYPE_ARRAY:
		for it in ow:
			if not it in owned:
				owned.append(it)
	var k = c.get_value("input", "keys", {})
	if typeof(k) == TYPE_DICTIONARY:
		for a in k:
			keys[a] = int(k[a])
