extends Node
# Стол возвратов. Иногда клиент приходит не забрать, а ВЕРНУТЬ посылку: ставит её на стойку.
#  - целая коробка -> положи в лоток возвратов (слева на стойке): +8, клиент доволен;
#  - испорченная (порвана, мокрая, следы ботинок, вмятина) -> не принимай, жми «ВОН!»: +6;
#  - положил испорченную в лоток -> гильдия штрафует -10; выгнал с целой -> как честного (-10).
# Только одиночная карьера (в коопе выключено), со смены 2.

const TRAY_POS := Vector3(-5.2, 0.98, -0.15)
const CHANCE := 0.18
const DAMAGES := ["tear", "stain", "boot", "dent"]
const DMG_NAMES := {"tear": "порвана", "stain": "мокрое пятно", "boot": "след ботинка", "dent": "вмятина"}

var main
var tray: Spatial
var area: Area
var count := 0
var _tex: ImageTexture


func setup(p_main) -> void:
	main = p_main
	if not enabled():
		return
	if ResourceLoader.exists("res://assets/props/returns_tray.png"):
		tray = main.prop("returns_tray", TRAY_POS, 0, 0.26, true)
	else:
		tray = main.deco(Vector3(0.6, 0.1, 0.4), TRAY_POS + Vector3(0, 0.05, 0), main.unshaded(Color(0.45, 0.3, 0.2)))
	main._clickable(tray, Vector3(0.32, 0.12, 0.25), tr("Лоток возвратов: сюда кладут ЦЕЛЫЕ возвращённые коробки"), "")
	area = Area.new()
	area.collision_layer = 0
	area.collision_mask = 8
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = Vector3(0.4, 0.3, 0.35)
	cs.shape = sh
	area.add_child(cs)
	area.translation = TRAY_POS + Vector3(0, 0.3, 0)
	main.add_child(area)


func enabled() -> bool:
	return Game.mode == "career" and not Net.active and Game.day >= 2 or "--rettest" in OS.get_cmdline_args()


# вызывается при появлении клиента: может сделать его «возвратным»
func maybe_mark(c, kind: String) -> void:
	if not enabled() or kind in ["thief", "maga", "boss", "dwarf", "inspector"]:
		return
	var force := "--rettest" in OS.get_cmdline_args() and count == 0
	if not force and randf() > CHANCE:
		return
	count += 1
	c.set_meta("ret", true)
	c.order = "%s-%02d" % [tr("В"), 10 + randi() % 89]  # номер возврата, на складе такой коробки нет
	c.scammer = false
	c.fake = ""
	c.safe_pin = ""
	c.set_meta("ret_dmg", DAMAGES[randi() % DAMAGES.size()] if (randf() < 0.45 or force) else "")


func on_arrived(c) -> void:
	if not c.has_meta("ret"):
		return
	var dmg: String = c.get_meta("ret_dmg")
	var p = load("res://scripts/parcel.gd").new()
	p.setup(c.order, false, Vector3(0.42, 0.34, 0.42), _box_tex())
	p.box_type = "normal"
	p.sorted = true
	p.set_meta("ret", c)
	var at: Vector3 = c.global_transform.origin
	p.translation = Vector3(at.x, 1.25, -0.05)
	main.add_child(p)
	main.parcels.append(p)
	c.set_meta("ret_box", p)
	if dmg != "":
		_decal(p, dmg)
	# бланк возврата рядом
	if ResourceLoader.exists("res://assets/props/return_form.png"):
		var f: Sprite3D = main.prop("return_form", Vector3(at.x + 0.38, 0.985, -0.05), 0, 0.2)
		f.axis = Vector3.AXIS_Y
		f.translation.y = 0.99
		c.set_meta("ret_form", f)
	c.line = tr("Хочу ВЕРНУТЬ посылку!")
	c._say(tr("Хочу ВЕРНУТЬ посылку! Вот она, на стойке."), Color(1, 0.85, 0.5), 4.0)
	Sfx.play("paper", 0.1, -3.0)
	if not "tip_returns" in Game.seen_kinds:
		Game.seen_kinds.append("tip_returns")
		main._flash(tr("ВОЗВРАТ! Целую коробку — в лоток возвратов (слева на стойке).\nИспорченную (порвана, мокрая, следы, вмятина) не принимай — жми «ВОН!»"), 7.0)


func _decal(p, dmg: String) -> void:
	var path := "res://assets/fx/dmg_%s.png" % dmg
	if not ResourceLoader.exists(path):
		return
	var t: Texture = load(path)
	var sz: Vector3 = p.size
	var tw: float = t.get_width()
	var th: float = t.get_height()
	# грани: [сдвиг, поворот, ширина и высота грани]; рисунок целиком влезает в грань (60 %), чуть повёрнут
	for face in [[Vector3(0, sz.y / 2.0 + 0.003, 0), Vector3(-90, 0, 0), Vector2(sz.x, sz.z)],
			[Vector3(0, 0, sz.z / 2.0 + 0.003), Vector3(0, 0, 0), Vector2(sz.x, sz.y)],
			[Vector3(0, 0, -sz.z / 2.0 - 0.003), Vector3(0, 180, 0), Vector2(sz.x, sz.y)]]:
		var s := Sprite3D.new()
		s.texture = t
		s.pixel_size = 0.6 * min(face[2].x / tw, face[2].y / th)
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.translation = face[0]
		s.rotation_degrees = face[1]
		s.rotate_object_local(Vector3.FORWARD, deg2rad(rand_range(-25.0, 25.0)))
		p.add_child(s)
	p.set_meta("dmg", dmg)


