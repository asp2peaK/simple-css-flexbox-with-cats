extends Node
# Редкие события посреди смены (одно за смену, со смены 3, примерно в каждой третьей):
#  inspector — инспектор встаёт у края стойки и 30 с смотрит: бросок -5, удар в лицо -15; без нарушений +25
#  rats      — крысы утаскивают мелкие коробки в нору; подбеги — бросят коробку
#  flood     — лужи на складе: наступил — поскользнулся и уронил коробки
#  mimic     — одна обычная коробка на полке оказывается мимиком
#  vip       — следующий клиент VIP: платит втрое, но ждёт меньше
# Только одиночная игра и хост-без-гостей не нужно: в коопе выключено (крысы и лужи не синхронизированы).

const EVENTS := ["inspector", "rats", "flood", "mimic", "vip"]
const NAMES := {"inspector": "ПРОВЕРКА! Инспектор смотрит: не швыряй коробки и не попадай в лицо",
	"rats": "КРЫСЫ! Тащат коробки в нору. Догони — бросят",
	"flood": "ПОТОП! Лужи на складе: не наступай, поскользнёшься",
	"mimic": "Одна из коробок на полке — МИМИК!",
	"vip": "VIP-клиент! Платит втрое, но ждать не любит"}
const HOLE := Vector3(6.6, 0.0, -1.0)

var main
var event := ""
var fire_at := -1.0  # секунда смены, когда случится
var t := 0.0
var left := 0.0
var icon: TextureRect
var vip_next := false
# инспектор
var insp = null
var insp_bad := 0
# крысы: [sprite, parcel|null, state, target]
var rats := []
var _rat_anim := 0.0
# лужи: [sprite, pos]
var puddles := []
var _slip_cd := 0.0


func setup(p_main) -> void:
	main = p_main
	var forced := ""
	for a in OS.get_cmdline_args():
		if a.begins_with("--rare="):
			forced = a.substr(7)
	if forced != "":
		event = forced
		fire_at = 3.0
		return
	if Game.mode != "career" or Net.active or Game.day < 3 or Game.is_boss_day() or Game.event != "":
		return
	if randf() < 0.35:
		event = EVENTS[randi() % EVENTS.size()]
		fire_at = rand_range(35.0, 80.0)


func _process(delta: float) -> void:
	if event == "" or main.shift_over or not main.is_open:
		return
	t += delta
	if fire_at > 0.0 and t >= fire_at:
		fire_at = -1.0
		_start()
	if left > 0.0:
		left -= delta
		if left <= 0.0:
			_end()
	_update_rats(delta)
	_update_puddles(delta)


func _start() -> void:
	Sfx.play("event", 0.0, -2.0)
	main._flash(tr(NAMES[event]), 4.0)
	_show_icon(event)
	match event:
		"inspector":
			left = 30.0
			_spawn_inspector()
		"rats":
			left = 40.0
			for k in 3:
				_spawn_rat(k)
		"flood":
			left = 60.0
			Sfx.play("splash", 0.1, 0.0)
			_spawn_puddles()
		"mimic":
			_make_mimic()
			left = 4.0
		"vip":
			vip_next = true
			left = 4.0


func _end() -> void:
	if icon and is_instance_valid(icon):
		icon.queue_free()
	match event:
		"inspector":
			if insp and is_instance_valid(insp):
				if insp_bad == 0:
					main.money += 25
					main._flash(tr("Инспектор доволен: нарушений нет. +25 монет"), 2.5)
					insp.leave_with(tr("Образцовый пункт. Так и запишу."), true)
				else:
					main._flash(tr("Инспектор ушёл. Нарушений: %d") % insp_bad, 2.5)
					insp.leave_with(tr("Я всё записал!"), false)
			main._refresh_hud()
		"rats":
			for r in rats:
				if is_instance_valid(r[0]):
					_rat_drop(r)
					r[0].queue_free()
			rats = []
		"flood":
			for pd in puddles:
				if is_instance_valid(pd[0]):
					pd[0].queue_free()
			puddles = []
	event = ""


func _show_icon(ev: String) -> void:
	var path := "res://assets/ui/ev_%s.png" % ev
	if not ResourceLoader.exists(path):
		return
	icon = TextureRect.new()
	icon.texture = load(path)
	icon.rect_position = Vector2(305, 26)
	main.hud_center.get_parent().add_child(icon)


