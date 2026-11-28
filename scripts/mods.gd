extends Node
# Моды. Ищем в двух местах:
#   <папка с игрой>/mods/   и   user://mods/   (%APPDATA%/Godot/app_userdata/<игра>/mods)
# Что умеет мод (см. MODDING.md):
#   *.pck / *.zip рядом — заменяет любые ресурсы игры (собирается в Godot 3.6 как обычный экспорт)
#   папка с mod.json — {"name", "author", "version", "description", "languages": {"pl": "Polski"}}
#     lang/<код>.json — переводы (ключ — русская строка), можно добавить новый язык
#     lines.json      — новые фразы клиентов: {"orc": {"*": ["..%s.."], "en": [...]}, ...}

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
				errors.append("не удалось загрузить " + p)


func _json(path: String):
	var f := File.new()
	if f.open(path, File.READ) != OK:
		return null
	var r := JSON.parse(f.get_as_text())
	f.close()
	if r.error != OK:
		errors.append("%s: строка %d: %s" % [path, r.error_line, r.error_string])
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
						errors.append("%s: фраза без одного %%s: %s" % [nm, str(s)])
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