func _box_tex() -> Texture:
	if _tex:
		return _tex
	var img := Image.new()
	img.create(96, 64, false, Image.FORMAT_RGB8)
	img.lock()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in 64:
		for x in 96:
			var c := Color(0.72, 0.55, 0.34).darkened(rng.randf() * 0.08)
			if (y % 32) >= 13 and (y % 32) <= 18:
				c = Color(0.78, 0.18, 0.16).darkened(rng.randf() * 0.1)  # красный скотч «возврат»
			if x % 32 == 0 or y % 32 == 0:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	img.unlock()
	_tex = ImageTexture.new()
	_tex.create_from_image(img, 0)
	return _tex


func _process(_delta: float) -> void:
	if area == null:
		return
	for b in area.get_overlapping_bodies():
		if b.is_in_group("parcel") and b.has_meta("ret") and not b.held and not b.delivered:
			_accept(b)


func _accept(p) -> void:
	var c = p.get_meta("ret")
	var dmg: String = p.get_meta("dmg") if p.has_meta("dmg") else ""
	_remove_box(p)
	if dmg == "":
		main.money += 8
		main._flash(tr("Возврат принят. +8 монет"), 2.0)
		_stamp(true)
	else:
		main.money = int(max(0, main.money - 10))
		main._flash(tr("Испорченный возврат (%s)! Гильдия штрафует: -10") % tr(DMG_NAMES[dmg]), 2.5)
		_stamp(false)
	if is_instance_valid(c) and c.state != "leaving":
		_clear(c)
		c.leave_with(tr("Спасибо! Деньги верните на карту.") if dmg == "" else tr("Хе-хе, прокатило!"), true)
	main._refresh_hud()


# «ВОН!» у окна с возвратом. true — обработали тут
func on_kick(c) -> bool:
	if not c.has_meta("ret"):
		return false
	var p = c.get_meta("ret_box") if c.has_meta("ret_box") else null
	var dmg := ""
	if p and is_instance_valid(p) and p.has_meta("dmg"):
		dmg = p.get_meta("dmg")
	if dmg == "":
		return false  # честный возврат выгнали — штраф как за честного клиента
	main.money += 6
	main._flash(tr("Правильно! Испорченное не принимаем. +6 монет"), 2.0)
	_stamp(false)
	_clear(c)
	c.leave_kicked(tr("Да она такая и была!.."))
	main._refresh_hud()
	return true


func on_left(c) -> void:
	if c.has_meta("ret"):
		_clear(c)


func _clear(c) -> void:
	if c.has_meta("ret_box"):
		var p = c.get_meta("ret_box")
		if is_instance_valid(p) and not p.delivered:
			_remove_box(p)
		c.remove_meta("ret_box")
	if c.has_meta("ret_form"):
		var f = c.get_meta("ret_form")
		if is_instance_valid(f):
			f.queue_free()
		c.remove_meta("ret_form")


func _remove_box(p) -> void:
	p.delivered = true
	main.parcels.erase(p)
	if p in main.player.stack:
		main.player.stack.erase(p)
	p.queue_free()


func _stamp(ok: bool) -> void:
	Sfx.play("stamp", 0.05, 0.0)
	var path := "res://assets/ui/stamp_%s.png" % ("green" if ok else "red")
	var root: Control = main.hud_center.get_parent()
	var tr_ := TextureRect.new()
	if ResourceLoader.exists(path):
		tr_.texture = load(path)
	tr_.rect_position = Vector2(256, 96)
	tr_.rect_scale = Vector2(2, 2)
	tr_.rect_rotation = -8
	var l := Label.new()
	l.text = tr("ПРИНЯТО") if ok else tr("ОТКАЗ")
	l.set_meta("keep", true)
	l.add_font_override("font", main.font_big)
	l.add_color_override("font_color", Color(0.2, 0.75, 0.25) if ok else Color(0.9, 0.15, 0.15))
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	l.rect_position = Vector2(256, 96)
	l.rect_size = Vector2(128, 56)
	l.rect_rotation = -8
	root.add_child(l)
	var tl := root.create_tween()
	tl.tween_interval(1.2)
	tl.tween_property(l, "modulate:a", 0.0, 0.5)
	tl.tween_callback(l, "queue_free")
	root.add_child(tr_)
	var tw := root.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(tr_, "modulate:a", 0.0, 0.5)
	tw.tween_callback(tr_, "queue_free")