# ---------------------------------------------------------------- инспектор
func _spawn_inspector() -> void:
	var c = load("res://scripts/customer.gd").new()
	c.setup("inspector", main._char_frames("inspector"), "", tr("Проверка. Работайте, работайте..."), 999.0)
	c.remote = true  # сам не уходит по терпению
	c.door = main.DOOR
	c.translation = main.DOOR
	main.add_child(c)
	c.walk_to(Vector3(6.2, 0, 1.3), "arrive")
	insp = c
	insp_bad = 0


func watching() -> bool:
	return event == "inspector" and insp != null and is_instance_valid(insp) and left > 0.0


func on_throw() -> void:
	if watching():
		insp_bad += 1
		main.money = int(max(0, main.money - 5))
		main._flash(tr("Инспектор: «Швырять посылки запрещено!» -5"), 2.0)
		main._refresh_hud()


func on_face_hit() -> bool:
	if watching():
		insp_bad += 1
		main.money = int(max(0, main.money - 15))
		main._flash(tr("Инспектор всё видел! -15 монет"), 2.0)
		return true
	return false


# ---------------------------------------------------------------- крысы
func _rat_tex(k: int) -> Texture:
	var p := "res://assets/props/rat_run%d.png" % k
	if ResourceLoader.exists(p):
		var t: Texture = load(p)
		return t
	return null


func _spawn_rat(k: int) -> void:
	var s := Sprite3D.new()
	s.texture = _rat_tex(0)
	if s.texture == null:
		return
	s.pixel_size = 0.14 / s.texture.get_height()
	s.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	main.add_child(s)
	s.global_transform.origin = HOLE + Vector3(0, 0.07, -k * 0.4)
	rats.append([s, null, "hunt", null, k * 1.5])


func _small_parcel(taken: Array):
	var best = null
	var bd := 999.0
	for p in main.parcels:
		if not is_instance_valid(p) or p.held or p.delivered or p.duo or p in taken or p.has_meta("ret"):
			continue
		if p.box_type in ["chest", "heavy", "cow"] or p.mode != RigidBody.MODE_RIGID:
			continue
		var d: float = p.global_transform.origin.distance_to(HOLE)
		if d < bd:
			bd = d
			best = p
	return best


func _update_rats(delta: float) -> void:
	if rats.empty():
		return
	_rat_anim += delta
	var taken := []
	for r in rats:
		if r[1]:
			taken.append(r[1])
	var pl_pos: Vector3 = main.player.global_transform.origin
	for r in rats:
		var s: Sprite3D = r[0]
		if not is_instance_valid(s):
			continue
		if r[4] > 0.0:
			r[4] -= delta
			continue
		s.texture = _rat_tex(int(_rat_anim * 10.0) % 2)
		var pos: Vector3 = s.global_transform.origin
		var target: Vector3
		if r[2] == "hunt":
			if r[1] == null or not is_instance_valid(r[1]) or r[1].held or r[1].delivered:
				r[1] = _small_parcel(taken)
				if r[1]:
					taken.append(r[1])
			if r[1] == null:
				target = HOLE
			else:
				target = r[1].global_transform.origin
				if Vector2(target.x - pos.x, target.z - pos.z).length() < 0.35 and target.y < 0.8:
					r[2] = "carry"
					r[1].mode = RigidBody.MODE_KINEMATIC
					Sfx.play_at("squeak", pos, 0.2, -4.0)
		elif r[2] == "carry":
			target = HOLE + Vector3(0, 0, rand_range(-0.1, 0.1))
			if not is_instance_valid(r[1]) or r[1].held:
				r[2] = "hunt"
				r[1] = null
			else:
				r[1].global_transform.origin = pos + Vector3(0, r[1].size.y / 2.0, 0)
				if Vector2(HOLE.x - pos.x, HOLE.z - pos.z).length() < 0.4:
					# дотащила до норы: бросает в углу (ищи её там) и бежит за следующей
					_rat_drop(r)
					main._flash(tr("Крыса утащила коробку в угол у норы!"), 1.8)
					r[2] = "hunt"
		else:  # flee
			target = HOLE
			if Vector2(HOLE.x - pos.x, HOLE.z - pos.z).length() < 0.4:
				r[2] = "hunt"
				r[4] = 4.0
		# игрок рядом: бросает коробку и удирает
		if r[2] != "flee" and Vector2(pl_pos.x - pos.x, pl_pos.z - pos.z).length() < 0.9:
			if r[2] == "carry":
				_rat_drop(r)
				main._flash(tr("Поймал! Крыса бросила коробку."), 1.5)
			r[2] = "flee"
			Sfx.play_at("squeak", pos, 0.2, 0.0)
		var dir := Vector3(target.x - pos.x, 0, target.z - pos.z)
		var spd := 2.6 if r[2] == "flee" else 1.7
		if dir.length() > 0.05:
			var step: Vector3 = dir.normalized() * min(dir.length(), spd * delta)
			s.global_transform.origin = Vector3(pos.x + step.x, 0.07, pos.z + step.z)
			# смотрит в сторону бега (кадры нарисованы влево)
			var cam = main.get_viewport().get_camera()
			if cam:
				var right: Vector3 = cam.global_transform.basis.x
				s.flip_h = step.dot(right) > 0.0


