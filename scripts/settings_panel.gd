extends PanelContainer
# Окно настроек (используется в главном меню и в паузе).

signal closed

var font: Font


func build(f: Font) -> void:
	theme = load("res://scripts/ui_theme.gd").make()
	font = f.duplicate()
	if font is DynamicFont:
		font.outline_size = 0  # тёмный текст на пергаменте без обводки
	pause_mode = Node.PAUSE_MODE_PROCESS
	rect_position = Vector2(150, 30)
	rect_min_size = Vector2(340, 290)
	var v := VBoxContainer.new()
	add_child(v)
	_title(v, tr("НАСТРОЙКИ"))
	_slider(v, tr("Музыка"), Settings.music, "_on_music")
	_slider(v, tr("Звуки"), Settings.sfx, "_on_sfx")
	_slider(v, tr("Чувствительность мыши"), (Settings.sens - 0.3) / 1.7, "_on_sens")
	var fs := CheckBox.new()
	fs.text = tr("Полный экран")
	fs.pressed = Settings.fullscreen
	fs.add_font_override("font", font)
	fs.connect("toggled", self, "_on_fs")
	v.add_child(fs)
	var vs := CheckBox.new()
	vs.text = tr("Вертикальная синхронизация")
	vs.pressed = Settings.vsync
	vs.add_font_override("font", font)
	vs.connect("toggled", self, "_on_vsync")
	v.add_child(vs)
	var row := HBoxContainer.new()
	v.add_child(row)
	var l := Label.new()
	l.text = tr("Размер окна  ")
	l.add_font_override("font", font)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.add_font_override("font", font)
	for r in Settings.RESOLUTIONS:
		ob.add_item("%d x %d" % [r.x, r.y])
	ob.selected = Settings.res_idx
	ob.connect("item_selected", self, "_on_res")
	row.add_child(ob)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	var l2 := Label.new()
	l2.text = tr("Картинка  ")
	l2.add_font_override("font", font)
	row2.add_child(l2)
	var q := OptionButton.new()
	q.add_font_override("font", font)
	q.add_item(tr("Чёткая (как окно)"))
	q.add_item(tr("Пиксельная 640x360"))
	q.selected = 0 if Settings.sharp else 1
	q.connect("item_selected", self, "_on_sharp")
	row2.add_child(q)
	var row3 := HBoxContainer.new()
	v.add_child(row3)
	var l3 := Label.new()
	l3.text = tr("Язык / Language  ")
	l3.add_font_override("font", font)
	row3.add_child(l3)
	var lg := OptionButton.new()
	lg.add_font_override("font", font)
	lg.add_item(tr("Русский"))
	lg.add_item("English")
	lg.selected = 1 if Settings.lang == "en" else 0
	lg.connect("item_selected", self, "_on_lang")
	row3.add_child(lg)
	var row4 := HBoxContainer.new()
	v.add_child(row4)
	var l4 := Label.new()
	l4.text = tr("Twitch-канал  ")
	l4.add_font_override("font", font)
	row4.add_child(l4)
	var tw := LineEdit.new()
	tw.text = Settings.twitch
	tw.placeholder_text = tr("ник канала")
	tw.rect_min_size = Vector2(170, 0)
	tw.add_font_override("font", font)
	tw.connect("text_entered", self, "_on_twitch")
	tw.connect("focus_exited", self, "_on_twitch_focus", [tw])
	row4.add_child(tw)
	var kb := Button.new()
	kb.text = tr("Управление (клавиши)")
	kb.add_font_override("font", font)
	kb.connect("pressed", self, "_open_keys")
	v.add_child(kb)
	var close := Button.new()
	close.text = tr("Готово")
	close.add_font_override("font", font)
	close.connect("pressed", self, "_close")
	v.add_child(close)


func _on_twitch(t: String) -> void:
	t = t.strip_edges()
	if t == Settings.twitch:
		return
	Settings.twitch = t
	Settings.save_cfg()
	Twitch.start(t)


func _on_twitch_focus(e: LineEdit) -> void:
	_on_twitch(e.text)


