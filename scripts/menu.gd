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
		if a == "--fakesteam=host":
			Game.tutorial_done = true
			Net.steam_host()
			Net.connect("peers_changed", Net, "start_shift", [], CONNECT_ONESHOT)
			return
		if a == "--fakesteam=join":
			Net.call_deferred("steam_join", 109775240000000555)
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
	_button(box, tr("Достижения"), "_achievements")
	_button(box, tr("Настройки"), "_settings")
	_button(box, tr("Выход"), "_quit")

	if Game.is_demo():
		var dl := Label.new()
		dl.text = tr("ДЕМОВЕРСИЯ")
		dl.add_font_override("font", font_big)
		dl.add_color_override("font_color", Color(1, 0.85, 0.3))
		dl.align = Label.ALIGN_CENTER
		dl.rect_position = Vector2(0, 112)
		dl.rect_size = Vector2(640, 16)
		add_child(dl)
	if Game.demo_over_pending:
		Game.demo_over_pending = false
		call_deferred("_demo_over")
	# Steam-приглашения: «Присоединиться» в списке друзей / +connect_lobby
	Net._hook_steam()
	Net.connect("lobby_ready", self, "_on_lobby_ready")
	if Net.pending_lobby != 0:
		call_deferred("_on_lobby_ready")

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
	if not Game.splash_done and not "--menushot" in OS.get_cmdline_args() and not "--settingsshot" in OS.get_cmdline_args() and not "--demoshot" in OS.get_cmdline_args() and not "--coopshot" in OS.get_cmdline_args():
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
	if "--demoshot" in OS.get_cmdline_args():
		yield(get_tree().create_timer(0.6), "timeout")
		_demo_over()
		yield(get_tree().create_timer(0.6), "timeout")
		var img4 := get_viewport().get_texture().get_data()
		img4.flip_y()
		img4.save_png(OS.get_environment("SHOT_DIR") + "/demo.png")
		get_tree().quit()
	if "--achshot" in OS.get_cmdline_args():
		Ach.unlock("ACH_FIRST_PARCEL")
		Ach.unlock("ACH_MAGA")
		yield(get_tree().create_timer(0.6), "timeout")
		_achievements()
		yield(get_tree().create_timer(0.8), "timeout")
		var img3 := get_viewport().get_texture().get_data()
		img3.flip_y()
		img3.save_png(OS.get_environment("SHOT_DIR") + "/ach.png")
		get_tree().quit()
	if "--coopshot" in OS.get_cmdline_args():
		_coop()
		yield(get_tree().create_timer(1.0), "timeout")
		var imgc := get_viewport().get_texture().get_data()
		imgc.flip_y()
		imgc.save_png(OS.get_environment("SHOT_DIR") + "/coop.png")
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


var ach_panel: Control


func _achievements() -> void:
	if ach_panel and is_instance_valid(ach_panel):
		ach_panel.queue_free()
	ach_panel = Ach.build_panel(font_big)
	var back := Button.new()
	back.text = tr("Назад")
	back.add_font_override("font", font_big)
	back.connect("pressed", ach_panel, "queue_free")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ach_panel.get_child(0).add_child(back)
	add_child(ach_panel)


func _settings() -> void:
	var sp = load("res://scripts/settings_panel.gd").new()
	sp.build(font_big)
	add_child(sp)


var demo_panel: Control


func _demo_over() -> void:
	if demo_panel and is_instance_valid(demo_panel):
		demo_panel.queue_free()
	var p := PanelContainer.new()
	p.theme = load("res://scripts/ui_theme.gd").make()
	p.rect_position = Vector2(110, 60)
	p.rect_min_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := Label.new()
	t.text = tr("Демо пройдено!")
	t.align = Label.ALIGN_CENTER
	t.add_font_override("font", font_big)
	load("res://scripts/ui_theme.gd").banner(t)
	v.add_child(t)
	var d := Label.new()
	d.text = tr("Спасибо, что сыграл! В полной версии тебя ждут 30 смен, 6 районов, Тёмный Почтмейстер, сейф, новые клиенты и украшения. Добавь игру в желаемое в Steam, чтобы не пропустить выход.")
	d.autowrap = true
	d.add_font_override("font", Ach._plain(font_big))
	d.rect_min_size = Vector2(400, 0)
	d.add_color_override("font_color", Color(0.3, 0.18, 0.08))
	v.add_child(d)
	if Game.STORE_APP_ID > 0:
		var b := Button.new()
		b.text = tr("Открыть страницу в Steam")
		b.add_font_override("font", font_big)
		b.connect("pressed", self, "_open_store")
		v.add_child(b)
	var back := Button.new()
	back.text = tr("В меню")
	back.add_font_override("font", font_big)
	back.connect("pressed", p, "queue_free")
	v.add_child(back)
	add_child(p)
	demo_panel = p


func _open_store() -> void:
	if Ach.steam:
		Ach.steam.activateGameOverlayToStore(Game.STORE_APP_ID, 0)
	else:
		OS.shell_open("https://store.steampowered.com/app/%d/" % Game.STORE_APP_ID)


func _continue() -> void:
	if Game.is_demo() and Game.has_save():
		Game.load_game()
		if Game.demo_locked():
			_demo_over()
			return
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
var nick_edit: LineEdit
var invite_btn: Button
var friends_box: VBoxContainer
var _friends_t := 0.0


