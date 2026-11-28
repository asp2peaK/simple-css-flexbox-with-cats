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
	# две колонки, чтобы всё влезало в 640x360 при любом размере окна
	rect_position = Vector2(14, 24)
	rect_min_size = Vector2(612, 0)
	var v := VBoxContainer.new()
	add_child(v)
	_title(v, tr("НАСТРОЙКИ"))
	var cols := HBoxContainer.new()
	cols.add_constant_override("separation", 14)
	v.add_child(cols)
	var left := VBoxContainer.new()
	cols.add_child(left)
	var right := VBoxContainer.new()
	cols.add_child(right)
	var grid := GridContainer.new()
	grid.columns = 2
	left.add_child(grid)
	_slider(grid, tr("Музыка"), Settings.music, "_on_music")
	_slider(grid, tr("Звуки"), Settings.sfx, "_on_sfx")
	_slider(grid, tr("Чувствительность мыши"), (Settings.sens - 0.3) / 1.7, "_on_sens")
	var fs := CheckBox.new()
	fs.text = tr("Полный экран")
	fs.pressed = Settings.fullscreen
	fs.add_font_override("font", font)
	fs.connect("toggled", self, "_on_fs")
	left.add_child(fs)
	var vs := CheckBox.new()
	vs.text = tr("Вертикальная синхронизация")
	vs.pressed = Settings.vsync
	vs.add_font_override("font", font)
	vs.connect("toggled", self, "_on_vsync")
	left.add_child(vs)
	var row := HBoxContainer.new()
	right.add_child(row)
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
	right.add_child(row2)
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
	right.add_child(row3)
	var l3 := Label.new()
	l3.text = tr("Язык / Language  ")
	l3.add_font_override("font", font)
	row3.add_child(l3)
	var lg := OptionButton.new()
	lg.add_font_override("font", font)
	for nm in Settings.LANG_NAMES:
		lg.add_item(nm)
	lg.selected = max(0, Settings.LANGS.find(Settings.lang))
	lg.connect("item_selected", self, "_on_lang")
	row3.add_child(lg)
	var row4 := HBoxContainer.new()
	right.add_child(row4)
	var l4 := Label.new()
	l4.text = tr("Twitch-канал  ")
	l4.add_font_override("font", font)
	row4.add_child(l4)
	var tw := LineEdit.new()
	tw.text = Settings.twitch
	tw.placeholder_text = tr("ник канала")
	tw.secret = Settings.streamer
	tw.rect_min_size = Vector2(150, 0)
	tw.add_font_override("font", font)
	tw.connect("text_entered", self, "_on_twitch")
	tw.connect("focus_exited", self, "_on_twitch_focus", [tw])
	row4.add_child(tw)
	# статус подключения и как это работает
	var ts := Label.new()
	var small: DynamicFont = font.duplicate()
	small.size = 12
	small.use_filter = true
	ts.add_font_override("font", small)
	ts.autowrap = true
	ts.rect_min_size = Vector2(290, 0)
	ts.modulate = Color(1, 1, 1, 0.85)
	right.add_child(ts)
	_tw_status = ts
	_on_tw_status(Twitch.status)
	Twitch.connect("status_changed", self, "_on_tw_status")
	var kb := Button.new()
	kb.text = tr("Управление (клавиши)")
	kb.add_font_override("font", font)
	kb.connect("pressed", self, "_open_keys")
	var row5 := HBoxContainer.new()
	row5.alignment = BoxContainer.ALIGN_CENTER
	v.add_child(row5)
	row5.add_child(kb)
	var lb := Button.new()
	lb.text = tr("Папка с логами")
	lb.add_font_override("font", font)
	lb.connect("pressed", Settings, "open_logs")
	row5.add_child(lb)
	var sm := CheckBox.new()
	sm.text = tr("Режим стримера (скрыть ники и IP)")
	sm.pressed = Settings.streamer
	sm.add_font_override("font", font)
	sm.connect("toggled", self, "_on_streamer")
	left.add_child(sm)
	var close := Button.new()
	close.text = tr("Готово")
	close.add_font_override("font", font)
	close.connect("pressed", self, "_close")
	row5.add_child(close)


func _on_streamer(on: bool) -> void:
	Settings.streamer = on
	Settings.save_cfg()


var _tw_status: Label


func _on_tw_status(st: String) -> void:
	if _tw_status == null or not is_instance_valid(_tw_status):
		return
	var hint := tr("Во время смены чат голосует за события: зрители пишут 1, 2 или 3.")
	_tw_status.text = (st + "\n" + hint) if st != "" else tr("Впиши ник своего канала и нажми Enter.") + " " + hint


func _exit_tree() -> void:
	if Twitch.is_connected("status_changed", self, "_on_tw_status"):
		Twitch.disconnect("status_changed", self, "_on_tw_status")


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


func _slider(row: Control, text: String, value: float, cb: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_font_override("font", font)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = value
	s.rect_min_size = Vector2(110, 16)
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
	Settings.lang = Settings.LANGS[i]
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
	keys_panel.rect_position = Vector2(150, 14)
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
		b.text = Settings.bind_name(int(Settings.keys[a]))
		b.connect("pressed", self, "_wait_key", [a])
		row.add_child(b)
		_key_buttons[a] = b
	var info := Label.new()
	info.text = tr("Можно назначать клавиши и кнопки мыши. Геймпад: левый стик — ходить, правый — смотреть, RT — взять/бросить, LT/B — поставить, A — нажать, Start — пауза.")
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
	if _wait_action == "" and event.is_action_pressed("ui_cancel"):
		# Esc: сначала окно клавиш, потом сами настройки
		if keys_panel and is_instance_valid(keys_panel):
			_close_keys()
		else:
			_close()
		get_tree().set_input_as_handled()
		return
	if _wait_action == "" or not event.pressed:
		return
	var code := 0
	if event is InputEventKey:
		if event.physical_scancode != KEY_ESCAPE:
			code = event.physical_scancode
	elif event is InputEventMouseButton:
		if event.button_index in [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN]:
			return
		code = -event.button_index
	else:
		return
	if code != 0:
		# эта кнопка уже занята другим действием — меняем их местами
		var old: int = int(Settings.keys[_wait_action])
		for a in Settings.keys:
			if a != _wait_action and int(Settings.keys[a]) == code:
				Settings.keys[a] = old
				if _key_buttons.has(a):
					_key_buttons[a].text = Settings.bind_name(old)
		Settings.keys[_wait_action] = code
		Settings.apply_keys()
		Settings.save_cfg()
	_key_buttons[_wait_action].text = Settings.bind_name(int(Settings.keys[_wait_action]))
	_wait_action = ""
	get_tree().set_input_as_handled()


func _reset_keys() -> void:
	Settings.keys = Settings.DEFAULT_KEYS.duplicate()
	Settings.apply_keys()
	Settings.save_cfg()
	for a in _key_buttons:
		_key_buttons[a].text = Settings.bind_name(int(Settings.keys[a]))


func _close_keys() -> void:
	keys_panel.queue_free()
	keys_panel = null


func _close() -> void:
	Settings.save_cfg()
	visible = false
	emit_signal("closed")
