extends Node
# Достижения: свои (работают без Steam) + отправка в Steam, если игра запущена через GodotSteam.
# Хранятся отдельно от сохранения карьеры: user://achievements.cfg

const PATH := "user://achievements.cfg"
# id (= API-имя в Steamworks), иконка, название, что сделать, скрытое
const LIST := [
	["ACH_FIRST_PARCEL", 1, "Первая посылка", "Выдай первую посылку", false],
	["ACH_PARCELS_100", 2, "Сотня", "Выдай 100 посылок", false],
	["ACH_PARCELS_1000", 3, "Тысяча коробок", "Выдай 1000 посылок", false],
	["ACH_NO_COMPLAINTS", 4, "Ни одной жалобы", "Отработай смену без злых клиентов (не меньше 5 выдач)", false],
	["ACH_FIRST_KICK", 5, "ВОН!", "Выгони мошенника красной кнопкой", false],
	["ACH_KICK_25", 6, "Детектор подделок", "Выгони 25 мошенников", false],
	["ACH_SAFE", 7, "Взломщик", "Открой сейф по коду с чека", true],
	["ACH_TAMER", 8, "Укротитель", "Успокой живую посылку или мимика в клетке", true],
	["ACH_SORT_100", 9, "Сортировщик", "Разложи 100 коробок из поставок по своим стеллажам", false],
	["ACH_DISTRICT_2", 10, "Новый район", "Доберись до второго района", false],
	["ACH_DISTRICT_6", 11, "Почта всех земель", "Доберись до шестого района", false],
	["ACH_BOSS", 12, "Тьма отступила", "Отдай Тёмному Почтмейстеру все его посылки", true],
	["ACH_CHAOS_1500", 13, "Хаос приручён", "Набери 1500 очков в режиме хаоса", false],
	["ACH_FACE_HIT", 14, "Прямо в лицо", "Попади посылкой клиенту в лицо", true],
	["ACH_FAST", 15, "Скорая выдача", "Выдай посылку меньше чем за 5 секунд после заказа", true],
	["ACH_BANK_2000", 16, "Касса полна", "Накопи 2000 монет", false],
	["ACH_DECOR_5", 17, "Уютный пункт", "Купи 5 вещей декора", false],
	["ACH_MIRROR", 18, "Модник", "Купи первую вещь у зеркала", false],
	["ACH_ALL_HATS", 19, "Шляпный маньяк", "Купи все шапки у зеркала", false],
	["ACH_REP_100", 20, "Народная любовь", "Подними репутацию до 100", false],
	["ACH_ALL_TASKS", 21, "План выполнен", "Выполни все задания дня за одну смену", false],
	["ACH_COOP", 22, "Вместе веселее", "Отработай смену в коопе", false],
	["ACH_MAGA", 23, "Друг студии", "Найди секретного гостя", true],
	["ACH_MASTER", 24, "Мастер пункта", "Получи все остальные достижения", false],
]
const GOALS := {"delivered": [[1, "ACH_FIRST_PARCEL"], [100, "ACH_PARCELS_100"], [1000, "ACH_PARCELS_1000"]],
	"kicked": [[1, "ACH_FIRST_KICK"], [25, "ACH_KICK_25"]], "sorted": [[100, "ACH_SORT_100"]]}

var got := {}  # id -> unix time
var counts := {}
var _queue := []
var _layer: CanvasLayer
var _busy := false
var steam = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		got = c.get_value("ach", "got", {})
		counts = c.get_value("ach", "counts", {})
	_init_steam()
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)


# GodotSteam: без steamInitEx() достижения в Steam не уходят.
func _init_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return
	var s = Engine.get_singleton("Steam")
	var r: Dictionary = s.steamInitEx()
	print("Steam init: ", r)
	if int(r.get("status", 1)) != 0:
		return
	steam = s
	set_process(true)
	Settings.steam_lang(str(steam.getCurrentGameLanguage()))
	# ник по умолчанию — из Steam (в зеркале его можно поменять)
	if str(Settings.look.get("nick", "")).strip_edges() == "":
		var pn: String = str(steam.getPersonaName()).strip_edges()
		if pn != "":
			Settings.look["nick"] = pn.substr(0, 16)
	# то, что открыто раньше без Steam, тоже отправляем
	for id in got.keys():
		steam.setAchievement(id)
	if got.size() > 0:
		steam.storeStats()


func _process(_delta: float) -> void:
	if steam:
		steam.run_callbacks()


func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("ach", "got", got)
	c.set_value("ach", "counts", counts)
	c.save(PATH)


func has(id: String) -> bool:
	return got.has(id)


func info(id: String) -> Array:
	for a in LIST:
		if a[0] == id:
			return a
	return []


