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
	"move_right": "Вправо", "grab": "Взять / зажать — швырнуть", "place": "Поставить",
	"interact": "Взять / поставить / нажать", "restart": "Переиграть смену", "shop": "Магазин после смены"}
# привязка: число > 0 — физическая клавиша, < 0 — кнопка мыши (-1 ЛКМ, -2 ПКМ, -3 колесо)
const DEFAULT_KEYS := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
	"move_right": KEY_D, "grab": -BUTTON_LEFT, "place": -BUTTON_RIGHT, "interact": KEY_E,
	"restart": KEY_R, "shop": KEY_N}
# геймпад (XInput-раскладка), не переназначается: кнопки и оси
const PAD_BUTTONS := {"move_forward": [JOY_DPAD_UP], "move_back": [JOY_DPAD_DOWN],
	"move_left": [JOY_DPAD_LEFT], "move_right": [JOY_DPAD_RIGHT], "grab": [JOY_R2, JOY_R],
	"place": [JOY_L2, JOY_XBOX_B], "interact": [JOY_XBOX_A], "restart": [JOY_SELECT], "shop": [JOY_XBOX_Y]}
const PAD_AXES := {"move_forward": [JOY_AXIS_1, -1.0], "move_back": [JOY_AXIS_1, 1.0],
	"move_left": [JOY_AXIS_0, -1.0], "move_right": [JOY_AXIS_0, 1.0],
	"grab": [JOY_ANALOG_R2, 1.0], "place": [JOY_ANALOG_L2, 1.0]}
var keys := DEFAULT_KEYS.duplicate()
var sharp := true  # чёткая картинка (рендер в размер окна) или пиксельная 640x360
var lang := "en"
var lang_saved := false  # язык уже выбран (иначе берём из Steam или системы)
var LANGS := ["ru", "en", "de", "es"]  # моды могут добавить свои (Mods.extra_langs)
var LANG_NAMES := ["Русский", "English", "Deutsch", "Español"]
var streamer := false  # режим стримера: прятать ники чата/друзей и IP
var twitch := ""  # канал Twitch для голосования чата
var reopen_settings := false
# внешний вид игрока (зеркало) и купленные вещи — общие для всех режимов
var look := {"nick": "", "race": "human", "skin": 0, "apron": 0, "hat": "", "face": ""}
var owned := ["human", "postal", "beanie", "glasses"]  # после смены языка снова открыть настройки


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	# шапка лога (user://logs/godot.log): по ней видно, на чём играл человек с ошибкой
	print("=== Not My Parcel! %s | %s | %s | %s | %s ===" % [load("res://scripts/game.gd").VERSION,
		OS.get_name(), OS.get_video_driver_name(OS.get_current_video_driver()),
		VisualServer.get_video_adapter_name(), Time.get_datetime_string_from_system()])
	_ensure_buses()
	_load_translation()
	load_cfg()
	if not lang_saved:
		lang = os_lang()
	for a in OS.get_cmdline_args():
		if a.begins_with("--lang="):
			lang = a.substr(7)
	apply()
	apply_keys()


# переводы: ключ — русская строка, значение — перевод (res://lang/<код>.json)
func _load_translation() -> void:
	for code in Mods.extra_langs:
		if not code in LANGS:
			LANGS.append(code)
			LANG_NAMES.append(Mods.extra_langs[code])
	for code in LANGS:
		var d = {}
		var f := File.new()
		if code != "ru" and f.open("res://lang/%s.json" % code, File.READ) == OK:
			d = parse_json(f.get_as_text())
			f.close()
		if typeof(d) != TYPE_DICTIONARY:
			d = {}
		var md: Dictionary = Mods.translations(code)
		for k in md:
			d[k] = md[k]
		if d.empty():
			continue
		var t := Translation.new()
		t.locale = code
		for k in d:
			t.add_message(k, d[k])
		TranslationServer.add_translation(t)


# латиница: таблички, коробки и неон берём английские (для en/de/es)
func latin() -> bool:
	return lang != "ru"


func os_lang() -> String:
	var l: String = OS.get_locale().to_lower().substr(0, 2)
	if l in ["ru", "be", "uk", "kk"]:
		return "ru"
	if l in LANGS:
		return l
	return "en"


# язык Steam (при первом запуске через Steam), вызывается из achievements.gd
func steam_lang(name: String) -> void:
	if lang_saved:
		return
	var m := {"russian": "ru", "english": "en", "german": "de", "spanish": "es", "latam": "es",
		"ukrainian": "ru"}
	if m.has(name) and m[name] != lang:
		lang = m[name]
		apply()


func apply_keys() -> void:
	var arrows := {"move_forward": KEY_UP, "move_back": KEY_DOWN, "move_left": KEY_LEFT, "move_right": KEY_RIGHT}
	for a in DEFAULT_KEYS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		InputMap.action_set_deadzone(a, 0.3)
		InputMap.action_add_event(a, bind_event(int(keys.get(a, DEFAULT_KEYS[a]))))
		if arrows.has(a):
			var ev2 := InputEventKey.new()
			ev2.physical_scancode = arrows[a]
			InputMap.action_add_event(a, ev2)
		for btn in PAD_BUTTONS.get(a, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = btn
			InputMap.action_add_event(a, jb)
		if PAD_AXES.has(a):
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[a][0]
			jm.axis_value = PAD_AXES[a][1]
			InputMap.action_add_event(a, jm)
	# пауза и меню с геймпада
	var st := InputEventJoypadButton.new()
	st.button_index = JOY_START
	if not InputMap.action_has_event("ui_cancel", st):
		InputMap.action_add_event("ui_cancel", st)


func bind_event(code: int) -> InputEvent:
	if code < 0:
		var mb := InputEventMouseButton.new()
		mb.button_index = -code
		return mb
	var ev := InputEventKey.new()
	ev.physical_scancode = code  # физические клавиши: работает на любой раскладке
	return ev


func bind_name(code: int) -> String:
	if code < 0:
		match -code:
			BUTTON_LEFT:
				return tr("ЛКМ")
			BUTTON_RIGHT:
				return tr("ПКМ")
			BUTTON_MIDDLE:
				return tr("Колесо")
		return tr("Мышь %d") % -code
	return OS.get_scancode_string(code)


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
			# окно размером с экран уходит под панель задач и заголовок: низ картинки пропадал.
			# Если выбранный размер не влезает в рабочую область — просто разворачиваем окно
			var want: Vector2 = RESOLUTIONS[res_idx]
			var scr: Vector2 = OS.get_screen_size()
			if want.x > scr.x - 20 or want.y > scr.y - 90:
				OS.window_maximized = true
			else:
				OS.window_maximized = false
				OS.window_size = want
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
	lang_saved = true
	c.set_value("game", "twitch", twitch)
	c.set_value("game", "streamer", streamer)
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
	if c.has_section_key("game", "lang"):
		lang = str(c.get_value("game", "lang", lang))
		lang_saved = lang in LANGS
		if not lang_saved:
			lang = "en"
	twitch = str(c.get_value("game", "twitch", twitch))
	streamer = bool(c.get_value("game", "streamer", streamer))
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
			if DEFAULT_KEYS.has(a):
				keys[a] = int(k[a])


func open_logs() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://logs"))
