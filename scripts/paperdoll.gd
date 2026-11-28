extends Spatial
# Персонаж игрока из слоёв: тело (раса + кожа), фартук (красится), шапка, аксессуар на лицо.
# Вид спереди/сбоку/сзади выбирается по направлению взгляда персонажа относительно камеры.

const PIXEL := 0.02
const RACES := ["human", "goblin", "orc"]
const RACE_NAMES := {"human": "Человек", "goblin": "Гоблин", "orc": "Орк"}
const RACE_PRICE := {"human": 0, "goblin": 150, "orc": 150}
const APRONS := [Color(0.2, 0.75, 0.95), Color(0.9, 0.25, 0.2), Color(0.25, 0.75, 0.3), Color(0.95, 0.75, 0.2),
	Color(0.65, 0.35, 0.9), Color(1.0, 0.5, 0.75), Color(0.95, 0.55, 0.15), Color(0.25, 0.25, 0.3)]
const HATS := ["", "postal", "beanie", "chef", "bandana", "propeller", "flowers", "headphones", "wizard", "cowboy",
	"viking", "crown", "mouse_ears"]
const FACES := ["", "glasses", "bowtie", "eyepatch", "mustache", "sunglasses"]
const ITEM_NAMES := {"": "Нет", "postal": "Почтовая фуражка", "beanie": "Шапка с помпоном", "chef": "Колпак повара",
	"bandana": "Пиратская бандана", "propeller": "Кепка с пропеллером", "flowers": "Венок", "headphones": "Наушники",
	"wizard": "Колпак волшебника", "cowboy": "Ковбойская шляпа", "viking": "Шлем викинга", "crown": "Корона",
	"mouse_ears": "Мышиные ушки", "glasses": "Очки", "bowtie": "Бабочка", "eyepatch": "Повязка пирата",
	"scarf": "Шарф", "mustache": "Накладные усы", "sunglasses": "Тёмные очки"}
const PRICE := {"postal": 0, "beanie": 0, "chef": 40, "bandana": 40, "propeller": 50, "flowers": 40,
	"headphones": 60, "wizard": 80, "cowboy": 80, "viking": 100, "crown": 150, "mouse_ears": -1,
	"glasses": 0, "bowtie": 25, "eyepatch": 30, "scarf": 40, "mustache": 40, "sunglasses": 50}
# посадка вещей: для каждой расы и вида — строки (в пикселях от верха головы кадра) низа шапки, глаз, рта, шеи,
# масштаб шапок hs и лицевых вещей fs, сдвиги по x для вида сбоку (подобрано по сетке «все расы × все вещи»)
const FIT := {"human": {"front": {"hat": 12, "hs": 1.0, "eye": 17, "mouth": 21, "neck": 26, "fs": 1.0}, "side": {"hat": 12, "hs": 1.0, "eye": 16, "mouth": 21, "neck": 26, "fs": 1.0, "dx_eye": 3, "dx_mouth": 6, "dx_neck": 2, "fx_eye": 11, "fx_mouth": 11, "fx_neck": 7}, "back": {"hat": 12, "hs": 1.0, "eye": 17, "mouth": 21, "neck": 25, "fs": 1.0}}, "goblin": {"front": {"hat": 10, "hs": 1.0, "eye": 14, "mouth": 22, "neck": 26, "fs": 1.0}, "side": {"hat": 11, "hs": 1.0, "eye": 15, "mouth": 23, "neck": 27, "fs": 1.0, "dx_eye": 4, "dx_mouth": 4, "dx_neck": 1, "fx_eye": 12, "fx_mouth": 13, "fx_neck": 8}, "back": {"hat": 13, "hs": 1.0, "eye": 17, "mouth": 25, "neck": 29, "fs": 1.0}}, "orc": {"front": {"hat": 12, "hs": 1.0, "eye": 18, "mouth": 23, "neck": 28, "fs": 1.0}, "side": {"hat": 11, "hs": 1.0, "eye": 19, "mouth": 23, "neck": 27, "fs": 1.0, "hx": 6, "dx_eye": 9, "dx_mouth": 13, "dx_neck": 5, "fx_eye": 16, "fx_mouth": 17, "fx_neck": 12}, "back": {"hat": 12, "hs": 1.0, "eye": 17, "mouth": 23, "neck": 28, "fs": 1.0}}}
# точечные поправки «раса/вид/вещь» (или «*/вид/вещь»): [сдвиг x, сдвиг y, масштаб]
const OVER := {"*/side/headphones": [0, 6, 1.0], "human/side/headphones": [-2, 6, 1.0], "goblin/side/headphones": [-6, 7, 1.0], "orc/side/headphones": [0, 7, 1.0], "*/side/bandana": [2, 2, 1.0], "*/front/bandana": [0, 1, 1.0], "*/back/bandana": [0, 1, 1.0], "*/side/mouse_ears": [2, 1, 1.0], "*/side/bowtie": [-1, 2, 1.0], "*/front/bowtie": [0, 1, 1.0], "orc/front/bandana": [0, 3, 1.0], "orc/back/bandana": [0, 2, 1.0], "orc/side/bandana": [2, 3, 1.0]}
const FACE_ROW := {"glasses": "eye", "sunglasses": "eye", "eyepatch": "eye", "mustache": "mouth", "scarf": "neck", "bowtie": "neck"}
const ITEM_SC := {"scarf": 0.7}
const ITEM_DY := {"headphones": 5, "viking": -2}

