extends Node
# Съёмка скриншотов для магазина и клипов для трейлера.
# Запуск: main.tscn --showcase=<сцена> [--rec=<папка>] [--still=<файл.png>] [--len=<сек>]
# Вместе с --fixed-fps 30 каждый кадр сохраняется в папку, а ffmpeg потом собирает видео.

var m
var rec_dir := ""
var still := ""
var length := 6.0
var _n := 0
var _t := 0.0
var _rec := false
var _cam_from := []
var _cam_to := []
var _move := []  # [узел, откуда, куда]
var _track = null  # камера следит за этим узлом
var hud := false
var follow := false  # камера едет за _track на расстоянии ~1 м
var eye := -1.0  # своя высота камеры (для низких ракурсов)


func run(main, scene: String) -> void:
	m = main
	pause_mode = Node.PAUSE_MODE_PROCESS
	for a in OS.get_cmdline_args():
		if a.begins_with("--rec="):
			rec_dir = a.substr(6)
		if a.begins_with("--still="):
			still = a.substr(8)
		if a.begins_with("--len="):
			length = float(a.substr(6))
		if a == "--hud":
			hud = true
	Game.tutorial_done = true
	m.tut_step = -1
	Ach._busy = true  # без всплывашек «Достижение получено» в кадре
	VisualServer.connect("frame_post_draw", self, "_post_draw")
	call(scene)


