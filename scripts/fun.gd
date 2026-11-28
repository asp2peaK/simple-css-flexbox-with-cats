extends Node
# Кооп и стрим-фишки (узел Main/Fun, одинаковый путь у всех игроков, поэтому rpc идут сюда):
#  - огонь по своим: коробка в напарника = падает, роняет всё, оглушён, звёздочки над головой;
#  - доска позора в конце кооп-смены;
#  - сундук и посылка-корова на двоих (только в коопе);
#  - проклятия от проклятых посылок: управление наоборот, большая голова, хрюкающие шаги, коробка прилипла;
#  - перегруз портала: 20 коробок и быстрая лента;
#  - голосование чата Twitch за события (на ПК стримера: хост или одиночная игра).

const CURSES := ["invert", "bighead", "oink", "glue"]
const CURSE_NAMES := {"invert": "УПРАВЛЕНИЕ НАОБОРОТ", "bighead": "БОЛЬШАЯ ГОЛОВА", "oink": "ХРЮКАЮЩИЕ ШАГИ",
	"glue": "КОРОБКА ПРИЛИПЛА К РУКАМ"}
const CURSE_TIME := 14.0
const CURSE_CHANCE := 0.4
const STUN_TIME := 3.2
const DUO_TYPES := ["chest", "cow"]
const COUNTER_TOP := 1.0
const VOTES := {"overload": "Перегруз портала", "curse_all": "Проклятие всем", "blackout": "Вырубить свет",
	"rush": "Наплыв клиентов", "tips": "Чаевые от чата +25", "bighead": "Большие головы"}
const VOTE_EVERY := 70.0
const VOTE_TIME := 25.0

var main
var board := {}  # id игрока -> счётчики смены (считает хост)
var duo := {}  # код посылки -> [id, id] кто держит
var belt_boost := 0.0
var overload_done := false
var _overload_at := -1.0
var _shift_t := 0.0
var _moo_t := 4.0
var blackout_done := false
# Twitch
var vote_cd := 30.0
var vote_left := 0.0
var vote_opts := []
var vote_counts := [0, 0, 0]
var voters := {}
var vote_box: Label
# свой игрок
var hud_curse: Label
var hud_curse_icon: TextureRect
var hud_stars: Control
var _stars_t := 0.0


static func make_stars(h: float) -> Spatial:
	var s: Spatial = load("res://scripts/stars.gd").new()
	s.translation = Vector3(0, h, 0)
	return s


func setup(m) -> void:
	main = m
	name = "Fun"
	pause_mode = Node.PAUSE_MODE_STOP
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var fnt = load("res://fonts/main_font.tres")
	hud_curse = Label.new()
	hud_curse.align = Label.ALIGN_CENTER
	hud_curse.rect_position = Vector2(0, 300)
	hud_curse.rect_size = Vector2(640, 16)
	hud_curse.add_color_override("font_color", Color(0.85, 0.5, 1.0))
	hud_curse.add_font_override("font", fnt)
	layer.add_child(hud_curse)
	hud_curse_icon = TextureRect.new()
	hud_curse_icon.rect_position = Vector2(304, 266)
	hud_curse_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_curse_icon)
	hud_stars = Control.new()
	hud_stars.visible = false
	hud_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_stars)
	var st: Texture = load("res://scripts/stars.gd").star_texture()
	if ResourceLoader.exists("res://assets/fx/star_0.png"):
		st = load("res://assets/fx/star_0.png")
	for k in 5:
		var tr2 := TextureRect.new()
		tr2.texture = st
		tr2.expand = true
		tr2.rect_size = Vector2(22, 22)
		tr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_stars.add_child(tr2)
	vote_box = Label.new()
	vote_box.rect_position = Vector2(8, 46)
	vote_box.add_font_override("font", fnt)
	vote_box.add_color_override("font_color", Color(0.75, 0.6, 1.0))
	vote_box.visible = false
	layer.add_child(vote_box)
	Twitch.connect("chat", self, "_on_chat")
	# перегруз портала сам по себе: иногда, с 4-й смены (в хаосе чаще)
	if not main.net_client():
		if Game.mode == "chaos" and randf() < 0.5:
			_overload_at = rand_range(40.0, 90.0)
		elif Game.mode == "career" and Game.day >= 4 and randf() < 0.3:
			_overload_at = rand_range(45.0, 110.0)
	if "--overload" in OS.get_cmdline_args():
		_overload_at = 8.0
	for a in OS.get_cmdline_args():
		if a.begins_with("--funtest="):
			var t = load("res://scripts/fun_tests.gd").new()
			add_child(t)
			t.call_deferred("run", main, a.substr(10))