static func meta() -> Dictionary:
	var f := File.new()
	if f.open("res://assets/players/meta.json", File.READ) != OK:
		return {}
	var d = parse_json(f.get_as_text())
	f.close()
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func available() -> bool:
	return ResourceLoader.exists("res://assets/players/human_0_front_idle.png")


static func tex(path: String) -> Texture:
	if not ResourceLoader.exists(path):
		return null
	var t: Texture = load(path)
	t.flags = 0
	return t


static func over(race: String, view: String, id: String) -> Array:
	return OVER.get("%s/%s/%s" % [race, view, id], OVER.get("*/%s/%s" % [view, id], [0, 0, 1.0]))


# центр вещи в пикселях тела (без отражения); сбоку лицевые вещи прижимаются правым краем к лицу
static func face_cx(fit: Dictionary, row: String, view: String, t: Texture, sc: float) -> float:
	if view == "side" and fit.has("fx_" + row) and t:
		return fit["fx_" + row] - t.get_width() * sc / 2.0
	return fit.get("dx_" + row, 0.0)


# у гоблина и орка свои версии вещей, нарисованные сразу нужного размера
static func acc_tex(race: String, id: String, view: String) -> Texture:
	var t := tex("res://assets/acc/%s/%s_%s.png" % [race, id, view])
	return t if t else tex("res://assets/acc/%s_%s.png" % [id, view])


static func owns(id: String) -> bool:
	return id == "" or id in Settings.owned


var look := {}
var M := {}
var body: Sprite3D
var apron: Sprite3D
var hat: Sprite3D
var face: Sprite3D
var view_cam: Camera  # для зеркала: вид считаем от этой камеры
var walking := false
var carrying := false
var down := ""  # оглушён: "back" — лежит на спине, "front" — лицом в пол
var big_head := false  # проклятие «большая голова»
var headspr: Sprite3D
var _t := 0.0
var _view := ""
var _pose := ""
var _flip := false
var _bw := 0.0


func _init() -> void:
	M = meta()
	body = _layer(0)
	apron = _layer(1)
	hat = _layer(3)
	face = _layer(2)
	headspr = _layer(0)
	headspr.region_enabled = true
	headspr.visible = false


