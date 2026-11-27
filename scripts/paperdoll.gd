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
# точки на голове (пиксели от макушки кадра): низ шапки, глаза, рот, шея; масштаб вещей
const ANCHOR := {"human": [9, 17, 21, 26, 1.0], "goblin": [11, 15, 22, 27, 1.0], "orc": [16, 18, 23, 28, 1.15]}
const FACE_AT := {"glasses": 1, "sunglasses": 1, "eyepatch": 1, "mustache": 2, "scarf": 3, "bowtie": 3}

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
	var an: Array = ANCHOR[race]
	var cx: float = hi["cx"] - W / 2.0
	if flip:
		cx = -cx
	var top_from_bottom: float = H - hi["top"]
	_place(hat, look.get("hat", ""), view, flip, an[4], cx, top_from_bottom - an[0], "bottom")
	var f: String = look.get("face", "")
	if view == "back" and f != "scarf":
		f = ""
	var row: int = FACE_AT.get(f, 1)
	var dx := 0.0
	if view == "side":
		dx = 5.0 if row == 1 else (7.0 if row == 2 else 2.0)
		if flip:
			dx = -dx
	_place(face, f, "front" if view == "back" else view, flip, an[4], cx + dx, top_from_bottom - an[row], "center")


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
	var py := (y / sc) if align == "bottom" else (y / sc - h / 2.0)
	s.offset = Vector2(px, py)


# ---- 2D-превью для редактора (слои как TextureRect)
static func preview_into(box: Control, l: Dictionary, view: String, zoom: float) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var M2 := meta()
	if M2.empty():
		return
	var race: String = l.get("race", "human")
	var key := "%s_idle" % view
	var bt := tex("res://assets/players/%s_%d_%s.png" % [race, int(l.get("skin", 0)), key])
	if bt == null:
		return
	var W: float = bt.get_width()
	var H: float = bt.get_height()
	var bw: float = box.rect_min_size.x
	var bh: float = box.rect_min_size.y
	var ox: float = bw / 2.0 - W * zoom / 2.0
	var oy: float = bh - H * zoom - 4.0
	var layers := [[bt, Vector2.ZERO, 1.0, Color(1, 1, 1)]]
	var at := tex("res://assets/players/%s_%s_apron.png" % [race, key])
	layers.append([at, Vector2.ZERO, 1.0, APRONS[int(l.get("apron", 0)) % APRONS.size()]])
	var hi: Dictionary = M2[race]["frames"].get(key, {"top": 2, "cx": W / 2.0})
	var an: Array = ANCHOR[race]
	var face_id: String = l.get("face", "")
	if view == "back" and face_id != "scarf":
		face_id = ""
	if face_id != "":
		var ft := tex("res://assets/acc/%s_%s.png" % [face_id, "front" if view == "back" else view])
		if ft:
			var row: int = FACE_AT.get(face_id, 1)
			var dx: float = 0.0 if view != "side" else (5.0 if row == 1 else (7.0 if row == 2 else 2.0))
			var fw: float = ft.get_width() * an[4]
			var fh: float = ft.get_height() * an[4]
			layers.append([ft, Vector2(hi["cx"] + dx - fw / 2.0, hi["top"] + an[row] - fh / 2.0), an[4], Color(1, 1, 1)])
	var hat_id: String = l.get("hat", "")
	if hat_id != "":
		var ht := tex("res://assets/acc/%s_%s.png" % [hat_id, view])
		if ht:
			var hw: float = ht.get_width() * an[4]
			var hh: float = ht.get_height() * an[4]
			layers.append([ht, Vector2(hi["cx"] - hw / 2.0, hi["top"] + an[0] - hh), an[4], Color(1, 1, 1)])
	for L in layers:
		if L[0] == null:
			continue
		var tr := TextureRect.new()
		tr.texture = L[0]
		tr.expand = true
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.rect_size = Vector2(L[0].get_width(), L[0].get_height()) * L[2] * zoom
		tr.rect_position = Vector2(ox, oy) + L[1] * zoom
		tr.modulate = L[3]
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
