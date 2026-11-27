extends Spatial
# Зеркало: настоящее отражение (вторая камера в маленький Viewport) и редактор внешности по клику.

const Doll := preload("res://scripts/paperdoll.gd")
# стекло в раме: x 15–71, y 34–133 из 88×160; высота подобрана, чтобы видеть себя с головой
const H := 2.4
const GW := H * 56.0 / 160.0
const GH := H * 99.0 / 160.0
const GLASS_Y := H * (160.0 - 83.5) / 160.0

var main
var vp: Viewport
var cam: Camera
var doll
var glass: MeshInstance
var panel: PanelContainer
var preview: Control
var info: Label
var buy_btn: Button
var nick_edit: LineEdit
var rows := {}
var edit := {}
var saved := {}
var view_i := 0
const VIEWS := ["front", "side", "back"]


func build(m) -> void:
	main = m
	var fr := Sprite3D.new()
	var t: Texture = load("res://assets/props/mirror.png")
	t.flags = 0
	fr.texture = t
	fr.pixel_size = H / t.get_height()
	fr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	fr.translation = Vector3(0, H / 2.0, 0)
	add_child(fr)
	main._clickable(fr, Vector3(0.53, 1.15, 0.06), tr("[ЛКМ/E] Зеркало: сменить внешность"), "_open_mirror")
	vp = Viewport.new()
	vp.size = Vector2(136, 240)
	vp.render_target_v_flip = true
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.shadow_atlas_size = 0
	vp.msaa = Viewport.MSAA_DISABLED
	add_child(vp)
	cam = Camera.new()
	cam.cull_mask = 1 | 2
	vp.add_child(cam)
	cam.current = true
	glass = MeshInstance.new()
	var q := QuadMesh.new()
	q.size = Vector2(GW, GH)
	glass.mesh = q
	var gm := SpatialMaterial.new()
	gm.flags_unshaded = true
	gm.albedo_texture = vp.get_texture()
	gm.uv1_scale = Vector3(-1, 1, 1)
	gm.uv1_offset = Vector3(1, 0, 0)
	gm.albedo_color = Color(0.92, 0.95, 1.0)
	glass.material_override = gm
	glass.translation = Vector3(0, GLASS_Y, -0.01)
	glass.layers = 4  # само стекло камера зеркала не видит
	add_child(glass)
	doll = Doll.new()
	doll.set_layers(2)
	doll.view_cam = cam
	main.add_child(doll)
	doll.set_look(Settings.look)
	if main.player and main.player.cam:
		main.player.cam.cull_mask = main.player.cam.cull_mask & ~2


func _process(_d: float) -> void:
	if main == null or main.player == null:
		return
	var p = main.player
	doll.global_transform.origin = p.global_transform.origin
	doll.rotation.y = p.rotation.y
	doll.walking = Vector2(p.velocity.x, p.velocity.z).length() > 0.5 if "velocity" in p else false
	doll.carrying = p.held != null
	var E: Vector3 = p.cam.global_transform.origin
	var C: Vector3 = global_transform.origin + Vector3(0, GLASS_Y, 0)
	var n: Vector3 = global_transform.basis.z.normalized()
	var d: float = (E - C).dot(n)
	var near: bool = d > 0.15 and (E - C).length() < 9.0
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS if near else Viewport.UPDATE_DISABLED
	if not near:
		return
	var E2: Vector3 = E - 2.0 * d * n
	# камера за зеркалом смотрит на центр стекла; угол обзора — ровно на стекло
	var dist: float = (C - E2).length()
	cam.global_transform = Transform(Basis(), E2).looking_at(C, Vector3.UP)
	var c: float = abs(n.dot((C - E2).normalized()))
	var nr: float = dist - 0.5 * max(GH, GW) * sqrt(max(0.0, 1.0 - c * c)) + 0.02
	cam.set_perspective(clamp(rad2deg(2.0 * atan(GH * 0.5 / dist)), 5.0, 120.0), max(0.05, nr), 40.0)