func count(key: String) -> int:
	return int(counts.get(key, 0))


# счётчик + проверка порогов
func add(key: String, n := 1) -> void:
	counts[key] = count(key) + n
	for g in GOALS.get(key, []):
		if counts[key] >= g[0]:
			unlock(g[1])
	_save()


func unlock(id: String) -> void:
	if got.has(id) or info(id).empty():
		return
	if not Game.records_ok():
		return  # моды со скриптами/паки или правка сейва: достижения не даём
	got[id] = OS.get_unix_time()
	_save()
	if steam:
		steam.setAchievement(id)
		steam.storeStats()
	_queue.append(id)
	if not _busy:
		_show_next()
	if id != "ACH_MASTER" and got.size() >= LIST.size() - 1:
		unlock("ACH_MASTER")


func icon(id: String) -> Texture:
	var a: Array = info(id)
	if a.empty():
		return null
	var p: String = "res://assets/ach/ach_%02d.png" % a[1]
	if not ResourceLoader.exists(p):
		return null
	var t: Texture = load(p)
	return t


# ---- всплывашка «Достижение получено»
func _show_next() -> void:
	if _queue.empty():
		_busy = false
		return
	_busy = true
	var id: String = _queue.pop_front()
	var a: Array = info(id)
	var panel := PanelContainer.new()
	panel.theme = load("res://scripts/ui_theme.gd").make()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	panel.add_child(h)
	var ic := TextureRect.new()
	ic.texture = icon(id)
	ic.expand = true
	ic.rect_min_size = Vector2(40, 40)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var v := VBoxContainer.new()
	h.add_child(v)
	var t1 := Label.new()
	t1.text = tr("Достижение получено!")
	t1.add_color_override("font_color", Color(0.55, 0.3, 0.05))
	v.add_child(t1)
	var t2 := Label.new()
	t2.text = tr(a[2])
	v.add_child(t2)
	_layer.add_child(panel)
	panel.rect_position = Vector2(640 - 250, -60)
	panel.rect_min_size = Vector2(240, 0)
	Sfx.play("coin", 0.0, -3.0)
	var tw := create_tween()
	tw.tween_property(panel, "rect_position:y", 8.0, 0.35)
	tw.tween_interval(3.2)
	tw.tween_property(panel, "rect_position:y", -70.0, 0.35)
	tw.tween_callback(panel, "queue_free")
	tw.tween_callback(self, "_show_next")


# ---- экран достижений (для меню): сетка иконок с описаниями, скрытые — «???»
func build_panel(font: Font) -> Control:
	var panel := PanelContainer.new()
	panel.theme = load("res://scripts/ui_theme.gd").make()
	panel.rect_position = Vector2(20, 8)
	panel.rect_min_size = Vector2(600, 344)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("ДОСТИЖЕНИЯ") + "   %d / %d" % [got.size(), LIST.size()]
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", font)
	load("res://scripts/ui_theme.gd").banner(title)
	v.add_child(title)
	var sc := ScrollContainer.new()
	sc.rect_min_size = Vector2(590, 262)
	sc.scroll_horizontal_enabled = false
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for a in LIST:
		var on: bool = got.has(a[0])
		var row := HBoxContainer.new()
		row.rect_min_size = Vector2(286, 44)
		g.add_child(row)
		var ic := TextureRect.new()
		ic.texture = icon(a[0])
		ic.expand = true
		ic.rect_min_size = Vector2(40, 40)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not on:
			ic.modulate = Color(0.25, 0.25, 0.28) if a[4] else Color(0.55, 0.55, 0.55, 0.8)
		row.add_child(ic)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		var n := Label.new()
		n.text = tr(a[2]) if on or not a[4] else "???"
		n.add_font_override("font", _plain(font))
		n.add_color_override("font_color", Color(0.24, 0.14, 0.07) if on else Color(0.45, 0.38, 0.32))
		tv.add_child(n)
		var d := Label.new()
		d.text = tr(a[3]) if on or not a[4] else tr("Скрытое достижение")
		d.autowrap = true
		d.rect_min_size = Vector2(236, 0)
		d.add_color_override("font_color", Color(0.4, 0.3, 0.22))
		d.add_font_override("font", _small_font(font))
		tv.add_child(d)
	return panel


func _plain(font: Font) -> Font:
	if font is DynamicFont:
		var f: DynamicFont = font.duplicate()
		f.outline_size = 0
		return f
	return font


func _small_font(font: Font) -> Font:
	if font is DynamicFont:
		var f: DynamicFont = font.duplicate()
		f.size = int(max(8, f.size * 0.7))
		f.outline_size = 0
		return f
	return font
