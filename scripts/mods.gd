extends Node
# Моды. Ищем в двух местах:
#   <папка с игрой>/mods/   и   user://mods/   (%APPDATA%/Godot/app_userdata/<игра>/mods)
# Что умеет мод (см. MODDING.md):
#   *.pck / *.zip рядом — заменяет любые ресурсы игры (собирается в Godot 3.6 как обычный экспорт)
#   папка с mod.json — {"name", "author", "version", "description", "languages": {"pl": "Polski"}}
#     lang/<код>.json — переводы (ключ — русская строка), можно добавить новый язык
#     lines.json      — новые фразы клиентов: {"orc": {"*": ["..%s.."], "en": [...]}, ...}
#     replace/...     — замена картинок (.png) и звуков (.wav/.ogg) по пути игры, без Godot:
#                       replace/assets/chars/orc_idle.png заменит res://assets/chars/orc_idle.png
#     main.gd         — скрипт мода (GDScript): подписывается на события игры ниже и меняет что хочет

# события для скриптов модов
signal menu_ready(menu)
signal level_ready(main)  # сцена пункта собрана (и в «закрыто», и в смене)
signal shift_started(main)
signal shift_ended(main)
signal customer_spawned(main, customer)
signal parcel_delivered(main, parcel, customer)

const API_VERSION := 1
var main = null  # текущая сцена пункта (scripts/main.gd), null в меню
var scripts := []  # узлы скриптов модов
var _keep := []  # заменённые ресурсы держим, иначе выпадут из кэша

var mods := []  # [{name, author, version, description, path, kind}]
var extra_langs := {}  # код -> название, новые языки из модов
var lang_files := {}  # код -> [пути к json]
var lines := {}  # вид клиента -> язык ("*" = любой) -> [фразы]
var errors := []
var disabled := false


func _enter_tree() -> void:
	if "--nomods" in OS.get_cmdline_args():
		disabled = true
		return
	for dir in dirs():
		_scan(dir)
	if mods.size() > 0:
		print("Mods: ", mods.size(), " loaded")
	call_deferred("_start_scripts")
	for e in errors:
		push_warning("Mods: " + e)


func dirs() -> Array:
	var out := []
	if not OS.has_feature("editor"):
		out.append(OS.get_executable_path().get_base_dir().plus_file("mods"))
	out.append(ProjectSettings.globalize_path("user://mods"))
	for a in OS.get_cmdline_args():
		if a.begins_with("--mods="):
			out.append(a.substr(7))
	return out


func user_dir() -> String:
	var d := Directory.new()
	d.make_dir_recursive("user://mods")
	return ProjectSettings.globalize_path("user://mods")


func _scan(dir: String) -> void:
	var d := Directory.new()
	if d.open(dir) != OK:
		return
	var names := []
	d.list_dir_begin(true, true)
	var n := d.get_next()
	while n != "":
		names.append(n)
		n = d.get_next()
	d.list_dir_end()
	names.sort()  # порядок загрузки — по алфавиту, поздний мод перекрывает ранний
	for nm in names:
		var p: String = dir.plus_file(nm)
		if d.dir_exists(p):
			_load_folder(p, nm)
		elif nm.get_extension().to_lower() in ["pck", "zip"]:
			if ProjectSettings.load_resource_pack(p, true):
				mods.append({"name": nm.get_basename(), "author": "", "version": "",
					"description": "", "path": p, "kind": "pck"})
			else:
				errors.append("can't load " + p)


func _json(path: String):
	var f := File.new()
	if f.open(path, File.READ) != OK:
		return null
	var r := JSON.parse(f.get_as_text())
	f.close()
	if r.error != OK:
		errors.append("%s: line %d: %s" % [path, r.error_line, r.error_string])
		return null
	return r.result


func _load_folder(p: String, nm: String) -> void:
	var info = _json(p.plus_file("mod.json"))
	if typeof(info) != TYPE_DICTIONARY:
		if File.new().file_exists(p.plus_file("mod.json")):
			return  # ошибка уже записана
		info = {}
	if info.get("disabled", false):
		return
	var m := {"name": str(info.get("name", nm)), "author": str(info.get("author", "")),
		"version": str(info.get("version", "")), "description": str(info.get("description", "")),
		"path": p, "kind": "folder"}
	var langs = info.get("languages", {})
	if typeof(langs) == TYPE_DICTIONARY:
		for code in langs:
			extra_langs[str(code)] = str(langs[code])
	# переводы
	var ld := Directory.new()
	if ld.open(p.plus_file("lang")) == OK:
		ld.list_dir_begin(true, true)
		var f := ld.get_next()
		while f != "":
			if f.get_extension() == "json":
				var code := f.get_basename()
				if not lang_files.has(code):
					lang_files[code] = []
				lang_files[code].append(p.plus_file("lang").plus_file(f))
			f = ld.get_next()
		ld.list_dir_end()
	# фразы клиентов
	var l = _json(p.plus_file("lines.json"))
	if typeof(l) == TYPE_DICTIONARY:
		for kind in l:
			var per = l[kind]
			if typeof(per) == TYPE_ARRAY:
				per = {"*": per}
			if typeof(per) != TYPE_DICTIONARY:
				continue
			if not lines.has(kind):
				lines[kind] = {}
			for lc in per:
				if typeof(per[lc]) != TYPE_ARRAY:
					continue
				if not lines[kind].has(lc):
					lines[kind][lc] = []
				for s in per[lc]:
					# фраза обязана содержать один %s (номер заказа)
					if typeof(s) == TYPE_STRING and s.count("%s") == 1 and s.count("%") == 1:
						lines[kind][lc].append(s)
					else:
						errors.append("%s: a line needs exactly one %%s: %s" % [nm, str(s)])
	_load_replacements(p.plus_file("replace"), "res://", nm)
	if File.new().file_exists(p.plus_file("main.gd")):
		m["script"] = p.plus_file("main.gd")
	mods.append(m)