# ---------------------------------------------------------------- редактор
func open() -> void:
	saved = Settings.look.duplicate()
	edit = Settings.look.duplicate()
	if not edit.get("face", "") in Doll.FACES:
		edit["face"] = ""
	if not edit.get("hat", "") in Doll.HATS:
		edit["hat"] = ""
	if panel:
		panel.queue_free()
	panel = PanelContainer.new()
	panel.theme = load("res://scripts/ui_theme.gd").make()
	panel.pause_mode = Node.PAUSE_MODE_PROCESS
	panel.rect_position = Vector2(40, 4)
	panel.rect_min_size = Vector2(420, 300)
	main.pause_panel.get_parent().add_child(panel)
	var font: Font = main.font_big.duplicate()
	if font is DynamicFont:
		font.outline_size = 0
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("ЗЕРКАЛО")
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", font)
	load("res://scripts/ui_theme.gd").banner(title)
	v.add_child(title)
	var h := HBoxContainer.new()
	v.add_child(h)
	var left := VBoxContainer.new()
	h.add_child(left)
	preview = Control.new()
	preview.rect_min_size = Vector2(160, 252)
	preview.rect_clip_content = true
	left.add_child(preview)
	var rot := Button.new()
	rot.text = tr("Повернуть")
	rot.add_font_override("font", font)
	rot.connect("pressed", self, "_rotate")
	left.add_child(rot)
	var r := VBoxContainer.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(r)
	var nr := HBoxContainer.new()
	r.add_child(nr)
	var nl := Label.new()
	nl.text = tr("Ник")
	nl.rect_min_size = Vector2(78, 0)
	nl.add_font_override("font", font)
	nr.add_child(nl)
	nick_edit = LineEdit.new()
	nick_edit.text = edit.get("nick", "")
	nick_edit.max_length = 16
	nick_edit.placeholder_text = tr("Игрок")
	nick_edit.rect_min_size = Vector2(230, 0)
	nick_edit.add_font_override("font", font)
	nr.add_child(nick_edit)
	for key in ["race", "skin", "apron", "hat", "face"]:
		var row := HBoxContainer.new()
		r.add_child(row)
		var l := Label.new()
		l.text = tr({"race": "Раса", "skin": "Кожа", "apron": "Фартук", "hat": "Шапка", "face": "Лицо"}[key])
		l.rect_min_size = Vector2(78, 0)
		l.add_font_override("font", font)
		row.add_child(l)
		var a := Button.new()
		a.text = "<"
		a.add_font_override("font", font)
		a.connect("pressed", self, "_step", [key, -1])
		row.add_child(a)
		var val := Label.new()
		val.rect_min_size = Vector2(196, 0)
		val.align = Label.ALIGN_CENTER
		val.clip_text = true
		val.add_font_override("font", font)
		row.add_child(val)
		var b := Button.new()
		b.text = ">"
		b.add_font_override("font", font)
		b.connect("pressed", self, "_step", [key, 1])
		row.add_child(b)
		rows[key] = val
	info = Label.new()
	info.autowrap = true
	info.rect_min_size = Vector2(330, 34)
	info.add_font_override("font", font)
	r.add_child(info)
	var br := HBoxContainer.new()
	r.add_child(br)
	buy_btn = Button.new()
	buy_btn.add_font_override("font", font)
	buy_btn.connect("pressed", self, "_buy")
	br.add_child(buy_btn)
	var ok := Button.new()
	ok.text = tr("Готово")
	ok.add_font_override("font", font)
	ok.connect("pressed", self, "close")
	br.add_child(ok)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()


func is_open() -> bool:
	return panel != null and is_instance_valid(panel) and panel.visible


func _rotate() -> void:
	view_i = (view_i + 1) % VIEWS.size()
	_refresh()


func _list(key: String) -> Array:
	match key:
		"race":
			return Doll.RACES
		"skin":
			return [0, 1, 2]
		"apron":
			return range(Doll.APRONS.size())
		"hat":
			return Doll.HATS
		"face":
			return Doll.FACES
	return []


func _step(key: String, d: int) -> void:
	var arr: Array = _list(key)
	var i: int = arr.find(edit.get(key))
	if i < 0:
		i = 0
	edit[key] = arr[(i + d + arr.size()) % arr.size()]
	_refresh()


func _cur_locked() -> String:
	# первая некупленная вещь в текущем наборе
	for key in ["race", "hat", "face"]:
		var id: String = edit[key]
		if not Doll.owns(id):
			return id
	return ""


func _price(id: String) -> int:
	if id in Doll.RACES:
		return Doll.RACE_PRICE[id]
	return Doll.PRICE.get(id, 0)


func _refresh() -> void:
	rows["race"].text = tr(Doll.RACE_NAMES[edit["race"]])
	rows["skin"].text = "%d / 3" % (int(edit["skin"]) + 1)
	rows["apron"].text = "■■■"
	rows["apron"].add_color_override("font_color", Doll.APRONS[int(edit["apron"])])
	rows["hat"].text = tr(Doll.ITEM_NAMES[edit["hat"]])
	rows["face"].text = tr(Doll.ITEM_NAMES[edit["face"]])
	for key in ["race", "hat", "face"]:
		var locked: bool = not Doll.owns(edit[key])
		rows[key].add_color_override("font_color", Color(0.55, 0.35, 0.3) if locked else Color(0.24, 0.14, 0.07))
	Doll.preview_into(preview, edit, VIEWS[view_i], 2.0)
	var lk := _cur_locked()
	if lk == "":
		info.text = tr("Монеты: %d") % Game.bank
		buy_btn.visible = false
	else:
		var pr := _price(lk)
		var nm: String = tr(Doll.RACE_NAMES[lk]) if lk in Doll.RACES else tr(Doll.ITEM_NAMES[lk])
		buy_btn.visible = true
		if pr < 0:
			info.text = tr("«%s» — секрет. Найди, кто их носит...") % nm
			buy_btn.visible = false
		elif Game.mode != "career" or Net.active and not Net.is_host:
			info.text = tr("«%s»: %d монет. Купить можно в карьере.") % [nm, pr]
			buy_btn.visible = false
		else:
			info.text = tr("«%s»: %d монет (у тебя %d)") % [nm, pr, Game.bank]
			buy_btn.text = tr("Купить")
			buy_btn.disabled = Game.bank < pr


func _buy() -> void:
	var lk := _cur_locked()
	if lk == "":
		return
	var pr := _price(lk)
	if pr < 0 or Game.bank < pr:
		return
	Game.bank -= pr
	Settings.owned.append(lk)
	Ach.unlock("ACH_MIRROR")
	var all_hats := true
	for h in Doll.HATS:
		if h != "" and Doll.PRICE.get(h, 0) > 0 and not h in Settings.owned:
			all_hats = false
	if all_hats:
		Ach.unlock("ACH_ALL_HATS")
	Game.save_game()
	Settings.save_cfg()
	Sfx.play("coin", 0.0, -4.0)
	main._refresh_hud()
	_refresh()


func close() -> void:
	edit["nick"] = nick_edit.text.strip_edges()
	# некупленное не надеваем: возвращаем то, что было
	for key in ["race", "hat", "face"]:
		if not Doll.owns(edit[key]):
			edit[key] = saved[key]
	Settings.look = edit.duplicate()
	Settings.save_cfg()
	doll.set_look(Settings.look)
	panel.queue_free()
	panel = null
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if main.has_method("_send_look"):
		main._send_look()