func _title(v: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.align = Label.ALIGN_CENTER
	l.add_font_override("font", font)
	load("res://scripts/ui_theme.gd").banner(l)
	v.add_child(l)


func _slider(v: Control, text: String, value: float, cb: String) -> void:
	var row := HBoxContainer.new()
	v.add_child(row)
	var l := Label.new()
	l.text = text
	l.rect_min_size = Vector2(150, 0)
	l.add_font_override("font", font)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = value
	s.rect_min_size = Vector2(160, 16)
	s.connect("value_changed", self, cb)
	row.add_child(s)


func _on_music(v: float) -> void:
	Settings.music = v
	Settings.apply()


func _on_sfx(v: float) -> void:
	Settings.sfx = v
	Settings.apply()
	Sfx.play("coin", 0.0, -6.0)


func _on_sens(v: float) -> void:
	Settings.sens = 0.3 + v * 1.7


func _on_fs(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()


func _on_vsync(on: bool) -> void:
	Settings.vsync = on
	Settings.apply()


func _on_res(i: int) -> void:
	Settings.res_idx = i
	Settings.apply()


func _on_sharp(i: int) -> void:
	Settings.sharp = i == 0
	Settings.apply()


func _on_lang(i: int) -> void:
	Settings.lang = "en" if i == 1 else "ru"
	Settings.apply()
	Settings.save_cfg()
	# перезапускаем сцену, чтобы все надписи и коробки сменили язык, и снова открываем настройки
	var sc = get_tree().current_scene
	if sc.name == "Menu":
		Settings.reopen_settings = true
		get_tree().reload_current_scene()
	elif sc.has_method("relang") and sc.relang():
		Settings.reopen_settings = true


# ---- переназначение клавиш
var keys_panel: PanelContainer
var _wait_action := ""
var _key_buttons := {}


func _open_keys() -> void:
	if keys_panel:
		keys_panel.queue_free()
	keys_panel = PanelContainer.new()
	keys_panel.pause_mode = Node.PAUSE_MODE_PROCESS
	keys_panel.rect_position = Vector2(160, 40)
	keys_panel.rect_min_size = Vector2(320, 250)
	get_parent().add_child(keys_panel)
	var v := VBoxContainer.new()
	keys_panel.add_child(v)
	_title(v, tr("УПРАВЛЕНИЕ"))
	_key_buttons = {}
	for a in Settings.DEFAULT_KEYS:
		var row := HBoxContainer.new()
		v.add_child(row)
		var l := Label.new()
		l.text = tr(Settings.KEY_NAMES[a])
		l.rect_min_size = Vector2(170, 0)
		l.add_font_override("font", font)
		row.add_child(l)
		var b := Button.new()
		b.rect_min_size = Vector2(120, 0)
		b.add_font_override("font", font)
		b.text = OS.get_scancode_string(int(Settings.keys[a]))
		b.connect("pressed", self, "_wait_key", [a])
		row.add_child(b)
		_key_buttons[a] = b
	var info := Label.new()
	info.text = tr("Мышь: ЛКМ — взять, зажать — бросить, ПКМ — поставить. ESC — пауза.")
	info.autowrap = true
	info.rect_min_size = Vector2(300, 0)
	info.add_font_override("font", font)
	info.modulate = Color(1, 1, 1, 0.7)
	v.add_child(info)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	var rs := Button.new()
	rs.text = tr("Сбросить")
	rs.add_font_override("font", font)
	rs.connect("pressed", self, "_reset_keys")
	row2.add_child(rs)
	var ok := Button.new()
	ok.text = tr("Готово")
	ok.add_font_override("font", font)
	ok.connect("pressed", self, "_close_keys")
	row2.add_child(ok)


func _wait_key(a: String) -> void:
	_wait_action = a
	_key_buttons[a].text = tr("нажми клавишу...")


func _input(event: InputEvent) -> void:
	if _wait_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	if event.physical_scancode != KEY_ESCAPE:
		Settings.keys[_wait_action] = event.physical_scancode
		Settings.apply_keys()
		Settings.save_cfg()
	_key_buttons[_wait_action].text = OS.get_scancode_string(int(Settings.keys[_wait_action]))
	_wait_action = ""
	get_tree().set_input_as_handled()


func _reset_keys() -> void:
	Settings.keys = Settings.DEFAULT_KEYS.duplicate()
	Settings.apply_keys()
	Settings.save_cfg()
	for a in _key_buttons:
		_key_buttons[a].text = OS.get_scancode_string(int(Settings.keys[a]))


func _close_keys() -> void:
	keys_panel.queue_free()
	keys_panel = null


func _close() -> void:
	Settings.save_cfg()
	visible = false
	emit_signal("closed")
