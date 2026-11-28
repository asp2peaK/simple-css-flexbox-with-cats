extends Node
# Кот на стойке: его можно гладить. Мурчит — клиенты у окон немного успокаиваются.
# Перегладишь — обидится и шипит. Кадры из листа 64 (props/cat_*), без них — прыжок и сердечки кодом.

const CALM_CD := 25.0  # как часто кот может успокоить клиентов
const CALM_ADD := 0.15  # +15% терпения всем у окон
const ANNOY_PETS := 6  # столько раз подряд — и он злится

var main
var spr: Sprite3D
var base_tex: Texture
var base_px := 0.0
var base_pos := Vector3.ZERO
var hat := false
var state := "sleep"  # sleep / wake / purr / belly / stretch / angry
var state_t := 0.0
var pets := 0
var pets_t := 0.0
var calm_cd := 0.0
var angry_t := 0.0
var bounce := 0.0
var _z_t := 2.0
var hearts := []


func setup(p_main, p_spr: Sprite3D, p_hat: bool) -> void:
	main = p_main
	spr = p_spr
	hat = p_hat
	base_tex = spr.texture
	base_px = spr.pixel_size
	base_pos = spr.translation
	var body: StaticBody = main._clickable(spr, Vector3(0.3, 0.16, 0.2), tr("[ЛКМ/E] Погладить кота"), "_pet_cat")
	body.set_meta("cat", true)


func _frame(name: String) -> void:
	# обычный кот: кадры из листа 64; кот в шляпе: только его картинка
	var path := "res://assets/props/cat_%s.png" % name
	if not hat and name != "sleep" and ResourceLoader.exists(path):
		var t: Texture = load(path)
		spr.texture = t
		spr.pixel_size = base_px  # все кадры листа 64 в одном масштабе
	else:
		spr.texture = base_tex
		spr.pixel_size = base_px
	spr.translation = base_pos + Vector3(0, (spr.texture.get_height() * spr.pixel_size - base_tex.get_height() * base_px) / 2.0, 0)


func pet() -> void:
	if angry_t > 0.0:
		Sfx.play_at("hiss", spr.global_transform.origin, 0.1, -2.0)
		main._flash(tr("Кот обиделся. Дай ему остыть."), 1.5)
		bounce = 0.5
		return
	pets += 1
	pets_t = 3.0
	bounce = 1.0
	_heart()
	if pets >= ANNOY_PETS:
		pets = 0
		angry_t = 20.0
		_set_state("angry", 3.0)
		Sfx.play_at("hiss", spr.global_transform.origin, 0.1, 0.0)
		main._flash(tr("Кот: «Ш-ш-ш!» Перегладил."), 2.0)
		return
	if state == "sleep":
		_set_state("wake", 1.2)
		Sfx.play_at("meow", spr.global_transform.origin, 0.15, -4.0)
	else:
		_set_state(["purr", "purr", "belly", "stretch"][randi() % 4] if pets > 1 else "purr", 4.0)
		Sfx.play_at("purr", spr.global_transform.origin, 0.1, -3.0)
	var bed := Game.lvl("catbed") > 0
	if calm_cd <= 0.0 and pets >= 2:
		calm_cd = CALM_CD * (0.6 if bed else 1.0)
		var n := 0
		for c in main.customers:
			if is_instance_valid(c) and c.state == "at_counter":
				c.patience = min(c.max_patience, c.patience + c.max_patience * CALM_ADD * (2.0 if bed else 1.0))
				n += 1
		if n > 0:
			main._flash(tr("Кот мурчит. Клиенты чуть подобрели (+терпение)."), 2.0)


func _set_state(s: String, dur: float) -> void:
	state = s
	state_t = dur
	_frame(s)


func _heart() -> void:
	var h := Sprite3D.new()
	var path := "res://assets/fx/heart_big.png" if randf() < 0.5 else "res://assets/fx/heart_small.png"
	h.texture = load(path) if ResourceLoader.exists(path) else _heart_tex()
	h.pixel_size = 0.12 / max(1.0, float(h.texture.get_height()))
	h.billboard = SpatialMaterial.BILLBOARD_ENABLED
	h.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	main.add_child(h)
	h.global_transform.origin = spr.global_transform.origin + Vector3(rand_range(-0.12, 0.12), 0.2, 0)
	hearts.append([h, 1.2])


func _zzz() -> void:
	var path := "res://assets/fx/zzz.png"
	var h := Sprite3D.new()
	h.texture = load(path) if ResourceLoader.exists(path) else _z_tex()
	h.pixel_size = 0.08 / max(1.0, float(h.texture.get_height()))
	h.billboard = SpatialMaterial.BILLBOARD_ENABLED
	h.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	main.add_child(h)
	h.global_transform.origin = spr.global_transform.origin + Vector3(-0.15, 0.15, 0)
	hearts.append([h, 1.8])


var _ht: ImageTexture
var _zt: ImageTexture


func _heart_tex() -> Texture:
	if _ht:
		return _ht
	var rows := ["0110110", "1221221", "1222221", "0122210", "0012100", "0001000"]
	_ht = _pix(rows, {"1": Color(0.35, 0.05, 0.15), "2": Color(1.0, 0.45, 0.65)})
	return _ht


func _z_tex() -> Texture:
	if _zt:
		return _zt
	var rows := ["11111", "00010", "00100", "01000", "11111"]
	_zt = _pix(rows, {"1": Color(1, 1, 1)})
	return _zt


func _pix(rows: Array, cols: Dictionary) -> ImageTexture:
	var img := Image.new()
	img.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.lock()
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			img.set_pixel(x, y, cols[ch] if cols.has(ch) else Color(0, 0, 0, 0))
	img.unlock()
	var t := ImageTexture.new()
	t.create_from_image(img, 0)
	return t


func _process(delta: float) -> void:
	if spr == null or not is_instance_valid(spr):
		return
	calm_cd = max(0.0, calm_cd - delta)
	angry_t = max(0.0, angry_t - delta)
	pets_t -= delta
	if pets_t <= 0.0:
		pets = 0
	if state != "sleep":
		state_t -= delta
		if state_t <= 0.0:
			_set_state("sleep", 0.0)
	else:
		_z_t -= delta
		if _z_t <= 0.0:
			_z_t = 3.0
			_zzz()
	# прыжок от поглаживания: сплющился и выпрямился
	bounce = max(0.0, bounce - delta * 3.0)
	var k := sin(bounce * PI * 2.0) * bounce * 0.12
	spr.scale = Vector3(1.0 + k, 1.0 - k, 1.0)
	for e in hearts.duplicate():
		e[1] -= delta
		if e[1] <= 0.0 or not is_instance_valid(e[0]):
			if is_instance_valid(e[0]):
				e[0].queue_free()
			hearts.erase(e)
		else:
			e[0].translation.y += delta * 0.25
			e[0].modulate.a = min(1.0, e[1])