func coop_duo() -> bool:
	return Net.active


func player():
	return main.player


func _name(id: int) -> String:
	if id == Net.my_id():
		var n: String = str(Settings.look.get("nick", "")).strip_edges()
		return n if n != "" else (tr("Хост") if id == 1 else tr("Я"))
	var av = main.avatars.get(id)
	return av.bubble_text if av else tr("Игрок")


# ================================================================ доска позора
func _count(id: int, key: String, n := 1) -> void:
	if id <= 0 or not Net.active:
		return
	if not board.has(id):
		board[id] = {"served": 0, "oops": 0, "ff": 0, "knocked": 0, "scam": 0}
	board[id][key] += n


func _holder(p) -> int:
	return int(p.get_meta("holder")) if p.has_meta("holder") else 0


func on_served(p) -> void:
	_count(_holder(p), "served")


func on_scam(p) -> void:
	_count(_holder(p), "scam")


func on_oops(p) -> void:
	_count(_holder(p), "oops")


func board_text() -> String:
	if not Net.active or board.empty():
		return ""
	var best := [0, -1]
	var oops := [0, -1]
	var sniper := [0, -1]
	var scam := []
	for id in board:
		var b: Dictionary = board[id]
		if b["served"] > best[1]:
			best = [id, b["served"]]
		var o: int = b["oops"] + b["knocked"]
		if o > oops[1]:
			oops = [id, o]
		if b["ff"] > sniper[1]:
			sniper = [id, b["ff"]]
		if b["scam"] > 0:
			scam.append("%s (%d)" % [_name(id), b["scam"]])
	var lines := ["", tr("ДОСКА ПОЗОРА")]
	if best[1] > 0:
		lines.append(tr("Лучший работник: %s — выдал %d") % [_name(best[0]), best[1]])
	if oops[1] > 0:
		lines.append(tr("Растяпа смены: %s — косяков: %d") % [_name(oops[0]), oops[1]])
	if sniper[1] > 0:
		lines.append(tr("Огонь по своим: %s — попаданий в напарников: %d") % [_name(sniper[0]), sniper[1]])
	if not scam.empty():
		lines.append(tr("Отдал посылку мошеннику: %s") % PoolStringArray(scam).join(", "))
	if lines.size() == 2:
		lines.append(tr("Все молодцы. Подозрительно."))
	return PoolStringArray(lines).join("\n")


# ================================================================ огонь по своим
func _stunned(id: int) -> bool:
	if id == Net.my_id():
		return player().stun_t > 0.0
	var av = main.avatars.get(id)
	return av != null and av.stars != null


# хост: летящая коробка задела напарника?
func check_ff(b, pos: Vector3) -> bool:
	if not Net.active or not Net.is_host:
		return false
	var thrower := int(b.get_meta("thrower")) if b.has_meta("thrower") else 0
	var targets := [[1, player().global_transform.origin]]
	for id in main.avatars:
		targets.append([id, main.avatars[id].global_transform.origin])
	for t in targets:
		var id: int = t[0]
		if id == thrower or _stunned(id):
			continue
		var base: Vector3 = t[1]
		var flat := Vector2(pos.x - base.x, pos.z - base.z).length()
		if flat < 0.55 and pos.y > base.y + 0.3 and pos.y < base.y + 2.0:
			b.hit_done = true
			var v: Vector3 = b.linear_velocity
			b.linear_velocity = Vector3(-v.x * 0.25, 2.0, -v.z * 0.25)
			_count(thrower, "ff")
			_count(id, "knocked")
			Sfx.play_at("bonk_player", pos, 0.1, 6.0)
			if id == 1:
				knock()
			else:
				rpc_id(id, "net_knock")
			if thrower > 0 and thrower != 1:
				rpc_id(thrower, "net_flash", tr("Попал в напарника!"))
			elif thrower == 1:
				main._flash(tr("Попал в напарника!"), 1.5)
			return true
	return false