func _layer(prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.pixel_size = PIXEL
	s.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
	# тело непрозрачное, остальные слои — прозрачный проход поверх (иначе мерцают в одной плоскости)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if prio == 0 else SpriteBase3D.ALPHA_CUT_DISABLED
	s.render_priority = prio
	s.centered = false
	add_child(s)
	return s


func set_layers(mask: int) -> void:
	for s in [body, apron, hat, face, headspr]:
		s.layers = mask


func set_look(l: Dictionary) -> void:
	look = l.duplicate()
	if not look.get("race", "") in RACES:
		look["race"] = "human"
	_view = ""
	_refresh(true)


func _process(delta: float) -> void:
	_t += delta
	_refresh(false)
	_nudge()


# слои в одной плоскости с телом спорят за глубину, и тело местами просвечивает сквозь шапку
# (у орка — чёрный пучок волос сквозь шлем). Чуть выдвигаем слои к камере: на экране
# они остаются на месте, но всегда оказываются ближе тела.
func _nudge() -> void:
	if not is_inside_tree():
		return
	var cam: Camera = view_cam if view_cam else get_viewport().get_camera()
	if cam == null:
		return
	var d: Vector3 = cam.global_transform.origin - global_transform.origin
	if d.length() < 0.01:
		return
	var dl: Vector3 = global_transform.basis.orthonormalized().xform_inv(d.normalized())
	apron.translation = dl * 0.006
	face.translation = dl * 0.012
	hat.translation = dl * 0.018
	headspr.translation = dl * 0.009


func _refresh(force: bool) -> void:
	if M.empty() or look.empty():
		return
	if not is_inside_tree():
		return
	var cam: Camera = view_cam if view_cam else get_viewport().get_camera()
	var view := "front"
	var flip := false
	if cam:
		var to_cam: Vector3 = cam.global_transform.origin - global_transform.origin
		to_cam.y = 0
		var fwd: Vector3 = -global_transform.basis.z
		fwd.y = 0
		if to_cam.length() > 0.01 and fwd.length() > 0.01:
			var a := fwd.normalized().dot(to_cam.normalized())
			var side := fwd.normalized().cross(to_cam.normalized()).y
			if a > 0.5:
				view = "front"
			elif a < -0.5:
				view = "back"
			else:
				view = "side"
				flip = side < 0.0
	var pose := "idle"
	if down != "":
		pose = "down_" + down
	elif carrying:
		pose = "carry"
	elif walking:
		pose = "walk" if int(_t * 5.0) % 2 == 0 else "walk2"
	if not force and view == _view and pose == _pose and flip == _flip:
		return
	_view = view
	_pose = pose
	_flip = flip
	var race: String = look["race"]
	var key := "%s_%s" % [view, pose]
	scale = Vector3.ONE
	if down != "":
		if _refresh_down(race):
			return
		key = "front_idle"
		scale = Vector3(1.25, 0.35, 1.0)  # кадров «лёжа» ещё нет: просто сплющиваем
	var bt := tex("res://assets/players/%s_%d_%s.png" % [race, int(look.get("skin", 0)), key])
	if bt == null:
		return
	body.texture = bt
	apron.texture = tex("res://assets/players/%s_%s_apron.png" % [race, key])
	apron.modulate = APRONS[int(look.get("apron", 0)) % APRONS.size()]
	var W: float = bt.get_width()
	var H: float = bt.get_height()
	_bw = W
	for s in [body, apron]:
		s.flip_h = flip
		s.offset = Vector2(-W / 2.0, 0)
	var hi: Dictionary = M[race]["frames"].get(key, {"top": 2, "cx": W / 2.0})
	var fit: Dictionary = FIT[race][view]
	var sg := -1.0 if flip else 1.0
	var cx: float = (hi["cx"] - W / 2.0) * sg
	var top: float = hi["top"]
	var h_id: String = look.get("hat", "")
	var ho: Array = over(race, view, h_id)
	_place(hat, h_id, view, flip, fit["hs"] * ITEM_SC.get(h_id, 1.0) * ho[2], cx + (fit.get("hx", 0.0) + ho[0]) * sg,
		H - (top + fit["hat"] + ITEM_DY.get(h_id, 0) + ho[1]), "bottom")
	var f: String = look.get("face", "")
	if view == "back" or not f in FACES:
		f = ""
	var row: String = FACE_ROW.get(f, "eye")
	var fo: Array = over(race, view, f)
	var fsc: float = fit["fs"] * ITEM_SC.get(f, 1.0) * fo[2]
	var ft: Texture = acc_tex(race, f, view) if f != "" else null
	_place(face, f, view, flip, fsc, cx + (face_cx(fit, row, view, ft, fsc) + fo[0]) * sg, H - (top + fit[row] + fo[1]), "center")
	headspr.visible = false
	if down != "":
		hat.visible = false
		face.visible = false
	elif big_head:
		_apply_big_head(bt, flip, W, H, float(hi.get("neck", top + 26)))


const BIG_K := 1.7


# большая голова: верх кадра (до шеи) рисуем ещё раз крупнее, шапку и очки растягиваем от шеи
func _apply_big_head(bt: Texture, flip: bool, W: float, H: float, neck: float) -> void:
	headspr.texture = bt
	headspr.region_rect = Rect2(0, 0, W, neck)
	headspr.pixel_size = PIXEL * BIG_K
	headspr.flip_h = flip
	headspr.offset = Vector2(-W / 2.0, (H - neck) / BIG_K)
	headspr.visible = true
	var nw := (H - neck) * PIXEL
	for s in [hat, face]:
		if not s.visible:
			continue
		var ps: float = s.pixel_size
		var wy: float = s.offset.y * ps
		var wx: float = s.offset.x * ps
		s.pixel_size = ps * BIG_K
		s.offset = Vector2(wx * BIG_K / s.pixel_size, (nw + (wy - nw) * BIG_K) / s.pixel_size)


# кадр «лежит»: свой спрайт на расу/кожу, если уже нарисован
func _refresh_down(race: String) -> bool:
	var key := "down_" + down
	var bt := tex("res://assets/players/%s_%d_%s.png" % [race, int(look.get("skin", 0)), key])
	if bt == null:
		return false
	body.texture = bt
	apron.texture = tex("res://assets/players/%s_%s_apron.png" % [race, key])
	apron.modulate = APRONS[int(look.get("apron", 0)) % APRONS.size()]
	var W: float = bt.get_width()
	for s in [body, apron]:
		s.flip_h = _flip
		s.offset = Vector2(-W / 2.0, 0)
	hat.visible = false
	face.visible = false
	headspr.visible = false
	return true


func set_state(p_down: String, p_big: bool) -> void:
	if p_down == down and p_big == big_head:
		return
	down = p_down
	big_head = p_big
	_view = ""


func _place(s: Sprite3D, id: String, view: String, flip: bool, sc: float, cx: float, y: float, align: String) -> void:
	if id == "":
		s.visible = false
		return
	var t := acc_tex(look.get("race", "human"), id, view)
	if t == null:
		s.visible = false
		return
	s.visible = true
	s.texture = t
	s.pixel_size = PIXEL * sc
	s.flip_h = flip
	var w: float = t.get_width()
	var h: float = t.get_height()
	# смещение в пикселях самого слоя: позиция задаётся в пикселях тела, переводим через масштаб
	var px := cx / sc - w / 2.0
	if sc == 1.0:
		# ровно по пиксельной сетке тела, иначе вещь выглядит кривой
		px = round(px + _bw / 2.0) - _bw / 2.0
	# у Sprite3D ось y смотрит вверх: offset.y — нижний край слоя
	var py := y / sc
	if align == "center":
		py -= h / 2.0
	elif align == "top":
		py -= h
	if sc == 1.0:
		py = round(py)
	s.offset = Vector2(px, py)


# ---- 2D-превью для редактора (слои как TextureRect); масштаб подбирается, чтобы влезло всё вместе с шапкой
static func preview_into(box: Control, l: Dictionary, view: String, zoom: float) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var M2 := meta()
	if M2.empty():
		return
	var race: String = l.get("race", "human")
	if not race in RACES:
		race = "human"
	var key := "%s_idle" % view
	var bt := tex("res://assets/players/%s_%d_%s.png" % [race, int(l.get("skin", 0)), key])
	if bt == null:
		return
	var W: float = bt.get_width()
	var H: float = bt.get_height()
	var layers := [[bt, Vector2.ZERO, 1.0, Color(1, 1, 1)]]
	var at := tex("res://assets/players/%s_%s_apron.png" % [race, key])
	layers.append([at, Vector2.ZERO, 1.0, APRONS[int(l.get("apron", 0)) % APRONS.size()]])
	var hi: Dictionary = M2[race]["frames"].get(key, {"top": 2, "cx": W / 2.0})
	var fit: Dictionary = FIT[race][view]
	var top: float = hi["top"]
	var face_id: String = l.get("face", "")
	if view == "back" or not face_id in FACES:
		face_id = ""
	if face_id != "":
		var ft := acc_tex(race, face_id, view)
		if ft:
			var row: String = FACE_ROW.get(face_id, "eye")
			var fo: Array = over(race, view, face_id)
			var fs: float = fit["fs"] * ITEM_SC.get(face_id, 1.0) * fo[2]
			var fw: float = ft.get_width() * fs
			var fh: float = ft.get_height() * fs
			var fp := Vector2(hi["cx"] + face_cx(fit, row, view, ft, fs) + fo[0] - fw / 2.0, top + fit[row] + fo[1] - fh / 2.0)
			if fs == 1.0:
				fp = fp.round()
			layers.append([ft, fp, fs, Color(1, 1, 1)])
	var hat_id: String = l.get("hat", "")
	if hat_id != "":
		var ht := acc_tex(race, hat_id, view)
		if ht:
			var ho: Array = over(race, view, hat_id)
			var hs: float = fit["hs"] * ITEM_SC.get(hat_id, 1.0) * ho[2]
			var hw: float = ht.get_width() * hs
			var hh: float = ht.get_height() * hs
			var hp := Vector2(hi["cx"] + fit.get("hx", 0.0) + ho[0] - hw / 2.0, top + fit["hat"] + ITEM_DY.get(hat_id, 0) + ho[1] - hh)
			if hs == 1.0:
				hp = hp.round()
			layers.append([ht, hp, hs, Color(1, 1, 1)])
	# общий прямоугольник всех слоёв
	var r := Rect2(Vector2.ZERO, Vector2(W, H))
	for L in layers:
		if L[0] != null:
			r = r.merge(Rect2(L[1], Vector2(L[0].get_width(), L[0].get_height()) * L[2]))
	var bw: float = box.rect_min_size.x
	var bh: float = box.rect_min_size.y
	var z: float = min(zoom, min((bw - 6.0) / r.size.x, (bh - 6.0) / r.size.y))
	# только целый масштаб: экран 640×360 растягивается целиком, дробный масштаб делает пиксели кривыми
	z = max(1.0, floor(z))
	var o := Vector2(bw / 2.0 - (r.position.x + r.size.x / 2.0) * z, bh - 3.0 - (r.position.y + r.size.y) * z)
	for L in layers:
		if L[0] == null:
			continue
		var tr := TextureRect.new()
		tr.texture = L[0]
		tr.expand = true
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.rect_size = Vector2(L[0].get_width(), L[0].get_height()) * L[2] * z
		tr.rect_position = o + L[1] * z
		tr.modulate = L[3]
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
