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
const FACES := ["", "glasses", "bowtie", "eyepatch", "scarf", "mustache", "sunglasses"]
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
const FIT := {"human": {"front": {"hat": 12, "hs": 1.0, "eye": 17, "mouth": 21, "neck": 26, "fs": 1.0}, "side": {"hat": 12, "hs": 1.0, "eye": 16, "mouth": 21, "neck": 26, "fs": 1.0, "dx_eye": 3, "dx_mouth": 6, "dx_neck": 2}, "back": {"hat": 12, "hs": 1.0, "eye": 17, "mouth": 21, "neck": 25, "fs": 1.0}}, "goblin": {"front": {"hat": 10, "hs": 0.9, "eye": 14, "mouth": 22, "neck": 26, "fs": 1.0}, "side": {"hat": 11, "hs": 0.9, "eye": 15, "mouth": 23, "neck": 27, "fs": 1.0, "dx_eye": 4, "dx_mouth": 4, "dx_neck": 1}, "back": {"hat": 13, "hs": 0.9, "eye": 17, "mouth": 25, "neck": 29, "fs": 1.0}}, "orc": {"front": {"hat": 12, "hs": 0.85, "eye": 18, "mouth": 23, "neck": 28, "fs": 1.05}, "side": {"hat": 11, "hs": 0.85, "eye": 19, "mouth": 23, "neck": 27, "fs": 1.05, "hx": 4, "dx_eye": 9, "dx_mouth": 13, "dx_neck": 5}, "back": {"hat": 12, "hs": 0.85, "eye": 17, "mouth": 23, "neck": 28, "fs": 1.05}}}
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
var _t := 0.0
var _view := ""
var _pose := ""
var _flip := false


func _init() -> void:
	M = meta()
	body = _layer(0)
	apron = _layer(1)
	hat = _layer(3)
	face = _layer(2)


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
	for s in [body, apron, hat, face]:
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
	if carrying:
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
	var bt := tex("res://assets/players/%s_%d_%s.png" % [race, int(look.get("skin", 0)), key])
	if bt == null:
		return
	body.texture = bt
	apron.texture = tex("res://assets/players/%s_%s_apron.png" % [race, key])
	apron.modulate = APRONS[int(look.get("apron", 0)) % APRONS.size()]
	var W: float = bt.get_width()
	var H: float = bt.get_height()
	for s in [body, apron]:
		s.flip_h = flip
		s.offset = Vector2(-W / 2.0, 0)
	var hi: Dictionary = M[race]["frames"].get(key, {"top": 2, "cx": W / 2.0})
	var fit: Dictionary = FIT[race][view]
	var sg := -1.0 if flip else 1.0
	var cx: float = (hi["cx"] - W / 2.0) * sg
	var top: float = hi["top"]
	var h_id: String = look.get("hat", "")
	_place(hat, h_id, view, flip, fit["hs"] * ITEM_SC.get(h_id, 1.0), cx + fit.get("hx", 0.0) * sg,
		H - (top + fit["hat"] + ITEM_DY.get(h_id, 0)), "bottom")
	var f: String = look.get("face", "")
	if view == "back" and f != "scarf":
		f = ""
	var row: String = FACE_ROW.get(f, "eye")
	_place(face, f, "front" if view == "back" else view, flip, fit["fs"] * ITEM_SC.get(f, 1.0),
		cx + fit.get("dx_" + row, 0.0) * sg, H - (top + fit[row]), "top" if f == "scarf" else "center")


func _place(s: Sprite3D, id: String, view: String, flip: bool, sc: float, cx: float, y: float, align: String) -> void:
	if id == "":
		s.visible = false
		return
	var t := tex("res://assets/acc/%s_%s.png" % [id, view])
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
	# у Sprite3D ось y смотрит вверх: offset.y — нижний край слоя
	var py := y / sc
	if align == "center":
		py -= h / 2.0
	elif align == "top":
		py -= h
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
	if view == "back" and face_id != "scarf":
		face_id = ""
	if face_id != "":
		var ft := tex("res://assets/acc/%s_%s.png" % [face_id, "front" if view == "back" else view])
		if ft:
			var row: String = FACE_ROW.get(face_id, "eye")
			var fs: float = fit["fs"] * ITEM_SC.get(face_id, 1.0)
			var fw: float = ft.get_width() * fs
			var fh: float = ft.get_height() * fs
			var fy: float = top + fit[row] - (0.0 if face_id == "scarf" else fh / 2.0)
			layers.append([ft, Vector2(hi["cx"] + fit.get("dx_" + row, 0.0) - fw / 2.0, fy), fs, Color(1, 1, 1)])
	var hat_id: String = l.get("hat", "")
	if hat_id != "":
		var ht := tex("res://assets/acc/%s_%s.png" % [hat_id, view])
		if ht:
			var hs: float = fit["hs"] * ITEM_SC.get(hat_id, 1.0)
			var hw: float = ht.get_width() * hs
			var hh: float = ht.get_height() * hs
			layers.append([ht, Vector2(hi["cx"] + fit.get("hx", 0.0) - hw / 2.0, top + fit["hat"] + ITEM_DY.get(hat_id, 0) - hh), hs, Color(1, 1, 1)])
	# общий прямоугольник всех слоёв
	var r := Rect2(Vector2.ZERO, Vector2(W, H))
	for L in layers:
		if L[0] != null:
			r = r.merge(Rect2(L[1], Vector2(L[0].get_width(), L[0].get_height()) * L[2]))
	var bw: float = box.rect_min_size.x
	var bh: float = box.rect_min_size.y
	var z: float = min(zoom, min((bw - 6.0) / r.size.x, (bh - 6.0) / r.size.y))
	if z > 1.0:
		z = floor(z * 4.0) / 4.0
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