remote func net_knock() -> void:
	knock()


remote func net_flash(t: String) -> void:
	main._flash(t, 1.5)


func knock() -> void:
	var pl = player()
	if pl.stun_t > 0.0:
		return
	if pl.duo:
		duo_release_local()
	pl.drop_all()
	pl.stun_t = STUN_TIME * (0.5 if Game.lvl("coffee") > 0 else 1.0)
	pl.down_dir = "back" if randf() < 0.5 else "front"
	Sfx.play("bonk_player", 0.1, 0.0)
	Sfx.play("dizzy", 0.05, -2.0)
	main._flash(tr("БДЫЩ! Напарник попал в тебя коробкой"), 2.0)
	send_fx()


func send_fx() -> void:
	if not Net.active:
		return
	var pl = player()
	rpc("net_fx", pl.down_dir if pl.stun_t > 0.0 else "", pl.curse)


remote func net_fx(down: String, curse: String) -> void:
	var id := get_tree().get_rpc_sender_id()
	main._avatar(id).set_fx(down, curse)


# ================================================================ проклятия
func on_grab_cursed(p) -> void:
	if p.cursed and player().curse == "" and randf() < CURSE_CHANCE:
		apply_curse(CURSES[randi() % CURSES.size()])


func apply_curse(c: String) -> void:
	var pl = player()
	pl.curse = c
	pl.curse_t = CURSE_TIME
	Sfx.play("curse", 0.05, 0.0)
	main._flash(tr("ПРОКЛЯТИЕ: %s!") % tr(CURSE_NAMES[c]), 2.5)
	send_fx()


remote func net_curse(c: String) -> void:
	apply_curse(c)


func curse_all(c: String) -> void:
	apply_curse(c if c != "" else CURSES[randi() % CURSES.size()])
	if Net.active:
		for id in Net.peers:
			rpc_id(id, "net_curse", c if c != "" else CURSES[randi() % CURSES.size()])


func curse_ended() -> void:
	main._flash(tr("Проклятие спало."), 1.5)
	send_fx()


# ================================================================ сундук и корова на двоих
func is_duo(p) -> bool:
	return p.get("duo") == true


func duo_grab(p) -> void:
	if Net.is_host or not Net.active:
		duo_request(Net.my_id(), p)
	else:
		rpc_id(1, "net_duo_req", p.code)


func duo_release_local() -> void:
	var pl = player()
	if pl.duo == null:
		return
	var code: String = pl.duo.code
	_unexcept_later(pl.duo)
	pl.duo = null
	pl.duo_lifted = false
	if Net.is_host or not Net.active:
		duo_release(Net.my_id(), code)
	else:
		rpc_id(1, "net_duo_release", code)


remote func net_duo_req(code: String) -> void:
	var p = main._parcel_by_code(code)
	if Net.is_host and p:
		duo_request(get_tree().get_rpc_sender_id(), p)


remote func net_duo_release(code: String) -> void:
	if Net.is_host:
		duo_release(get_tree().get_rpc_sender_id(), code)


func _lift_ready(hs: Array) -> bool:
	# вдвоём, или напарник ушёл из игры — тогда можно и одному (медленно)
	return hs.size() >= 2 or Net.peers.empty()


func duo_request(id: int, p) -> void:
	if p.delivered or not is_duo(p):
		return
	var hs: Array = duo.get(p.code, [])
	if id in hs or hs.size() >= 2:
		return
	hs.append(id)
	duo[p.code] = hs
	if not p.has_meta("holder"):
		p.set_meta("holder", id)
	_duo_sync(p)


func duo_release(id: int, code: String) -> void:
	var hs: Array = duo.get(code, [])
	hs.erase(id)
	var p = main._parcel_by_code(code)
	if hs.empty():
		duo.erase(code)
	if p:
		_duo_drop(p)
		_duo_sync(p)