# переводы из модов для языка code: {русская строка: перевод}
func translations(code: String) -> Dictionary:
	var out := {}
	for path in lang_files.get(code, []):
		var d = _json(path)
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				out[k] = str(d[k])
	return out


# дополнительные фразы клиента для текущего языка
func lines_for(kind: String, lang: String) -> Array:
	var out := []
	var per: Dictionary = lines.get(kind, {})
	out += per.get("*", [])
	out += per.get(lang, [])
	return out


# --- замена ресурсов -------------------------------------------------------

func _load_replacements(dir: String, res: String, nm: String) -> void:
	var d := Directory.new()
	if d.open(dir) != OK:
		return
	d.list_dir_begin(true, true)
	var f := d.get_next()
	while f != "":
		var full := dir.plus_file(f)
		if d.current_is_dir():
			_load_replacements(full, res.plus_file(f), nm)
		else:
			var r = load_file(full)
			if r:
				replace(res.plus_file(f), r)
			elif not f.get_extension() in ["import", "txt", "md"]:
				errors.append("%s: can't use %s (png, jpg, wav, ogg only)" % [nm, f])
		f = d.get_next()
	d.list_dir_end()


# загрузить картинку или звук с диска (не из игры): для модов без Godot
func load_file(path: String) -> Resource:
	match path.get_extension().to_lower():
		"png", "jpg", "jpeg", "webp":
			var img := Image.new()
			if img.load(path) != OK:
				return null
			var t := ImageTexture.new()
			t.create_from_image(img, 0)  # пиксель-арт: без фильтра и мипмапов
			return t
		"ogg":
			var f := File.new()
			if f.open(path, File.READ) != OK:
				return null
			var o := AudioStreamOGGVorbis.new()
			o.data = f.get_buffer(f.get_len())
			f.close()
			return o
		"wav":
			return _load_wav(path)
	return null


# res-путь игры теперь отдаёт этот ресурс: load("res://...") вернёт замену
func replace(res_path: String, r: Resource) -> void:
	if r == null:
		return
	r.take_over_path(res_path)
	_keep.append(r)


func _load_wav(path: String) -> AudioStreamSample:
	var f := File.new()
	if f.open(path, File.READ) != OK:
		return null
	if f.get_buffer(4).get_string_from_ascii() != "RIFF":
		f.close()
		return null
	f.get_32()
	f.get_buffer(4)  # WAVE
	var s := AudioStreamSample.new()
	var bits := 16
	while f.get_position() + 8 <= f.get_len():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var next := f.get_position() + size + (size % 2)
		if id == "fmt ":
			var fmt := f.get_16()
			s.stereo = f.get_16() == 2
			s.mix_rate = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
			if fmt != 1 or not bits in [8, 16]:
				f.close()
				errors.append("%s: only PCM 8/16-bit wav" % path.get_file())
				return null
		elif id == "data":
			var data := f.get_buffer(size)
			if bits == 8:
				# wav хранит 8 бит без знака, Godot ждёт со знаком
				for i in data.size():
					data[i] = (data[i] - 128) & 0xFF
				s.format = AudioStreamSample.FORMAT_8_BITS
			else:
				s.format = AudioStreamSample.FORMAT_16_BITS
			s.data = data
		f.seek(next)
	f.close()
	return s


# --- скрипты модов ---------------------------------------------------------

func _start_scripts() -> void:
	for m in mods:
		if not m.has("script"):
			continue
		var sc = load(m.script)
		if sc == null or not sc is Script or not sc.can_instance():
			errors.append("%s: main.gd has errors, see the log (Settings, Logs folder)" % m.name)
			continue
		var n = sc.new()
		if not n is Node:
			errors.append("%s: main.gd must start with 'extends Node'" % m.name)
			continue
		n.name = "mod_" + m.path.get_file().replace(".", "_")
		add_child(n)
		scripts.append(n)
		if n.has_method("_mod_ready"):
			n._mod_ready(self, m.path)
		print("Mods: script started: ", m.name)


# моды, меняющие игру (скрипты и паки ресурсов), выключают достижения и рекорды.
# Переводы, фразы и замена картинок/звуков — только внешний вид, их можно.
func affects_play() -> bool:
	for m in mods:
		if m.kind == "pck" or m.has("script"):
			return true
	return false


# вызывается игрой
func on_menu(menu) -> void:
	main = null
	emit_signal("menu_ready", menu)


func on_level(m) -> void:
	main = m
	emit_signal("level_ready", m)


# --- помощь для скриптов модов ---------------------------------------------

func flash(text: String, sec := 2.5) -> void:
	if main:
		main._flash(text, sec)


func add_money(n: int) -> void:
	if main:
		main.money = int(max(0, main.money + n))
		main._refresh_hud()


func add_line(kind: String, text: String, lang := "*") -> void:
	if text.count("%s") != 1:
		errors.append("add_line: a line needs exactly one %s: " + text)
		return
	if not lines.has(kind):
		lines[kind] = {}
	if not lines[kind].has(lang):
		lines[kind][lang] = []
	lines[kind][lang].append(text)