func _coop() -> void:
	if coop_panel:
		coop_panel.visible = true
		_refresh_friends()
		return
	coop_panel = PanelContainer.new()
	coop_panel.theme = load("res://scripts/ui_theme.gd").make()
	coop_panel.rect_position = Vector2(120, 24)
	coop_panel.rect_min_size = Vector2(400, 200)
	add_child(coop_panel)
	var v := VBoxContainer.new()
	coop_panel.add_child(v)
	var t := Label.new()
	t.add_font_override("font", font_big)
	t.align = Label.ALIGN_CENTER
	t.text = tr("ИГРА С ДРУЗЬЯМИ (до 4 человек, бета)")
	v.add_child(t)
	var nr := HBoxContainer.new()
	v.add_child(nr)
	var nl := Label.new()
	nl.text = tr("Твой ник  ")
	nl.add_font_override("font", font_big)
	nr.add_child(nl)
	nick_edit = LineEdit.new()
	nick_edit.text = Settings.look.get("nick", "")
	nick_edit.placeholder_text = tr("Игрок")
	nick_edit.max_length = 16
	nick_edit.rect_min_size = Vector2(180, 0)
	nick_edit.add_font_override("font", font_big)
	nick_edit.connect("text_changed", self, "_on_nick")
	nr.add_child(nick_edit)
	var fs: DynamicFont = font_big.duplicate()
	fs.size = 11
	if Net.has_steam():
		var sl := Label.new()
		sl.text = tr("Через Steam (без портов и IP)")
		sl.add_font_override("font", fs)
		sl.modulate = Color(1, 0.85, 0.4)
		v.add_child(sl)
		var sr := HBoxContainer.new()
		v.add_child(sr)
		_button(sr, tr("Создать лобби"), "_coop_steam_host")
		invite_btn = _button(sr, tr("Пригласить друга"), "_coop_invite")
		invite_btn.disabled = Net.lobby_id == 0
		friends_box = VBoxContainer.new()
		v.add_child(friends_box)
		_refresh_friends()
	var ll := Label.new()
	ll.text = tr("По IP (локальная сеть или VPN)")
	ll.add_font_override("font", fs)
	ll.modulate = Color(1, 0.85, 0.4)
	v.add_child(ll)
	var row := HBoxContainer.new()
	v.add_child(row)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.secret = Settings.streamer  # режим стримера: IP не видно на экране
	ip_edit.rect_min_size = Vector2(130, 0)
	ip_edit.add_font_override("font", font_big)
	row.add_child(ip_edit)
	_button(row, tr("Подключиться"), "_coop_join")
	_button(row, tr("Хост по IP"), "_coop_host")
	coop_status = Label.new()
	coop_status.add_font_override("font", fs)
	coop_status.autowrap = true
	coop_status.rect_min_size = Vector2(380, 30)
	if Net.has_steam():
		coop_status.text = tr("Создай лобби и позови друга, или зайди к другу из списка. Друг может нажать «Присоединиться» в друзьях Steam.")
	else:
		coop_status.text = tr("Хост делится своим IP. Нужен открытый порт %d (UDP) или общий VPN (Radmin VPN, Hamachi).") % Net.PORT
	v.add_child(coop_status)
	var br := HBoxContainer.new()
	br.alignment = BoxContainer.ALIGN_CENTER
	v.add_child(br)
	start_btn = _button(br, tr("Начать смену"), "_coop_start")
	start_btn.disabled = not (Net.active and Net.is_host)
	_button(br, tr("Назад"), "_coop_back")
	Net.connect("status", self, "_on_net_status")
	Net.connect("peers_changed", self, "_on_peers")


func _prepare_host() -> void:
	if Net.active:
		Net.leave()
	if not Game.load_game():
		Game.new_game()
	Game.tutorial_done = true


func _coop_host() -> void:
	_prepare_host()
	if Net.host() and start_btn:
		start_btn.disabled = false  # можно начать и одному, друзья подключатся к следующей смене


func _coop_steam_host() -> void:
	_prepare_host()
	Net.steam_host()


func _coop_invite() -> void:
	Net.invite()


func _coop_join() -> void:
	if Net.active:
		Net.leave()
	Net.join(ip_edit.text)


func _coop_join_lobby(lid: int) -> void:
	Net.steam_join(lid)


func _on_lobby_ready() -> void:
	if Net.pending_lobby != 0:
		var lid := Net.pending_lobby
		_coop()
		Net.steam_join(lid)
		return
	if invite_btn:
		invite_btn.disabled = Net.lobby_id == 0 or not Net.is_host
	if start_btn:
		start_btn.disabled = not Net.is_host
	_refresh_friends()


func _refresh_friends() -> void:
	if friends_box == null:
		return
	for c in friends_box.get_children():
		c.queue_free()
	var list: Array = Net.friends_in_lobbies()
	for i in min(list.size(), 3):
		var b := Button.new()
		b.text = tr("Зайти к %s") % (tr("другу %d") % (i + 1) if Settings.streamer else list[i][0])
		b.add_font_override("font", font_big)
		b.connect("pressed", self, "_coop_join_lobby", [list[i][1]])
		friends_box.add_child(b)


func _coop_start() -> void:
	Net.start_shift()


func _coop_back() -> void:
	Net.leave()
	if invite_btn:
		invite_btn.disabled = true
	if start_btn:
		start_btn.disabled = true
	coop_panel.visible = false


func _on_net_status(t: String) -> void:
	if coop_status:
		coop_status.text = t


func _on_peers() -> void:
	if start_btn:
		start_btn.disabled = not Net.is_host



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
	if coop_panel and coop_panel.visible and friends_box and not Net.active:
		_friends_t += delta
		if _friends_t > 3.0:
			_friends_t = 0.0
			_refresh_friends()
	if logo and _lt > 0.8:
		logo.rect_rotation = sin(_lt * 1.6) * 1.5
		var k := 1.0 + sin(_lt * 2.3) * 0.02
		logo.rect_scale = Vector2(k, k)


func _on_nick(t: String) -> void:
	Settings.look["nick"] = t.strip_edges()
	Settings.save_cfg()