func _duo_drop(p) -> void:
	# отпустили над стойкой — ставим на стойку (поднимаем на её высоту)
	var o: Vector3 = p.global_transform.origin
	if p.mode != RigidBody.MODE_RIGID and o.z > -1.0 and o.z < 0.6 and abs(o.x) < 6.5:
		p.global_transform.origin = Vector3(o.x, COUNTER_TOP + p.size.y / 2.0 + 0.03, clamp(o.z, -0.2, 0.2))
	if p.mode != RigidBody.MODE_RIGID:
		p.held = false
		p.mode = RigidBody.MODE_RIGID
		p.sleeping = false
		p.linear_velocity = Vector3(0, -0.5, 0)


func _duo_sync(p) -> void:
	var hs: Array = duo.get(p.code, [])
	var lifted := _lift_ready(hs)
	if lifted and hs.size() > 0:
		p.held = true
		p.mode = RigidBody.MODE_KINEMATIC
	for id in hs:
		if id == Net.my_id():
			net_duo_state(p.code, lifted)
		else:
			rpc_id(id, "net_duo_state", p.code, lifted)


remote func net_duo_state(code: String, lifted: bool) -> void:
	var p = main._parcel_by_code(code)
	var pl = player()
	if p == null:
		pl.duo = null
		return
	if pl.duo != p:
		Sfx.play("pickup", 0.1, -2.0)
		pl.add_collision_exception_with(p)
	pl.duo = p
	pl.duo_lifted = lifted


remote func net_duo_drop() -> void:
	var pl = player()
	if pl.duo and is_instance_valid(pl.duo):
		pl.remove_collision_exception_with(pl.duo)
	pl.duo = null
	pl.duo_lifted = false
	main._flash(tr("Не удержали! Идите рядом."), 1.5)


func _holder_point(id: int) -> Vector3:
	if id == Net.my_id():
		return player().hold_point.global_transform.origin
	var av = main.avatars.get(id)
	return av.hold_point() if av else Vector3.ZERO


# куда держатель тянет ношу: на 1.3 м перед собой (у хоста и гостя по-разному берём направление)
func _carry_point(id: int) -> Vector3:
	var pos := _holder_body(id)
	var yaw := 0.0
	if id == Net.my_id():
		yaw = player().rotation.y
	else:
		var av = main.avatars.get(id)
		yaw = av._rot if av else 0.0
	return pos + Vector3(-sin(yaw), 0, -cos(yaw)) * 1.3


func _holder_body(id: int) -> Vector3:
	if id == Net.my_id():
		return player().global_transform.origin
	var av = main.avatars.get(id)
	return av.global_transform.origin if av else Vector3.ZERO


func _update_duo(delta: float) -> void:
	for code in duo.keys():
		var p = main._parcel_by_code(code)
		var hs: Array = duo[code]
		if p == null or p.delivered:
			duo.erase(code)
			for id in hs:
				_tell_drop(id)
			continue
		if _lift_ready(hs):
			var a := _carry_point(hs[0])
			var b := a if hs.size() < 2 else _carry_point(hs[1])
			if hs.size() >= 2 and _holder_body(hs[0]).distance_to(_holder_body(hs[1])) > 3.5:
				# разошлись слишком далеко: сундук падает
				duo.erase(code)
				_duo_drop(p)
				for id in hs:
					_tell_drop(id)
				continue
			var mid := (a + b) / 2.0
			mid.y = 0.55 + p.size.y / 2.0  # несут на руках низко, чтобы видеть дорогу
			# у стойки: поднимаем над столешницей и не пускаем сквозь стенку к клиентам
			var r: float = max(p.size.x, p.size.z) / 2.0
			mid.z = min(mid.z, 0.38 - min(r, 0.35))
			if mid.z > -0.4 - r and abs(mid.x) < 7.0:
				mid.y = max(mid.y, COUNTER_TOP + p.size.y / 2.0 + 0.04)
			var basis: Basis = p.global_transform.basis
			if hs.size() >= 2 and Vector2(b.x - a.x, b.z - a.z).length() > 0.2:
				basis = Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z) + PI / 2.0)
			p.global_transform = p.global_transform.interpolate_with(Transform(basis, mid), min(1.0, 10.0 * delta))
		else:
			# один держит за край: сундук трясётся на месте, ушёл далеко — отпустил
			var a2 := _holder_point(hs[0])
			if Vector2(a2.x - p.global_transform.origin.x, a2.z - p.global_transform.origin.z).length() > 2.2:
				duo.erase(code)
				_tell_drop(hs[0])
			elif p.mode == RigidBody.MODE_RIGID and randf() < delta * 3.0:
				p.sleeping = false
				p.apply_central_impulse(Vector3(rand_range(-0.3, 0.3), 1.2, rand_range(-0.3, 0.3)) * p.mass * 0.25)