func _process(delta: float) -> void:
	if m == null or m.player == null:
		return
	if m.hud_tut:
		m.hud_tut.visible = false
	if not hud:
		_hide_hud()
	if eye > 0.0:
		m.player.cam.translation.y = eye
	if _rec:
		_t += delta
		var k: float = clamp(_t / length, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		if not _cam_from.empty():
			m.player.global_transform.origin = _cam_from[0].linear_interpolate(_cam_to[0], k)
			m.player.rotation = Vector3(0, lerp_angle(_cam_from[1], _cam_to[1], k), 0)
			m.player.cam.rotation.x = lerp(_cam_from[2], _cam_to[2], k)
		if follow and _track and is_instance_valid(_track):
			var tp: Vector3 = _track.global_transform.origin
			var cp: Vector3 = m.player.global_transform.origin
			var off := Vector3(cp.x - tp.x, 0, cp.z - tp.z)
			if off.length() > 0.01:
				var want: Vector3 = tp + off.normalized() * 1.0
				m.player.global_transform.origin = cp.linear_interpolate(Vector3(want.x, cp.y, want.z), min(1.0, delta * 3.0))
		if _track and is_instance_valid(_track):
			_aim(_track.global_transform.origin + Vector3(0, 0.3 if eye < 0.0 else 0.1, 0))
		for mv in _move:
			if is_instance_valid(mv[0]):
				var pos: Vector3 = mv[1].linear_interpolate(mv[2], clamp(_t / length, 0.0, 1.0))
				mv[0].net_set(pos, PI, 0.0)


func _post_draw() -> void:
	if not _rec:
		return
	if rec_dir != "":
		var img := get_viewport().get_texture().get_data()
		img.flip_y()
		img.save_png(rec_dir + "/f_%05d.png" % _n)
	_n += 1
	if still != "" and _t >= length * 0.5:
		var img2 := get_viewport().get_texture().get_data()
		img2.flip_y()
		img2.save_png(still)
		print("still ", still, " cam ", m.player.cam.global_transform.origin, " yaw ", rad2deg(m.player.rotation.y), " pos ", m.player.global_transform.origin)
		still = ""
	if _t >= length:
		print("frames ", _n)
		get_tree().quit()


func _hide_hud() -> void:
	for ch in m.get_children():
		if ch is CanvasLayer and ch.get_child_count() > 0:
			for w in ch.get_child(0).get_children():
				if w is Label and not w in m.hud_bubbles and not w.has_meta("keep"):
					w.visible = false
			return


# повернуть камеру игрока на точку (глаза на высоте 1.6 м)
func _aim(t: Vector3) -> void:
	var p: Vector3 = m.player.global_transform.origin + Vector3(0, eye if eye > 0.0 else 1.6, 0)
	var d := t - p
	m.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	m.player.cam.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _yaw_to(from: Vector3, t: Vector3) -> float:
	var d := t - from
	return rad2deg(atan2(-d.x, -d.z))


func _pitch_to(from: Vector3, t: Vector3) -> float:
	var d := t - (from + Vector3(0, eye if eye > 0.0 else 1.6, 0))
	return atan2(d.y, Vector2(d.x, d.z).length())


# камера едет из точки в точку, глядя на цели
func _dolly(a: Vector3, at_a: Vector3, b: Vector3, at_b: Vector3) -> void:
	_cam(a, _yaw_to(a, at_a), _pitch_to(a, at_a), b, _yaw_to(b, at_b), _pitch_to(b, at_b))


func _cam(from_pos: Vector3, from_yaw: float, from_pitch: float, to_pos: Vector3, to_yaw: float, to_pitch: float) -> void:
	_cam_from = [from_pos, deg2rad(from_yaw), from_pitch]
	_cam_to = [to_pos, deg2rad(to_yaw), to_pitch]
	m.player.global_transform.origin = from_pos
	m.player.rotation = Vector3(0, deg2rad(from_yaw), 0)
	m.player.cam.rotation.x = from_pitch


func _start() -> void:
	_t = 0.0
	_rec = true


func _wait(sec: float):
	return get_tree().create_timer(sec)


func _right_parcel(c):
	for q in m.parcels:
		if is_instance_valid(q) and q.code == c.order and not q.delivered:
			return q
	return null


func _at_counter() -> Array:
	var out := []
	for c in m.customers:
		if is_instance_valid(c) and c.state == "at_counter":
			out.append(c)
	return out


# ---- сцены
func counter() -> void:
	# очередь у окон, камера проезжает вдоль стойки
	for i in 3:
		m._spawn_customer()
		yield(_wait(1.0), "timeout")
	yield(_wait(7.5), "timeout")
	_dolly(Vector3(1.4, 0.05, -2.0), Vector3(-0.6, 1.3, 1.2), Vector3(-1.0, 0.05, -1.8), Vector3(0.6, 1.3, 1.2))
	_start()
	yield(_wait(length * 0.6), "timeout")
	var cs := _at_counter()
	if not cs.empty():
		var p = _right_parcel(cs[0])
		if p:
			p.global_transform.origin = cs[0].global_transform.origin + Vector3(0.2, 0.4, -0.6)
			p.linear_velocity = Vector3.ZERO


func warehouse() -> void:
	# поставка из портала, цветные стеллажи по буквам
	m._portal_wave(6)
	yield(_wait(2.5), "timeout")
	_dolly(Vector3(2.6, 0.05, -1.6), Vector3(-1.5, 1.0, -4.5), Vector3(1.4, 0.05, -2.0), Vector3(-3.0, 1.0, -4.0))
	_start()


func living() -> void:
	# живая посылка удирает, камера за ней
	yield(_wait(1.5), "timeout")
	var p = m._find_type("living")
	if p == null:
		p = m._find_type("mimic")
	if p:
		p.global_transform.origin = Vector3(0.0, 0.5, -2.8)
		p.linear_velocity = Vector3.ZERO
		_track = p
	_cam(Vector3(1.3, 0.05, -1.2), 0.0, -0.3, Vector3(0.9, 0.05, -1.4), 0.0, -0.3)
	_start()


func scam() -> void:
	# мошенник с поддельным чеком, красная кнопка «ВОН!»
	m._spawn_customer()
	for _i in 30:
		yield(_wait(0.5), "timeout")
		if not _at_counter().empty():
			break
	var c = _at_counter()[0] if not _at_counter().empty() else null
	var x: float = c.global_transform.origin.x if c else 0.0
	_dolly(Vector3(x + 0.9, 0.05, -2.3), Vector3(x - 0.2, 1.3, 0.6), Vector3(x + 0.6, 0.05, -2.0), Vector3(x, 1.45, 0.8))
	_start()
	yield(_wait(length * 0.6), "timeout")
	if c and is_instance_valid(c) and m.kick_buttons.has(c.slot):
		m._press_kick(m.kick_buttons[c.slot].get_child(0))


func coop() -> void:
	# три игрока разных рас с никами
	var looks := [{"nick": "2peaK", "race": "orc", "skin": 0, "apron": 1, "hat": "viking", "face": ""},
		{"nick": "Maga", "race": "human", "skin": 1, "apron": 0, "hat": "headphones", "face": "glasses"},
		{"nick": "Gobbo", "race": "goblin", "skin": 0, "apron": 3, "hat": "wizard", "face": "mustache"}]
	var starts := [Vector3(-1.2, 0.0, -2.9), Vector3(0.2, 0.0, -3.2), Vector3(1.4, 0.0, -2.8)]
	var ends := [Vector3(-0.8, 0.0, -2.5), Vector3(0.15, 0.0, -2.7), Vector3(1.0, 0.0, -2.4)]
	for i in 3:
		var av = m._avatar(100 + i)
		av.set_look(looks[i])
		av.net_set(starts[i], PI, 0.0)
		av.translation = starts[i]
		av.rotation.y = PI
		_move.append([av, starts[i], ends[i]])
	yield(_wait(0.5), "timeout")
	_dolly(Vector3(0.3, 0.05, -0.2), Vector3(0.2, 1.25, -2.8), Vector3(0.15, 0.05, -0.5), Vector3(0.1, 1.3, -2.6))
	_start()


func chaos() -> void:
	# режим хаоса: толпа и драка посылок
	for i in 4:
		m._spawn_customer()
		yield(_wait(0.8), "timeout")
	yield(_wait(6.0), "timeout")
	m._chaos_brawl()
	_dolly(Vector3(2.0, 0.05, -2.4), Vector3(-0.5, 1.0, 0.5), Vector3(1.2, 0.05, -2.0), Vector3(-0.5, 1.0, 0.8))
	_start()


func boss() -> void:
	for _i in 40:
		yield(_wait(0.5), "timeout")
		if m.boss and m.boss.state == "at_counter":
			break
	var x: float = m.boss.global_transform.origin.x if m.boss else 0.0
	_dolly(Vector3(x + 0.3, 0.05, -2.8), Vector3(x, 1.6, 1.0), Vector3(x, 0.05, -1.5), Vector3(x, 1.9, 1.0))
	_start()


func decor() -> void:
	# украшенный пункт в другом районе
	yield(_wait(2.0), "timeout")
	_dolly(Vector3(2.2, 0.05, -3.4), Vector3(-1.0, 1.0, 0.2), Vector3(1.0, 0.05, -3.8), Vector3(-2.0, 1.0, 0.5))
	_start()


func mirror() -> void:
	# зеркало: отражение, потом редактор
	if m.mirror == null:
		get_tree().quit()
		return
	Settings.look = {"nick": "2peaK", "race": "goblin", "skin": 0, "apron": 4, "hat": "cowboy", "face": "sunglasses"}
	for id in ["goblin", "orc", "cowboy", "sunglasses", "crown", "wizard", "viking", "propeller", "headphones", "mustache", "glasses", "bowtie"]:
		if not id in Settings.owned:
			Settings.owned.append(id)
	m.mirror.doll.set_look(Settings.look)
	var mp: Vector3 = m.mirror.global_transform.origin
	_dolly(mp + Vector3(0.5, 0.05, 2.2), mp + Vector3(0, 1.2, 0), mp + Vector3(0.25, 0.05, 1.6), mp + Vector3(0, 1.2, 0))
	_start()
	if still != "":
		yield(_wait(0.3), "timeout")
		m.mirror.open()
		m.mirror.edit["race"] = "orc"
		m.mirror.edit["hat"] = "viking"
		m.mirror.edit["face"] = "sunglasses"
		m.mirror.edit["apron"] = 1
		m.mirror._refresh()
		return
	yield(_wait(length * 0.45), "timeout")
	m.mirror.open()
	var seq := [["race", "orc", "hat", "viking"], ["race", "human", "hat", "crown"], ["race", "goblin", "hat", "propeller"]]
	for sq in seq:
		yield(_wait(length * 0.16), "timeout")
		m.mirror.edit[sq[0]] = sq[1]
		m.mirror.edit[sq[2]] = sq[3]
		m.mirror._refresh()


# ---- v0.14
func cat() -> void:
	# кота гладят: сердечки, мурчит
	yield(_wait(1.5), "timeout")
	if m.cat == null:
		get_tree().quit()
		return
	var cp: Vector3 = m.cat.spr.global_transform.origin
	_dolly(cp + Vector3(0.3, -1.35, -0.75), cp, cp + Vector3(0.1, -1.4, -0.55), cp)
	m.cat.pet()
	yield(_wait(0.4), "timeout")
	m.cat.pet()
	_start()
	for k in 3:
		yield(_wait(length * 0.15), "timeout")
		m.cat.pets = 1
		m.cat.pet()


func returns() -> void:
	# возврат: клиент принёс мятую коробку, лоток возвратов
	m._spawn_customer()
	yield(_wait(0.1), "timeout")
	var c = null
	for q in m.customers:
		if is_instance_valid(q):
			c = q
	if c:
		c.set_meta("ret", true)
		c.order = "%s-%02d" % [tr("В"), 47]
		c.scammer = false
		c.fake = ""
		c.safe_pin = ""
		c.set_meta("ret_dmg", "boot")
	for _i in 30:
		yield(_wait(0.5), "timeout")
		if not _at_counter().empty():
			break
	yield(_wait(1.0), "timeout")
	var x: float = c.global_transform.origin.x if c else 0.0
	_dolly(Vector3(x + 0.8, 0.05, -1.8), Vector3(x, 1.35, 0.3), Vector3(x + 0.5, 0.05, -1.5), Vector3(x, 1.4, 0.4))
	_start()
	if still != "":
		return
	yield(_wait(length * 0.55), "timeout")
	if c and is_instance_valid(c):
		m.returns.on_kick(c)


func letter() -> void:
	# письмо от владельца сети, дракона
	yield(_wait(1.5), "timeout")
	_cam(Vector3(0.9, 0.05, -1.4), 0.0, -0.35, Vector3(0.9, 0.05, -1.4), 0.0, -0.35)
	var li := 6
	for a in OS.get_cmdline_args():
		if a.begins_with("--letterid="):
			li = int(a.substr(11))
	m.story._day = li
	m.story._show(li)
	_start()


func rats() -> void:
	# редкое событие: крысы тащат коробки в нору (коробки заранее на полу у норы)
	yield(_wait(1.0), "timeout")
	var spots := [Vector3(5.6, 0.3, -2.4), Vector3(5.0, 0.3, -3.0), Vector3(6.1, 0.3, -3.3)]
	var k := 0
	for p in m.parcels:
		if k < 3 and is_instance_valid(p) and p.box_type == "normal" and not p.duo:
			p.global_transform.origin = spots[k]
			p.linear_velocity = Vector3.ZERO
			k += 1
	m.player.global_transform.origin = Vector3(4.5, 0.0, -1.7)
	m.rare.event = "rats"
	m.rare.scared = false
	m.rare.fire_at = -1.0
	m.rare._start()
	yield(_wait(3.0), "timeout")
	eye = 0.3
	_dolly(Vector3(4.5, 0.0, -1.7), Vector3(6.0, 0.08, -2.2), Vector3(4.8, 0.0, -1.6), Vector3(6.2, 0.08, -1.8))
	for r in m.rare.rats:
		if is_instance_valid(r[0]) and r[4] <= 0.0:
			_track = r[0]
			break
	follow = true
	_cam_from = []
	_start()


func mirror0() -> void:
	# зеркало с внешностью по умолчанию (проверка нового игрока)
	if m.mirror == null:
		get_tree().quit()
		return
	var mp: Vector3 = m.mirror.global_transform.origin
	_dolly(mp + Vector3(0.5, 0.05, 2.2), mp + Vector3(0, 1.2, 0), mp + Vector3(0.25, 0.05, 1.6), mp + Vector3(0, 1.2, 0))
	_start()
	yield(_wait(0.3), "timeout")
	print("look=", Settings.look, " doll_look=", m.mirror.doll.look)
	m.mirror.open()


func board() -> void:
	# доска объявлений (проверка текста)
	hud = true
	yield(_wait(1.0), "timeout")
	m._read_board(null)
	_start()


func layout() -> void:
	# склад сверху: стеллажи, зеркало, раскладушка (проверка расстановки)
	eye = 3.0
	_dolly(Vector3(0, 0.05, -1.0), Vector3(0, 0, -7.0), Vector3(0, 0.05, -1.0), Vector3(0, 0, -7.0))
	_start()


func flood() -> void:
	# редкое событие: потоп, лужи на складе
	yield(_wait(1.0), "timeout")
	m.rare.event = "flood"
	m.rare.fire_at = -1.0
	m.rare._start()
	m.rare._slip_cd = 999.0  # в кадре не падаем
	yield(_wait(1.5), "timeout")
	_dolly(Vector3(1.2, 0.05, -0.9), Vector3(0.0, 0.0, -2.6), Vector3(0.6, 0.05, -1.3), Vector3(-0.8, 0.0, -2.8))
	_start()
