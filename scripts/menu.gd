extends Control
# Главное меню.

var font_big: DynamicFont
var font_title: DynamicFont
var logo: TextureRect
var _lt := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a == "--nethost":  # тест сети: хост сам начинает, когда кто-то подключится
			Game.tutorial_done = true
			Net.host()
			Net.connect("peers_changed", Net, "start_shift", [], CONNECT_ONESHOT)
			return
		if a.begins_with("--netjoin="):
			Net.join(a.substr(10))
			return
		if a.begins_with("--shot") or a.begins_with("--test"):
			Game.tutorial_done = true
			get_tree().change_scene("res://main.tscn")
			return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	anchor_right = 1
	anchor_bottom = 1
	var data = load("res://fonts/DejaVuSans-Bold.ttf")
	font_big = DynamicFont.new()
	font_big.font_data = data
	font_big.size = 14
	font_big.outline_size = 1
	font_big.outline_color = Color(0, 0, 0)
	font_title = DynamicFont.new()
	font_title.font_data = data
	font_title.size = 34
	font_title.outline_size = 3
	font_title.outline_color = Color(0.2, 0.05, 0.05)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.07)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	add_child(bg)
	if ResourceLoader.exists("res://assets/ui/menu_bg.png"):
		var bgtex := TextureRect.new()
		bgtex.texture = load("res://assets/ui/menu_bg.png")
		bgtex.expand = true
		bgtex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bgtex.anchor_right = 1
		bgtex.anchor_bottom = 1
		add_child(bgtex)
	else:
		# временный фон: клиенты в очереди
		var x := 30
		for k in ["witch", "orc", "skeleton", "goblin", "vampire", "dragon", "ghost", "dwarf"]:
			var t: Texture = load("res://assets/chars/%s_idle.png" % k)
			t.flags = 0
			var tr2 := TextureRect.new()
			tr2.texture = t
			tr2.rect_position = Vector2(x, 360 - t.get_height() - 10)
			add_child(tr2)
			x += t.get_width() + 6

	if ResourceLoader.exists("res://assets/ui/logo.png"):
		var lg := TextureRect.new()
		var lt: Texture = load("res://assets/ui/logo.png")
		lt.flags = 0
		lg.texture = lt
		lg.rect_position = Vector2((640 - lt.get_width()) / 2, 8)
		lg.rect_pivot_offset = Vector2(lt.get_width() / 2.0, lt.get_height() / 2.0)
		add_child(lg)
		logo = lg
		# лого влетает сверху и потом покачивается
		lg.rect_position.y = -130
		var tw := create_tween()
		tw.tween_property(lg, "rect_position:y", 8.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		var title := Label.new()
		title.add_font_override("font", font_title)
		title.add_color_override("font_color", Color(1, 0.8, 0.3))
		title.text = "NOT MY PARCEL!"
		title.align = Label.ALIGN_CENTER
		title.rect_position = Vector2(0, 30)
		title.rect_size = Vector2(640, 90)
		add_child(title)
	Sfx.play_music("music_menu")
	Sfx.set_ambient(false)

	var box := VBoxContainer.new()
	box.theme = load("res://scripts/ui_theme.gd").make()
	box.rect_position = Vector2(240, 130)
	box.rect_min_size = Vector2(160, 100)
	add_child(box)
	if Game.mode != "chaos" and Game.has_save() and not Net.active:
		Game.load_game()  # чтобы показать рекорд хаоса
	if Game.mode == "chaos":
		Game.end_chaos(0)  # вышли из хаоса посреди смены: карьеру возвращаем
	var cont := _button(box, tr("Продолжить"), "_continue")
	cont.disabled = not Game.has_save()
	_button(box, tr("Новая игра"), "_new_game")
	var ch := _button(box, tr("Режим хаоса"), "_chaos")
	if Game.chaos_best > 0:
		ch.text = tr("Режим хаоса") + " (" + tr("рекорд") + " %d)" % Game.chaos_best
	_button(box, tr("Играть с друзьями"), "_coop")
	_button(box, tr("Настройки"), "_settings")
	_button(box, tr("Выход"), "_quit")

	var help := Label.new()
	help.add_font_override("font", font_big)
	help.modulate = Color(1, 1, 1, 0.7)
	help.text = "v%s  ·  2peaK's Studio" % Game.VERSION
	help.align = Label.ALIGN_RIGHT
	help.rect_position = Vector2(0, 342)
	help.rect_size = Vector2(632, 16)
	var fs: DynamicFont = font_big.duplicate()
	fs.size = 9
	help.add_font_override("font", fs)
	add_child(help)
	if not Game.splash_done and not "--menushot" in OS.get_cmdline_args() and not "--settingsshot" in OS.get_cmdline_args():
		Game.splash_done = true
		_studio_splash()
	if Settings.reopen_settings:
		Settings.reopen_settings = false
		_settings()
	if "--settingsshot" in OS.get_cmdline_args():
		yield(get_tree().create_timer(0.5), "timeout")
		_settings()
		yield(get_tree().create_timer(0.8), "timeout")
		var img2 := get_viewport().get_texture().get_data()
		img2.flip_y()
		img2.save_png(OS.get_environment("SHOT_DIR") + "/settings.png")
		get_tree().quit()
	if "--menushot" in OS.get_cmdline_args():
		yield(get_tree().create_timer(1.0), "timeout")
		var img := get_viewport().get_texture().get_data()
		img.flip_y()
		img.save_png(OS.get_environment("SHOT_DIR") + "/menu.png")
		get_tree().quit()


func _button(parent: Control, text: String, target: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_font_override("font", font_big)
	b.connect("pressed", self, target)
	parent.add_child(b)
	return b


func _settings() -> void:
	var sp = load("res://scripts/settings_panel.gd").new()
	sp.build(font_big)
	add_child(sp)


func _continue() -> void:
	if Game.load_game():
		Game.roll_event()
		Game.phase = "closed"
		get_tree().change_scene("res://main.tscn")


func _chaos() -> void:
	if Game.has_save():
		Game.load_game()
	Game.start_chaos()
	Game.phase = "open"
	get_tree().change_scene("res://main.tscn")


func _new_game() -> void:
	Game.new_game()
	Game.phase = "closed"
	Game.save_game()
	get_tree().change_scene("res://main.tscn")


func _quit() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- кооп
var coop_panel: PanelContainer
var ip_edit: LineEdit
var coop_status: Label
var start_btn: Button


func _coop() -> void:
	if coop_panel:
		coop_panel.visible = true
		return
	coop_panel = PanelContainer.new()
	coop_panel.theme = load("res://scripts/ui_theme.gd").make()
	coop_panel.rect_position = Vector2(150, 90)
	coop_panel.rect_min_size = Vector2(340, 200)
	add_child(coop_panel)
	var v := VBoxContainer.new()
	coop_panel.add_child(v)
	var t := Label.new()
	t.add_font_override("font", font_big)
	t.align = Label.ALIGN_CENTER
	t.text = tr("ИГРА С ДРУЗЬЯМИ (до 4 человек, бета)")
	v.add_child(t)
	_button(v, tr("Создать игру (я хост)"), "_coop_host")
	var row := HBoxContainer.new()
	v.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.rect_min_size = Vector2(180, 0)
	ip_edit.add_font_override("font", font_big)
	row.add_child(ip_edit)
	_button(row, tr("Подключиться"), "_coop_join")
	coop_status = Label.new()
	coop_status.add_font_override("font", font_big)
	coop_status.autowrap = true
	coop_status.rect_min_size = Vector2(320, 40)
	coop_status.text = tr("Хост делится своим IP. Нужен открытый порт %d (UDP) или общий VPN (Radmin VPN, Hamachi).") % Net.PORT
	v.add_child(coop_status)
	start_btn = _button(v, tr("Начать смену"), "_coop_start")
	start_btn.disabled = true
	_button(v, tr("Назад"), "_coop_back")
	Net.connect("status", self, "_on_net_status")
	Net.connect("peers_changed", self, "_on_peers")


func _coop_host() -> void:
	if Net.active:
		Net.leave()
	if not Game.load_game():
		Game.new_game()
	Game.tutorial_done = true
	Net.host()


func _coop_join() -> void:
	if Net.active:
		Net.leave()
	Net.join(ip_edit.text)


func _coop_start() -> void:
	Net.start_shift()


func _coop_back() -> void:
	Net.leave()
	coop_panel.visible = false


func _on_net_status(t: String) -> void:
	if coop_status:
		coop_status.text = t


func _on_peers() -> void:
	if start_btn:
		start_btn.disabled = not (Net.is_host and not Net.peers.empty())



var _splash: Control


func _studio_splash() -> void:
	# заставка «2peaK's Studio»: держится пару секунд, клик или клавиша пропускает
	_splash = ColorRect.new()
	_splash.color = Color(0.07, 0.05, 0.07)
	_splash.anchor_right = 1
	_splash.anchor_bottom = 1
	add_child(_splash)
	var bgtex := TextureRect.new()
	bgtex.texture = load("res://assets/ui/splash.png")
	bgtex.expand = true
	bgtex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bgtex.anchor_right = 1
	bgtex.anchor_bottom = 1
	_splash.add_child(bgtex)
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(_splash, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_splash, "queue_free")


func _input(event: InputEvent) -> void:
	if _splash and is_instance_valid(_splash) and (event is InputEventMouseButton or event is InputEventKey) and event.pressed:
		_splash.queue_free()
		_splash = null
		get_tree().set_input_as_handled()



func _process(delta: float) -> void:
	_lt += delta
	if logo and _lt > 0.8:
		logo.rect_rotation = sin(_lt * 1.6) * 1.5
		var k := 1.0 + sin(_lt * 2.3) * 0.02
		logo.rect_scale = Vector2(k, k)