func _tell_drop(id: int) -> void:
	if id == Net.my_id():
		net_duo_drop()
	else:
		rpc_id(id, "net_duo_drop")


# ================================================================ перегруз портала
func overload() -> void:
	if overload_done or main.shift_over or main.net_client():
		return
	overload_done = true
	var used := {}
	for p in main.parcels:
		if is_instance_valid(p):
			used[p.code] = true
	for p in main.incoming:
		used[p.code] = true
	var extra := []
	for i in main.CODES.size():
		if not used.has(main.CODES[i]) and main.BOX_TYPES[i] in ["normal", "gift", "heavy", "fragile"]:
			extra.append(i)
	extra.shuffle()
	var picked := []
	for k in int(min(max(0, 20 - main.incoming.size()), extra.size())):
		picked.append(extra[k])
	if Net.active:
		rpc("net_overload", picked)
	net_overload(picked)
	main._portal_wave(main.incoming.size())


remote func net_overload(extra: Array) -> void:
	overload_done = true
	belt_boost = 25.0
	for i in extra:
		var p = main._new_parcel(int(i))
		if main.net_client():
			p.mode = RigidBody.MODE_KINEMATIC
		main.incoming.append(p)
	Sfx.play("siren", 0.0, -2.0)
	main._flash(tr("ПЕРЕГРУЗ ПОРТАЛА!\nКоробки летят пачкой, лента на полной скорости. Раскидывай по стеллажам!"), 4.0)
	main.portal_open_t = 9.0


func belt_speed() -> float:
	return 2.6 if belt_boost > 0.0 else (1.8 if Game.lvl("belt") > 0 else 0.9)


# ================================================================ Twitch: голосование чата
func _vote_allowed() -> bool:
	return Twitch.connected and main.is_open and not main.shift_over and not main.net_client() \
		and Game.mode != "tutorial" and not (Game.mode == "career" and Game.day == 1 and not Game.tutorial_done)


func _start_vote() -> void:
	var pool := []
	for k in VOTES:
		if k == "overload" and overload_done:
			continue
		if k == "blackout" and (Game.event == "blackout" or blackout_done):
			continue
		pool.append(k)
	pool.shuffle()
	vote_opts = pool.slice(0, 2)
	vote_counts = [0, 0, 0]
	voters = {}
	vote_left = VOTE_TIME
	Sfx.play("vote", 0.0, -4.0)


func _on_chat(user: String, text: String) -> void:
	if vote_left <= 0.0 or voters.has(user):
		return
	var t := text.strip_edges().trim_prefix("!")
	if t in ["1", "2", "3"]:
		voters[user] = true
		vote_counts[int(t) - 1] += 1


func _finish_vote() -> void:
	var best := -1
	var bi := -1
	for i in vote_opts.size():
		if vote_counts[i] > best or (vote_counts[i] == best and randf() < 0.5):
			best = vote_counts[i]
			bi = i
	if best <= 0:
		main._flash(tr("Чат промолчал. Работаем спокойно."), 2.0)
		return
	var ev: String = vote_opts[bi]
	main._flash(tr("ЧАТ РЕШИЛ: %s!") % tr(VOTES[ev]), 2.5)
	run_event(ev)