func _rat_drop(r) -> void:
	if r[1] and is_instance_valid(r[1]) and not r[1].held and not r[1].delivered:
		r[1].mode = RigidBody.MODE_RIGID
		r[1].sleeping = false
	r[1] = null


# ---------------------------------------------------------------- лужи
func _spawn_puddles() -> void:
	var spots := [Vector3(0, 0.02, -2.0), Vector3(-2.2, 0.02, -2.8), Vector3(2.4, 0.02, -1.6), Vector3(0.8, 0.02, -5.6)]
	spots.shuffle()
	var tex: Texture = load("res://assets/props/puddle.png") if ResourceLoader.exists("res://assets/props/puddle.png") else null
	for k in 3:
		var s := Sprite3D.new()
		if tex:
			s.texture = tex
			s.pixel_size = 1.3 / tex.get_width()
		s.axis = Vector3.AXIS_Y  # лежит на полу
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		main.add_child(s)
		s.global_transform.origin = spots[k]
		puddles.append([s, spots[k]])


func _update_puddles(delta: float) -> void:
	if puddles.empty():
		return
	_slip_cd -= delta
	if _slip_cd > 0.0:
		return
	var pl = main.player
	var pp: Vector3 = pl.global_transform.origin
	for pd in puddles:
		if Vector2(pp.x - pd[1].x, pp.z - pd[1].z).length() < 0.55 and pl.velocity.length() > 1.0:
			_slip_cd = 2.5
			Sfx.play("splash", 0.1, -2.0)
			var had: bool = not pl.stack.empty()
			pl.drop_all()
			pl.stun_t = 0.9
			pl.down_dir = "back"
			main._flash(tr("Поскользнулся!") + (" " + tr("Коробки на полу.") if had else ""), 1.5)
			return


# ---------------------------------------------------------------- мимик и VIP
func _make_mimic() -> void:
	var cand := []
	for p in main.parcels:
		if is_instance_valid(p) and p.box_type == "normal" and not p.held and not p.delivered and p.global_transform.origin.y > 0.6:
			cand.append(p)
	if cand.empty():
		return
	var p = cand[randi() % cand.size()]
	p.box_type = "mimic"
	p.calm = 0.0
	Sfx.play_at("bite", p.global_transform.origin, 0.1, 0.0)


func on_spawn(c) -> void:
	if not vip_next:
		return
	vip_next = false
	c.set_meta("vip", true)
	c.max_patience *= 0.6
	c.patience = c.max_patience
	var path := "res://assets/ui/ev_vip.png"
	if ResourceLoader.exists(path):
		var cr := Sprite3D.new()
		cr.texture = load(path)
		cr.pixel_size = 0.3 / cr.texture.get_height()
		cr.billboard = SpatialMaterial.BILLBOARD_ENABLED
		cr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		cr.translation.y = c.base_y * 2.0 + 0.45
		c.add_child(cr)


func vip_bonus(c, earned: int) -> int:
	if c.has_meta("vip"):
		return earned * 2  # итого втрое
	return 0