func run_event(ev: String) -> void:
	match ev:
		"overload":
			overload()
		"curse_all":
			curse_all("")
		"bighead":
			curse_all("bighead")
		"blackout":
			blackout_done = true
			main._blackout()
			if Net.active:
				rpc("net_blackout")
		"rush":
			for k in 3:
				main._spawn_customer_later(0.5 + k * 1.2)
		"tips":
			main.money += 25
			Sfx.play("coin", 0.0, 0.0)
			main._refresh_hud()


remote func net_blackout() -> void:
	main._blackout()


func _update_vote(delta: float) -> void:
	if not _vote_allowed():
		vote_box.visible = false
		return
	if vote_left > 0.0:
		vote_left -= delta
		var lines := [tr("ЧАТ ГОЛОСУЕТ: пиши 1, 2 или 3 (%d с)") % int(ceil(vote_left))]
		for i in vote_opts.size():
			lines.append("%d) %s — %d" % [i + 1, tr(VOTES[vote_opts[i]]), vote_counts[i]])
		vote_box.text = PoolStringArray(lines).join("\n")
		vote_box.visible = true
		if vote_left <= 0.0:
			vote_box.visible = false
			vote_cd = VOTE_EVERY
			_finish_vote()
	else:
		vote_cd -= delta
		if vote_cd <= 0.0:
			_start_vote()


# ================================================================ кадр
func _process(delta: float) -> void:
	var pl = player()
	if pl == null:
		return
	# HUD: проклятие и звёздочки
	if pl.curse != "":
		hud_curse.text = tr("ПРОКЛЯТИЕ: %s (%d)") % [tr(CURSE_NAMES[pl.curse]), int(ceil(pl.curse_t))]
		var ip: String = "res://assets/ui/curse_%s.png" % pl.curse
		hud_curse_icon.texture = load(ip) if ResourceLoader.exists(ip) else null
	else:
		hud_curse.text = ""
		hud_curse_icon.texture = null
	hud_stars.visible = pl.stun_t > 0.0
	if hud_stars.visible:
		_stars_t += delta
		for k in hud_stars.get_child_count():
			var a: float = _stars_t * 3.0 + k * TAU / 5.0
			hud_stars.get_child(k).rect_position = Vector2(320 + cos(a) * 70 - 11, 70 + sin(a) * 22 - 11)
	_update_vote(delta)


func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	belt_boost = max(0.0, belt_boost - delta)
	if main.is_open and not main.shift_over:
		_shift_t += delta
		if _overload_at > 0.0 and _shift_t > _overload_at:
			_overload_at = -1.0
			overload()
	if Net.active and Net.is_host:
		_update_duo(delta)
	# корова в ящике мычит
	_moo_t -= delta
	if _moo_t <= 0.0:
		_moo_t = rand_range(5.0, 9.0)
		for p in main.parcels:
			if is_instance_valid(p) and p.box_type == "cow" and not p.delivered:
				Sfx.play_at("moo", p.global_transform.origin, 0.1, 0.0)
				_moo_face(p)
				break


# корова открывает рот, пока мычит (кадр 2 листа 63)
func _moo_face(p) -> void:
	if not p.has_meta("cow") or not ResourceLoader.exists("res://assets/props/cow_crate_moo.png"):
		return
	var cs: Sprite3D = p.get_meta("cow")
	cs.texture = load("res://assets/props/cow_crate_moo.png")
	yield(get_tree().create_timer(1.0), "timeout")
	if is_instance_valid(cs):
		cs.texture = load("res://assets/props/cow_crate.png")


func _unexcept_later(p) -> void:
	yield(get_tree().create_timer(0.6), "timeout")
	if is_instance_valid(p) and is_instance_valid(player()):
		player().remove_collision_exception_with(p)


# напарник отключился: отпускаем его край сундука
func peer_gone(id: int) -> void:
	for code in duo.keys():
		var hs: Array = duo[code]
		if id in hs:
			hs.erase(id)
			if hs.empty():
				duo.erase(code)
				var p = main._parcel_by_code(code)
				if p:
					_duo_drop(p)
			else:
				var p2 = main._parcel_by_code(code)
				if p2:
					_duo_sync(p2)
