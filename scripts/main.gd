extends Spatial
# Пункт выдачи: прототип (Godot 3.6, GLES2). Мир строится кодом, арт из art_src (tools/import_art.py).

const Parcel = preload("res://scripts/parcel.gd")
const Player = preload("res://scripts/player.gd")
const Customer = preload("res://scripts/customer.gd")

# Номера и виды совпадают с tools/box_codes.json и текстурами assets/boxes/box_XX.png
const CODES := ["В-20", "Г-84", "А-10", "М-69", "А-47", "Д-08", "Д-28", "А-12", "Г-54", "А-31", "А-71", "Г-08",
	"М-73", "А-29", "К-81", "Д-75", "Г-07", "Б-06", "Д-18", "В-54", "Б-70", "А-74", "В-72", "М-88",
	"Г-72", "М-60", "Г-66", "М-76", "Б-24", "М-66", "Г-81", "Д-24", "А-58", "В-19", "А-69", "М-89"]
const BOX_TYPES := ["cursed", "cursed", "cursed", "cursed", "explosive", "explosive", "explosive", "heavy", "heavy",
	"heavy", "gift", "gift", "gift", "fragile", "fragile", "fragile", "normal", "normal",
	"normal", "normal", "normal", "normal", "normal", "normal", "mimic", "mimic", "timer",
	"timer", "chest", "chest", "frozen", "frozen", "living", "living", "normal", "normal"]
const KINDS := {
	"witch": ["Ведьма", ["Котёл пришёл? %s", "Мне зелья, номер %s", "Метла, заказ %s"]],
	"orc": ["Орк", ["ОРК ЗАБРАТЬ %s!", "Топор. %s. Быстро.", "Где %s?! Я ждать!"]],
	"skeleton": ["Скелет", ["Кхе... заказ %s", "Мне кости... то есть %s", "Номер %s, я не спешу"]],
	"goblin": ["Гоблин", ["Хи-хи, %s мой!", "Дай %s, дай-дай!", "Заказ %s, без вскрытия!"]],
	"vampire": ["Вампир", ["Прошу, без света... %s", "Посылка %s. Я подожду в тени", "Номер %s, и выключите лампу"]],
	"dragon": ["Дракончик", ["Р-р-р! %s мой!", "Мама сказала забрать %s", "%s! Быстро, а то подожгу!"]],
	"ghost": ["Призрак", ["Ууу... посылка %s...", "Я тут с 1847 года жду %s", "%s... ууу... пожалуйста"]],
	"dwarf": ["Гном", ["Курьер я, но %s заберу сам", "Номер %s, борода не ждёт!", "Где мой %s? Тащи!"]],
	"thief": ["Вор", ["Посылочка %s... моя, честно", "Э-э, %s. Быстренько", "Мне %s, я тут постою"]],
	"king": ["Король", ["КОРОЛЮ — %s! Немедля!", "Мы требуем %s!", "%s. Король ждать не привык!"]],
	"troll": ["Тролль-малыш", ["Хочу %s! ХОЧУ!", "Мама дала чек: %s", "%s! А это что за кнопка?"]],
	"werewolf": ["Оборотень", ["Добрый день, я человек. %s", "Посылка %s. Ауу... то есть, алло", "Мой заказ %s, я точно не волк"]],
	"giant": ["Ледяной великан", ["МНЕ %s. ХОЛОДНЫЙ.", "%s... НЕ РАСТОПИ.", "ВЕЛИКАН ЗАБРАТЬ %s"]],
	"maga": ["Мага", ["Я за посылкой от Королевы Мышей. %s — розовая, с ушками, пищит!",
		"Couldn't take the box out!.. Шучу. Мне %s", "Рошка или картошка? А пока дай %s",
		"Полки по буквам? Я же говорил! Мне %s", "Пи-пи! Это не я пищу, это %s у тебя на складе",
		"Маленькая, да удаленькая, как наша Королева. Заказ %s"]],
}
const SLOTS := [-3.0, 0.0, 3.0]  # места у стойки
const KIND_HINTS := {
	"maga": "Секретный гость! Его посылка М-01 розовая, с ушками и прячется на складе. Ищи по писку.",
	"orc": "Орк уважает сильный бросок. Попадёшь в лицо — он только рад!",
	"vampire": "Вампир не любит свет. Сбей коробкой фонарь над стойкой!",
	"skeleton": "Скелет никуда не спешит: ждёт дольше всех.",
	"ghost": "Призрак ждёт вечно, но платит мало. Коробки пролетают сквозь него.",
	"dwarf": "Гном ловит свою посылку на лету. Кидай смело!",
	"goblin": "Гоблин торгуется: быстро отдашь — даст сверху, долго — потребует скидку.",
	"witch": "Ведьма обожает проклятые посылки: за них доплачивает.",
	"dragon": "Дракончик нетерпеливый: заждётся — подпалит стойку!",
}
const PATIENCE_MULT := {"maga": 2.5, "skeleton": 1.4, "ghost": 1.8, "king": 0.7, "troll": 0.8, "giant": 1.2}
const EVENTS := {
	"blackout": "СВЕТ ВЫРУБИЛИ! Ищи с фонариком. Вампиры в восторге.",
	"rush": "ЧЁРНАЯ ПЯТНИЦА! Толпа клиентов, мало терпения, но платят в 1.5 раза больше.",
	"inspector": "ИНСПЕКТОР! Удар в лицо -15. Смена без злых клиентов и ударов: +50.",
}
const DOOR := Vector3(5.2, 0, 4.2)
const LETTERS := ["А", "Б", "В", "Г", "Д", "К", "М"]
const LETTER_ORDER := [0, 3, 6, 4, 2, 1, 5]  # в каком порядке буквы появляются: А, Г, М, Д, В, Б, К
const LETTER_COLORS := [Color(0.85, 0.2, 0.15), Color(0.95, 0.55, 0.1), Color(0.2, 0.5, 0.95), Color(0.2, 0.7, 0.25),
	Color(0.65, 0.3, 0.85), Color(0.95, 0.85, 0.2), Color(0.1, 0.75, 0.75)]
const SHELF_POS := [Vector3(-4, 0, -4), Vector3(4, 0, -4), Vector3(-4, 0, -7.5), Vector3(4, 0, -7.5)]
const OPEN_SLOTS := [[1], [0, 1], [0, 1, 2]]
const PORTAL := Vector3(-6.8, 1.3, -2.4)
const FREEZER := Vector3(6.3, 0, -2.2)
const NPC = preload("res://scripts/npc.gd")
const COW_IDX := 32  # «живая» посылка, которая в коопе становится коровой
const PAY := {"chest": 12, "mimic": 8, "living": 6, "frozen": 10, "heavy": 5, "gift": 10, "cow": 25}
const Career = preload("res://scripts/career.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const SAFE := Vector3(6.45, 0, -0.95)
const CAGE := Vector3(-6.48, 0, -3.25)  # у левой стены между лентой портала и стеллажом

var mats := {}
var parcels := []
var shelf_slots := []
var shelf_units := []  # стеллажи: центр и все их узлы (чтобы двигать целиком)
var rail_mats := {}  # буква -> материал кромки (перекраска)
var carry_kind := ""  # что несём: floor / surface / shelf
var carry_from := Vector3.ZERO
var carry_ok := false
var carry_shelf := -1
var carry_parcels := []
var carry_marker: MeshInstance
var money := 0
var served := 0
var failed := 0
var spawned := 0
var customers := []
var total_customers := 8
var shift_over := false
var player
var counter_area: Area

var font_big: DynamicFont
var font_small: DynamicFont
var hud_stats: Label
var hud_hint: Label
var hud_order: Label
var hud_center: Label
var hud_bubbles := []
var hide_nicks := false  # съёмка трейлера: без ников над игроками
var hud_meters := []  # шкалы терпения под репликами (рамка, заливка, рожица)
var hud_event: Label
var hud_tut: Label
var hud_help: Label
var cat  # кот на стойке (scripts/cat.gd)
var returns  # стол возвратов (scripts/returns.gd)
var extras  # кофемашина, камера, лежанка (scripts/extras.gd)
var story  # письма владельца (scripts/story.gd)
var rare  # редкие события смены (scripts/rare.gd)
var _pad_was := false
var pause_panel: PanelContainer
var shop_panel: PanelContainer
var shop_box: VBoxContainer
var end_buttons: HBoxContainer
var lanterns := []  # [sprite, light, off_timer]
var lamps := []
var flashlight: SpotLight
var hits := 0
var tut_step := -1  # 0-3 обучение в смене; 10 — «пункт закрыт», 11 — новый день
var tut_arrow: Sprite3D
var mirror
var bell_rings := []  # время последних звонков (пасхалка)
var maga_parcel = null
var maga_c = null
var maga_pending := false
var _squeak_t := 0.0
var hud_power: Label
var hud_panel: PanelContainer
var hud_panel_text: Label
var _flash_id := 0
var shelves := []  # [{pos, slots, letters}]
var incoming := []  # посылки, которые ещё придут через портал
var portal_sprite: Sprite3D
var portal_open_t := 0.0
var portal_light: OmniLight
var conv_mat: SpatialMaterial
var belt_area: Area
var lever: Sprite3D
var lever_cd := 0.0
var alarm_bell: Sprite3D
var avatars := {}  # id игрока -> узел аватара
var remote_hold := {}  # (хост) id -> коробки в руках у этого игрока
var _net_t := 0.0
var _net_alive_t := 0.0
var wave2_done := false
var freezer_area: Area
var lid_pivot: Spatial
var lid_open := false
var golem = null
var helper = null
var helper_cd := 15.0
var kick_buttons := {}
var stats := {}  # счётчики смены: задания и книга жалоб
var streak := 0
var hud_tasks: Label
var hud_panel_side: Label
var boss = null
var boss_left := 0
var safe_code := [0, 0, 0]
var safe_digits := []  # Sprite3D колёсиков
var safe_door: Spatial
var cage_area: Area
var vinyl_disc: Spatial
var chaos_t := 6.0
var chaos_over := false
var no_day_inc := false
var is_open := false
var fun  # кооп/стрим-фишки (scripts/fun.gd)
var movables := []
var carrying = null  # декор в руках (режим «закрыто»)
var ui_block := false
var board_open := false
var sign_spr: Sprite3D
var structural_bought := false
var deliveries := 0
var pile := []
var shop_tab := "up"


func _ready() -> void:
	# HUD (реплики над головами) считаем последним, когда камера уже сдвинута в этом кадре,
	# иначе подписи отстают на кадр и дрожат
	process_priority = 100
	if Net.active:
		seed(Net.seed_value)  # у всех одинаковый склад
	else:
		randomize()
	if "--allup" in OS.get_cmdline_args():
		for id in Game.UPGRADES:
			Game.upgrades[id] = Game.UPGRADES[id][2]
	for a in OS.get_cmdline_args():
		if a.begins_with("--day="):
			Game.day = int(a.substr(6))
		if a.begins_with("--event="):
			Game.event = a.substr(8)
		if a == "--tut":
			Game.tutorial_done = false
		if a == "--decor":
			for id in Career.DECOR:
				Game.decor[id] = true
			Game.record = "rec_jazz"
		if a == "--chaos":
			Game.start_chaos()
		if a == "--closed":
			Game.phase = "closed"
		if a.begins_with("--bank="):
			Game.bank = int(a.substr(7))
		if a.begins_with("--up="):  # для тестов: --up=window:2,shelf:3
			for kv in a.substr(5).split(","):
				var parts: PoolStringArray = kv.split(":")
				Game.upgrades[parts[0]] = int(parts[1])
	total_customers = Game.customers_total()
	_setup_input()
	_make_env()
	_build_room()
	_build_shelves()
	_build_portal()
	_build_freezer()
	_build_safe()
	_build_cage()
	_build_decor()
	_build_windows()
	_spawn_parcels()
	_build_hud()

	player = Player.new()
	player.translation = Vector3(0, 0.05, -2.0)
	add_child(player)
	player.connect("look_changed", self, "_on_look_changed")
	fun = load("res://scripts/fun.gd").new()
	add_child(fun)
	fun.setup(self)
	returns = load("res://scripts/returns.gd").new()
	returns.name = "Returns"
	add_child(returns)
	returns.setup(self)
	extras = load("res://scripts/extras.gd").new()
	add_child(extras)
	extras.setup(self)
	story = load("res://scripts/story.gd").new()
	add_child(story)
	story.setup(self)
	rare = load("res://scripts/rare.gd").new()
	add_child(rare)
	rare.setup(self)

	_play_music()
	Sfx.set_ambient(true)
	if Game.mode == "career" and Game.tasks_day != Game.day:
		Game.tasks = Career.pick_tasks(Game.day, Game.lvl("freezer") > 0)
		Game.tasks_day = Game.day
	if Game.mode == "chaos":
		Game.tasks = []
	if Game.event == "blackout":
		_blackout()
	_build_helpers()
	if net_client():
		for p in parcels:
			p.mode = RigidBody.MODE_KINEMATIC
	if Net.active or Game.mode == "chaos":
		Game.phase = "open"
	_build_closed_props()
	_build_mirror()
	if Game.phase == "closed":
		_enter_closed()
	else:
		_begin_shift()
	if Net.active:
		hud_event.text = (tr("ХОСТ") if Net.is_host else tr("КООП")) + tr(": игроков %d") % (Net.peers.size() + 1)
		_send_look_later()
		_hook_net_peers()

	if Settings.reopen_settings:
		Settings.reopen_settings = false
		call_deferred("_reopen_settings")
	if "--shot" in OS.get_cmdline_args():
		_screenshot_mode()
	if "--rejointest" in OS.get_cmdline_args():
		_rejoin_test()
	if "--hctest" in OS.get_cmdline_args():
		_hc_test()
	if "--cattest" in OS.get_cmdline_args():
		_cat_test()
	if "--rettest" in OS.get_cmdline_args():
		_ret_test()
	if "--uptest" in OS.get_cmdline_args():
		_up_test()
	if "--storytest" in OS.get_cmdline_args():
		_story_test()
	for a in OS.get_cmdline_args():
		if a.begins_with("--rare="):
			_rare_test(a.substr(7))
	for a in OS.get_cmdline_args():
		if a.begins_with("--showcase="):
			var sc = load("res://scripts/showcase.gd").new()
			add_child(sc)
			sc.run(self, a.substr(11))
	if "--test2" in OS.get_cmdline_args():
		_test2()
	if "--test3" in OS.get_cmdline_args():
		_test3()
	if "--test4" in OS.get_cmdline_args():
		_test4()
	if "--test5" in OS.get_cmdline_args():
		_test5()
	if "--test6" in OS.get_cmdline_args():
		_test6()
	if "--test7" in OS.get_cmdline_args():
		_test7()
	if "--test8" in OS.get_cmdline_args():
		_test8()
	if "--test9" in OS.get_cmdline_args():
		_test9()
	if "--test10" in OS.get_cmdline_args():
		_test10()
	if "--test11" in OS.get_cmdline_args():
		_test11()
	if "--relangtest" in OS.get_cmdline_args():
		_relangtest()
	if "--shelftest" in OS.get_cmdline_args():
		_shelftest()
	if "--mirrortest" in OS.get_cmdline_args():
		_mirrortest()
	if "--shotfix" in OS.get_cmdline_args():
		_shotfix()
	if "--test13" in OS.get_cmdline_args():
		_test13()
	if "--test12" in OS.get_cmdline_args():
		_test12()


func pick(arr: Array):
	return arr[randi() % arr.size()]


# ---------------------------------------------------------------- input
func _setup_input() -> void:
	Settings.apply_keys()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and story and story.is_open():
		story.close()
		get_tree().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and mirror and mirror.is_open():
		mirror.close()
		get_tree().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and board_open:
		ui_click(event)
		return
	if event.is_action_pressed("ui_cancel") and shop_panel.visible and not shift_over:
		_close_laptop()
		get_tree().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not shift_over:
		_set_paused(not get_tree().paused)
		return
	if not shift_over or shop_panel.visible or net_client():
		return
	if event.is_action_pressed("restart"):
		if hc_fired or (hardcore_on() and not chaos_over):
			return
		if chaos_over:
			_open_shop()
		else:
			get_tree().reload_current_scene()
	elif event.is_action_pressed("shop"):
		_open_shop()


# ---------------------------------------------------------------- world
func tex(name: String, repeat := true) -> Texture:
	var t: Texture = load("res://assets/%s.png" % name)
	t.flags = Texture.FLAG_REPEAT if repeat else 0
	return t


func mat(name: String, scale := 1.0, col := Color(1, 1, 1)) -> SpatialMaterial:
	var key := "%s_%s_%s" % [name, scale, col]
	if mats.has(key):
		return mats[key]
	var m := SpatialMaterial.new()
	m.albedo_texture = tex(name)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.albedo_color = col
	mats[key] = m
	return m


func solid(size: Vector3, pos: Vector3, m: Material, layer := 1) -> StaticBody:
	var b := StaticBody.new()
	b.translation = pos
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = size / 2.0
	cs.shape = sh
	b.add_child(cs)
	if m:
		var mi := MeshInstance.new()
		var cm := CubeMesh.new()
		cm.size = size
		mi.mesh = cm
		mi.material_override = m
		b.add_child(mi)
	add_child(b)
	return b


func deco(size: Vector3, pos: Vector3, m: Material) -> MeshInstance:
	var mi := MeshInstance.new()
	var cm := CubeMesh.new()
	cm.size = size
	mi.mesh = cm
	mi.material_override = m
	mi.translation = pos
	add_child(mi)
	return mi


func make_sign(name: String, pos: Vector3, rot_y: float, px := 0.008) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex("sign_" + name + ("_en" if Settings.latin() else ""), false)
	# на табличках мелкий текст: сглаживание и мипмапы, иначе буквы рябят при движении камеры
	s.texture.flags = Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS
	s.pixel_size = px
	s.double_sided = false
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.translation = pos
	s.rotation.y = rot_y
	add_child(s)
	return s


func unshaded(col: Color) -> SpatialMaterial:
	var m := SpatialMaterial.new()
	m.flags_unshaded = true
	m.albedo_color = col
	return m


func _make_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.05)
	env.ambient_light_color = Game.district()["amb"]
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_color = Game.district()["fog"]
	env.background_color = Game.district()["fog"].darkened(0.5)
	env.fog_depth_begin = 3.0
	env.fog_depth_end = 16.0
	we.environment = env
	add_child(we)


func lamp(pos: Vector3, col: Color, energy := 1.6, rng := 7.0) -> OmniLight:
	var l := OmniLight.new()
	lamps.append(l)
	l.translation = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	# светильник прижат к потолку: тёмный корпус + тёплая панель
	deco(Vector3(0.62, 0.05, 0.62), Vector3(pos.x, 3.175, pos.z), unshaded(Color(0.18, 0.13, 0.1)))
	deco(Vector3(0.46, 0.03, 0.46), Vector3(pos.x, 3.14, pos.z), unshaded(col.darkened(0.05)))
	return l


# текстура района, если она уже нарисована (env_wall_swamp и т.д.)
func _dtex(base: String) -> String:
	var suf: String = ["", "_swamp", "_crypt", "_castle", "_ice", "_lair"][Game.district_idx()]
	if suf != "" and ResourceLoader.exists("res://assets/%s%s.png" % [base, suf]):
		return base + suf
	return base


func _build_room() -> void:
	var wood := mat("env_wood", 0.8, Color(0.72, 0.6, 0.52))
	var fl_name := _dtex("env_floor")
	var wl_name := _dtex("env_wall")
	solid(Vector3(14, 0.2, 16), Vector3(0, -0.1, -3), mat(fl_name, 0.5))
	solid(Vector3(14, 0.2, 16), Vector3(0, 3.3, -3), mat("env_ceiling", 0.5, Color(0.7, 0.65, 0.65)))
	var wall := mat(wl_name, 0.5)
	solid(Vector3(14, 3.4, 0.2), Vector3(0, 1.6, -11), wall)
	solid(Vector3(14, 3.4, 0.2), Vector3(0, 1.6, 5), wall)
	solid(Vector3(0.2, 3.4, 16), Vector3(-7, 1.6, -3), wall)
	solid(Vector3(0.2, 3.4, 16), Vector3(7, 1.6, -3), wall)

	# Стойка выдачи на всю ширину + невидимая стенка, чтобы игрок не перелез
	solid(Vector3(14, 0.95, 0.8), Vector3(0, 0.475, 0), wood)
	solid(Vector3(14, 3.2, 0.1), Vector3(0, 2.55, 0.45), null, 2)
	deco(Vector3(14, 0.05, 0.9), Vector3(0, 0.975, 0), mat("env_wood", 0.8, Color(0.8, 0.68, 0.6)))

	counter_area = Area.new()
	counter_area.collision_layer = 0
	counter_area.collision_mask = 8
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = Vector3(7, 0.35, 0.43)
	cs.shape = sh
	counter_area.add_child(cs)
	counter_area.translation = Vector3(0, 1.3, 0)
	add_child(counter_area)

	# Дверь для клиентов
	var door := MeshInstance.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 2.3)
	door.mesh = qm
	var dm := SpatialMaterial.new()
	dm.albedo_texture = tex("env_door", false)
	door.material_override = dm
	door.translation = Vector3(DOOR.x, 1.15, 4.88)
	door.rotation.y = PI
	add_child(door)
	deco(Vector3(1.6, 0.15, 0.1), Vector3(DOOR.x, 2.35, 4.86), wood)

	make_sign("front", Vector3(0, 2.6, 0.52), 0)
	make_sign("back", Vector3(0, 2.6, 0.38), PI)
	make_sign("sklad", Vector3(0, 2.5, -10.88), 0, 0.012)
	make_sign("rules", Vector3(-4.5, 1.9, 4.88), PI, 0.016)

	_build_props()

	lamp(Vector3(-3, 2.9, -3), Color(1.0, 0.8, 0.55))
	lamp(Vector3(3, 2.9, -3), Color(1.0, 0.8, 0.55))
	lamp(Vector3(0, 2.9, -8), Color(1.0, 0.75, 0.5), 1.6, 8.0)
	lamp(Vector3(0, 2.9, -0.8), Color(1.0, 0.85, 0.6), 1.4, 5.0)
	lamp(Vector3(0, 2.9, 2.6), Color(0.55, 0.65, 1.0), 1.4)


func prop(name: String, pos: Vector3, rot_y: float, height_m: float, billboard := false, flip := false) -> Sprite3D:
	var s := Sprite3D.new()
	var t := tex("props/" + name, false)
	s.texture = t
	s.pixel_size = height_m / t.get_height()
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = not billboard
	s.double_sided = billboard
	s.flip_h = flip
	if billboard:
		s.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
	s.translation = pos + Vector3(0, height_m / 2.0, 0)
	s.rotation.y = rot_y
	add_child(s)
	return s


func _build_props() -> void:
	# Фонари на цепях над открытыми окнами: их можно сбить коробкой (вампиру нравится темнота)
	for i in OPEN_SLOTS[Game.windows() - 1]:
		var lx: float = SLOTS[i] - 0.9
		var ls := prop("lantern", Vector3(lx, 2.2, 0.0), 0, 0.7, true)
		deco(Vector3(0.03, 0.4, 0.03), Vector3(lx, 3.0, 0.0), unshaded(Color(0.2, 0.18, 0.16)))
		_clickable(ls, Vector3(0.18, 0.3, 0.18), tr("Фонарь на цепи: сбей его коробкой, если клиенту мешает свет"), "")
		var ll := OmniLight.new()
		ll.light_color = Color(1.0, 0.75, 0.4)
		ll.light_energy = 0.9
		ll.omni_range = 3.5
		ll.translation = Vector3(lx, 2.45, 0.25)
		add_child(ll)
		lanterns.append([ls, ll, 0.0])
	prop("plant", Vector3(-6.0, 0.98, -0.05), 0, 0.7, true)
	var cat_name := "cat"
	if Game.decor.has("cat_hat") and ResourceLoader.exists("res://assets/props/cat_hat.png"):
		cat_name = "cat_hat"
	var cat_spr := prop(cat_name, Vector3(4.8, 0.98, -0.1), 0, 0.3 if cat_name == "cat" else 0.6, true)
	cat = load("res://scripts/cat.gd").new()
	add_child(cat)
	cat.setup(self, cat_spr, cat_name != "cat")
	prop("clock", Vector3(-4.0, 2.25, -10.88), 0, 0.75)
	prop("cobweb", Vector3(-6.45, 2.55, -10.88), 0, 0.7)
	prop("cobweb", Vector3(6.45, 2.55, -10.88), 0, 0.7, false, true)
	prop("cobweb", Vector3(-6.45, 2.55, 4.88), PI, 0.7, false, true)
	prop("poster", Vector3(6.88, 1.3, -0.7), -PI / 2, 0.8)
	alarm_bell = prop("bell_ring", Vector3(-6.84, 2.05, -0.8), PI / 2, 0.38)
	deco(Vector3(0.04, 0.5, 0.36), Vector3(-6.88, 2.22, -0.8), mat("env_wood", 0.8, Color(0.5, 0.38, 0.3)))
	prop("poster", Vector3(-2.5, 1.4, 4.88), PI, 0.8)
	if Game.lvl("expand") > 0:
		prop("boxstack", Vector3(-6.2, 0.0, -10.2), 0, 0.9, true)
	else:
		prop("boxstack", Vector3(-6.2, 0.0, -5.0), 0, 0.9, true)
	if Game.lvl("freezer") == 0:
		prop("boxstack", Vector3(6.2, 0.0, -2.3), 0, 0.8, true)
	prop("boxstack", Vector3(-6.0, 0.0, 4.2), 0, 0.8, true)


func _build_shelves() -> void:
	var metal := mat("env_metal", 1.0)
	var wood := mat("env_wood", 0.8, Color(0.85, 0.75, 0.65))
	var n: int = Game.shelves()
	if Game.lvl("expand") == 0:
		n = int(min(n, 2))
		# стена: пока склад маленький
		solid(Vector3(14, 3.4, 0.2), Vector3(0, 1.6, -5.6), mat(_dtex("env_wall"), 0.5))
		make_sign("sklad", Vector3(0, 2.5, -5.48), 0, 0.012)
	# Буквы: в начале 4, по ходу карьеры больше (хаос — все). Каждая буква — своя секция стеллажа
	# со своей табличкой и цветной кромкой.
	var active := active_letters()
	var units := []
	for si in n:
		units.append([])
	for k in active.size():
		units[int(k * n / active.size())].append(active[k])
	shelf_units = []
	for si in n:
		var c: Vector3 = shelf_center(si)
		var nodes0 := get_child_count()
		var x := c.x
		var z := c.z
		var w := 4.4
		var d := 0.7
		for px in [-w / 2, w / 2]:
			for pz in [-d / 2, d / 2]:
				solid(Vector3(0.08, 2.4, 0.08), Vector3(x + px, 1.2, z + pz), metal)
		for y in [0.1, 0.9, 1.7]:
			solid(Vector3(w, 0.06, d), Vector3(x, y, z), wood)
		# секции: 4 колонки по 1.1 м делим между буквами этого стеллажа
		var lets: Array = units[si]
		var nsec := int(min(lets.size(), 4))
		if nsec == 0:
			nsec = 1
		var cols := []
		for k in nsec:
			cols.append(int(4 / nsec))
		for k in 4 - int(4 / nsec) * nsec:
			cols[k] += 1
		var col0 := 0
		for k in nsec:
			var sec_lets := []
			for li in lets.size():
				if li % nsec == k:
					sec_lets.append(lets[li])
			var x0 := x - w / 2 + col0 * 1.1
			var sw: float = cols[k] * 1.1
			var cx := x0 + sw / 2.0
			var slots := []
			for y in [0.1, 0.9, 1.7]:
				for ci in cols[k]:
					slots.append(Vector3(x0 + 0.55 + ci * 1.1, y + 0.35, z))
			slots.shuffle()
			var col: Color = letter_color(sec_lets[0]) if not sec_lets.empty() else Color(0.5, 0.5, 0.5)
			var rail := unshaded(col)
			if not sec_lets.empty():
				rail_mats[sec_lets[0]] = rail
			for y in [0.1, 0.9, 1.7]:
				# бортики цвета буквы, чтобы коробки не соскальзывали и секцию было видно издалека
				for side in [-1, 1]:
					solid(Vector3(sw - 0.04, 0.07, 0.03), Vector3(cx, y + 0.065, z + side * (d / 2 - 0.015)), rail)
			if k > 0:
				# перегородка между секциями
				solid(Vector3(0.05, 1.7, d), Vector3(x0, 0.95, z), wood)
			shelves.append({"pos": Vector3(cx, 0, z), "half": sw / 2.0, "slots": slots, "letters": sec_lets, "unit": si})
			col0 += cols[k]
		var unit := {"c": c, "nodes": []}
		for ci in range(nodes0, get_child_count()):
			var nd: Node = get_child(ci)
			unit["nodes"].append(nd)
			if nd is StaticBody:
				nd.set_meta("shelf", si)
		shelf_units.append(unit)
		# ручки на торцах: стеллаж можно перекатить, пока пункт закрыт (в коопе — нет, склад общий)
		if not Net.active and Game.mode == "career":
			for side in [-1, 1]:
				var hnd := Spatial.new()
				hnd.translation = Vector3(x + side * (w / 2 + 0.02), 1.2, z)
				add_child(hnd)
				var hb := _clickable(hnd, Vector3(0.1, 1.2, d / 2 + 0.05), tr("[ЛКМ/E] Передвинуть стеллаж (пока пункт закрыт)"), "_pick_shelf")
				hb.set_meta("shelf", si)
				unit["nodes"].append(hnd)
	# таблички с буквами над каждой секцией (с двух сторон), цвет как у кромки
	for sh in shelves:
		var lets: Array = sh["letters"]
		if lets.empty():
			continue
		var wpl := lets.size() * 0.4 + 0.14
		var col: Color = letter_color(lets[0])
		var sign0 := get_child_count()
		for side in [1, -1]:
			var zz: float = sh["pos"].z + 0.38 * side
			deco(Vector3(wpl, 0.5, 0.04), Vector3(sh["pos"].x, 2.62, zz - 0.03 * side), wood)
			var stripe := deco(Vector3(wpl + 0.06, 0.06, 0.05), Vector3(sh["pos"].x, 2.34, zz - 0.03 * side), rail_mats.get(lets[0], unshaded(col)))
			if side == 1 and Game.lvl("paints") > 0 and not Net.active:
				# табличка — кнопка перекраски секции
				var pb := _clickable(stripe, Vector3(wpl / 2.0, 0.3, 0.06), tr("[ЛКМ/E] Перекрасить секцию (пока пункт закрыт)"), "_paint_section")
				pb.translation = Vector3(0, 0.28, 0)
				pb.set_meta("letter", lets[0])
			for k in lets.size():
				var s := Sprite3D.new()
				s.texture = tex(("ui/let_en_%d" if Settings.latin() else "ui/let_%d") % lets[k], false)
				s.pixel_size = 0.38 / 28.0
				s.shaded = false
				s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				var ox: float = (k - (lets.size() - 1) / 2.0) * 0.4
				s.translation = Vector3(sh["pos"].x + ox * side, 2.64, zz)
				s.rotation.y = 0.0 if side == 1 else PI
				add_child(s)
		for ci in range(sign0, get_child_count()):
			shelf_units[sh["unit"]]["nodes"].append(get_child(ci))


# палитра перекраски секций (улучшение «Краски для стеллажей»)
const PAINT_COLORS := [Color(0.85, 0.2, 0.15), Color(0.95, 0.55, 0.1), Color(0.95, 0.85, 0.2), Color(0.55, 0.85, 0.2),
	Color(0.2, 0.7, 0.25), Color(0.1, 0.75, 0.75), Color(0.2, 0.5, 0.95), Color(0.35, 0.3, 0.9),
	Color(0.65, 0.3, 0.85), Color(0.95, 0.4, 0.7), Color(0.95, 0.95, 0.95), Color(0.45, 0.3, 0.2)]


func letter_color(li: int) -> Color:
	var ci = Game.letter_colors.get(str(li))
	if ci != null and Game.lvl("paints") > 0 and not Net.active:
		return PAINT_COLORS[int(ci) % PAINT_COLORS.size()]
	return LETTER_COLORS[li]


func _paint_section(b) -> void:
	if is_open:
		_flash(tr("Красить можно, когда пункт закрыт."), 1.5)
		return
	if carrying:
		return
	var li := int(b.get_meta("letter"))
	var cur: Color = letter_color(li)
	var ci := 0
	for k in PAINT_COLORS.size():
		if PAINT_COLORS[k].is_equal_approx(cur):
			ci = k
	ci = (ci + 1) % PAINT_COLORS.size()
	Game.letter_colors[str(li)] = ci
	if rail_mats.has(li):
		rail_mats[li].albedo_color = PAINT_COLORS[ci]
	Sfx.play("splash", 0.15, -8.0)
	Game.save_game()


# какие буквы сегодня в ходу (индексы в LETTERS)
func active_letters() -> Array:
	var cnt := 7
	if Game.mode == "career":
		cnt = [4, 5, 5, 6, 7, 7][Game.district_idx()]
	var out := []
	for k in cnt:
		out.append(LETTER_ORDER[k])
	return out


func shelf_for(code: String) -> int:
	var li := LETTERS.find(code.substr(0, 1))
	for si in shelves.size():
		if li in shelves[si]["letters"]:
			return si
	return 0


func _shelf_at(pos: Vector3) -> int:
	for si in shelves.size():
		var c: Vector3 = shelves[si]["pos"]
		if abs(pos.x - c.x) < shelves[si]["half"] + 0.05 and abs(pos.z - c.z) < 0.45 and pos.y > 0.1 and pos.y < 2.3:
			return si
	return -1


func _build_portal() -> void:
	# Магический портал поставок на левой стене + лента под ним + рычаг
	portal_sprite = prop("portal_0", PORTAL - Vector3(0, 0.8, 0) + Vector3(0.05, 0, 0), PI / 2, 1.6)
	portal_light = OmniLight.new()
	portal_light.light_color = Color(0.7, 0.4, 1.0)
	portal_light.light_energy = 0.6
	portal_light.omni_range = 3.5
	portal_light.translation = PORTAL + Vector3(0.6, 0, 0)
	add_child(portal_light)
	# лента: везёт коробки от портала в склад
	conv_mat = SpatialMaterial.new()
	conv_mat.albedo_texture = tex("env_conveyor_x")
	conv_mat.uv1_triplanar = true
	conv_mat.uv1_scale = Vector3.ONE * 1.2
	solid(Vector3(2.6, 0.3, 0.9), Vector3(-5.55, 0.15, PORTAL.z), conv_mat)
	var side := mat("env_metal", 1.0)
	deco(Vector3(2.6, 0.1, 0.05), Vector3(-5.55, 0.33, PORTAL.z + 0.47), side)
	deco(Vector3(2.6, 0.1, 0.05), Vector3(-5.55, 0.33, PORTAL.z - 0.47), side)
	belt_area = Area.new()
	belt_area.collision_layer = 0
	belt_area.collision_mask = 8
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = Vector3(1.3, 0.3, 0.45)
	cs.shape = sh
	belt_area.add_child(cs)
	belt_area.translation = Vector3(-5.55, 0.55, PORTAL.z)
	add_child(belt_area)
	lever = prop("lever_up", Vector3(-6.86, 1.0, -1.15), PI / 2, 0.45)
	_clickable(lever, Vector3(0.1, 0.25, 0.2), tr("[ЛКМ/E] Рычаг портала: вызвать поставку сейчас"), "_pull_lever")


func _clickable(spr: Spatial, ext: Vector3, look: String, press: String) -> StaticBody:
	var body := StaticBody.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = ext
	cs.shape = sh
	body.add_child(cs)
	body.set_meta("look", look)
	if press != "":
		body.set_meta("press", press)
	spr.add_child(body)
	return body


func _pull_lever(_b) -> void:
	if net_client():
		rpc_id(1, "net_req_lever")
		return
	if lever_cd > 0.0:
		return
	lever_cd = 1.2
	lever.texture = tex("props/lever_down", false)
	Sfx.play_at("lid", lever.global_transform.origin, 0.2, 0.0)
	if incoming.empty():
		_flash(tr("Поставок на сегодня больше нет."), 1.5)
	else:
		wave2_done = true
		_portal_wave(incoming.size())
	yield(get_tree().create_timer(1.0), "timeout")
	lever.texture = tex("props/lever_up", false)


func _ring_alarm() -> void:
	if alarm_bell == null:
		return
	Sfx.play_at("doorbell", alarm_bell.global_transform.origin, 0.3, 4.0)
	var tw := create_tween()
	for k in 6:
		tw.tween_property(alarm_bell, "rotation:z", 0.25 if k % 2 == 0 else -0.25, 0.06)
	tw.tween_property(alarm_bell, "rotation:z", 0.0, 0.06)


func _tex_mat(name: String, tint := Color(1, 1, 1)) -> SpatialMaterial:
	var m := SpatialMaterial.new()
	m.albedo_texture = tex(name, false)
	m.albedo_color = tint
	return m


func _quad(parent: Spatial, size: Vector2, pos: Vector3, rot: Vector3, m: Material) -> void:
	var mi := MeshInstance.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	if m is SpatialMaterial:
		m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	mi.material_override = m
	mi.translation = pos
	mi.rotation = rot
	parent.add_child(mi)


func _box_body(parent: Spatial, size: Vector3, pos: Vector3) -> void:
	var b := StaticBody.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.translation = pos
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = size / 2.0
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)


func _build_freezer() -> void:
	if Game.lvl("freezer") == 0:
		return
	# Ларь стоит задней стенкой к правой стене, крышка открывается к стене
	var fz := Spatial.new()
	fz.translation = FREEZER
	fz.rotation.y = -PI / 2
	add_child(fz)
	var has_art := ResourceLoader.exists("res://assets/env_freezer_side.png")
	var side: Material = _tex_mat("env_freezer_side") if has_art else unshaded(Color(0.6, 0.8, 1.0))
	var inner: Material = _tex_mat("env_freezer_in") if has_art else unshaded(Color(0.8, 0.92, 1.0))
	var lidm: Material = _tex_mat("env_freezer_lid") if has_art else side
	var W := 1.4
	var D := 0.9
	var H := 0.9
	# наружные стенки (сосульки сверху)
	_quad(fz, Vector2(W, H), Vector3(0, H / 2, D / 2), Vector3.ZERO, side)
	_quad(fz, Vector2(W, H), Vector3(0, H / 2, -D / 2), Vector3(0, PI, 0), side)
	_quad(fz, Vector2(D, H), Vector3(W / 2, H / 2, 0), Vector3(0, PI / 2, 0), side)
	_quad(fz, Vector2(D, H), Vector3(-W / 2, H / 2, 0), Vector3(0, -PI / 2, 0), side)
	# внутри иней
	var t := 0.06
	_quad(fz, Vector2(W - t * 2, H - 0.12), Vector3(0, 0.12 + (H - 0.12) / 2, D / 2 - t), Vector3(0, PI, 0), inner)
	_quad(fz, Vector2(W - t * 2, H - 0.12), Vector3(0, 0.12 + (H - 0.12) / 2, -D / 2 + t), Vector3.ZERO, inner)
	_quad(fz, Vector2(D - t * 2, H - 0.12), Vector3(W / 2 - t, 0.12 + (H - 0.12) / 2, 0), Vector3(0, -PI / 2, 0), inner)
	_quad(fz, Vector2(D - t * 2, H - 0.12), Vector3(-W / 2 + t, 0.12 + (H - 0.12) / 2, 0), Vector3(0, PI / 2, 0), inner)
	_quad(fz, Vector2(W - t * 2, D - t * 2), Vector3(0, 0.12, 0), Vector3(-PI / 2, 0, 0), inner)
	# кромка сверху
	var rim := unshaded(Color(0.55, 0.7, 0.85))
	_quad(fz, Vector2(W, t), Vector3(0, H, D / 2 - t / 2), Vector3(-PI / 2, 0, 0), rim)
	_quad(fz, Vector2(W, t), Vector3(0, H, -D / 2 + t / 2), Vector3(-PI / 2, 0, 0), rim)
	_quad(fz, Vector2(t, D), Vector3(W / 2 - t / 2, H, 0), Vector3(-PI / 2, 0, 0), rim)
	_quad(fz, Vector2(t, D), Vector3(-W / 2 + t / 2, H, 0), Vector3(-PI / 2, 0, 0), rim)
	# физика стенок и дна
	_box_body(fz, Vector3(W, 0.12, D), Vector3(0, 0.06, 0))
	_box_body(fz, Vector3(W, H, t), Vector3(0, H / 2, D / 2 - t / 2))
	_box_body(fz, Vector3(W, H, t), Vector3(0, H / 2, -D / 2 + t / 2))
	_box_body(fz, Vector3(t, H, D), Vector3(W / 2 - t / 2, H / 2, 0))
	_box_body(fz, Vector3(t, H, D), Vector3(-W / 2 + t / 2, H / 2, 0))
	# крышка на шарнире у задней стенки (у стены)
	lid_pivot = Spatial.new()
	lid_pivot.translation = Vector3(0, H, -D / 2)
	fz.add_child(lid_pivot)
	var lb := StaticBody.new()
	lb.collision_layer = 1
	lb.collision_mask = 0
	lb.translation = Vector3(0, 0.03, D / 2)
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = Vector3(W / 2 + 0.02, 0.03, D / 2 + 0.01)
	cs.shape = sh
	lb.add_child(cs)
	lid_pivot.add_child(lb)
	_quad(lb, Vector2(W + 0.04, D + 0.02), Vector3(0, 0.031, 0), Vector3(-PI / 2, 0, 0), lidm)
	_quad(lb, Vector2(W + 0.04, D + 0.02), Vector3(0, -0.031, 0), Vector3(PI / 2, 0, 0), inner)
	var edge := unshaded(Color(0.45, 0.6, 0.75))
	_quad(lb, Vector2(W + 0.04, 0.06), Vector3(0, 0, D / 2 + 0.01), Vector3.ZERO, edge)
	var cold := OmniLight.new()
	cold.light_color = Color(0.6, 0.85, 1.0)
	cold.light_energy = 0.5
	cold.omni_range = 2.0
	cold.translation = Vector3(0, 0.7, 0)
	fz.add_child(cold)
	freezer_area = Area.new()
	freezer_area.collision_layer = 0
	freezer_area.collision_mask = 8
	var cs2 := CollisionShape.new()
	var sh2 := BoxShape.new()
	sh2.extents = Vector3(W / 2 - 0.08, 0.35, D / 2 - 0.08)
	cs2.shape = sh2
	freezer_area.add_child(cs2)
	freezer_area.translation = Vector3(0, 0.5, 0)
	fz.add_child(freezer_area)


func _set_lid(open: bool) -> void:
	if lid_pivot == null or open == lid_open:
		return
	lid_open = open
	Sfx.play_at("lid", lid_pivot.global_transform.origin, 0.1, -2.0)
	var tw := create_tween()
	tw.tween_property(lid_pivot, "rotation:x", deg2rad(-86.0) if open else 0.0, 0.35)


func _build_windows() -> void:
	var open: Array = OPEN_SLOTS[Game.windows() - 1]
	var wood := mat("env_wood", 0.8, Color(0.6, 0.48, 0.4))
	for i in SLOTS.size():
		var x: float = SLOTS[i]
		if not i in open:
			# закрытое окно: доски
			# окно заколочено: перегородка от стойки до потолка, на ней ставни
			solid(Vector3(2.9, 2.25, 0.1), Vector3(x, 0.98 + 1.125, 0.35), mat("env_wood", 0.8, Color(0.5, 0.4, 0.33)))
			var shut := prop("shutters_closed", Vector3(x, 1.25, 0.29), PI, 1.5)
			shut.double_sided = true
			continue
		var b := prop("button_up", Vector3(x + 1.15, 0.98, -0.3), PI, 0.3)
		var body := StaticBody.new()
		body.collision_layer = 16
		body.collision_mask = 0
		var cs := CollisionShape.new()
		var sh := BoxShape.new()
		sh.extents = Vector3(0.14, 0.14, 0.1)
		cs.shape = sh
		body.add_child(cs)
		body.set_meta("look", tr("[ЛКМ/E] Кнопка «ВОН!»: выгнать клиента (мошенник +15, честный -10)"))
		body.set_meta("press", "_press_kick")
		body.set_meta("slot", i)
		b.add_child(body)
		kick_buttons[i] = b


func _build_helpers() -> void:
	if Game.lvl("golem") > 0:
		golem = NPC.new()
		golem.setup(_char_frames("golem"))
		golem.translation = Vector3(3.6, 0, 3.4)
		add_child(golem)
	if Game.lvl("helper") > 0:
		helper = NPC.new()
		helper.setup(_char_frames("helper"))
		helper.translation = Vector3(-1.2, 0, -1.3)
		add_child(helper)


func _new_parcel(i: int):
	var sizes := [Vector3(0.5, 0.4, 0.5), Vector3(0.45, 0.35, 0.45), Vector3(0.55, 0.45, 0.5), Vector3(0.4, 0.4, 0.4)]
	var p = Parcel.new()
	var t := tex(("boxes_en/box_%02d" if Settings.latin() else "boxes/box_%02d") % i, false)
	var typ: String = BOX_TYPES[i]
	var sz: Vector3 = pick(sizes)
	# кооп: сундук огромный, а одна «живая» посылка — корова в ящике; несут только вдвоём
	var duo := false
	if Net.active and typ == "chest":
		duo = true
	elif Net.active and i == COW_IDX:
		typ = "cow"
		duo = true
	match typ:
		"heavy":
			sz = Vector3(0.55, 0.5, 0.55)
		"gift", "frozen":
			sz = Vector3(0.38, 0.38, 0.38)
		"chest":
			sz = Vector3(1.0, 0.6, 0.6) if duo else Vector3(0.7, 0.5, 0.5)
		"cow":
			sz = Vector3(1.1, 0.75, 0.6)
	p.setup(CODES[i], typ == "cursed", sz, t)
	p.box_type = typ
	p.duo = duo
	if typ == "cow":
		p.mass = 16.0
		var cow_tex := tex("props/cow_crate", false) if ResourceLoader.exists("res://assets/props/cow_crate.png") else null
		if cow_tex:
			var cs := Sprite3D.new()
			cs.texture = cow_tex
			cs.pixel_size = 0.9 / cow_tex.get_width()
			cs.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
			cs.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			cs.translation.y = sz.y * 0.5
			cs.offset = Vector2(0, cow_tex.get_height() / 2.0)
			p.add_child(cs)
			p.set_meta("cow", cs)
	if typ == "heavy":
		p.mass = 6.0  # тяжеленный ящик: далеко не швырнёшь
	elif typ == "chest":
		p.mass = 20.0 if duo else 9.0
	p.rotation.y = rand_range(-0.2, 0.2)
	p.connect("exploded", self, "_on_parcel_exploded")
	p.connect("cracked", self, "_on_parcel_cracked")
	p.connect("melted", self, "_on_parcel_melted")
	return p


func _spawn_parcels() -> void:
	# Какие посылки бывают сегодня
	var allowed := []
	var act := active_letters()
	for i in CODES.size():
		var typ: String = BOX_TYPES[i]
		if typ == "frozen" and Game.lvl("freezer") == 0:
			continue
		if typ == "chest" and Game.day < 3 and not Net.active:
			continue
		if typ == "living" and Net.active and i == COW_IDX:
			pass  # корова в коопе с первого дня
		elif typ in ["mimic", "timer", "living"] and Game.day < 2:
			continue
		var duo_item: bool = Net.active and (typ == "chest" or i == COW_IDX)
		if not LETTERS.find(CODES[i].substr(0, 1)) in act and not duo_item:
			continue
		allowed.append(i)
	allowed.shuffle()
	var fav: Array = Game.district()["boxes"]
	if not fav.empty():
		var front := []
		var back := []
		for i in allowed:
			if BOX_TYPES[i] in fav and randf() < 0.75:
				front.append(i)
			else:
				back.append(i)
		allowed = front + back
	if Net.active:
		# в коопе ноши на двоих — почти всегда в начале списка
		var duo_first := []
		for i in allowed.duplicate():
			if i == COW_IDX or (BOX_TYPES[i] == "chest" and randf() < 0.7):
				allowed.erase(i)
				duo_first.append(i)
		allowed = duo_first + allowed
	var count := int(min(allowed.size(), total_customers + 3))
	total_customers = int(min(total_customers, count))
	var pre := int(ceil(count / 2.0))
	var fz := 0
	var duo_k := 0
	for n in count:
		var i: int = allowed[n]
		var p = _new_parcel(i)
		if p.box_type == "frozen":
			# замороженные лежат в ларе
			p.translation = FREEZER + Vector3(0, 0.55, -0.35 + fz * 0.7)
			p.home = p.translation
			fz += 1
			add_child(p)
			parcels.append(p)
		elif n < pre and Game.phase == "closed" and Game.mode == "career" and not Net.active:
			# утренняя поставка: свалена кучей у портала, надо разложить до открытия
			p.translation = Vector3(rand_range(-4.2, -2.4), 0.3 + (n % 3) * 0.45, rand_range(-3.2, -1.6))
			p.home = p.translation
			p.from_portal = true
			pile.append(p)
			add_child(p)
			parcels.append(p)
		elif p.duo and n < pre:
			# ноша на двоих стоит на полу склада, на полку не влезает
			p.translation = [Vector3(1.8, 0.5, -2.7), Vector3(-1.8, 0.5, -2.7), Vector3(0.0, 0.5, -5.75)][duo_k % 3]
			p.home = p.translation
			duo_k += 1
			add_child(p)
			parcels.append(p)
		elif n < pre:
			var spot = _free_spot(p.code)
			p.translation = spot
			p.home = spot
			p.sorted = true
			add_child(p)
			parcels.append(p)
		else:
			incoming.append(p)
	# ценные посылки заперты в сейфе
	if safe_door:
		var cand := []
		for p in parcels:
			if (p.sorted or p in pile) and p.box_type in ["normal", "gift", "fragile"]:
				cand.append(p)
		cand.shuffle()
		for k in int(min(cand.size(), 2 if Game.day >= 10 else 1)):
			_lock_in_safe(cand[k])


func _free_spot(code: String) -> Vector3:
	# сначала свой стеллаж по букве, потом любой, потом пол
	var own: Array = shelves[shelf_for(code)]["slots"]
	if not own.empty():
		return own.pop_back()
	for sh in shelves:
		if not sh["slots"].empty():
			return sh["slots"].pop_back()
	return Vector3(rand_range(-1.0, 1.0), 0.4, rand_range(-3.0, -1.5))


func _portal_wave_later(sec: float, n: int) -> void:
	yield(get_tree().create_timer(sec), "timeout")
	_portal_wave(n)


func _portal_wave(n: int) -> void:
	if shift_over or incoming.empty() or n <= 0:
		return
	if not "hint_portal" in Game.seen_kinds:
		Game.seen_kinds.append("hint_portal")
		_flash(tr("ПОСТАВКА через портал!\nРазложи коробки по стеллажам: буква номера = табличка. +2 за каждую"), 6.0)
	else:
		_flash(tr("Новая поставка!"), 2.0)
		_tip_later("lever", 3.0)
	Sfx.play_at("portal", PORTAL, 0.0, 4.0)
	portal_open_t = 1.0 + n * 0.45
	var tw := create_tween()
	tw.tween_property(portal_light, "light_energy", 3.0, 0.3)
	tw.tween_property(portal_light, "light_energy", 0.6, 1.5)
	for k in n:
		if incoming.empty() or shift_over:
			break
		var p = incoming.pop_front()
		if Net.active:
			rpc("net_portal_add", p.code)
		p.translation = PORTAL + Vector3(0.45, rand_range(-0.2, 0.2), rand_range(-0.3, 0.3))
		p.home = Vector3(-5.5, 0.7, PORTAL.z)
		p.from_portal = true
		add_child(p)
		parcels.append(p)
		p.apply_central_impulse(Vector3(rand_range(0.8, 1.4), 0.5, rand_range(-0.2, 0.2)) * p.mass)
		Sfx.play_at("whoosh", PORTAL, 0.2, 0.0)
		yield(get_tree().create_timer(0.45), "timeout")


# ---------------------------------------------------------------- customers
func _spawn_customer_later(sec: float) -> void:
	yield(get_tree().create_timer(sec), "timeout")
	_spawn_customer()


func _free_slot() -> int:
	var used := []
	for c in customers:
		used.append(c.slot)
	var free := []
	for i in OPEN_SLOTS[Game.windows() - 1]:
		if not i in used:
			free.append(i)
	if free.empty():
		return -1
	return pick(free)


func _spawn_customer() -> void:
	if shift_over or spawned >= total_customers or customers.size() >= Game.max_at_once():
		return
	var ordered := []
	for c in customers:
		ordered.append(c.order)
	var avail := []
	for p in parcels:
		if is_instance_valid(p) and not p.delivered and not p.stolen and not p.code in ordered:
			avail.append(p)
	if maga_parcel and is_instance_valid(maga_parcel):
		avail.erase(maga_parcel)
	var slot := _free_slot()
	if slot < 0:
		return
	var maga_now: bool = maga_pending and maga_c == null and maga_parcel and is_instance_valid(maga_parcel)
	if maga_now:
		avail = [maga_parcel]
	if avail.empty():
		if incoming.empty() and customers.empty():
			# посылки кончились: смена закончится
			total_customers = spawned
			_end_shift()
		else:
			_spawn_customer_later(2.0)
		return
	spawned += 1
	var kind: String = _pick_kind()
	var is_boss: bool = Game.is_boss_day() and boss == null and spawned >= total_customers
	if "--boss" in OS.get_cmdline_args() and spawned == 1:
		is_boss = true
	if is_boss:
		kind = "king"
	for a in OS.get_cmdline_args():
		if a.begins_with("--kind=") and spawned == 1:
			kind = a.substr(7)
	if maga_now:
		kind = "maga"
	var p = pick(avail)
	# кооп: ношу на двоих заказывают пораньше (иначе может не дойти очередь)
	for q in avail:
		if q.duo and (randf() < 0.45 or ("--cowfirst" in OS.get_cmdline_args() and q.box_type == "cow")):
			p = q
			break
	if kind == "giant":
		# великан любит холодное
		for q in avail:
			if q.box_type == "frozen" and not q.melted:
				p = q
	var c = Customer.new()
	# Мошенник: оборотень почти всегда, остальные иногда (с 3-й смены)
	var scam_chance := 0.0
	if Game.day >= 2 and kind == "werewolf":
		scam_chance = 0.7
	elif Game.day >= 3 and not kind in ["king", "troll", "ghost"]:
		scam_chance = 0.12
	for a in OS.get_cmdline_args():
		if a == "--scam" and spawned == 1:
			scam_chance = 1.0
	c.scammer = randf() < scam_chance
	c.receipt_code = p.code
	if c.scammer:
		c.fake = pick(["seal", "code"])
		if c.fake == "code":
			var other: String = pick(CODES)
			while other == p.code:
				other = pick(CODES)
			c.receipt_code = other
	c.grabber = kind == "thief" and (randf() < 0.5 or "--grab" in OS.get_cmdline_args())
	if p.valuable:
		c.safe_pin = p.get_meta("pin")
		if c.scammer:
			c.safe_pin = str(100 + randi() % 900)
	c.mischief = rand_range(3.0, 5.0)
	if maga_now:
		c.scammer = false
		c.fake = ""
		c.receipt_code = p.code
		c.grabber = false
		maga_c = c
	if is_boss:
		c.scammer = false
		c.fake = ""
		c.receipt_code = p.code
		c.grabber = false
	var opts := []
	for l in KINDS[kind][1]:
		opts.append(tr(l))
	opts += Mods.lines_for(kind, Settings.lang)
	var fmt: String = pick(opts)
	var line: String = fmt % disp(p.code)
	if is_boss:
		line = tr("Я — Тёмный Почтмейстер. Мне %s. И это только начало.") % disp(p.code)
	var pat: float = Game.patience() * rand_range(0.85, 1.15) * PATIENCE_MULT.get(kind, 1.0)
	if is_boss:
		pat *= 2.5
	if Game.decor.has("plant"):
		pat *= 1.05
	var boss_art := is_boss and ResourceLoader.exists("res://assets/chars/boss_idle.png")
	if p.duo:
		pat *= 1.8  # вдвоём тащить долго: клиент готов подождать
	c.setup(kind, _char_frames("boss" if boss_art else kind), p.code, line, pat)
	if is_boss:
		boss = c
		boss_left = 3
		c.scale = Vector3.ONE * (1.15 if boss_art else 1.3)
		if not boss_art:
			c.sprite.modulate = Color(0.45, 0.28, 0.6)  # пока нет своего спрайта: тёмный король
		Sfx.play_music("music_boss")
	if not kind in Game.seen_kinds:
		Game.seen_kinds.append(kind)
		if KIND_HINTS.has(kind) and tut_step < 0:
			_flash(tr("Новый клиент: %s\n%s") % [tr(KINDS[kind][0]), tr(KIND_HINTS[kind])], 5.0)
	c.door = DOOR
	c.slot = slot
	c.translation = DOOR
	add_child(c)
	customers.append(c)
	Sfx.play("doorbell", 0.03, -3.0)
	c.connect("left", self, "_on_customer_left", [c])
	c.connect("arrived", self, "_on_customer_arrived", [c])
	c.connect("escaped", self, "_on_thief_escaped", [c])
	var target := Vector3(SLOTS[slot] + rand_range(-0.4, 0.4), 0, 0.9)
	c.set_meta("target", target)
	returns.maybe_mark(c, kind)
	rare.on_spawn(c)
	c.walk_to(target, "arrive")
	c.net_id = spawned
	if Net.active:
		rpc("net_customer", c.net_id, kind, p.code, line, slot, pat, target, c.scammer, c.fake, c.receipt_code)
	_refresh_hud()
	# следующий подтянется сам, если есть свободное место
	if customers.size() < Game.max_at_once():
		if Game.event == "rush":
			_spawn_customer_later(rand_range(2.0, 4.0))
		else:
			_spawn_customer_later(rand_range(4.0, 8.0))
	# вторая поставка в середине смены
	if not wave2_done and spawned >= total_customers / 2:
		wave2_done = true
		_portal_wave_later(3.0, incoming.size())


func _char_frames(kind: String) -> Dictionary:
	var fr := {}
	for f in ["idle", "happy", "angry", "walk", "walk2", "back", "back_walk", "back_walk2", "run",
			"hold", "point", "carry", "carry2", "back_carry", "steal"]:
		var path := "res://assets/chars/%s_%s.png" % [kind, f]
		if ResourceLoader.exists(path):
			var t: Texture = load(path)
			t.flags = 0
			fr[f] = t
	return fr


func _on_customer_left(happy: bool, c) -> void:
	if Net.active:
		rpc("net_customer_leave", c.net_id, happy, c.bubble_text)
	_drop_receipt(c)
	returns.on_left(c)
	if c == maga_c:
		maga_pending = false
		if happy:
			_maga_reward()
	if c.kicked:
		pass  # штраф/награда уже посчитаны у кнопки
	elif not happy and c.scammer:
		_flash(tr("Мошенник ушёл ни с чем."), 2.0)
	elif not happy:
		failed += 1
		stat("angry")
		streak = 0
		var fine := 5 - 2 * Game.lvl("bell")
		money = int(max(0, money - fine))
		_flash(tr("Клиент ушёл злой. -%d монет") % fine, 2.0)
		_hardcore_check()
	_customer_gone(c)


func _customer_gone(c) -> void:
	customers.erase(c)
	_refresh_hud()
	if spawned >= total_customers:
		if customers.empty():
			yield(get_tree().create_timer(2.0), "timeout")
			if customers.empty():
				_end_shift()
	else:
		_spawn_customer_later(rand_range(2.0, 4.0))


func _on_customer_arrived(c) -> void:
	_refresh_hud()
	if c.has_meta("ret"):
		returns.on_arrived(c)
		return
	_make_receipt(c)
	if served >= 1 or spawned >= 2:
		_tip("receipt")
	if c.safe_pin != "":
		_tip("safe")
	if c.kind == "thief":
		_tip("golem" if golem else "thief")
	var op = _parcel_by_code(c.order)
	if op and op.box_type in ["living", "mimic"] and cage_area:
		_tip("cage")
	if Game.lvl("sorter") > 0:
		for q in parcels:
			if is_instance_valid(q) and q.code == c.order:
				q.set_highlight(true)
	if c.kind == "king":
		for w in waiting():
			if w != c:
				w.patience -= 6.0
				w._say(tr("Эй! Король без очереди?!"), Color(1, 0.6, 0.3), 2.0)
	if c.scammer and not "hint_receipt" in Game.seen_kinds:
		Game.seen_kinds.append("hint_receipt")
		_flash(tr("Посмотри на ЧЕК на стойке! Подделка (кривая печать или чужой номер)?\nЖми красную кнопку «ВОН!» у окна"), 6.0)
	if tut_step == 0:
		tut_step = 1


func _make_receipt(c) -> void:
	var x: float = c.global_transform.origin.x
	var r := prop("receipt_fake" if c.fake == "seal" else "receipt", Vector3(x + 0.55, 0.98, 0.15), PI, 0.36)
	r.rotation.x = 0.15
	var body := StaticBody.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = Vector3(0.16, 0.2, 0.1)
	cs.shape = sh
	body.add_child(cs)
	var who: String = _who(c)
	var t := tr("ЧЕК (%s): заказ %s. Печать на месте.") % [who, disp(c.receipt_code)]
	if c.fake == "seal":
		t = tr("ЧЕК (%s): заказ %s. Печать какая-то КРИВАЯ...") % [who, disp(c.receipt_code)]
	if c.safe_pin != "":
		t += "  " + tr("Код сейфа: %s") % ("%s-%s-%s" % [c.safe_pin[0], c.safe_pin[1], c.safe_pin[2]])
	body.set_meta("look", t)
	r.add_child(body)
	c.receipt = r


func _drop_receipt(c) -> void:
	if c.receipt and is_instance_valid(c.receipt):
		c.receipt.queue_free()
	c.receipt = null


func _button_up(spr) -> void:
	if is_instance_valid(spr):
		spr.texture = tex("props/button_up", false)


func _press_kick(btn) -> void:
	if net_client():
		rpc_id(1, "net_req_kick", btn.get_meta("slot"))
		return
	var slot: int = btn.get_meta("slot")
	var spr = kick_buttons.get(slot)
	if spr:
		spr.texture = tex("props/button_down", false)
		get_tree().create_timer(0.35).connect("timeout", self, "_button_up", [spr])
	Sfx.play("kick", 0.0, -2.0)
	var c = null
	for w in waiting():
		if w.slot == slot:
			c = w
	if c == null:
		_flash(tr("У этого окна никого нет."), 1.5)
		return
	if returns.on_kick(c):
		return
	if c.scammer:
		stat("scam")
		Ach.add("kicked")
		money += 15
		_flash(tr("Мошенник разоблачён! +15 монет"), 2.5)
		c.leave_kicked(tr("Р-р-р... Ладно, ухожу!"))
	else:
		money = int(max(0, money - 10))
		failed += 1
		stat("kicked_honest")
		streak = 0
		_flash(tr("Это был честный клиент! -10 монет"), 2.5)
		c.leave_kicked(tr("За что?! Я с настоящим чеком!"))
		_hardcore_check()
	_refresh_hud()


func _on_thief_escaped(c) -> void:
	if Net.active:
		rpc("net_customer_leave", c.net_id, true, tr("Пока, лохи!"))
	var b = c.drop_loot()
	if b and is_instance_valid(b):
		b.stolen = true
		parcels.erase(b)
		var owner_c = _customer_for(b.code)
		b.queue_free()
		if owner_c:
			owner_c._say(tr("Это же была МОЯ посылка!"), Color(1, 0.35, 0.3), 2.0)
			owner_c.leave(false)
	money = int(max(0, money - 10))
	stat("stolen")
	_flash(tr("Вор утащил посылку! -10 монет"), 2.5)
	_customer_gone(c)


func _thief_drop(c, by_golem: bool) -> void:
	var b = c.drop_loot()
	if b and is_instance_valid(b):
		b.held = false
		_toss_back(b)
	if by_golem:
		money += 5
		_flash(tr("Голем поймал вора! +5 монет"), 2.5)
	else:
		money += 5
		_flash(tr("Попал в вора! Посылка спасена. +5 монет"), 2.5)
	c.leave_kicked(tr("Ай-ай! Отпусти!"))
	_refresh_hud()


func _thief_grab(c, b) -> void:
	_drop_receipt(c)
	b.held = true
	b.mode = RigidBody.MODE_KINEMATIC
	c.run_off_with(b)
	_ring_alarm()
	if golem:
		_flash(tr("ВОР! Голем, держи его!"), 2.0)
		golem.go([Vector3(4.6, 0, 2.6)], 4.0)
		golem.say(tr("СТОЯТЬ!"), Color(1, 0.8, 0.4), 2.0)
		yield(get_tree().create_timer(1.0), "timeout")
		if is_instance_valid(c) and c.state == "running":
			golem.pose = "hold"
			_thief_drop(c, true)
			yield(get_tree().create_timer(1.5), "timeout")
			if golem:
				golem.pose = ""
				golem.go([Vector3(3.6, 0, 3.4)], 2.0)
	else:
		_flash(tr("ВОР схватил посылку! Попади в него коробкой!"), 2.5)


func _on_mimic_bite(p) -> void:
	stat("mimic")
	_tip("mimic")
	money = int(max(0, money - 2))
	_flash(tr("Мимик укусил! -2 монеты. Он успокоится через пару секунд"), 2.0)
	_refresh_hud()


func _on_parcel_melted(p) -> void:
	stat("melted")
	_flash(tr("Замороженная посылка %s растаяла! Держи такие в ларе") % disp(p.code), 2.5)


func waiting() -> Array:
	var r := []
	for c in customers:
		if is_instance_valid(c) and c.state == "at_counter":
			r.append(c)
	return r


func _customer_for(code: String):
	for c in waiting():
		if c.order == code:
			return c
	return null


func _nearest_waiting(x: float, max_dx := 99.0):
	var best = null
	var bd := max_dx
	for c in waiting():
		var d: float = abs(c.global_transform.origin.x - x)
		if d < bd:
			bd = d
			best = c
	return best


func _physics_process(delta: float) -> void:
	_net_tick(delta)
	if net_client():
		_update_warehouse()
		return
	_update_rules(delta)
	_update_warehouse()
	for b in parcels:
		if not is_instance_valid(b) or b.held or b.delivered:
			continue
		var pos: Vector3 = b.global_transform.origin
		# Попадание коробкой в лицо любому клиенту
		if b.thrown and not b.hit_done and b.linear_velocity.length() > 3.0:
			if fun.check_ff(b, pos):
				continue
			for c in customers:
				if not is_instance_valid(c) or c.state == "leaving" or c.kind == "ghost":
					continue
				var head: Vector3 = c.global_transform.origin + Vector3(0, c.base_y * 1.8, 0)
				if pos.distance_to(head) < 0.65:
					b.hit_done = true
					if c.state == "running":
						c.on_hit()
						_thief_drop(c, false)
						break
					if c.kind == "dwarf" and c.order == b.code and c.state == "at_counter":
						b.bonus_catch = true
						_deliver(b, c, 0)
						return
					var v: Vector3 = b.linear_velocity
					b.linear_velocity = Vector3(v.x * 0.2, 1.5, -abs(v.z) * 0.35 - 1.0)
					fun.on_oops(b)
					_on_face_hit(c)
					break
		# Сбить фонарь броском
		if b.thrown and b.linear_velocity.length() > 3.0:
			for ln in lanterns:
				if ln[2] <= 0.0 and pos.distance_to(ln[0].global_transform.origin) < 0.55:
					_lantern_off(ln)
					b.set_meta("grace", OS.get_ticks_msec() + 4000)  # упала на стойку: не «чужая посылка»
		# Коробка улетела в зал: хозяин забирает, остальные кидают обратно
		if pos.z > 0.55 and pos.y < 0.8 and b.mode == RigidBody.MODE_RIGID:
			b.hall_time += delta
			if b.hall_time > 1.2:
				b.hall_time = 0.0
				var owner_c = _customer_for(b.code)
				if owner_c:
					_deliver(b, owner_c, 5)
					return
				_toss_back(b)
		else:
			b.hall_time = 0.0

	for b in counter_area.get_overlapping_bodies():
		if not b.is_in_group("parcel") or b.held or b.delivered or b.has_meta("ret"):
			continue
		if b.linear_velocity.length() > 0.6:
			continue
		var owner_c = _customer_for(b.code)
		if owner_c:
			_deliver(b, owner_c, 0)
			return
		var near = _nearest_waiting(b.global_transform.origin.x, 2.2)
		if b.has_meta("grace") and OS.get_ticks_msec() < int(b.get_meta("grace")):
			if near:
				b.rejected_by = near.get_instance_id()
			continue
		if near and b.rejected_by != near.get_instance_id():
			b.rejected_by = near.get_instance_id()
			near.reject()


func _on_face_hit(c) -> void:
	c.on_hit()
	hits += 1
	Ach.unlock("ACH_FACE_HIT")
	stat("orc_hit" if c.kind == "orc" else "hit")
	if rare.on_face_hit():
		pass
	elif Game.event == "inspector":
		money = int(max(0, money - 15))
		_flash(tr("Инспектор всё видел! -15 монет"), 2.0)
	elif c.kind == "orc":
		money += 5
		_flash(tr("Орк оценил бросок. +5 монет"), 2.0)
	else:
		money = int(max(0, money - 3))
		_flash(tr("Прямо в лицо! -3 монеты"), 2.0)
	_refresh_hud()


func _on_parcel_exploded(p) -> void:
	var pos: Vector3 = p.global_transform.origin
	fun.on_oops(p)
	Sfx.play_at("boom", pos, 0.05, 8.0)
	# вспышка
	var fl := OmniLight.new()
	fl.light_color = Color(1, 0.6, 0.2)
	fl.light_energy = 6.0
	fl.omni_range = 7.0
	fl.translation = pos
	add_child(fl)
	var ball := MeshInstance.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	ball.mesh = sm
	var bm := unshaded(Color(1, 0.65, 0.2))
	bm.flags_transparent = true
	ball.material_override = bm
	ball.translation = pos
	add_child(ball)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 4.0, 0.35)
	tw.tween_property(bm, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(fl, "light_energy", 0.0, 0.5)
	tw.chain().tween_callback(ball, "queue_free")
	tw.tween_callback(fl, "queue_free")
	# раскидывает коробки вокруг
	for q in parcels:
		if is_instance_valid(q) and q != p and not q.held and not q.delivered and q.mode == RigidBody.MODE_RIGID:
			var d: Vector3 = q.global_transform.origin - pos
			if d.length() < 3.0:
				q.sleeping = false
				q.apply_central_impulse((d.normalized() + Vector3.UP * 0.6) * (3.0 - d.length()) * 3.0 * q.mass)
	# игрока толкает
	var pd: Vector3 = player.global_transform.origin - pos
	if pd.length() < 3.0:
		player.velocity += (pd.normalized() + Vector3.UP * 0.3) * (3.0 - pd.length()) * 3.0
	# клиенты рядом в шоке
	for c in customers:
		if is_instance_valid(c) and c.global_transform.origin.distance_to(pos) < 4.0:
			c.scare()
	money = int(max(0, money - 10))
	stat("boom")
	_flash(tr("БАБАХ! Осторожнее со взрывными! -10 монет"), 2.5)
	_refresh_hud()


func _on_parcel_cracked(p) -> void:
	if p.cracks == 1:
		_flash(tr("Хрусь! Хрупкая посылка треснула..."), 2.0)


func _toss_back(b) -> void:
	# Клиент закидывает коробку обратно на стойку
	b.mode = RigidBody.MODE_KINEMATIC
	var x: float = clamp(b.global_transform.origin.x, -6.0, 6.0)
	var near = _nearest_waiting(x)
	if near:
		x = near.global_transform.origin.x + rand_range(-0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(b, "global_transform:origin", Vector3(x, 2.2, 0.2), 0.35)
	tw.tween_property(b, "global_transform:origin", Vector3(x, 1.3, -0.15), 0.25)
	tw.tween_callback(self, "_unfreeze", [b])
	if near:
		near._say(tr("Держи своё обратно!"), Color(1, 0.8, 0.4), 1.5)


func _unfreeze(b) -> void:
	if is_instance_valid(b):
		b.mode = RigidBody.MODE_RIGID
		b.sleeping = false
		b.linear_velocity = Vector3.ZERO


func _deliver(p, c, penalty: int) -> void:
	if c.kind == "thief" and c.grabber and c.state == "at_counter":
		# вор хватает посылку и сбегает, не заплатив
		_thief_grab(c, p)
		return
	p.delivered = true
	p.mode = RigidBody.MODE_STATIC
	var fuse_was: float = p.fuse
	p.fuse = -1.0
	var tw := create_tween()
	tw.tween_property(p, "global_transform:origin", c.global_transform.origin + Vector3(0, 1.0, 0), 0.4)
	tw.tween_callback(p, "queue_free")
	if tut_step >= 0 and tut_step < 3:
		tut_step = 3
	if c.scammer:
		# отдали посылку мошеннику
		fun.on_scam(p)
		money = int(max(0, money - 20))
		Sfx.play("reject", 0.0, -2.0)
		_flash(tr("Это был МОШЕННИК! Чужая посылка уплыла. -20 монет"), 2.5)
		streak = 0
		c.leave_with(tr("Хе-хе, спасибо, растяпа!"), true)
		_refresh_hud()
		return
	fun.on_served(p)
	var bonus := int(c.patience / c.max_patience * 15.0)
	var earned := int(max(1, 10 + bonus - penalty))
	var extra := ""
	if p.cursed:
		earned += 10
		extra += tr("  (за проклятую +10)")
	if penalty > 0:
		extra += tr("  (поднял с пола, -%d)") % penalty
	if PAY.has(p.box_type) and not p.melted:
		earned += PAY[p.box_type] + (15 if p.duo and p.box_type == "chest" else 0)
		var names := {"chest": tr("сундук"), "mimic": tr("мимик"), "living": tr("живая"), "frozen": tr("холодная"), "heavy": tr("тяжёлая"), "gift": tr("чаевые за подарок"), "cow": tr("корова")}
		extra += "  (%s +%d)" % [names[p.box_type], PAY[p.box_type]]
	if p.box_type == "timer" and fuse_was != 0.0:
		earned += 10
		extra += tr("  (успел до взрыва +10)")
	if c.kind == "witch" and p.cursed:
		earned += 10
		extra += tr("  (ведьма в восторге +10)")
	if c.kind == "goblin":
		if c.patience > c.max_patience * 0.7:
			earned += 5
			extra += tr("  (гоблин доволен +5)")
		elif c.patience < c.max_patience * 0.3:
			earned -= 5
			extra += tr("  (гоблин выторговал -5)")
	if p.get("bonus_catch"):
		earned += 5
		extra += tr("  (гном поймал +5)")
	if c.kind == "ghost":
		earned = int(earned * 0.6)
		extra += tr("  (призраки платят мало)")
	if c.kind == "king":
		earned *= 2
		extra += tr("  (король платит x2)")
	if c.kind == "giant" and p.box_type == "frozen" and not p.melted:
		earned *= 2
		extra += tr("  (великан доволен холодным x2)")
	if Game.event == "rush":
		earned = int(earned * 1.5)
		extra += "  (x1.5)"
	var pm := Game.pay_mult()
	if abs(pm - 1.0) > 0.02:
		earned = int(round(earned * pm))
		extra += "  (" + tr("репутация") + " x%.2f)" % pm
	var broken := ""
	if p.box_type == "fragile" and p.cracks > 0:
		broken = tr("Оно же РАЗБИТО!")
	elif p.melted:
		broken = tr("Оно же РАСТАЯЛО! Лужа какая-то...")
	elif p.box_type == "timer" and fuse_was == 0.0:
		broken = tr("Оно... дымится?!")
	if broken != "":
		earned = 2
		extra = tr("  (испорчено, почти ничего)")
	earned = int(max(1, earned))
	var vipb: int = rare.vip_bonus(c, earned)
	if vipb > 0:
		earned += vipb
		extra += tr("  (VIP: втройне!)")
	money += earned
	served += 1
	Ach.add("delivered")
	if c.max_patience - c.patience < 5.0:
		Ach.unlock("ACH_FAST")
	if Game.mode == "career" and Game.bank + money >= 2000:
		Ach.unlock("ACH_BANK_2000")
	if broken != "":
		stat("broken")
	else:
		if p.cursed:
			stat("cursed")
		if p.box_type in ["heavy", "chest"]:
			stat("heavy")
		if p.box_type == "gift":
			stat("gift")
		if p.box_type == "frozen":
			stat("frozen")
		if c.patience > c.max_patience * 0.7:
			stat("fast")
		if c.kind == "king":
			stat("king")
	streak += 1
	stats["streak"] = int(max(stats.get("streak", 0), streak))
	if c == boss:
		boss_left -= 1
		if boss_left > 0:
			_boss_next(c)
			_refresh_hud()
			return
	Sfx.play("coin", 0.05, -2.0)
	var msg: String = tr("+%d монет%s") % [earned, extra]
	_flash(msg, 2.0)
	if p.get("bonus_catch"):
		c.leave_with(tr("Ловко! Курьер курьера видит издалека!"), true)
	elif broken != "":
		c.leave_with(broken, false)
	elif p.box_type == "gift":
		c.leave_with(tr("Ой, подарочек! Держи на чай!"), true)
	elif c.kind == "king":
		c.leave_with(tr("Королевская щедрость! Держи золото!"), true)
	else:
		c.leave(true)
	_refresh_hud()


func _end_shift() -> void:
	if shift_over or net_client():
		return
	shift_over = true
	Sfx.play("shift_end", 0.0, -2.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var stars := 3
	if failed > 2:
		stars = 1
	elif failed > 0:
		stars = 2
	var rating := ""
	for k in 3:
		rating += "★" if k < stars else "☆"
	if Game.event == "inspector" and failed == 0 and hits == 0:
		money += 50
	hud_tut.visible = false
	end_buttons.visible = true
	var txt := ""
	var side := []
	if Game.mode == "chaos":
		var best_before := Game.chaos_best
		var score := money
		Game.end_chaos(score)
		chaos_over = true
		txt = tr("ХАОС ОКОНЧЕН\n\nВыдано: %d из %d\nЗлых клиентов: %d\nСчёт: %d\nРекорд: %d") % [served, spawned, failed, score, Game.chaos_best]
		if score >= 1500:
			Ach.unlock("ACH_CHAOS_1500")
		if score > best_before:
			txt += "\n\n" + tr("НОВЫЙ РЕКОРД!")
		end_buttons.get_child(0).text = tr("Ещё раз")
		end_buttons.get_child(1).text = tr("В меню")
	else:
		# задания дня
		var done_n := 0
		if not Game.tasks.empty():
			side.append(tr("ЗАДАНИЯ ДНЯ"))
			for id in Game.tasks:
				var ok := Career.task_done(id, stats, served)
				if ok:
					done_n += 1
				side.append(Career.task_text(id, stats, served, ok))
			if done_n > 0:
				side.append(tr("Награда: +%d жетон., +%d монет") % [done_n, done_n * Career.TASK_COINS])
			side.append("")
		money += done_n * Career.TASK_COINS
		Game.tokens += done_n
		# книга жалоб
		var revs := Career.reviews(stats, failed, served)
		Game.last_reviews = []
		var rv := 0
		if not revs.empty():
			side.append(tr("КНИГА ЖАЛОБ И ПРЕДЛОЖЕНИЙ"))
			for r in revs:
				var st := ""
				for k in 5:
					st += "★" if k < r[1] else "☆"
				side.append("%s %s: «%s»" % [st, tr(r[2]), tr(r[3])])
				Game.last_reviews.append("%s %s: «%s»" % [st, tr(r[2]), tr(r[3])])
				rv += 1 if r[1] >= 4 else (-1 if r[1] <= 2 else 0)
		var drep: int = {3: 6, 2: 1, 1: -5}[stars] + rv
		var rep_before := Game.rep
		var closed := Game.add_rep(drep)
		var beaten: bool = Game.is_boss_day() and boss != null and boss_left <= 0
		if beaten:
			Ach.unlock("ACH_BOSS")
		if failed == 0 and served >= 5:
			Ach.unlock("ACH_NO_COMPLAINTS")
		if Game.rep >= 100:
			Ach.unlock("ACH_REP_100")
		if not Game.tasks.empty() and done_n == Game.tasks.size():
			Ach.unlock("ACH_ALL_TASKS")
		if Game.bank + money >= 2000:
			Ach.unlock("ACH_BANK_2000")
		txt = tr("СМЕНА %d ОКОНЧЕНА\n\nВыдано: %d из %d\nЗлых клиентов: %d\nЗаработано: %d монет\nВсего в кассе: %d\nРейтинг: %s\nРепутация: %d → %d\nЖетоны: %d") % [Game.day, served, spawned, failed, money, Game.bank + money, rating, rep_before, Game.rep, Game.tokens]
		if closed:
			no_day_inc = true
			txt += "\n\n" + tr("Гильдия закрыла пункт за плохие отзывы!\nПереезд в начало района.")
		elif Game.is_boss_day() and not beaten:
			no_day_inc = true
			txt += "\n\n" + tr("Почтмейстер ушёл ни с чем.\nПопробуй последнюю смену ещё раз!")
		if beaten:
			Game.career_done = true
			side = [tr("ФИНАЛ"), "", tr("Тёмный Почтмейстер получил все свои посылки и... улыбнулся. Впервые за тысячу лет."),
				tr("«Ладно, работник. Этот пункт — лучший во всех королевствах». Он отдал тебе ключи от Гильдии."),
				"", tr("Карьера пройдена! Можно работать дальше в бесконечном режиме."), "",
				tr("Спасибо за игру!") + "  2peaK's Studio", tr("Тестировщик: Мага")]
		Game.save_game()
	if Game.mode == "career" and Game.day == 1 and not Net.active:
		txt += "\n\n" + tr("ОБУЧЕНИЕ: смена окончена! Жми «Закрыть пункт» — деньги уйдут в кассу, и наступит утро смены 2.")
	var shame: String = fun.board_text()
	if shame != "":
		side.append(shame)
	hud_panel_text.text = txt
	hud_panel_side.text = PoolStringArray(side).join("\n")
	hud_panel.visible = true
	if Net.active:
		Ach.unlock("ACH_COOP")
		rpc("net_end_shift", txt + ("\n" + shame if shame != "" else ""))


# ---------------------------------------------------------------- rules / events
func _update_rules(delta: float) -> void:
	# фонари снова зажигаются через время
	for ln in lanterns:
		if ln[2] > 0.0:
			ln[2] -= delta
			if ln[2] <= 0.0 and Game.event != "blackout":
				ln[1].visible = true
				ln[0].modulate = Color(1, 1, 1)
	for c in customers:
		if not is_instance_valid(c) or c.state != "at_counter":
			continue
		# Вампир на свету
		if c.kind == "vampire":
			var lit := false
			if Game.event != "blackout":
				for ln in lanterns:
					if ln[1].visible and abs(ln[0].global_transform.origin.x - c.global_transform.origin.x) < 3.2:
						lit = true
			c.drain_mult = 1.7 if lit else 0.7
			if lit and randf() < delta * 0.15:
				c._say(tr("Слишком светло!.. Сбей фонарь!"), Color(1, 0.7, 0.7), 1.5)
		# Дракончик заждался: огонь
		if c.kind == "dragon" and not c.fired and c.patience < c.max_patience * 0.35:
			c.fired = true
			_dragon_fire(c)
		# Вор хватает коробку со стойки
		if c.kind == "thief" and c.grabber:
			c.mischief -= delta
			if c.mischief <= 0.0:
				var b = _counter_box_near(c.global_transform.origin.x, c.order)
				if b:
					_thief_grab(c, b)
				else:
					c.mischief = 1.0
		# Тролль-малыш сшибает коробки со стойки
		if c.kind == "troll":
			c.mischief -= delta
			if c.mischief <= 0.0:
				c.mischief = rand_range(6.0, 9.0)
				var b2 = _counter_box_near(c.global_transform.origin.x, c.order)
				if b2:
					b2.sleeping = false
					b2.apply_central_impulse(Vector3(rand_range(-1, 1), 2.5, -3.0) * b2.mass * 0.5)
					c._say(tr("БУМ! Хи-хи-хи!"), Color(1, 0.9, 0.4), 1.5)
					Sfx.play_at("boing", b2.global_transform.origin, 0.2, 0.0)
				else:
					c._say(pick([tr("А чё это у вас?"), tr("Скучно! Быстрее!"), tr("Мама, смотри, коробки!")]), Color(1, 0.9, 0.6), 1.5)


func _counter_box_near(x: float, except_code: String):
	for b in parcels:
		if not is_instance_valid(b) or b.held or b.delivered or b.code == except_code or b.mode != RigidBody.MODE_RIGID:
			continue
		var p: Vector3 = b.global_transform.origin
		if p.y > 0.95 and p.y < 1.7 and abs(p.z) < 0.5 and abs(p.x - x) < 2.0:
			return b
	return null


func _update_warehouse() -> void:
	var dt := get_physics_process_delta_time()
	lever_cd -= dt
	if conv_mat:
		var bs: float = fun.belt_speed() if fun else 0.9
		conv_mat.uv1_offset.x -= dt * bs * 1.2
		for b in belt_area.get_overlapping_bodies():
			if b.is_in_group("parcel") and not b.held and b.mode == RigidBody.MODE_RIGID:
				b.sleeping = false
				b.linear_velocity.x = max(b.linear_velocity.x, bs)
	if portal_sprite:
		if portal_open_t > 0.0:
			portal_open_t -= dt
			portal_sprite.texture = tex("props/portal_%d" % (1 + int(portal_open_t / 0.15) % 2), false)
		elif portal_sprite.texture.resource_path.find("portal_0") < 0:
			portal_sprite.texture = tex("props/portal_0", false)
	if net_client():
		if freezer_area:
			var pd2: Vector3 = player.global_transform.origin - FREEZER
			pd2.y = 0
			_set_lid(pd2.length() < 2.4)
		return
	# сортировка: коробка из портала легла на свой стеллаж
	for p in parcels:
		if not is_instance_valid(p) or p.held or p.delivered or p.sorted or not p.from_portal:
			continue
		if p.linear_velocity.length() > 0.3:
			continue
		var si := _shelf_at(p.global_transform.origin)
		if si >= 0 and si == shelf_for(p.code):
			p.sorted = true
			money += 2
			stat("sort")
			Ach.add("sorted")
			Sfx.play("coin", 0.1, -10.0)
			_flash(tr("Разложено по букве: +2"), 1.2)
			_tip("sort")
			_refresh_hud()
	# морозилка
	if freezer_area:
		var inside := freezer_area.get_overlapping_bodies()
		for p in parcels:
			if is_instance_valid(p) and p.box_type == "frozen":
				p.in_freezer = p in inside
		var pd: Vector3 = player.global_transform.origin - FREEZER
		pd.y = 0
		_set_lid(pd.length() < 2.4)
	if cage_area:
		for b in cage_area.get_overlapping_bodies():
			if b.is_in_group("parcel") and b.box_type in ["living", "mimic", "cursed"]:
				b.calm = max(b.calm, 1.0)
				if b.box_type != "cursed" and not b.held:
					Ach.unlock("ACH_TAMER")
	if helper:
		_update_helper()
	if Game.mode == "chaos" and not shift_over:
		chaos_t -= dt
		if chaos_t <= 0.0:
			chaos_t = rand_range(8.0, 13.0)
			_chaos_brawl()


func _update_helper() -> void:
	if helper.busy:
		return
	helper_cd -= get_physics_process_delta_time()
	if helper_cd > 0.0:
		return
	helper_cd = rand_range(16.0, 26.0)
	var steal := randf() < 0.1
	var target = null
	var cand := []
	var ordered := []
	for c in waiting():
		ordered.append(c.order)
	for p in parcels:
		if not is_instance_valid(p) or p.held or p.delivered or p.mode != RigidBody.MODE_RIGID:
			continue
		if p.global_transform.origin.z > -0.8 or p.box_type == "chest":
			continue
		if steal == (not p.code in ordered):
			cand.append(p)
	if cand.empty():
		helper_cd = 4.0
		return
	target = pick(cand)
	var c = _customer_for(target.code)
	_helper_job(target, c, steal)


func _helper_job(p, c, steal: bool) -> void:
	helper.busy = true
	var pp: Vector3 = p.global_transform.origin
	var stand := Vector3(pp.x, 0, pp.z + 0.9)
	var a := Vector3(0, 0, helper.translation.z)
	var path := [a, Vector3(0, 0, stand.z), stand]
	helper.go(path, 2.4)
	yield(helper, "arrived")
	if not is_instance_valid(p) or p.held or p.delivered or shift_over:
		helper.go([Vector3(0, 0, stand.z), Vector3(-1.2, 0, -1.3)], 2.4)
		yield(helper, "arrived")
		helper.busy = false
		return
	p.held = true
	p.mode = RigidBody.MODE_KINEMATIC
	helper.carry = p
	if steal:
		stat("helper_steal")
		helper.pose = "steal"
		helper.say(tr("Хи-хи... никто не видел"), Color(1, 0.9, 0.5), 2.0)
		yield(get_tree().create_timer(1.2), "timeout")
		if is_instance_valid(p):
			parcels.erase(p)
			p.stolen = true
			p.queue_free()
		helper.carry = null
		helper.pose = ""
		money = int(max(0, money - 3))
		_flash(tr("Гоблин-помощник стащил посылку! -3"), 2.0)
		_refresh_hud()
		helper.go([Vector3(0, 0, stand.z), Vector3(-1.2, 0, -1.3)], 2.4)
		yield(helper, "arrived")
		helper.busy = false
		return
	helper.say(tr("Несу-несу!"), Color(0.7, 1, 0.7), 1.5)
	var x := 0.0
	if c and is_instance_valid(c):
		x = c.global_transform.origin.x
	helper.go([Vector3(0, 0, stand.z), Vector3(0, 0, -0.9), Vector3(x, 0, -0.9)], 2.4)
	yield(helper, "arrived")
	if is_instance_valid(p) and not p.delivered:
		helper.carry = null
		p.global_transform.origin = Vector3(x, 1.3, -0.1)
		p.held = false
		p.mode = RigidBody.MODE_RIGID
		p.sleeping = false
		p.linear_velocity = Vector3.ZERO
	helper.carry = null
	helper.go([Vector3(-1.2, 0, -1.3)], 2.4)
	yield(helper, "arrived")
	helper.busy = false


func _lantern_off(ln) -> void:
	ln[2] = 25.0
	ln[1].visible = false
	ln[0].modulate = Color(0.35, 0.3, 0.3)
	Sfx.play_at("crack", ln[0].global_transform.origin, 0.1, 4.0)
	for c in waiting():
		if c.kind == "vampire":
			c._say(tr("Ах... темнота. Благодарю."), Color(0.7, 0.8, 1), 2.0)


func _dragon_fire(c) -> void:
	stat("fire")
	var pos: Vector3 = c.global_transform.origin + Vector3(0, 1.2, -0.6)
	Sfx.play_at("boom", pos, 0.3, -2.0)
	c._say(tr("ПФФФ!!! *огонь*"), Color(1, 0.6, 0.2), 2.0)
	var fl := OmniLight.new()
	fl.light_color = Color(1, 0.5, 0.1)
	fl.light_energy = 5.0
	fl.omni_range = 5.0
	fl.translation = pos
	add_child(fl)
	var tw := create_tween()
	tw.tween_property(fl, "light_energy", 0.0, 0.8)
	tw.tween_callback(fl, "queue_free")
	# подпаливает коробки на стойке рядом
	for q in parcels:
		if is_instance_valid(q) and not q.delivered and q.global_transform.origin.distance_to(pos) < 1.8:
			q._mat.albedo_color = q._mat.albedo_color.darkened(0.4)
	money = int(max(0, money - 5))
	_flash(tr("Дракончик заждался и подпалил стойку! -5 монет"), 2.5)
	_refresh_hud()


func _blackout() -> void:
	for l in lamps:
		l.light_energy *= 0.12
	for ln in lanterns:
		ln[1].visible = false
		ln[0].modulate = Color(0.35, 0.3, 0.3)
	flashlight = SpotLight.new()
	flashlight.light_energy = 2.2
	flashlight.spot_range = 12.0
	flashlight.spot_angle = 28.0
	flashlight.light_color = Color(1, 0.95, 0.8)
	player.cam.add_child(flashlight)


# ---------------------------------------------------------------- tutorial
func _update_tutorial() -> void:
	if tut_step < 0:
		hud_tut.text = Pad.prompt(tip_text)
		return
	var t := ""
	match tut_step:
		10:
			t = tr("ОБУЧЕНИЕ: пункт пока ЗАКРЫТ, клиентов нет. Чтобы начать смену, подойди к табличке «CLOSED» над стойкой (жёлтая стрелка) и кликни по ней (ЛКМ или E).")
		11:
			t = tr("Новый день! Пока закрыто: ноутбук — магазин улучшений, доска — задания, раскладушка — сохранить и выйти. Готов — переверни табличку (стрелка).")
		0:
			t = tr("ОБУЧЕНИЕ: пункт открыт! Клиенты приходят сами, звонить не надо (звонок на стойке — позвать следующего быстрее). Первый уже идёт...")
		1:
			var w := waiting()
			var code: String = w[0].order if not w.empty() else "?"
			t = tr("Клиент назвал номер %s. Найди коробку с этим номером на полках и возьми её (ЛКМ или E).") % disp(code)
			if player.held and not w.empty() and player.held.code == code:
				tut_step = 2
		2:
			t = tr("Неси к стойке. ПКМ — положить аккуратно, зажать ЛКМ — швырнуть (сильнее держишь — дальше летит).")
		3:
			t = tr("Отлично! Дальше сам. Следи за терпением клиентов (полоска над головой). Когда все уйдут, смена закончится. Удачи!")
	hud_tut.text = Pad.prompt(t)
	if tut_step == 3 and not Game.tutorial_done:
		Game.tutorial_done = true
		Game.save_game()
		yield(get_tree().create_timer(6.0), "timeout")
		tut_step = -1


# ---------------------------------------------------------------- pause & shop
func _set_paused(on: bool) -> void:
	if net_client():
		# гость: меню паузы без остановки мира (мир крутит хост)
		if net_paused and not on:
			return
		pause_panel.visible = on
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED)
		return
	get_tree().paused = on
	pause_panel.visible = on
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED)
	if Net.active and Net.is_host:
		drop_wait = false
		rpc("net_pause", on)


func _button(parent: Control, text: String, target: String, args := []) -> Button:
	var b := Button.new()
	b.text = text
	b.add_font_override("font", font_big)
	b.add_color_override("font_color_disabled", Color(0.92, 0.9, 0.86))
	b.connect("pressed", self, target, args)
	parent.add_child(b)
	return b


func _open_settings() -> void:
	var sp = load("res://scripts/settings_panel.gd").new()
	sp.build(font_big)
	pause_panel.get_parent().add_child(sp)


# смена языка в паузе: пока пункт закрыт — перезагружаем пункт, чтобы всё перевелось
func relang() -> bool:
	if is_open or Net.active or Game.mode == "chaos" or carrying:
		return false
	Game.phase = "closed"
	Game.save_game()
	get_tree().paused = false
	get_tree().reload_current_scene()
	return true


func _reopen_settings() -> void:
	_set_paused(true)
	_open_settings()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene("res://menu.tscn")


func _quit() -> void:
	get_tree().quit()


func _retry() -> void:
	if hc_fired or hardcore_on():
		return
	if chaos_over:
		_to_menu()
		return
	if Net.active and Net.is_host:
		Net.start_shift()
		return
	get_tree().reload_current_scene()


func _open_shop() -> void:
	if chaos_over:
		Game.start_chaos()
		get_tree().reload_current_scene()
		return
	# смена окончена: деньги в кассу, день +1, пункт закрыт до утра
	Game.bank += money
	money = 0
	if not no_day_inc:
		Game.day += 1
	Game.roll_event()
	Game.phase = "closed"
	Game.save_game()
	if Game.demo_locked() and not Net.active:
		# демо закончилось: дальше только в полной версии
		Game.demo_over_pending = true
		get_tree().paused = false
		get_tree().change_scene("res://menu.tscn")
		return
	if Net.active and Net.is_host:
		Net.start_shift()
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _refresh_shop() -> void:
	for ch in shop_box.get_children():
		ch.queue_free()
	var title := Label.new()
	title.add_font_override("font", font_big)
	title.align = Label.ALIGN_CENTER
	title.text = tr("МАГАЗИН      В кассе: %d монет      Жетоны: %d") % [Game.bank, Game.tokens]
	shop_box.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGN_CENTER
	shop_box.add_child(tabs)
	var t1 := _button(tabs, tr("Улучшения"), "_shop_tab", ["up"])
	var t2 := _button(tabs, tr("Декор пункта"), "_shop_tab", ["decor"])
	t1.disabled = shop_tab == "up"
	t2.disabled = shop_tab == "decor"
	UiTheme.tab_style(t1, shop_tab == "up")
	UiTheme.tab_style(t2, shop_tab == "decor")
	UiTheme.banner(title)
	if shop_tab == "decor":
		_refresh_decor_shop()
		return
	var grid := GridContainer.new()
	grid.columns = 2
	# улучшений много: список прокручивается (колесо, стик, перетаскивание)
	var sc := ScrollContainer.new()
	sc.rect_min_size = Vector2(530, 214)
	sc.scroll_horizontal_enabled = false
	shop_box.add_child(sc)
	sc.add_child(grid)
	var fsm: DynamicFont = font_big.duplicate()
	fsm.size = 10
	for id in Game.ORDER:
		var u: Array = Game.UPGRADES[id]
		var lv := Game.bought(id)
		var pr := Game.price(id)
		var why: String = Game.blocked(id)
		var txt: String
		if pr < 0:
			txt = tr("%s (макс.)\n%s") % [tr(u[0]), tr(u[1])]
		elif why != "":
			txt = tr("%s  ур.%d/%d  %d мон.\n(%s)") % [tr(u[0]), lv, u[2], pr, why]
		else:
			txt = tr("%s  ур.%d/%d  %d мон.\n%s") % [tr(u[0]), lv, u[2], pr, tr(u[1])]
		var b := _button(grid, txt, "_buy", [id])
		b.add_font_override("font", fsm)
		b.rect_min_size = Vector2(258, 34)
		b.clip_text = true
		var ip: String = "res://assets/ui/up_%s.png" % id
		if ResourceLoader.exists(ip):
			b.icon = load(ip)
		b.disabled = pr < 0 or Game.bank < pr or why != ""
		b.align = Button.ALIGN_LEFT
	_shop_bottom()


func _shop_bottom() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGN_CENTER
	shop_box.add_child(row)
	_button(row, tr("Закрыть ноутбук"), "_close_laptop")
	_button(row, tr("Сохранить и в меню"), "_to_menu")


func _shop_tab(t: String) -> void:
	shop_tab = t
	_refresh_shop()


func _refresh_decor_shop() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	shop_box.add_child(grid)
	var fsm: DynamicFont = font_big.duplicate()
	fsm.size = 10
	for id in Career.DECOR_ORDER:
		var d: Array = Career.DECOR[id]
		var cost: String = (tr("%d мон.") % d[2]) if d[2] > 0 else (tr("%d жет.") % d[3])
		var txt: String
		var can := true
		if Game.decor.has(id):
			txt = "%s (%s)\n%s" % [tr(d[0]), tr("есть"), tr(d[1])]
			can = false
		elif d[4] != "" and not Game.decor.has(d[4]):
			txt = "%s  %s\n(%s)" % [tr(d[0]), cost, tr("сначала проигрыватель")]
			can = false
		else:
			txt = "%s  %s\n%s" % [tr(d[0]), cost, tr(d[1])]
			can = Game.bank >= d[2] and Game.tokens >= d[3]
		var b := _button(grid, txt, "_buy_decor", [id])
		b.add_font_override("font", fsm)
		b.rect_min_size = Vector2(258, 34)
		b.clip_text = true
		b.align = Button.ALIGN_LEFT
		var ip: String = "res://assets/decor/icon_%s.png" % id
		if ResourceLoader.exists(ip):
			b.icon = load(ip)
		b.disabled = not can
	_shop_bottom()


func _buy_decor(id: String) -> void:
	var d: Array = Career.DECOR[id]
	if Game.decor.has(id) or Game.bank < d[2] or Game.tokens < d[3]:
		return
	Game.bank -= d[2]
	Game.tokens -= d[3]
	Game.decor[id] = true
	if Game.decor.size() >= 5:
		Ach.unlock("ACH_DECOR_5")
	if id.begins_with("rec_") or id == "vinyl":
		Game.record = "rec_jazz" if id == "vinyl" else id
	Game.save_game()
	if not id.begins_with("rec_"):
		_deliver_decor(id)
	elif vinyl_disc:
		_play_music()
	Sfx.play("coin", 0.05, 0.0)
	_refresh_shop()


func _buy(id: String) -> void:
	if id in ["window", "shelf", "expand", "freezer", "golem", "helper", "paints"] and Game.price(id) >= 0 and Game.bank >= Game.price(id):
		structural_bought = true
	if Game.buy(id):
		Sfx.play("coin", 0.05, 0.0)
	_refresh_shop()


# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	font_big = DynamicFont.new()
	font_big.font_data = load("res://fonts/DejaVuSans-Bold.ttf")
	font_big.size = 13
	font_big.outline_size = 1
	font_big.outline_color = Color(0, 0, 0)
	font_small = font_big.duplicate()
	font_small.size = 9

	var layer := CanvasLayer.new()
	layer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1
	root.anchor_bottom = 1
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var cross := _label(root, font_big, Vector2(316, 170))
	cross.text = "+"

	var coin := TextureRect.new()
	coin.texture = tex("ui/coin", false)
	coin.rect_position = Vector2(6, 5)
	root.add_child(coin)
	hud_stats = _label(root, font_big, Vector2(26, 6))
	hud_order = _label(root, font_big, Vector2(8, 24))
	hud_order.add_color_override("font_color", Color(1, 0.85, 0.4))

	var fh: DynamicFont = font_big.duplicate()
	fh.size = 11
	hud_hint = _label(root, fh, Vector2(20, 290))
	hud_hint.rect_size = Vector2(600, 44)
	hud_hint.align = Label.ALIGN_CENTER
	hud_hint.valign = Label.VALIGN_BOTTOM
	hud_hint.autowrap = true

	hud_help = _label(root, font_small, Vector2(8, 344))
	hud_help.text = tr("WASD — ходить   мышь — смотреть   ESC — пауза")
	var help := hud_help
	help.modulate = Color(1, 1, 1, 0.6)

	hud_center = _label(root, font_big, Vector2(20, 72))
	hud_center.rect_size = Vector2(600, 60)
	hud_center.align = Label.ALIGN_CENTER
	hud_center.autowrap = true

	hud_power = _label(root, font_big, Vector2(20, 190))
	hud_power.rect_size = Vector2(600, 20)
	hud_power.align = Label.ALIGN_CENTER

	for i in 5:
		var fm: DynamicFont = font_big.duplicate()
		fm.size = 11
		var bl := _label(root, fm, Vector2.ZERO)
		bl.align = Label.ALIGN_CENTER
		bl.valign = Label.VALIGN_BOTTOM
		bl.autowrap = true
		bl.rect_size = Vector2(150, 50)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.03, 0.05, 0.6)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 3
		sb.content_margin_right = 3
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		bl.add_stylebox_override("normal", sb)
		hud_bubbles.append(bl)
		hud_meters.append(_patience_meter(root))

	hud_event = _label(root, font_big, Vector2(400, 6))
	hud_event.rect_size = Vector2(232, 20)
	hud_event.align = Label.ALIGN_RIGHT
	hud_event.add_color_override("font_color", Color(1, 0.5, 0.4))

	var ft: DynamicFont = font_big.duplicate()
	ft.size = 9
	hud_tasks = _label(root, ft, Vector2(332, 24))
	hud_tasks.align = Label.ALIGN_RIGHT
	hud_tasks.add_color_override("font_color", Color(1, 0.95, 0.75))

	hud_tut = _label(root, font_big, Vector2(20, 220))
	hud_tut.rect_size = Vector2(600, 60)
	hud_tut.autowrap = true
	hud_tut.align = Label.ALIGN_CENTER
	hud_tut.add_color_override("font_color", Color(0.75, 1, 0.8))
	for l in [hud_tut, hud_center, hud_hint]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.03, 0.05, 0.62)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		l.add_stylebox_override("normal", sb)

	hud_panel = PanelContainer.new()
	hud_panel.rect_position = Vector2(20, 12)
	hud_panel.rect_min_size = Vector2(600, 270)
	hud_panel.visible = false
	root.add_child(hud_panel)
	var ph := HBoxContainer.new()
	ph.add_constant_override("separation", 10)
	hud_panel.add_child(ph)
	var fpanel: DynamicFont = font_big.duplicate()
	fpanel.outline_size = 0
	hud_panel_text = Label.new()
	hud_panel_text.add_font_override("font", fpanel)
	hud_panel_text.align = Label.ALIGN_CENTER
	hud_panel_text.valign = Label.VALIGN_CENTER
	hud_panel_text.rect_min_size = Vector2(230, 0)
	ph.add_child(hud_panel_text)
	var fs: DynamicFont = font_big.duplicate()
	fs.size = 12
	fs.outline_size = 0
	fs.use_filter = true  # на части видеокарт мелкий шрифт при нецелом масштабе терял верхние палочки (Т, Г, п)
	hud_panel_side = Label.new()
	hud_panel_side.add_font_override("font", fs)
	hud_panel_side.autowrap = true
	hud_panel_side.valign = Label.VALIGN_TOP
	hud_panel_side.rect_min_size = Vector2(350, 0)
	hud_panel_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(hud_panel_side)

	end_buttons = HBoxContainer.new()
	end_buttons.rect_position = Vector2(150, 296)
	end_buttons.rect_min_size = Vector2(340, 30)
	end_buttons.alignment = BoxContainer.ALIGN_CENTER
	end_buttons.visible = false
	root.add_child(end_buttons)
	_button(end_buttons, tr("Закрыть пункт [N]"), "_open_shop")
	_button(end_buttons, tr("Переиграть [R]"), "_retry")

	shop_panel = PanelContainer.new()
	shop_panel.rect_position = Vector2(48, 14)
	shop_panel.rect_min_size = Vector2(544, 330)
	shop_panel.visible = false
	root.add_child(shop_panel)
	shop_box = VBoxContainer.new()
	shop_panel.add_child(shop_box)

	pause_panel = PanelContainer.new()
	pause_panel.rect_position = Vector2(220, 110)
	pause_panel.rect_min_size = Vector2(200, 140)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var pv := VBoxContainer.new()
	pause_panel.add_child(pv)
	var pl := Label.new()
	pl.add_font_override("font", font_big)
	pl.align = Label.ALIGN_CENTER
	pl.text = tr("ПАУЗА")
	UiTheme.banner(pl)
	pv.add_child(pl)
	_button(pv, tr("Продолжить"), "_set_paused", [false])
	_button(pv, tr("Настройки"), "_open_settings")
	_button(pv, tr("Выйти в меню"), "_to_menu")
	_button(pv, tr("Выйти из игры"), "_quit")
	var th := UiTheme.make()
	for c in [pause_panel, shop_panel, hud_panel, end_buttons]:
		c.theme = th


func _label(parent: Control, f: Font, pos: Vector2) -> Label:
	var l := Label.new()
	l.rect_position = pos
	l.add_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _on_look_changed(t: String) -> void:
	hud_hint.text = Pad.prompt(t)


func _process(_delta: float) -> void:
	_update_carry()
	_update_tips(_delta)
	_update_decor(_delta)
	_update_tutorial()
	_update_tut_arrow()
	_update_maga(_delta)
	if Pad.active != _pad_was:
		_pad_was = Pad.active
		hud_help.text = Pad.prompt(tr("WASD — ходить   мышь — смотреть   ESC — пауза"))
	# подложки под текстом: только когда текст есть, высота по тексту
	for l in [hud_tut, hud_center, hud_hint]:
		l.visible = l.text != ""
		l.rect_size = Vector2(l.rect_size.x, 0)
	hud_hint.rect_position.y = 336 - hud_hint.rect_size.y
	# Шкала силы броска
	if player and player.charging:
		var n := int(round(player.charge * 10.0))
		var bar := ""
		for i in 10:
			bar += "▮" if i < n else "▯"
		hud_power.text = tr("СИЛА ") + bar
		hud_power.add_color_override("font_color", Color(1, 1, 0.4).linear_interpolate(Color(1, 0.3, 0.2), player.charge))
	else:
		hud_power.text = ""
	# Реплики клиентов над головами
	var i := 0
	var talkers := customers.duplicate()
	for n in [golem, helper]:
		if n and n.bubble_text != "":
			talkers.append(n)
	if not hide_nicks:
		for av in avatars.values():
			talkers.append(av)
	for c in talkers:
		if i >= hud_bubbles.size():
			break
		if not is_instance_valid(c) or player == null:
			continue
		var bl: Label = hud_bubbles[i]
		var head: Vector3 = c.global_transform.origin + Vector3(0, c.base_y * 2.0 + 0.45, 0)
		if player.cam.is_position_behind(head):
			continue
		bl.visible = true
		bl.text = c.bubble_text
		bl.add_color_override("font_color", c.bubble_color)
		bl.rect_size = Vector2(150, 0)
		var sp: Vector2 = player.cam.unproject_position(head)
		var pk: float = c.get("pat_k") if c.get("pat_k") != null else -1.0
		var mt: Control = hud_meters[i]
		mt.visible = pk >= 0.0
		if mt.visible:
			_set_meter(mt, pk)
			mt.rect_position = (sp - Vector2(mt.rect_size.x / 2.0, mt.rect_size.y)).round()
			sp.y -= mt.rect_size.y + 1
		bl.rect_position = (sp - Vector2(75, bl.rect_size.y)).round()
		i += 1
	for j in range(i, hud_bubbles.size()):
		hud_bubbles[j].visible = false
		hud_meters[j].visible = false


# шкала терпения клиента: деревянная рамка (лист 69), заливка цветом настроения и рожица слева
const PAT_COLORS := [Color(0.2, 0.85, 0.15), Color(1.0, 0.75, 0.05), Color(1.0, 0.45, 0.05), Color(0.95, 0.1, 0.1)]


func _patience_meter(root: Control) -> Control:
	var m := Control.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.rect_size = Vector2(90, 16)
	var has_art := ResourceLoader.exists("res://assets/ui/pat_frame.png")
	var fill := ColorRect.new()
	fill.name = "fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(fill)
	if has_art:
		var fr := TextureRect.new()
		fr.texture = load("res://assets/ui/pat_frame.png")
		fr.rect_position = Vector2(18, 3)
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(fr)
		m.move_child(fill, m.get_child_count() - 1)  # заливка поверх тёмного паза рамки
		var face := TextureRect.new()
		face.name = "face"
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(face)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.6)
		bg.rect_position = Vector2(24, 6)
		bg.rect_size = Vector2(60, 6)
		m.add_child(bg)
		m.move_child(bg, 0)
	m.visible = false
	root.add_child(m)
	return m


func _set_meter(m: Control, k: float) -> void:
	k = clamp(k, 0.0, 1.0)
	var mood := 0 if k > 0.7 else (1 if k > 0.45 else (2 if k > 0.2 else 3))
	var fill: ColorRect = m.get_node("fill")
	fill.color = PAT_COLORS[mood]
	# пустой паз рамки: x 7..64, y 3..7 в картинке рамки, рамка сдвинута на (18, 3)
	fill.rect_position = Vector2(18 + 7, 3 + 3)
	fill.rect_size = Vector2(round(58.0 * k), 5)
	if m.has_node("face"):
		var face: TextureRect = m.get_node("face")
		var p := "res://assets/ui/pat_face_%d.png" % mood
		if face.texture == null or face.texture.resource_path != p:
			face.texture = load(p)
		face.rect_position = Vector2(16 - face.texture.get_width(), 0)


func _refresh_hud() -> void:
	if not is_open and Game.phase == "closed":
		hud_stats.text = tr("%d    Смена %d    Реп. %d    ПУНКТ ЗАКРЫТ") % [Game.bank, Game.day, Game.rep]
	elif Game.mode == "chaos":
		hud_stats.text = tr("%d    ХАОС    Выдано: %d    Клиент %d/%d") % [money, served, spawned, total_customers]
	else:
		hud_stats.text = tr("%d    Смена %d    Реп. %d    Выдано: %d    Клиент %d/%d") % [Game.bank + money, Game.day, Game.rep, served, spawned, total_customers]
		if hardcore_on():
			var marks := ""
			for k in 3:
				marks += "✖" if k < failed else "○"
			hud_stats.text += "    " + tr("ХАРДКОР") + " " + marks
	if hud_tasks:
		_refresh_tasks()
	# номер заказа видно, только когда клиент подошёл и назвал его
	var lines := []
	for c in waiting():
		var who: String = _who(c)
		lines.append("%s — %s" % [who, disp(c.order)])
	hud_order.text = (tr("Ждут: ") + PoolStringArray(lines).join(", ")) if not lines.empty() else ""


func _flash(t: String, dur: float) -> void:
	_flash_id += 1
	var id := _flash_id
	hud_center.text = Pad.prompt(t)
	yield(get_tree().create_timer(dur), "timeout")
	if id == _flash_id:
		hud_center.text = ""


func _begin_shift() -> void:
	# пункт открыт: пошли клиенты и поставки
	Game.phase = "open"
	is_open = true
	if Game.mode == "career":
		if Game.district_idx() >= 1:
			Ach.unlock("ACH_DISTRICT_2")
		if Game.district_idx() >= 5:
			Ach.unlock("ACH_DISTRICT_6")
	if not Game.tutorial_done and Game.mode == "career":
		tut_step = 0
	if helper:
		_tip_later("helper", 12.0)
	if Game.day >= 2 and Game.mode == "career":
		_tip_later("rep", 14.0)
		_tip_later("complaints", 40.0)
	_refresh_hud()
	var hint := tr("Номер на коробке = номер заказа.")
	if Game.max_at_once() > 1:
		hint = tr("Теперь до %d клиентов сразу!") % Game.max_at_once()
	if Game.event != "":
		hint = tr(EVENTS[Game.event])
		hud_event.text = {"blackout": tr("Событие: темнота"), "rush": tr("Событие: чёрная пятница"), "inspector": tr("Событие: инспектор")}[Game.event]
		var ep := "res://assets/ui/ev_%s.png" % Game.event
		if ResourceLoader.exists(ep):
			var ei := TextureRect.new()
			ei.texture = load(ep)
			ei.rect_position = Vector2(604, 24)
			hud_event.get_parent().add_child(ei)
	if Game.mode == "career" and Game.day > 1 and (Game.day - 1) % 5 == 0:
		hint = tr("Новый район!") + " " + tr(Game.district()["name"])
		_tip_later("district", 6.0)
	if Game.is_boss_day():
		hint = tr("ПОСЛЕДНЯЯ СМЕНА. Сегодня придёт сам Тёмный Почтмейстер...")
	if Game.mode == "chaos":
		_flash(tr("РЕЖИМ ХАОСА!\n24 клиента, посылки буянят. Заработай как можно больше!"), 5.0)
	else:
		_flash(tr("СМЕНА %d — %s\n%s") % [Game.day, tr(Game.district()["name"]), hint], 5.0)
	if Game.mode == "career" and Game.tutorial_done and not Game.tasks.empty():
		_tip_later("tasks", 7.0)
	if not net_client():
		_spawn_customer_later(2.5)
		_portal_wave_later(6.0, int(ceil(incoming.size() / 2.0)))


# ---------------------------------------------------------------- пункт закрыт: между сменами
func _build_closed_props() -> void:
	if Game.mode == "chaos":
		return
	# табличка на окне выдачи, висит с нашей стороны
	sign_spr = prop("sign_closed", Vector3(-1.4, 1.75, -0.3), PI, 0.6)
	# держатель: брус под потолком, латунные крюки и цепи до самой таблички
	var beam_m: Material = mat("env_wood", 0.8, Color(0.45, 0.3, 0.2))
	deco(Vector3(0.9, 0.1, 0.12), Vector3(-1.4, 3.15, -0.3), beam_m)
	var brass := unshaded(Color(0.75, 0.58, 0.25))
	var chain := unshaded(Color(0.22, 0.2, 0.18))
	for cx in [-1.22, -1.59]:
		deco(Vector3(0.06, 0.06, 0.06), Vector3(cx, 3.08, -0.3), brass)
		deco(Vector3(0.035, 0.76, 0.035), Vector3(cx, 2.7, -0.3), chain)
	for bx in [-1.78, -1.02]:
		deco(Vector3(0.05, 0.05, 0.14), Vector3(bx, 3.15, -0.3), brass)
	sign_spr.shaded = false
	_clickable(sign_spr, Vector3(0.36, 0.3, 0.05), tr("[ЛКМ/E] Табличка: перевернуть на «ОТКРЫТО» и начать смену"), "_flip_sign")
	# ноутбук-магазин на столике у левой стены
	var wood: Material = mat("env_wood", 0.8, Color(0.42, 0.3, 0.22))
	solid(Vector3(0.8, 0.8, 0.7), Vector3(-6.45, 0.4, -1.45), wood)
	var lt := prop("laptop", Vector3(-6.4, 0.8, -1.45), PI / 2, 0.6)
	lt.shaded = false
	_clickable(lt, Vector3(0.36, 0.3, 0.3), tr("[ЛКМ/E] Ноутбук: магазин улучшений и декора"), "_open_laptop")
	# раскладушка между стеллажами
	var cot := prop("cot", Vector3(0.75, 0.0, -5.05), 0, 1.1)
	solid(Vector3(1.85, 0.62, 0.68), Vector3(0.75, 0.31, -5.05), null)
	_clickable(cot, Vector3(0.98, 0.52, 0.4), tr("[ЛКМ/E] Раскладушка: сохраниться и выйти в меню"), "_sleep")
	# доска объявлений над ларём
	var bd := prop("board", Vector3(6.88, 1.45, -3.2), -PI / 2, 0.75)
	_clickable(bd, Vector3(0.5, 0.36, 0.05), tr("[ЛКМ/E] Доска объявлений: задания, отзывы, район"), "_read_board")
	# звонок на стойке: позвать следующего клиента
	var bl := prop("desk_bell", Vector3(1.6, 0.98, -0.25), 0, 0.14, true)
	_clickable(bl, Vector3(0.1, 0.08, 0.1), tr("[ЛКМ/E] Звонок: позвать следующего клиента"), "_ring_desk")


func _enter_closed() -> void:
	is_open = false
	if Game.mode == "career" and not Net.active:
		if not Game.tutorial_done:
			tut_step = 10
		elif not "tip_closed2" in Game.seen_kinds:
			Game.seen_kinds.append("tip_closed2")
			tut_step = 11
		if tut_step >= 10:
			_tut_arrow_at(sign_spr.translation + Vector3(0, 0.6, -0.15))
	hud_event.text = tr("ПУНКТ ЗАКРЫТ")
	if story:
		story.call_deferred("on_closed")
	if tut_step >= 10:
		_flash(tr("ПУНКТ ЗАКРЫТ — смена %d, %s") % [Game.day, tr(Game.district()["name"])], 4.0)
	else:
		_flash(tr("ПУНКТ ЗАКРЫТ — смена %d, %s\nРазложи утреннюю поставку, загляни в ноутбук, переставь декор.\nПереверни табличку на окне — и открываемся!") % [Game.day, tr(Game.district()["name"])], 8.0)
	_refresh_hud()


func _flip_sign(_b) -> void:
	if is_open or shift_over:
		_flash(tr("Пункт уже открыт!"), 1.2)
		return
	if carrying:
		return
	sign_spr.texture = tex("props/sign_open", false)
	for ch in sign_spr.get_children():
		if ch is StaticBody:
			ch.set_meta("look", tr("Табличка: пункт ОТКРЫТ"))
	var tw := create_tween()
	tw.tween_property(sign_spr, "rotation:y", PI * 3.0, 0.4)
	Sfx.play("doorbell", 0.0, 0.0)
	hud_event.text = ""
	if tut_step >= 10:
		tut_step = -1
	_tut_arrow_at(null)
	_begin_shift()


func _open_laptop(_b) -> void:
	if is_open:
		_flash(tr("Магазин работает, когда пункт закрыт."), 1.5)
		return
	shop_tab = "up"
	shop_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_shop()


func _close_laptop() -> void:
	shop_panel.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if structural_bought:
		# стены, окна, стеллажи меняются: перестраиваем пункт (остаёмся закрытыми)
		Game.phase = "closed"
		Game.save_game()
		get_tree().reload_current_scene()


func _sleep(_b) -> void:
	if is_open:
		_flash(tr("Спать на работе нельзя! Только когда пункт закрыт."), 1.5)
		return
	Game.save_game()
	_to_menu()


func _read_board(_b) -> void:
	var lines := [tr("ДОСКА ОБЪЯВЛЕНИЙ"), "", tr("Смена %d из %d. Район: %s") % [Game.day, Game.CAREER_DAYS, tr(Game.district()["name"])]]
	if Game.mode == "career" and Game.day < Game.CAREER_DAYS:
		var nd := (Game.district_idx() + 1) * 5 + 1
		if nd <= Game.CAREER_DAYS:
			lines.append(tr("До переезда: %d смен.") % (nd - Game.day))
	lines.append(tr("Репутация: %d   Жетоны: %d") % [Game.rep, Game.tokens])
	if not Game.tasks.empty():
		lines.append("")
		lines.append(tr("ЗАДАНИЯ НА СЕГОДНЯ"))
		for id in Game.tasks:
			if Career.TASKS.has(id):
				lines.append("• " + tr(Career.TASKS[id][0]))
	if not Game.last_reviews.empty():
		lines.append("")
		lines.append(tr("ОТЗЫВЫ ЗА ВЧЕРА"))
		for r in Game.last_reviews:
			lines.append(r)
	lines.append("")
	lines.append(tr("(клик — закрыть)"))
	hud_panel_text.visible = false
	hud_panel_side.text = PoolStringArray(lines).join("\n")
	hud_panel.visible = true
	board_open = true
	ui_block = true


func _ring_desk(b) -> void:
	Sfx.play_at("doorbell", b.global_transform.origin, 0.4, 2.0)
	if not maga_pending:
		# пасхалка: 5 звонков подряд, пока закрыто
		var now := OS.get_ticks_msec()
		bell_rings.append(now)
		while bell_rings.size() > 5:
			bell_rings.pop_front()
		if bell_rings.size() == 5 and now - int(bell_rings[0]) < 3500:
			bell_rings.clear()
			if not is_open and not Net.active and Game.mode == "career":
				_maga_summon()
			else:
				# подсказка, почему не сработало
				Sfx.play("squeak", 0.1, -6.0)
				if Net.active or Game.mode != "career":
					_flash(tr("Пи?.. Мышка выходит только в одиночной карьере."), 3.0)
				else:
					_flash(tr("Пи?.. Мышка прячется, пока пункт открыт. Позвони так, когда закроешь."), 3.0)
	if not is_open or shift_over or net_client():
		return
	if customers.size() < Game.max_at_once() and spawned < total_customers:
		_spawn_customer()


const SURFACE_DECOR := ["vinyl", "trophy", "mouse_queen"]  # ставятся только на стол/стойку, остальное — на пол


func _pick_decor(b) -> void:
	if is_open:
		_flash(tr("Переставлять декор можно, когда пункт закрыт."), 1.5)
		return
	if carrying or player.held:
		return
	var root: Spatial = b.get_parent()
	carrying = root
	carry_shelf = -1
	carry_kind = "surface" if str(root.get_meta("key")) in SURFACE_DECOR else "floor"
	carry_from = root.global_transform.origin
	ui_block = true
	_set_root_layers(root, true)
	_flash(tr("Наведи, куда поставить, и кликни. ПКМ — отмена.") if carry_kind == "floor" else tr("Это ставится на стол или стойку. ПКМ — отмена."), 2.5)


func _pick_shelf(b) -> void:
	if is_open:
		_flash(tr("Двигать стеллажи можно, когда пункт закрыт."), 1.5)
		return
	if carrying or player.held:
		return
	carry_shelf = int(b.get_meta("shelf"))
	var u: Dictionary = shelf_units[carry_shelf]
	carrying = u
	carry_kind = "shelf"
	carry_from = u["c"]
	ui_block = true
	for nd in u["nodes"]:
		if nd is StaticBody:
			nd.set_meta("layer_was", nd.collision_layer)
			nd.collision_layer = 0
	# коробки на полках едут вместе со стеллажом
	carry_parcels = []
	for q in parcels:
		if is_instance_valid(q) and not q.held and not q.delivered:
			var o: Vector3 = q.global_transform.origin - u["c"]
			if abs(o.x) < 2.3 and abs(o.z) < 0.45 and o.y > 0.05 and o.y < 2.4:
				q.mode = RigidBody.MODE_KINEMATIC
				carry_parcels.append(q)
	_flash(tr("Наведи на пол склада и кликни. Нужен проход с обеих сторон. ПКМ — отмена."), 3.0)


func shelf_center(si: int) -> Vector3:
	var c: Vector3 = SHELF_POS[si]
	var sp = Game.shelf_pos.get(str(si))
	if not Net.active and Game.mode == "career" and sp is Array and sp.size() == 2:
		c = Vector3(float(sp[0]), 0, float(sp[1]))
	if not _shelf_clear(c):
		# новый стеллаж встал бы на передвинутый: ищем свободное место на складе
		var zmin := -10.6 if Game.lvl("expand") > 0 else -5.0
		var z := -3.0
		while z >= zmin:
			for x in [-4.0, 4.0, 0.0, -2.0, 2.0]:
				if _shelf_clear(Vector3(x, 0, z)):
					return Vector3(x, 0, z)
			z -= 0.25
	return c


func _shelf_clear(c: Vector3) -> bool:
	for u in shelf_units:
		if abs(u["c"].x - c.x) < 4.5 and abs(u["c"].z - c.z) < 1.9:
			return false
	return true


func _move_shelf(si: int, to: Vector3) -> void:
	var u: Dictionary = shelf_units[si]
	var dl: Vector3 = to - u["c"]
	if dl.length() < 0.001:
		return
	u["c"] = to
	for nd in u["nodes"]:
		if is_instance_valid(nd):
			nd.translation += dl
	for sh in shelves:
		if sh.get("unit", -1) == si:
			sh["pos"] += dl
			var sl: Array = sh["slots"]
			for k in sl.size():
				sl[k] += dl
	for q in carry_parcels:
		if is_instance_valid(q):
			q.global_transform.origin += dl


# можно ли поставить стеллаж: только склад (за стойкой), не в стену и не впритык — с проходом
func _shelf_ok(si: int, c: Vector3) -> bool:
	if c.z > -2.9 or abs(c.x) > 4.4:
		return false
	var space := get_world().direct_space_state
	var q := PhysicsShapeQueryParameters.new()
	var bx := BoxShape.new()
	bx.extents = Vector3(2.25, 1.0, 0.35 + 0.6)
	q.set_shape(bx)
	q.transform = Transform(Basis(), c + Vector3(0, 1.2, 0))
	q.collision_mask = 1
	for r in space.intersect_shape(q, 16):
		var col = r["collider"]
		if col is StaticBody and not (col.has_meta("shelf") and int(col.get_meta("shelf")) == si):
			if "--shelftest" in OS.get_cmdline_args():
				print("shelf blocked by ", col.name, " at ", col.global_transform.origin)
			return false
	var pp: Vector3 = player.global_transform.origin - c
	if abs(pp.x) < 2.6 and abs(pp.z) < 0.75:
		return false  # не накатывать стеллаж на себя
	if mirror:
		var mp: Vector3 = mirror.global_transform.origin
		if abs(c.x - mp.x) < 2.2 + 0.6 and abs(c.z - mp.z) < 0.35 + 0.9:
			return false
	return true


# можно ли поставить декор: цветы — на пол, мелочь — на стол/стойку; не внутрь мебели и не друг в друга
func _decor_ok(hit: Dictionary) -> bool:
	var p: Vector3 = hit["position"]
	var col = hit["collider"]
	if hit["normal"].y < 0.7 or col is RigidBody:
		return false
	if carry_kind == "floor":
		if p.y > 0.1:
			return false
	else:
		if p.y < 0.5 or p.y > 2.0 or col.has_meta("shelf"):
			return false
	for m in movables:
		if m != carrying and is_instance_valid(m) and m.global_transform.origin.distance_to(p) < (0.55 if carry_kind == "floor" else 0.3):
			return false
	var q := PhysicsShapeQueryParameters.new()
	var sp := SphereShape.new()
	sp.radius = 0.25 if carry_kind == "floor" else 0.1
	q.set_shape(sp)
	q.transform = Transform(Basis(), p + Vector3(0, sp.radius + 0.06, 0))
	q.collision_mask = 1
	for r in get_world().direct_space_state.intersect_shape(q, 8):
		if r["collider"] is StaticBody:
			return false
	return true


func _set_root_layers(root: Node, off: bool) -> void:
	for ch in root.get_children():
		if ch is CollisionObject:
			if off:
				ch.set_meta("layer_was", ch.collision_layer)
				ch.collision_layer = 0
			elif ch.has_meta("layer_was"):
				ch.collision_layer = ch.get_meta("layer_was")
		_set_root_layers(ch, off)


func _update_carry() -> void:
	if carrying == null or player == null:
		if carry_marker:
			carry_marker.visible = false
		return
	var from: Vector3 = player.cam.global_transform.origin
	var to: Vector3 = from - player.cam.global_transform.basis.z * 5.0
	var hit := get_world().direct_space_state.intersect_ray(from, to, [player], 1)
	if carry_marker == null:
		carry_marker = MeshInstance.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 0.02
		cyl.radial_segments = 16
		carry_marker.mesh = cyl
		var mm := SpatialMaterial.new()
		mm.flags_unshaded = true
		mm.flags_transparent = true
		carry_marker.material_override = mm
		add_child(carry_marker)
	carry_ok = false
	if not hit:
		carry_marker.visible = false
		return
	var p: Vector3 = hit["position"]
	if carry_kind == "shelf":
		var c := Vector3(stepify(p.x, 0.5), 0, stepify(p.z, 0.25))
		carry_ok = hit["normal"].y > 0.7 and p.y < 0.1 and _shelf_ok(carry_shelf, c)
		if carry_ok:
			_move_shelf(carry_shelf, c)
		carry_marker.scale = Vector3(10.0, 1, 1.6) if carry_ok else Vector3(1, 1, 1)
		carry_marker.global_transform.origin = (c if carry_ok else p) + Vector3(0, 0.02, 0)
	else:
		carry_ok = _decor_ok(hit)
		if carry_ok:
			carrying.global_transform.origin = p
		carry_marker.scale = Vector3(1, 1, 1) if carry_kind == "floor" else Vector3(0.6, 1, 0.6)
		carry_marker.global_transform.origin = p + Vector3(0, 0.015, 0)
	carry_marker.visible = true
	carry_marker.material_override.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if carry_ok else Color(1.0, 0.25, 0.2, 0.55)


func _drop_carry(cancel: bool) -> void:
	if carry_kind == "shelf":
		if cancel:
			_move_shelf(carry_shelf, carry_from)
		var u: Dictionary = shelf_units[carry_shelf]
		for nd in u["nodes"]:
			if nd is StaticBody and nd.has_meta("layer_was"):
				nd.collision_layer = nd.get_meta("layer_was")
		for q in carry_parcels:
			if is_instance_valid(q):
				q.mode = RigidBody.MODE_RIGID
				q.linear_velocity = Vector3.ZERO
				q.sleeping = false
		carry_parcels = []
		var c: Vector3 = u["c"]
		if c.distance_to(SHELF_POS[carry_shelf]) < 0.01:
			Game.shelf_pos.erase(str(carry_shelf))
		else:
			Game.shelf_pos[str(carry_shelf)] = [c.x, c.z]
		carry_shelf = -1
	else:
		if cancel:
			carrying.global_transform.origin = carry_from
		var p: Vector3 = carrying.global_transform.origin
		Game.decor_pos[carrying.get_meta("key")] = [p.x, p.y, p.z]
		_set_root_layers(carrying, false)
	carrying = null
	carry_kind = ""
	ui_block = false
	if carry_marker:
		carry_marker.visible = false
	Sfx.play("thud1", 0.1, -4.0)
	Game.save_game()


func ui_click(_event) -> void:
	if story and story.is_open():
		story.close()
		return
	if board_open:
		board_open = false
		ui_block = carrying != null
		hud_panel.visible = false
		hud_panel_text.visible = true
		return
	if carrying:
		if _event and _event.is_action_pressed("place"):
			_drop_carry(true)  # ПКМ — вернуть на место
		elif carry_ok:
			_drop_carry(false)
		else:
			_flash(tr("Сюда нельзя: красная метка. Найди место, где метка зелёная."), 1.5)


func _deliver_decor(id: String) -> void:
	# купленный декор приезжает коробкой через портал
	var pos := Vector3(-3.9 + deliveries * 0.6, 0, -2.4 + (deliveries % 2) * 0.5)
	deliveries += 1
	Sfx.play_at("portal", PORTAL, 0.0, 4.0)
	portal_open_t = 1.2
	var bx := prop("deliv_box", pos, 0, 0.45, true)
	var b := _clickable(bx, Vector3(0.25, 0.22, 0.25), tr("[ЛКМ/E] Доставка: открыть коробку"), "_open_delivery")
	b.set_meta("decor", id)


func _open_delivery(b) -> void:
	var bx: Sprite3D = b.get_parent()
	var id: String = b.get_meta("decor")
	b.queue_free()
	bx.texture = tex("props/deliv_box_open", false)
	Sfx.play_at("lid", bx.global_transform.origin, 0.1, 2.0)
	var p: Vector3 = bx.global_transform.origin
	p.y = 0
	var key := {"plant": "plant2", "vinyl": "vinyl", "trophy": "trophy"}
	if key.has(id):
		Game.decor_pos[key[id]] = [p.x + 0.6, 0.0, p.z]
		Game.save_game()
	_decor_item(id)
	if id == "cat_hat":
		_flash(tr("Шляпа появится на коте завтра — он пока стесняется."), 2.0)
	else:
		_flash(tr("Распаковано: %s") % tr(Career.DECOR[id][0]), 2.0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(bx, "modulate:a", 0.0, 0.5)
	tw.tween_callback(bx, "queue_free")


# ---------------------------------------------------------------- карьера: задания, подсказки, босс
var tip_text := ""
var tip_t := 0.0
var tip_queue := []
var garland := []
var _garland_t := 0.0


func stat(key: String, n := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
	if hud_tasks:
		_refresh_tasks()


func _tip(id: String) -> void:
	var key := "tip_" + id
	if key in Game.seen_kinds or not Career.TIPS.has(id) or net_client() and false:
		return
	if tut_step >= 0:
		return  # во время обучения не отвлекаем, покажем в другой раз
	Game.seen_kinds.append(key)
	tip_queue.append(tr(Career.TIPS[id]))


func _tip_later(id: String, sec: float) -> void:
	yield(get_tree().create_timer(sec), "timeout")
	_tip(id)


func _update_tips(delta: float) -> void:
	if tip_t > 0.0:
		tip_t -= delta
		if tip_t <= 0.0:
			tip_text = ""
	elif not tip_queue.empty():
		tip_text = tr("ПОДСКАЗКА") + ": " + tip_queue.pop_front()
		tip_t = 7.0
	# подсказки по механикам, когда игрок впервые с ней столкнулся
	if player and player.held:
		var bt: String = player.held.box_type
		if bt in ["mimic", "timer", "chest", "frozen", "living", "cursed", "explosive", "fragile"]:
			_tip(bt)
		if player.held.from_portal and not player.held.sorted:
			_tip("portal")


func _who(c) -> String:
	if c != null and c == boss:
		return tr("Тёмный Почтмейстер")
	return tr(KINDS[c.kind][0])


func disp(code: String) -> String:
	return Game.disp(code)


func _pick_kind() -> String:
	if Game.mode == "career":
		if Game.rep >= 75 and randf() < 0.12:
			return "king"  # слава о пункте дошла до замка
		if Game.rep < 30 and randf() < 0.25:
			return pick(["thief", "werewolf"])  # плохая репутация тянет жуликов
	var fav: Array = Game.district()["kinds"]
	if not fav.empty() and randf() < 0.55:
		return pick(fav)
	# секретный гость приходит только по пасхалке
	var ks: Array = KINDS.keys()
	ks.erase("maga")
	return pick(ks)


func _play_music() -> void:
	if Game.mode == "chaos":
		Sfx.play_music("music_chaos")
	elif Game.decor.has("vinyl") and Game.record != "":
		Sfx.play_music(Game.record)
	else:
		Sfx.play_music(Game.district()["music"])


func _boss_next(c) -> void:
	# Почтмейстер заказывает следующую посылку
	var ordered := []
	for w in customers:
		ordered.append(w.order)
	var avail := []
	for p in parcels:
		if is_instance_valid(p) and not p.delivered and not p.stolen and not p.code in ordered:
			avail.append(p)
	if avail.empty():
		boss_left = 0
		c.leave_with(tr("Хм. Посылок больше нет? Ладно... ты победил."), true)
		return
	var p = pick(avail)
	_drop_receipt(c)
	c.order = p.code
	c.receipt_code = p.code
	c.patience = c.max_patience
	var lines := [tr("Неплохо. Теперь %s. Живо!"), tr("Ещё одну: %s. Последнюю!")]
	c.line = tr(lines[int(clamp(2 - boss_left, 0, 1))]) % disp(p.code)
	c._say(c.line, Color(0.85, 0.6, 1.0), 4.0)
	_make_receipt(c)
	if Game.lvl("sorter") > 0:
		p.set_highlight(true)
	_flash(tr("Почтмейстер: осталось посылок %d") % boss_left, 2.0)


func _chaos_brawl() -> void:
	# посылки дерутся: две коробки прыгают друг на друга
	var cand := []
	for p in parcels:
		if is_instance_valid(p) and not p.held and not p.delivered and not p.in_safe and p.mode == RigidBody.MODE_RIGID:
			cand.append(p)
	if cand.size() < 2:
		return
	cand.shuffle()
	var a = cand[0]
	var b = cand[1]
	for pair in [[a, b], [b, a]]:
		var d: Vector3 = pair[1].global_transform.origin - pair[0].global_transform.origin
		d.y = 0
		var dir: Vector3 = d.normalized() if d.length() > 0.01 else Vector3.RIGHT
		pair[0].sleeping = false
		pair[0].apply_central_impulse((dir * min(1.5, d.length()) + Vector3.UP * 2.2) * pair[0].mass * 0.5)
		Sfx.play_at("boing", pair[0].global_transform.origin, 0.2, -3.0)
	if randf() < 0.3:
		_flash(pick([tr("Посылки дерутся!"), tr("Коробки устроили бунт!"), tr("Хаос на складе!")]), 1.2)


func _refresh_tasks() -> void:
	if Game.mode != "career" or Game.tasks.empty():
		hud_tasks.text = ""
		return
	var lines := [tr("Задания дня:")]
	for id in Game.tasks:
		if Career.TASKS.has(id):
			lines.append(Career.task_text(id, stats, served, Career.task_done(id, stats, served)))
	hud_tasks.text = PoolStringArray(lines).join("\n")
	hud_tasks.rect_size = Vector2.ZERO
	hud_tasks.rect_position.x = 634 - hud_tasks.get_combined_minimum_size().x


# ---------------------------------------------------------------- сейф и клетка
func _build_safe() -> void:
	if not (Game.day >= 4 or Game.mode == "chaos"):
		return
	var sf := Spatial.new()
	sf.translation = SAFE
	sf.rotation.y = -PI / 2  # дверцей в комнату
	add_child(sf)
	var metal: Material = mat("env_metal", 1.0, Color(0.6, 0.6, 0.65))
	var W := 0.7
	var H := 0.8
	var D := 0.6
	_quad(sf, Vector2(W, H), Vector3(0, H / 2, -D / 2), Vector3(0, PI, 0), metal)
	_quad(sf, Vector2(D, H), Vector3(W / 2, H / 2, 0), Vector3(0, PI / 2, 0), metal)
	_quad(sf, Vector2(D, H), Vector3(-W / 2, H / 2, 0), Vector3(0, -PI / 2, 0), metal)
	_quad(sf, Vector2(W, D), Vector3(0, H, 0), Vector3(-PI / 2, 0, 0), metal)
	_box_body(sf, Vector3(W, H, D), Vector3(0, H / 2, 0))
	# дверца на петле слева
	safe_door = Spatial.new()
	safe_door.translation = Vector3(-W / 2, 0, D / 2 + 0.005)
	sf.add_child(safe_door)
	_quad(safe_door, Vector2(W, H), Vector3(W / 2, H / 2, 0), Vector3.ZERO, _tex_mat("env_safe"))
	safe_digits = []
	for k in 3:
		var dg := Sprite3D.new()
		dg.texture = tex("ui/dig_0", false)
		dg.pixel_size = 0.1 / 48.0
		dg.shaded = false
		dg.translation = Vector3(W / 2 - 0.13 + k * 0.13, H - 0.08, 0.01)
		safe_door.add_child(dg)
		var b := _clickable(dg, Vector3(0.06, 0.06, 0.03), "", "_safe_dial")
		b.set_meta("idx", k)
		safe_digits.append(dg)
	_update_safe_looks()


func _update_safe_looks() -> void:
	var code := "%d-%d-%d" % safe_code
	for k in safe_digits.size():
		var dg: Sprite3D = safe_digits[k]
		dg.texture = tex("ui/dig_%d" % safe_code[k], false)
		for ch in dg.get_children():
			if ch is StaticBody:
				ch.set_meta("look", tr("[ЛКМ/E] Сейф: крутить колёсико. Набрано %s. Код — на чеке клиента") % code)


func _safe_dial(b) -> void:
	var k: int = b.get_meta("idx")
	safe_code[k] = (safe_code[k] + 1) % 10
	Sfx.play_at("tick", b.global_transform.origin, 0.1, 0.0)
	_update_safe_looks()
	hud_hint.text = b.get_meta("look")
	var code := "%d%d%d" % safe_code
	for c in waiting():
		if c.safe_pin == "" or c.safe_pin != code:
			continue
		for p in parcels:
			if is_instance_valid(p) and p.in_safe and p.code == c.order:
				_safe_open(p)
				return


func _safe_open(p) -> void:
	Ach.unlock("ACH_SAFE")
	Sfx.play_at("lid", SAFE, 0.1, 2.0)
	_flash(tr("Сейф открыт! Ценная посылка %s выпала") % disp(p.code), 2.0)
	p.in_safe = false
	p.visible = true
	p.collision_layer = 8
	p.global_transform.origin = SAFE + Vector3(-0.7, 0.9, 0)
	p.mode = RigidBody.MODE_RIGID
	p.sleeping = false
	p.apply_central_impulse(Vector3(-1.0, 1.0, 0) * p.mass * 0.4)
	var tw := create_tween()
	tw.tween_property(safe_door, "rotation:y", -1.7, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(safe_door, "rotation:y", 0.0, 0.4)


func _lock_in_safe(p) -> void:
	p.valuable = true
	p.in_safe = true
	p.visible = false
	p.collision_layer = 0
	p.mode = RigidBody.MODE_STATIC
	p.global_transform.origin = SAFE + Vector3(0, 0.4, 0)
	var pin := ""
	for k in 3:
		pin += str(randi() % 10)
	p.set_meta("pin", pin)


func _build_cage() -> void:
	if Game.day < 2 and Game.mode != "chaos":
		return
	var cg := Spatial.new()
	cg.translation = CAGE
	add_child(cg)
	var m := SpatialMaterial.new()
	m.albedo_texture = tex("env_cage_a", false)
	m.flags_transparent = false
	m.params_use_alpha_scissor = true
	m.params_alpha_scissor_threshold = 0.5
	var S := 0.74
	var H := 0.42
	for r in 4:
		var ang: float = r * PI / 2
		var off := Vector3(sin(ang), 0, cos(ang)) * S / 2
		_quad(cg, Vector2(S, H), off + Vector3(0, H / 2, 0), Vector3(0, ang, 0), m.duplicate())
		var wb := StaticBody.new()
		wb.collision_layer = 1
		wb.collision_mask = 0
		var cs := CollisionShape.new()
		var sh := BoxShape.new()
		sh.extents = Vector3(S / 2, H / 2, 0.03)
		cs.shape = sh
		wb.add_child(cs)
		wb.translation = off + Vector3(0, H / 2, 0)
		wb.rotation.y = ang
		cg.add_child(wb)
	cage_area = Area.new()
	cage_area.collision_layer = 0
	cage_area.collision_mask = 8
	var acs := CollisionShape.new()
	var ash := BoxShape.new()
	ash.extents = Vector3(S / 2 - 0.05, 0.5, S / 2 - 0.05)
	acs.shape = ash
	cage_area.add_child(acs)
	cage_area.translation = Vector3(0, 0.5, 0)
	cg.add_child(cage_area)
	# сверху ничего нет: коробки свободно кладутся и достаются


# ---------------------------------------------------------------- декор пункта
func _build_decor() -> void:
	for id in Career.DECOR_ORDER:
		if Game.decor.has(id):
			_decor_item(id)
	if Game.decor.has("mouse_queen") and ResourceLoader.exists("res://assets/props/mouse_plush.png"):
		_decor_item("mouse_queen")


# переставляемый декор: корень, который можно взять в режиме «закрыто»
func _movable(key: String, def: Vector3) -> Spatial:
	var root := Spatial.new()
	root.name = "decor_" + key
	var sp = Game.decor_pos.get(key)
	root.translation = Vector3(sp[0], sp[1], sp[2]) if sp is Array and sp.size() == 3 else def
	root.set_meta("key", key)
	add_child(root)
	movables.append(root)
	return root


func _adopt(root: Spatial, n: Spatial) -> Spatial:
	# деталь, созданная в мировых координатах, переезжает в корень
	var gp: Vector3 = n.translation
	remove_child(n)
	root.add_child(n)
	n.translation = gp
	return n


func _move_handle(root: Spatial, ext: Vector3, y: float) -> void:
	var b := _clickable(root, ext, tr("[ЛКМ/E] Переставить (пока пункт закрыт)"), "_pick_decor")
	b.translation = Vector3(0, y, 0)


func _decor_item(id: String) -> void:
	match id:
		"plant":
			var big := "plant_big" if ResourceLoader.exists("res://assets/props/plant_big.png") else "plant"
			var trap := "plant_flytrap" if ResourceLoader.exists("res://assets/props/plant_flytrap.png") else "plant"
			var spots := [["plant1", big, Vector3(-6.3, 0, 0.9), 1.1], ["plant2", trap, Vector3(-2.6, 0, -0.75), 0.8],
				["plant3", big, Vector3(-2.0, 0, 4.4), 1.0]]
			for sp in spots:
				var r := _movable(sp[0], sp[2])
				var s := prop(sp[1], Vector3.ZERO, 0, sp[3], true)
				_adopt(r, s)
				_move_handle(r, Vector3(0.25, sp[3] / 2.0, 0.25), sp[3] / 2.0)
		"rug":
			var rm := SpatialMaterial.new()
			rm.albedo_texture = tex("decor/rug", false)
			_quad(self, Vector2(6.0, 1.7), Vector3(0, 0.012, 2.1), Vector3(-PI / 2, 0, 0), rm)
		"garland":
			var cols := [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.3, 1, 0.4), Color(0.4, 0.6, 1)]
			var k := 0
			var x := -6.6
			while x <= 6.6:
				var y: float = 3.08 - abs(sin(x * 1.3)) * 0.12
				var g := deco(Vector3(0.07, 0.07, 0.07), Vector3(x, y, 0.55), unshaded(cols[k % 4]))
				garland.append([g, k])
				k += 1
				x += 0.42
		"vinyl":
			var r := _movable("vinyl", Vector3(-6.5, 0, -0.68))
			var wood: Material = mat("env_wood", 0.8, Color(0.45, 0.3, 0.22))
			_adopt(r, solid(Vector3(0.5, 0.7, 0.5), Vector3(0, 0.35, 0), wood))
			_adopt(r, deco(Vector3(0.44, 0.08, 0.38), Vector3(0, 0.74, 0), unshaded(Color(0.25, 0.14, 0.1))))
			vinyl_disc = Spatial.new()
			vinyl_disc.translation = Vector3(-0.02, 0.79, -0.02)
			r.add_child(vinyl_disc)
			var dm := MeshInstance.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.15
			cm.bottom_radius = 0.15
			cm.height = 0.012
			cm.radial_segments = 16
			dm.mesh = cm
			dm.material_override = unshaded(Color(0.06, 0.06, 0.07))
			vinyl_disc.add_child(dm)
			var lab := MeshInstance.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.05
			lm.bottom_radius = 0.05
			lm.height = 0.016
			lm.radial_segments = 10
			lab.mesh = lm
			lab.material_override = unshaded(Color(0.85, 0.2, 0.2))
			vinyl_disc.add_child(lab)
			var mark := deco(Vector3(0.02, 0.018, 0.08), Vector3.ZERO, unshaded(Color(0.9, 0.85, 0.7)))
			remove_child(mark)
			vinyl_disc.add_child(mark)
			mark.translation = Vector3(0, 0.0, 0.09)
			_adopt(r, deco(Vector3(0.02, 0.02, 0.24), Vector3(0.16, 0.82, -0.04), unshaded(Color(0.75, 0.75, 0.8))))
			var body := _clickable(vinyl_disc, Vector3(0.22, 0.04, 0.2), "", "_vinyl_click")
			body.translation = Vector3(0, 0.03, 0)
			_vinyl_look(body)
			_move_handle(r, Vector3(0.26, 0.3, 0.26), 0.35)
		"cat_hat":
			if not ResourceLoader.exists("res://assets/props/cat_hat.png"):
				var hat := MeshInstance.new()
				var cm2 := CylinderMesh.new()
				cm2.top_radius = 0.0
				cm2.bottom_radius = 0.09
				cm2.height = 0.24
				cm2.radial_segments = 8
				hat.mesh = cm2
				hat.material_override = unshaded(Color(0.35, 0.2, 0.7))
				hat.translation = Vector3(4.8, 1.5, -0.1)
				hat.rotation.z = 0.2
				add_child(hat)
		"neon":
			var ns := Sprite3D.new()
			ns.texture = tex("decor/neon_en" if Settings.latin() else "decor/neon", false)
			ns.pixel_size = 2.6 / ns.texture.get_width()
			ns.shaded = false
			ns.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			ns.translation = Vector3(0.6, 2.55, 4.86)
			ns.rotation.y = PI
			add_child(ns)
			var nl := OmniLight.new()
			nl.light_color = Color(1, 0.4, 0.8)
			nl.light_energy = 0.7
			nl.omni_range = 3.0
			nl.translation = Vector3(0.6, 2.5, 4.3)
			add_child(nl)
		"gold":
			var gm := SpatialMaterial.new()
			gm.albedo_color = Color(0.95, 0.75, 0.25)
			gm.metallic = 0.8
			gm.roughness = 0.3
			gm.emission_enabled = true
			gm.emission = Color(0.4, 0.28, 0.05)
			deco(Vector3(14, 0.02, 0.92), Vector3(0, 1.005, 0), gm)
			deco(Vector3(14, 0.08, 0.02), Vector3(0, 0.9, 0.41), gm)
		"mouse_queen":
			var r := _movable("mouse_queen", Vector3(-4.6, 0.98, 0.05))
			_adopt(r, prop("mouse_plush", Vector3.ZERO, 0, 0.4, true))
			_move_handle(r, Vector3(0.16, 0.2, 0.16), 0.2)
		"trophy":
			var r := _movable("trophy", Vector3(6.4, 0.98, 0.05))
			if ResourceLoader.exists("res://assets/props/trophy.png"):
				_adopt(r, prop("trophy", Vector3.ZERO, 0, 0.42, true))
			else:
				var tm := unshaded(Color(1, 0.8, 0.3))
				_adopt(r, deco(Vector3(0.14, 0.05, 0.14), Vector3(0, 0.05, 0), unshaded(Color(0.2, 0.12, 0.08))))
				_adopt(r, deco(Vector3(0.12, 0.25, 0.12), Vector3(0, 0.2, 0), tm))
			_move_handle(r, Vector3(0.14, 0.21, 0.14), 0.21)


func _records() -> Array:
	var out := [Career.RECORDS[0], Career.RECORDS[1]]
	for r in Career.RECORDS.slice(2, Career.RECORDS.size() - 1):
		if Game.decor.has(r[0]):
			out.append(r)
	return out


func _vinyl_look(body) -> void:
	var cur := ""
	for r in _records():
		if r[0] == Game.record:
			cur = tr(r[1])
	body.set_meta("look", tr("[ЛКМ/E] Проигрыватель: сменить пластинку. Играет: %s") % cur)


func _vinyl_click(b) -> void:
	var recs := _records()
	var idx := 0
	for i in recs.size():
		if recs[i][0] == Game.record:
			idx = i
	Game.record = recs[(idx + 1) % recs.size()][0]
	Game.save_game()
	_play_music()
	Sfx.play_at("tick", b.global_transform.origin, 0.1, 0.0)
	_vinyl_look(b)
	hud_hint.text = b.get_meta("look")


func _update_decor(delta: float) -> void:
	if vinyl_disc:
		vinyl_disc.rotation.y += delta * (3.5 if Game.record != "" else 1.5)
	if not garland.empty():
		_garland_t += delta
		if _garland_t > 0.5:
			_garland_t = 0.0
			var cols := [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.3, 1, 0.4), Color(0.4, 0.6, 1)]
			for g in garland:
				g[1] += 1
				g[0].material_override.albedo_color = cols[g[1] % 4]


# ---------------------------------------------------------------- screenshots (dev only)
func _screenshot_mode() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(5.0), "timeout")
	# 1: вид на стойку и клиента
	player.global_transform.origin = Vector3(0.5, 0.05, -1.4)
	player.rotation.y = PI
	player.cam.rotation.x = -0.05
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/g3_shot1_counter.png")
	# 2: склад, игрок держит коробку
	player.global_transform.origin = Vector3(0, 0.05, -2.2)
	player.rotation.y = 0
	player.cam.rotation.x = -0.15
	var p = parcels[1]
	player.grab(p)
	yield(get_tree().create_timer(0.6), "timeout")
	_save(dir + "/g3_shot2_warehouse.png")
	# 3: неправильная посылка, потом правильная
	player.release(false)
	var right = null
	for q in parcels:
		if is_instance_valid(q) and q.code == customers[0].order:
			right = q
	var cx: float = customers[0].global_transform.origin.x
	player.global_transform.origin = Vector3(cx, 0.05, -1.3)
	player.rotation.y = PI
	player.cam.rotation.x = -0.1
	p.global_transform.origin = Vector3(cx - 0.6, 1.4, 0)
	yield(get_tree().create_timer(1.0), "timeout")
	_save(dir + "/g3_shot3_wrong.png")
	right.global_transform.origin = Vector3(cx + 0.3, 1.4, 0)
	right.linear_velocity = Vector3.ZERO
	right.sleeping = false
	yield(get_tree().create_timer(0.8), "timeout")
	_save(dir + "/g3_shot4_right.png")
	print("served=", served, " money=", money)
	get_tree().quit()


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(path)
	print("saved ", path)


func _test2() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(5.5), "timeout")
	var cx: float = customers[0].global_transform.origin.x
	player.global_transform.origin = Vector3(cx, 0.05, -1.3)
	player.rotation.y = PI
	player.cam.rotation.x = -0.05
	var wrong = null
	var right = null
	for q in parcels:
		if q.code == customers[0].order:
			right = q
		elif wrong == null and not q.cursed:
			wrong = q
	# 1) неправильная коробка в зале -> должна вернуться на стойку
	wrong.global_transform.origin = Vector3(cx + 1.0, 0.4, 2.5)
	wrong.sleeping = false
	yield(get_tree().create_timer(2.5), "timeout")
	print("wrong box after hall: ", wrong.global_transform.origin)
	_save(dir + "/t2_tossback.png")
	# 2) бросок в лицо
	var head: Vector3 = customers[0].global_transform.origin + Vector3(0, 1.6, 0)
	var start := Vector3(cx, 1.6, -0.9)
	player.grab(right)
	right.global_transform.origin = start
	player.held = right
	player.charge = 0.8
	player.cam.look_at(head, Vector3.UP)
	player.release(true)
	yield(get_tree().create_timer(0.35), "timeout")
	_save(dir + "/t2_hit.png")
	yield(get_tree().create_timer(2.5), "timeout")
	print("patience=", customers[0].patience if not customers.empty() else -1.0, " money=", money, " served=", served, " right_pos=", right.global_transform.origin if is_instance_valid(right) else "delivered")
	_save(dir + "/t2_after.png")
	get_tree().quit()


func _test3() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(3.0), "timeout")
	_spawn_customer()
	yield(get_tree().create_timer(0.5), "timeout")
	_spawn_customer()
	yield(get_tree().create_timer(5.0), "timeout")
	print("customers=", customers.size(), " waiting=", waiting().size(), " hud=", hud_order.text)
	player.global_transform.origin = Vector3(0, 0.05, -2.6)
	player.rotation.y = PI
	player.cam.rotation.x = -0.05
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/t3_three.png")
	# взрывная: роняем с размаху на стойку
	var ex = null
	for q in parcels:
		if q.box_type == "explosive":
			ex = q
	ex.global_transform.origin = Vector3(1.0, 2.5, 0.0)
	ex.sleeping = false
	ex.linear_velocity = Vector3(0, -9, 0)
	yield(get_tree().create_timer(0.25), "timeout")
	_save(dir + "/t3_boom.png")
	yield(get_tree().create_timer(1.0), "timeout")
	print("after boom money=", money)
	# хрупкая: трескаем и отдаём владельцу (подменяем заказ)
	var fr = null
	for q in parcels:
		if q.box_type == "fragile":
			fr = q
	fr.global_transform.origin = Vector3(-2.0, 0.3, -2.0)
	fr.sleeping = false
	fr.linear_velocity = Vector3(0, -6, 0)
	yield(get_tree().create_timer(0.6), "timeout")
	print("cracks=", fr.cracks)
	var c = waiting()[0]
	c.order = fr.code
	fr.global_transform.origin = Vector3(c.global_transform.origin.x, 1.3, 0)
	fr.linear_velocity = Vector3.ZERO
	yield(get_tree().create_timer(1.0), "timeout")
	print("served=", served, " money=", money, " fr_delivered=", not is_instance_valid(fr) or fr.delivered)
	_save(dir + "/t3_fragile.png")
	get_tree().quit()


func _test4() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(6.0), "timeout")
	player.global_transform.origin = Vector3(0, 0.05, -2.2)
	player.rotation.y = 0
	_save(dir + "/t4_blackout.png")
	player.rotation.y = PI
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/t4_tutorial.png")
	Game.bank = 150
	spawned = total_customers
	_end_shift()
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/t4_end.png")
	is_open = false
	_open_laptop(null)
	_buy("cart")
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/t4_shop.png")
	print("bank=", Game.bank, " cart=", Game.lvl("cart"), " day=", Game.day, " cap=", Game.carry_capacity())
	_set_paused(true)
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/t4_pause.png")
	get_tree().quit()


func _find_type(t: String):
	for q in parcels:
		if is_instance_valid(q) and q.box_type == t and not q.delivered:
			return q
	return null


func _test5() -> void:
	# v0.6: склад, портал, морозилка, вор, мошенник, новые посылки
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(6.8), "timeout")
	player.global_transform.origin = Vector3(-1.5, 0.05, -0.9)
	player.rotation.y = deg2rad(35)
	player.cam.rotation.x = -0.2
	yield(get_tree().create_timer(0.4), "timeout")
	_save(dir + "/t5_portal.png")
	print("parcels=", parcels.size(), " incoming=", incoming.size(), " shelves=", shelves.size())
	player.global_transform.origin = Vector3(0, 0.05, -1.0)
	player.rotation.y = 0
	player.cam.rotation.x = -0.05
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/t5_warehouse.png")
	# морозилка
	player.global_transform.origin = Vector3(4.6, 0.05, -0.9)
	player.rotation.y = deg2rad(-35)
	player.cam.rotation.x = -0.6
	yield(get_tree().create_timer(0.8), "timeout")
	_save(dir + "/t5_freezer.png")
	var fz = _find_type("frozen")
	if fz:
		print("frozen in freezer: ", fz.in_freezer, " melt=", fz.melt)
	# сортировка: коробку из портала на свой стеллаж
	for q in parcels:
		if is_instance_valid(q) and q.from_portal and not q.sorted:
			var spot: Vector3 = shelves[shelf_for(q.code)]["pos"] + Vector3(0, 1.0, 0)
			q.global_transform.origin = spot
			q.linear_velocity = Vector3.ZERO
			break
	yield(get_tree().create_timer(1.0), "timeout")
	print("money after sort: ", money)
	# таймер
	var tm = _find_type("timer")
	if tm:
		player.grab(tm)
		print("timer fuse after grab: ", tm.fuse)
		tm.fuse = 0.6
		yield(get_tree().create_timer(1.2), "timeout")
		player.release(false)
		print("timer exploded, money=", money)
	# мимик
	var mm = _find_type("mimic")
	if mm:
		for k in 4:
			mm.calm = 0.0
			player.grab(mm)
			if mm.held:
				player.release(false)
		print("mimic tested, money=", money)
	# вор у стойки
	yield(get_tree().create_timer(1.0), "timeout")
	var c = customers[0] if not customers.empty() else null
	if c and c.kind == "thief":
		while c.state != "at_counter":
			yield(get_tree().create_timer(0.2), "timeout")
		var mine = null
		for q in parcels:
			if is_instance_valid(q) and q.code == c.order:
				mine = q
		if mine.held:
			player.release(false)
		player.global_transform.origin = Vector3(c.global_transform.origin.x, 0.05, -1.3)
		player.rotation.y = PI
		player.cam.rotation.x = 0.0
		mine.mode = RigidBody.MODE_RIGID
		mine.global_transform.origin = Vector3(c.global_transform.origin.x, 1.3, 0.0)
		mine.linear_velocity = Vector3.ZERO
		yield(get_tree().create_timer(1.0), "timeout")
		_save(dir + "/t5_thief.png")
		print("thief state: ", c.state if is_instance_valid(c) else "gone")
		yield(get_tree().create_timer(1.5), "timeout")
		_save(dir + "/t5_golem.png")
		print("after golem: money=", money)
	# магазин
	yield(get_tree().create_timer(1.0), "timeout")
	Game.bank = 500
	_end_shift()
	is_open = false
	_open_laptop(null)
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/t5_shop.png")
	get_tree().quit()


func _test6() -> void:
	# мошенник с чеком и кнопка «ВОН»
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(3.0), "timeout")
	var c = customers[0]
	while c.state != "at_counter":
		yield(get_tree().create_timer(0.2), "timeout")
	var x: float = c.global_transform.origin.x
	player.global_transform.origin = Vector3(x + 0.55, 0.05, -0.9)
	player.rotation.y = PI
	player.cam.rotation.x = -0.42
	yield(get_tree().create_timer(0.5), "timeout")
	print("look: ", hud_hint.text, " scammer=", c.scammer, " fake=", c.fake)
	_save(dir + "/t6_receipt.png")
	var m0 := money
	_press_kick(kick_buttons[c.slot].get_child(0))
	yield(get_tree().create_timer(0.8), "timeout")
	print("kick: money ", m0, " -> ", money)
	_save(dir + "/t6_kick.png")
	get_tree().quit()


func _test7() -> void:
	# гоблин-помощник сам несёт посылку
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(5.0), "timeout")
	helper_cd = 0.0
	player.global_transform.origin = Vector3(1.5, 0.05, -0.6)
	player.rotation.y = deg2rad(30)
	player.cam.rotation.x = -0.1
	yield(get_tree().create_timer(3.0), "timeout")
	_save(dir + "/t7_helper.png")
	yield(get_tree().create_timer(9.0), "timeout")
	print("helper busy=", helper.busy, " served=", served, " money=", money)
	get_tree().quit()



# ---------------------------------------------------------------- сеть (кооп)
func net_client() -> bool:
	return Net.active and not Net.is_host


func _parcel_by_code(code: String):
	for p in parcels:
		if is_instance_valid(p) and p.code == code:
			return p
	return null


func _net_tick(delta: float) -> void:
	if not Net.active or player == null:
		return
	_net_t += delta
	if _net_t >= 0.05:
		_net_t = 0.0
		rpc_unreliable("net_player", player.global_transform.origin, player.rotation.y, player.cam.rotation.x)
		if Net.is_host:
			var arr := []
			for p in parcels:
				if is_instance_valid(p) and not p.delivered and (not p.sleeping or p.held or p.mode != RigidBody.MODE_RIGID):
					arr.append([p.code, p.global_transform.origin, p.global_transform.basis.get_rotation_quat()])
			if not arr.empty():
				rpc_unreliable("net_parcels", arr)
	if Net.is_host:
		_net_alive_t += delta
		if _net_alive_t >= 0.5:
			_net_alive_t = 0.0
			var alive := []
			for p in parcels:
				if is_instance_valid(p) and not p.delivered:
					alive.append(p.code)
			rpc("net_state", alive, money, served, spawned, total_customers)
		# коробки в руках у других игроков
		for id in remote_hold:
			var av = avatars.get(id)
			if av == null:
				continue
			var h := 0.0
			for b in remote_hold[id]:
				if is_instance_valid(b) and not b.delivered:
					b.global_transform.origin = av.hold_point() + Vector3.UP * h
					h += b.size.y + 0.02
	else:
		# плавно двигаем коробки к позициям от хоста
		for p in parcels:
			if is_instance_valid(p) and p.has_meta("net_to") and not p in player.stack:
				var t: Transform = p.get_meta("net_to")
				p.global_transform = p.global_transform.interpolate_with(t, min(1.0, 15.0 * delta))


func _avatar(id: int):
	if avatars.has(id):
		return avatars[id]
	var av = load("res://scripts/avatar.gd").new()
	av.setup(id, avatars.size() + 1)
	add_child(av)
	avatars[id] = av
	remote_hold[id] = []
	return av


remote func net_player(pos: Vector3, rot_y: float, pitch: float) -> void:
	var id := get_tree().get_rpc_sender_id()
	_avatar(id).net_set(pos, rot_y, pitch)


remote func net_parcels(arr: Array) -> void:
	for e in arr:
		var p = _parcel_by_code(e[0])
		if p:
			p.set_meta("net_to", Transform(Basis(e[2]), e[1]))


remote func net_state(alive: Array, m: int, sv: int, sp: int, tot: int) -> void:
	money = m
	served = sv
	spawned = sp
	total_customers = tot
	for p in parcels.duplicate():
		if is_instance_valid(p) and not p.code in alive:
			parcels.erase(p)
			if p in player.stack:
				player.stack.erase(p)
			p.queue_free()
	_refresh_hud()


remote func net_portal_add(code: String) -> void:
	for p in incoming:
		if p.code == code:
			incoming.erase(p)
			p.translation = PORTAL + Vector3(0.45, 0, 0)
			p.from_portal = true
			add_child(p)
			p.mode = RigidBody.MODE_KINEMATIC
			parcels.append(p)
			portal_open_t = 1.0
			Sfx.play_at("portal", PORTAL, 0.0, 2.0)
			return


remote func net_customer(id: int, kind: String, order: String, line: String, slot: int, pat: float,
		target: Vector3, scam: bool, fake: String, rcode: String) -> void:
	var c = Customer.new()
	c.setup(kind, _char_frames(kind), order, line, pat)
	c.net_id = id
	c.remote = true
	c.scammer = scam
	c.fake = fake
	c.receipt_code = rcode
	c.door = DOOR
	c.slot = slot
	c.translation = DOOR
	add_child(c)
	customers.append(c)
	Sfx.play("doorbell", 0.03, -3.0)
	c.connect("arrived", self, "_net_customer_arrived", [c])
	c.walk_to(target, "arrive")


func _net_customer_arrived(c) -> void:
	_make_receipt(c)
	_refresh_hud()


remote func net_customer_leave(id: int, happy: bool, text: String) -> void:
	for c in customers.duplicate():
		if is_instance_valid(c) and c.net_id == id:
			_drop_receipt(c)
			customers.erase(c)
			if c.state != "leaving":
				c.leave_with(text, happy)
	_refresh_hud()


remote func net_end_shift(txt: String) -> void:
	shift_over = true
	Ach.unlock("ACH_COOP")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud_panel_text.text = txt + tr("\n\nЖдём, пока хост начнёт новую смену...")
	hud_panel.visible = true
	end_buttons.visible = false


# --- запросы от гостей к хосту
remote func net_req_grab(code: String) -> void:
	if not Net.is_host:
		return
	var id := get_tree().get_rpc_sender_id()
	var p = _parcel_by_code(code)
	_avatar(id)
	if p and p.duo:
		fun.duo_request(id, p)
		return
	if p == null or p.held or p.delivered or remote_hold[id].size() >= Game.carry_capacity():
		return
	p.set_meta("holder", id)
	p.on_grabbed()
	p.held = true
	p.mode = RigidBody.MODE_KINEMATIC
	remote_hold[id].append(p)
	rpc_id(id, "net_grab_ok", code)


remote func net_grab_ok(code: String) -> void:
	var p = _parcel_by_code(code)
	if p:
		player.grab_local(p)


remote func net_req_release(code: String, throw: bool, charge: float, dir: Vector3, vel: Vector3) -> void:
	if not Net.is_host:
		return
	var id := get_tree().get_rpc_sender_id()
	var p = _parcel_by_code(code)
	if p == null or not remote_hold.has(id):
		return
	remote_hold[id].erase(p)
	p.held = false
	p.mode = RigidBody.MODE_RIGID
	p.sleeping = false
	p.linear_velocity = Vector3(vel.x, 0, vel.z)
	if throw:
		p.thrown = true
		p.set_meta("thrower", id)
		p.apply_central_impulse(dir * lerp(player.THROW_MIN, player.THROW_MAX, charge) * min(p.mass, 2.0))
		Sfx.play_at("whoosh", p.global_transform.origin, 0.1, 0.0)


remote func net_req_kick(slot: int) -> void:
	if Net.is_host and kick_buttons.has(slot):
		_press_kick(kick_buttons[slot].get_child(0))


remote func net_req_lever() -> void:
	if Net.is_host:
		_pull_lever(null)


func _test8() -> void:
	# сеть: гость берёт посылку первого клиента и кладёт на стойку
	if not net_client():
		return
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(4.0), "timeout")
	while waiting().empty():
		yield(get_tree().create_timer(0.3), "timeout")
	var c = waiting()[0]
	var p = _parcel_by_code(c.order)
	print("client: customer ", c.kind, " wants ", c.order, " parcel=", p != null, " avatars=", avatars.size())
	rpc_id(1, "net_req_grab", c.order)
	yield(get_tree().create_timer(0.6), "timeout")
	print("client: holding ", player.stack.size())
	var x: float = c.global_transform.origin.x
	player.global_transform.origin = Vector3(x, 0.05, -1.2)
	player.rotation.y = PI
	player.cam.rotation.x = -0.35
	yield(get_tree().create_timer(0.8), "timeout")
	_save(dir + "/t8_client_hold.png")
	player.release(false)
	yield(get_tree().create_timer(2.0), "timeout")
	print("client: served=", served, " money=", money)
	_save(dir + "/t8_client_after.png")
	get_tree().quit()


func _test9() -> void:
	# ставим коробки на полку и на стойку
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(2.0), "timeout")
	var sh: Vector3 = SHELF_POS[0]
	var ok := 0
	for k in 3:
		var p = parcels[k]
		player.grab(p)
		player.global_transform.origin = Vector3(sh.x - 1.65 + k * 1.1, 0.05, sh.z + 1.4)
		player.rotation.y = 0
		player.cam.rotation.x = -0.25
		yield(get_tree().create_timer(0.4), "timeout")
		player.release(false)
		yield(get_tree().create_timer(1.5), "timeout")
		var y: float = p.global_transform.origin.y
		print("shelf place ", k, " y=", y, " z=", p.global_transform.origin.z)
		if y > 0.9 and abs(p.global_transform.origin.z - sh.z) < 0.4:
			ok += 1
	_save(dir + "/t9_shelf.png")
	var p2 = parcels[3]
	player.grab(p2)
	player.global_transform.origin = Vector3(-1.0, 0.05, -1.0)
	player.rotation.y = PI
	player.cam.rotation.x = -0.6
	yield(get_tree().create_timer(0.4), "timeout")
	player.release(false)
	yield(get_tree().create_timer(1.0), "timeout")
	if is_instance_valid(p2):
		print("counter y=", p2.global_transform.origin.y, " shelf ok=", ok)
	else:
		print("counter: delivered to customer, shelf ok=", ok)
	player.global_transform.origin = Vector3(4.6, 0.05, -1.0)
	player.rotation.y = deg2rad(-60)
	player.cam.rotation.x = -0.5
	yield(get_tree().create_timer(0.8), "timeout")
	_save(dir + "/t9_freezer.png")
	get_tree().quit()


func _test10() -> void:
	# декор, сейф, клетка, финальная панель, магазин декора
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(4.0), "timeout")
	player.global_transform.origin = Vector3(2.4, 0.05, -1.6)
	player.rotation.y = -PI / 2
	player.cam.rotation.x = -0.4
	print("safe at ", safe_door.global_transform.origin, " cage ", cage_area.global_transform.origin, " vis ", safe_door.is_visible_in_tree())
	yield(get_tree().create_timer(0.4), "timeout")
	_save(dir + "/v8_safe_cage.png")
	player.global_transform.origin = Vector3(-4.6, 0.05, -1.6)
	player.rotation.y = PI / 2 + 0.5
	player.cam.rotation.x = -0.35
	yield(get_tree().create_timer(0.4), "timeout")
	_save(dir + "/v8_vinyl.png")
	player.global_transform.origin = Vector3(0, 0.05, -1.0)
	player.rotation.y = PI
	player.cam.rotation.x = 0.05
	yield(get_tree().create_timer(0.4), "timeout")
	_save(dir + "/v8_hall.png")
	# сейф: выдать ценную посылку через код
	var vp = null
	for p in parcels:
		if is_instance_valid(p) and p.in_safe:
			vp = p
	print("safe parcels: ", vp != null)
	if vp:
		var pin: String = vp.get_meta("pin")
		var fake_c = Customer.new()
		fake_c.safe_pin = pin
		fake_c.order = vp.code
		fake_c.state = "at_counter"
		for k in 3:
			safe_code[k] = (int(pin[k]) + 9) % 10
		# кликаем по каждому колёсику один раз
		customers.append(fake_c)
		for k in 3:
			var b = safe_digits[k].get_child(0)
			_safe_dial(b)
		customers.erase(fake_c)
		fake_c.free()
		yield(get_tree().create_timer(1.0), "timeout")
		print("safe opened: ", not vp.in_safe, " y=", vp.global_transform.origin.y)
	stats = {"hit": 1, "fast": 3, "gift": 1, "sort": 4, "cursed": 2}
	served = 6
	spawned = 7
	failed = 1
	money = 77
	_end_shift()
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/v8_endshift.png")
	is_open = false
	_open_laptop(null)
	_shop_tab("decor")
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/v8_shop_decor.png")
	get_tree().quit()


func _test11() -> void:
	# босс: три посылки подряд, потом финал
	var dir := OS.get_environment("SHOT_DIR")
	for _i in 40:
		yield(get_tree().create_timer(0.5), "timeout")
		if boss and boss.state == "at_counter":
			break
	print("boss present: ", boss != null)
	player.global_transform.origin = Vector3(boss.global_transform.origin.x, 0.05, -1.3)
	player.rotation.y = PI
	player.cam.rotation.x = 0.1
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/v8_boss.png")
	for k in 3:
		var right = _parcel_by_code(boss.order)
		if right == null:
			break
		if right.in_safe:
			_safe_open(right)
		right.mode = RigidBody.MODE_RIGID
		right.global_transform.origin = Vector3(boss.global_transform.origin.x, 1.4, 0)
		right.linear_velocity = Vector3.ZERO
		right.sleeping = false
		yield(get_tree().create_timer(1.5), "timeout")
		print("boss left: ", boss_left)
	for c in customers.duplicate():
		if c != boss and is_instance_valid(c):
			c.leave(true)
	yield(get_tree().create_timer(4.0), "timeout")
	total_customers = spawned
	_end_shift()
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/v8_final.png")
	print("career_done: ", Game.career_done)
	get_tree().quit()


func _look_at_point(pos: Vector3, target: Vector3) -> void:
	player.global_transform.origin = pos
	var d: Vector3 = target - (pos + Vector3(0, 1.6, 0))
	player.rotation.y = atan2(-d.x, -d.z)
	player.cam.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _test12() -> void:
	# режим «закрыто»: табличка, ноутбук, доставка, перестановка, открытие
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(3.0), "timeout")
	print("closed: is_open=", is_open, " pile=", pile.size(), " customers=", customers.size())
	_look_at_point(Vector3(-1.8, 0.05, -1.6), Vector3(-1.5, 2.0, 0.36))
	yield(get_tree().create_timer(0.4), "timeout")
	_save(dir + "/v9_sign.png")
	print("look sign: ", hud_hint.text)
	_look_at_point(Vector3(-4.2, 0.05, -1.2), Vector3(-6.5, 0.8, -1.6))
	yield(get_tree().create_timer(0.4), "timeout")
	_save(dir + "/v9_laptop_pile.png")
	_open_laptop(null)
	_shop_tab("decor")
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/v9_laptop_shop.png")
	_buy_decor("plant")
	_close_laptop()
	yield(get_tree().create_timer(0.5), "timeout")
	var box = null
	for ch in get_children():
		if ch is Sprite3D and ch.texture and ch.texture.resource_path.find("deliv_box") >= 0:
			box = ch
	print("delivery box: ", box != null)
	_look_at_point(Vector3(-2.5, 0.05, -1.0), box.global_transform.origin)
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/v9_delivery.png")
	_open_delivery(box.get_child(0))
	yield(get_tree().create_timer(0.5), "timeout")
	var tr_root = get_node_or_null("decor_plant2")
	print("plant built: ", tr_root != null)
	# перестановка
	_pick_decor(tr_root.get_child(tr_root.get_child_count() - 1))
	_look_at_point(Vector3(0, 0.05, -2.0), Vector3(0.5, 0.98, -0.1))
	yield(get_tree().create_timer(0.3), "timeout")
	ui_click(null)
	print("plant moved to ", tr_root.global_transform.origin, " saved=", Game.decor_pos.get("plant2"))
	_read_board(null)
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/v9_board.png")
	ui_click(null)
	_flip_sign(null)
	yield(get_tree().create_timer(6.0), "timeout")
	print("opened: is_open=", is_open, " customers=", customers.size())
	_look_at_point(Vector3(-1.8, 0.05, -1.6), Vector3(-1.5, 2.0, 0.36))
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/v9_open.png")
	get_tree().quit()


func _shotfix() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	var views := [
		["cot", Vector3(0, 0.05, -3.2), 0.0, -0.35],
		["laptop", Vector3(-4.9, 0.05, -1.5), PI / 2, -0.35],
		["sign", Vector3(-1.4, 0.05, -1.9), 0.0 + PI, 0.25],
		["start", Vector3(0, 0.05, -3.0), 2.66, 0.15],
		["shelves", Vector3(-4.0, 0.05, -1.6), 0.0, 0.12],
		["mirror", Vector3(-1.0, 0.05, -3.4), 0.25, -0.05],
		["cage", Vector3(3.0, 0.05, -2.8), -2.3, -0.45],
	]
	var D = load("res://scripts/paperdoll.gd").new()
	add_child(D)
	D.translation = Vector3(0.3, 0, -2.4)
	D.rotation.y = PI
	D.set_look({"race": "goblin", "skin": 0, "apron": 2, "hat": "cowboy", "face": "sunglasses"})
	views.push_front(["doll", Vector3(0, 0.05, -0.7), 0.0, -0.2])
	yield(get_tree().create_timer(1.5), "timeout")
	for v in views:
		player.translation = v[1]
		player.rotation.y = v[2]
		player.cam.rotation.x = v[3]
		yield(get_tree().create_timer(0.6), "timeout")
		_save(dir + "/fix_" + v[0] + ".png")
	if lid_pivot:
		_set_lid(true)
		player.translation = Vector3(4.4, 0.05, -2.2)
		player.rotation.y = -PI / 2
		player.cam.rotation.x = -0.3
		yield(get_tree().create_timer(0.8), "timeout")
		_save(dir + "/fix_freezer.png")
	if cage_area:
		var cp = parcels[0]
		cp.global_transform.origin = CAGE + Vector3(0, 0.3, 0)
		cp.linear_velocity = Vector3.ZERO
		yield(get_tree().create_timer(1.0), "timeout")
		player.global_transform.origin = CAGE + Vector3(1.3, 0.05, 0.3)
		player.look_at(CAGE + Vector3(0, 0.05, 0), Vector3.UP)
		player.rotation.x = 0
		player.rotation.z = 0
		player.cam.rotation.x = -0.75
		yield(get_tree().create_timer(0.5), "timeout")
		_save(dir + "/fix_cage_grab.png")
		print("cage: looked parcel=", player.looked_parcel() == cp, " in cage y=", cp.global_transform.origin.y)
		player.grab(cp)
		yield(get_tree().create_timer(0.3), "timeout")
		player.release(false)
		yield(get_tree().create_timer(1.0), "timeout")
		print("cage: put back at ", cp.global_transform.origin, " inside=", cp in cage_area.get_overlapping_bodies())
	if mirror:
		Settings.look = {"nick": "2peaK", "race": "orc", "skin": 1, "apron": 1, "hat": "viking", "face": "glasses"}
		Settings.owned.append("orc")
		mirror.doll.set_look(Settings.look)
		player.translation = Vector3(-1.0, 0.05, -3.4)
		player.rotation.y = 0.25
		player.cam.rotation.x = -0.05
		yield(get_tree().create_timer(0.6), "timeout")
		_save(dir + "/fix_mirror2.png")
		var vimg: Image = mirror.vp.get_texture().get_data()
		vimg.save_png(dir + "/fix_mirror_vp.png")
		print("mirror cam ", mirror.cam.global_transform.origin, " doll=", mirror.doll.global_transform.origin, " vis=", mirror.doll.body.visible, " tex=", mirror.doll.body.texture)
		mirror.open()
		yield(get_tree().create_timer(0.4), "timeout")
		_save(dir + "/fix_editor.png")
		var k := 0
		for lk in [{"race": "human", "hat": "bandana", "face": "glasses"}, {"race": "goblin", "hat": "headphones", "face": "mustache"},
				{"race": "orc", "hat": "wizard", "face": "eyepatch"}, {"race": "orc", "hat": "viking", "face": "bowtie"},
				{"race": "human", "hat": "mouse_ears", "face": "mustache"}, {"race": "goblin", "hat": "viking", "face": "glasses"}]:
			for key in lk:
				mirror.edit[key] = lk[key]
			mirror.view_i = k % 3
			mirror._refresh()
			yield(get_tree().create_timer(0.3), "timeout")
			_save(dir + "/fix_editor%d.png" % k)
			k += 1
		mirror.close()
	_open_laptop(null)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	_unhandled_input(ev)
	print("esc closes laptop: ", not shop_panel.visible, " paused=", get_tree().paused)
	get_tree().quit()


func _relangtest() -> void:
	yield(get_tree().create_timer(1.0), "timeout")
	if Settings.lang == "ru":
		var sp = load("res://scripts/settings_panel.gd").new()
		sp.build(font_big)
		add_child(sp)
		sp._on_lang(1)
		return
	print("relang: lang=", Settings.lang, " paused=", get_tree().paused, " pause_panel=", pause_panel.visible)
	_save(OS.get_environment("SHOT_DIR") + "/fix_relang.png")
	Settings.lang = "ru"
	Settings.save_cfg()
	get_tree().quit()


# ---- жёлтая стрелка обучения: показывает, куда нажимать
func _tut_arrow_at(pos) -> void:
	if pos == null:
		if tut_arrow:
			tut_arrow.queue_free()
			tut_arrow = null
		return
	if tut_arrow == null:
		tut_arrow = Sprite3D.new()
		tut_arrow.texture = tex("ui/tut_arrow", false)
		tut_arrow.pixel_size = 0.45 / tut_arrow.texture.get_height()
		tut_arrow.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
		tut_arrow.shaded = false
		tut_arrow.no_depth_test = true
		tut_arrow.render_priority = 10
		add_child(tut_arrow)
	tut_arrow.translation = pos
	tut_arrow.set_meta("base", pos)


func _update_tut_arrow() -> void:
	if tut_arrow:
		var b: Vector3 = tut_arrow.get_meta("base")
		tut_arrow.translation = b + Vector3(0, abs(sin(OS.get_ticks_msec() / 250.0)) * 0.12, 0)


# ---------------------------------------------------------------- зеркало и внешность игрока
func _aim_at(target: Vector3, from: Vector3) -> void:
	player.global_transform.origin = from
	var dir: Vector3 = target - player.cam.global_transform.origin
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.cam.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _shelftest() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(1.5), "timeout")
	print("units=", shelf_units.size(), " closed=", not is_open, " parcels=", parcels.size())
	for k in 3:
		var sl: Vector3 = shelves[0]["slots"][k]
		parcels[k].global_transform.origin = sl
		parcels[k].linear_velocity = Vector3.ZERO
	yield(get_tree().create_timer(1.0), "timeout")
	var fake := StaticBody.new()
	fake.set_meta("shelf", 0)
	var before := 0
	for q in parcels:
		var o: Vector3 = q.global_transform.origin - shelf_units[0]["c"]
		if abs(o.x) < 2.3 and abs(o.z) < 0.45 and o.y > 0.05:
			before += 1
	_pick_shelf(fake)
	# 1) в стойку — нельзя
	_aim_at(Vector3(-4, 0, -0.5), Vector3(-2, 0.05, -2.0))
	yield(get_tree().create_timer(0.3), "timeout")
	print("aim counter ok=", carry_ok)
	# 2) свободное место на складе — можно
	_aim_at(Vector3(0.0, 0, -3.5), Vector3(0.0, 0.05, -1.5))
	yield(get_tree().create_timer(0.3), "timeout")
	print("aim free ok=", carry_ok, " c=", shelf_units[0]["c"])
	_save(dir + "/shelf_carry.png")
	ui_click(null)
	yield(get_tree().create_timer(1.0), "timeout")
	var after := 0
	for q in parcels:
		var o: Vector3 = q.global_transform.origin - shelf_units[0]["c"]
		if abs(o.x) < 2.3 and abs(o.z) < 0.45 and o.y > 0.05:
			after += 1
	print("dropped: pos=", Game.shelf_pos, " parcels on shelf before=", before, " after=", after, " slot0=", shelves[0]["slots"][0] if shelves[0]["slots"].size() > 0 else null)
	# 3) декор: цветок на стойку — нельзя, на пол — можно
	for m in movables:
		if str(m.get_meta("key")) == "plant2":
			var fb := StaticBody.new()
			m.add_child(fb)
			_pick_decor(fb)
			_aim_at(Vector3(-1.0, 0.98, 0.0), Vector3(-1.0, 0.05, -1.5))
			yield(get_tree().create_timer(0.3), "timeout")
			print("plant on counter ok=", carry_ok)
			_aim_at(Vector3(0.5, 0.0, -2.2), Vector3(0.5, 0.05, -1.0))
			yield(get_tree().create_timer(0.3), "timeout")
			print("plant on floor ok=", carry_ok)
			_save(dir + "/plant_carry.png")
			ui_click(null)
	# 4) перекраска
	if Game.lvl("paints") > 0:
		var pb := StaticBody.new()
		pb.set_meta("letter", shelves[0]["letters"][0])
		_paint_section(pb)
		_paint_section(pb)
		print("paint: ", Game.letter_colors)
	_aim_at(shelf_units[0]["c"] + Vector3(0, 1.2, 0), shelf_units[0]["c"] + Vector3(0, 0.05, 2.6))
	yield(get_tree().create_timer(0.5), "timeout")
	_save(dir + "/shelf_after.png")
	get_tree().quit()


func _mirrortest() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(1.5), "timeout")
	var mp: Vector3 = mirror.global_transform.origin
	for dist in [0.6, 1.2, 2.5, 1.7]:
		player.global_transform.origin = Vector3(mp.x + (0.8 if dist == 1.7 else 0.0), 0.05, mp.z + dist)
		player.rotation.y = 0.0
		player.cam.rotation.x = 0.0
		yield(get_tree().create_timer(0.6), "timeout")
		_save(dir + "/mirror_%s.png" % str(dist))
	get_tree().quit()


func _build_mirror() -> void:
	if not ResourceLoader.exists("res://assets/props/mirror.png") or not load("res://scripts/paperdoll.gd").available():
		return
	mirror = load("res://scripts/mirror.gd").new()
	var z := -10.82 if Game.lvl("expand") > 0 else -5.42
	mirror.translation = Vector3(-1.35, 0.25, z)  # висит на стене, стекло на уровне глаз
	add_child(mirror)
	mirror.build(self)


func _open_mirror(_b) -> void:
	if carrying or player.held or shift_over:
		return
	mirror.open()


func _send_look() -> void:
	if Net.active:
		rpc("net_look", Settings.look)


remote func net_look(l: Dictionary) -> void:
	var id := get_tree().get_rpc_sender_id()
	var av = _avatar(id)
	if av.has_method("set_look"):
		av.set_look(l)


func _send_look_later() -> void:
	# всем рассказываем, как выглядим (несколько раз: вдруг кто-то ещё грузится)
	for k in 3:
		yield(get_tree().create_timer(1.0 + k * 2.0), "timeout")
		_send_look()


# ---------------------------------------------------------------- пасхалка «Мага-тестировщик»
func _maga_summon() -> void:
	if not ResourceLoader.exists("res://assets/chars/maga_idle.png"):
		return
	maga_pending = true
	Sfx.play("squeak", 0.05, 0.0)
	# розовая вспышка
	var fl := ColorRect.new()
	fl.color = Color(1.0, 0.45, 0.75, 0.45)
	fl.anchor_right = 1
	fl.anchor_bottom = 1
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_center.get_parent().add_child(fl)
	var tw := create_tween()
	tw.tween_property(fl, "color:a", 0.0, 1.2)
	tw.tween_callback(fl, "queue_free")
	# по залу пробегает мышка в короне
	var ms := Sprite3D.new()
	ms.texture = tex("props/mouse_run0", false)
	ms.pixel_size = 0.3 / ms.texture.get_height()
	ms.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
	ms.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	ms.translation = Vector3(4.5, 0.16, -2.4)
	add_child(ms)
	var tm := create_tween()
	tm.tween_property(ms, "translation:x", -4.5, 2.4)
	tm.tween_callback(ms, "queue_free")
	# посылка Королевы прячется в дальнем углу склада
	var Parcel = load("res://scripts/parcel.gd")
	var p = Parcel.new()
	var bx := "boxes_en/box_maga" if Settings.latin() else "boxes/box_maga"
	p.setup("М-01", false, Vector3(0.38, 0.38, 0.38), tex(bx, false))
	p.box_type = "living"
	var spot := Vector3(6.4, 0.4, -9.6) if Game.lvl("expand") > 0 else Vector3(6.4, 0.4, -5.1)
	p.translation = spot
	p.home = spot
	p.sorted = true
	add_child(p)
	parcels.append(p)
	maga_parcel = p
	_flash(tr("Пи-пи! Кто-то пищит на складе... Открывай пункт!"), 3.0)


func _update_maga(delta: float) -> void:
	if maga_parcel == null or not is_instance_valid(maga_parcel) or maga_parcel.delivered or maga_parcel.held:
		return
	_squeak_t -= delta
	if _squeak_t <= 0.0 and player and player.global_transform.origin.distance_to(maga_parcel.global_transform.origin) < 4.5:
		_squeak_t = 2.5
		Sfx.play_at("squeak", maga_parcel.global_transform.origin, 0.1, 0.0)


func _maga_reward() -> void:
	Ach.unlock("ACH_MAGA")
	Game.tokens += 5
	if not "mouse_ears" in Settings.owned:
		Settings.owned.append("mouse_ears")
	Game.decor["mouse_queen"] = true
	if not "secret_maga" in Game.seen_kinds:
		Game.seen_kinds.append("secret_maga")
	Settings.save_cfg()
	Game.save_game()
	Sfx.play("squeak", 0.0, 0.0)
	_flash(tr("СЕКРЕТ НАЙДЕН: «Друг студии»!\n+5 жетонов, мышиные ушки в зеркале и Королева Мышей на стойку."), 6.0)
	if ResourceLoader.exists("res://assets/ui/medal_maga.png"):
		var md := TextureRect.new()
		md.texture = load("res://assets/ui/medal_maga.png")
		md.rect_position = Vector2(296, 150)
		md.rect_scale = Vector2(1.2, 1.2)
		hud_center.get_parent().add_child(md)
		var tw := create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(md, "modulate:a", 0.0, 1.0)
		tw.tween_callback(md, "queue_free")


func _test13() -> void:
	# пасхалка: 5 звонков пока закрыто -> Мага приходит первым, выдаём М-01 -> награда
	yield(get_tree().create_timer(1.5), "timeout")
	var bell: Spatial = null
	for ch in get_children():
		if ch is Sprite3D and ch.texture and ch.texture.resource_path.find("desk_bell") >= 0:
			bell = ch
	if is_open:
		Game.phase = "closed"
		_enter_closed()
	for k in 5:
		_ring_desk(bell)
	print("maga pending=", maga_pending, " parcel=", maga_parcel != null)
	_flip_sign(null)
	yield(get_tree().create_timer(9.0), "timeout")
	print("first customer=", customers[0].kind if not customers.empty() else "none", " order=", customers[0].order if not customers.empty() else "")
	_save(OS.get_environment("SHOT_DIR") + "/t13_maga.png")
	if maga_c and is_instance_valid(maga_c):
		var cx: float = maga_c.global_transform.origin.x
		maga_parcel.global_transform.origin = Vector3(cx + 0.3, 1.4, 0)
		maga_parcel.linear_velocity = Vector3.ZERO
		maga_parcel.sleeping = false
		yield(get_tree().create_timer(4.0), "timeout")
	print("reward: ears=", "mouse_ears" in Settings.owned, " plush=", Game.decor.has("mouse_queen"), " tokens=", Game.tokens)
	_save(OS.get_environment("SHOT_DIR") + "/t13_reward.png")
	get_tree().quit()


# ---------------------------------------------------------------- кооп: пауза хоста и переподключение
var net_paused := false  # гость: хост поставил паузу
var drop_wait := false  # хост: пауза, потому что напарник отвалился
var pause_note: Label


func _hook_net_peers() -> void:
	var t := get_tree()
	if not t.is_connected("network_peer_disconnected", self, "_on_net_peer_gone"):
		t.connect("network_peer_disconnected", self, "_on_net_peer_gone")
	if Net.is_host and not t.is_connected("network_peer_connected", self, "_on_net_peer_back"):
		t.connect("network_peer_connected", self, "_on_net_peer_back")
	if net_client():
		rpc_id(1, "net_hello_ready")


func _pause_note(t: String) -> void:
	if pause_note == null:
		pause_note = Label.new()
		pause_note.add_font_override("font", font_big)
		pause_note.align = Label.ALIGN_CENTER
		pause_note.autowrap = true
		pause_note.rect_position = Vector2(120, 62)
		pause_note.rect_size = Vector2(400, 40)
		pause_note.add_color_override("font_color", Color(1, 0.85, 0.4))
		pause_panel.get_parent().add_child(pause_note)
	pause_note.text = t
	pause_note.visible = t != ""


func _on_net_peer_gone(id: int) -> void:
	if avatars.has(id):
		var av = avatars[id]
		var at: Vector3 = av.global_transform.origin
		if is_instance_valid(av):
			av.queue_free()
		avatars.erase(id)
		# коробки из рук ушедшего падают на пол
		for b in remote_hold.get(id, []):
			if is_instance_valid(b) and not b.delivered:
				b.held = false
				b.global_transform.origin = at + Vector3(0, 1.0, 0)
				if Net.is_host:
					b.mode = RigidBody.MODE_RIGID
					b.sleeping = false
		remote_hold.erase(id)
	if fun and fun.has_method("peer_gone"):
		fun.peer_gone(id)
	hud_event.text = (tr("ХОСТ") if Net.is_host else tr("КООП")) + tr(": игроков %d") % (Net.peers.size() + 1)
	if Net.is_host and not shift_over:
		_flash(tr("Напарник отключился. Пауза: ждём, пока он зайдёт снова (ESC — играть дальше)."), 4.0)
		if not get_tree().paused:
			_set_paused(true)
			drop_wait = true
		_pause_note(tr("Напарник отключился. Ждём переподключения..."))


func _on_net_peer_back(id: int) -> void:
	if shift_over or not Net.is_host:
		return
	# вернувшийся (или новый) игрок: запускаем у него ту же смену, потом досылаем состояние
	Net.rpc_id(id, "_start", Net.seed_value, Game.day, Game.upgrades, Game.event)
	_pause_note(tr("Напарник заходит..."))


remote func net_hello_ready() -> void:
	if not Net.is_host:
		return
	var id := get_tree().get_rpc_sender_id()
	var arr := []
	for p in parcels:
		if is_instance_valid(p) and not p.delivered:
			arr.append([p.code, p.global_transform.origin, p.global_transform.basis.get_rotation_quat(), p.from_portal])
	var cs := []
	for c in customers:
		if is_instance_valid(c) and c.state != "leaving":
			cs.append([c.net_id, c.kind, c.order, c.line, c.slot, c.patience,
				c.get_meta("target") if c.has_meta("target") else c.global_transform.origin,
				c.scammer, c.fake, c.receipt_code])
	rpc_id(id, "net_catchup", arr, cs, money, served, spawned, total_customers)
	if get_tree().paused:
		rpc_id(id, "net_pause", true)
	if drop_wait:
		_set_paused(false)
	_pause_note("")
	_flash(tr("Напарник снова в игре!"), 2.0)
	hud_event.text = tr("ХОСТ") + tr(": игроков %d") % (Net.peers.size() + 1)
	_send_look_later()


remote func net_catchup(arr: Array, cs: Array, m: int, sv: int, sp: int, tot: int) -> void:
	var alive := []
	for e in arr:
		alive.append(e[0])
		if e[3]:
			net_portal_add(e[0])
		var p = _parcel_by_code(e[0])
		if p:
			p.global_transform = Transform(Basis(e[2]), e[1])
			p.set_meta("net_to", p.global_transform)
	for e in cs:
		var known := false
		for c in customers:
			if is_instance_valid(c) and c.net_id == e[0]:
				known = true
		if not known:
			net_customer(e[0], e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9])
			var c2 = customers.back()
			c2.translation = e[6]
	net_state(alive, m, sv, sp, tot)
	portal_open_t = 0.0


remote func net_pause(on: bool) -> void:
	net_paused = on
	get_tree().paused = on
	pause_panel.visible = on
	_pause_note(tr("Хост поставил паузу") if on else "")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED)


func _rejoin_test() -> void:
	# кооп: гость вылетает и заходит снова (см. tools/test/rejoin.sh)
	var dir := OS.get_environment("SHOT_DIR")
	var tag := "HOST" if Net.is_host else "CLIENT"
	for k in 8:
		yield(get_tree().create_timer(5.0), "timeout")
		var n := 0
		for p in parcels:
			if is_instance_valid(p) and not p.delivered:
				n += 1
		print("%s t=%d parcels=%d customers=%d money=%d paused=%s peers=%s" % [tag, (k + 1) * 5, n, customers.size(), money, get_tree().paused, Net.peers])
		if k == 1 and not Net.is_host:
			_save(dir + "/rj_client.png")
	if Net.is_host:
		_save(dir + "/rj_host.png")
	get_tree().quit()


# ---------------------------------------------------------------- хардкор
var hc_fired := false


func hardcore_on() -> bool:
	return Game.hardcore and Game.mode == "career" and not net_client()


func _hardcore_check() -> void:
	if not hardcore_on() or shift_over:
		return
	_refresh_hud()
	if failed == 2:
		_flash(tr("ХАРДКОР: ещё один злой клиент — и тебя уволят!"), 3.0)
		Sfx.play("siren", 0.0, -6.0)
	if failed >= 3:
		_hardcore_fired()


func _hardcore_fired() -> void:
	hc_fired = true
	shift_over = true
	Sfx.play("shift_end", 0.0, -2.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var reached := Game.day
	var record := reached > Game.hc_best
	Game.hc_best = max(Game.hc_best, reached)
	# карьера сначала, рекорд остаётся
	var best := Game.hc_best
	Game.new_game(true)
	Game.hc_best = best
	Game.tutorial_done = true
	Game.phase = "closed"
	Game.save_game()
	hud_tut.visible = false
	end_buttons.visible = true
	for b in end_buttons.get_children():
		if b is Control:
			b.visible = false
	var txt := tr("УВОЛЕН!\n\nТри злых клиента за смену. Гильдия забрала ключи.\nТы дошёл до смены %d.") % reached
	txt += "\n" + (tr("НОВЫЙ РЕКОРД ХАРДКОРА!") if record else tr("Рекорд: смена %d") % Game.hc_best)
	txt += "\n\n" + tr("Карьера начнётся заново с первой смены.")
	hud_panel_text.text = txt
	hud_panel_side.text = ""
	hud_panel.visible = true
	_hc_menu_button()
	if Net.active:
		rpc("net_end_shift", txt)


func _hc_menu_button() -> void:
	var b := _button(end_buttons, tr("В меню"), "_to_menu")
	b.visible = true


func _hc_test() -> void:
	Game.hardcore = true
	Game.day = 4
	yield(get_tree().create_timer(2.0), "timeout")
	failed = 1
	_refresh_hud()
	_save(OS.get_environment("SHOT_DIR") + "/hc_hud.png")
	failed = 2
	_hardcore_check()
	yield(get_tree().create_timer(1.0), "timeout")
	failed = 3
	_hardcore_check()
	yield(get_tree().create_timer(1.0), "timeout")
	print("fired=", hc_fired, " day now=", Game.day, " best=", Game.hc_best, " hardcore=", Game.hardcore)
	_save(OS.get_environment("SHOT_DIR") + "/hc_fired.png")
	get_tree().quit()


func _pet_cat(_b) -> void:
	cat.pet()
	if net_client():
		rpc_id(1, "net_pet_cat")
	elif Net.active:
		rpc("net_pet_cat_fx")


remote func net_pet_cat() -> void:
	if Net.is_host:
		cat.pet()
		rpc("net_pet_cat_fx")


remote func net_pet_cat_fx() -> void:
	if cat and cat.has_method("pet") and get_tree().get_rpc_sender_id() == 1:
		cat.bounce = 1.0
		cat._heart()


func _rare_test(ev: String) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(1.0), "timeout")
	match ev:
		"inspector":
			player.global_transform.origin = Vector3(3.0, 0.05, -0.6)
			player.rotation.y = -PI * 0.7
		"rats":
			player.global_transform.origin = Vector3(3.5, 0.05, -3.0)
			player.rotation.y = -PI * 0.6
		"flood":
			player.global_transform.origin = Vector3(0.5, 0.05, -0.9)
			player.cam.rotation.x = -0.45
	yield(get_tree().create_timer(6.0), "timeout")
	_save(dir + "/rare_%s_1.png" % ev)
	match ev:
		"inspector":
			rare.on_throw()
			print("insp bad=", rare.insp_bad, " money=", money, " watching=", rare.watching())
		"rats":
			yield(get_tree().create_timer(5.0), "timeout")
			_save(dir + "/rare_rats_2.png")
			for r in rare.rats:
				print("rat ", r[2], " carry=", r[1] != null)
		"flood":
			for q in rare.puddles:
				print("puddle ", q[0].global_transform.origin, " tex=", q[0].texture, " vis=", q[0].is_visible_in_tree())
			var pd = rare.puddles[0]
			player.global_transform.origin = pd[1] + Vector3(0, 0.05, 0.5)
			Input.action_press("move_forward")
			yield(get_tree().create_timer(0.5), "timeout")
			Input.action_release("move_forward")
			print("stun=", player.stun_t)
			_save(dir + "/rare_flood_2.png")
		"mimic":
			var n := 0
			for p in parcels:
				if is_instance_valid(p) and p.box_type == "mimic":
					n += 1
			print("mimics=", n)
		"vip":
			for c in customers.duplicate():
				c.leave_with("test", true)
			yield(get_tree().create_timer(14.0), "timeout")
			var v := 0
			for c in customers:
				if is_instance_valid(c) and c.has_meta("vip"):
					v += 1
			print("vip customers=", v, " vip_next=", rare.vip_next)
			_save(dir + "/rare_vip_2.png")
	get_tree().quit()


func _cat_test() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(2.0), "timeout")
	player.global_transform.origin = Vector3(4.8, 0.05, -1.1)
	player.rotation.y = PI
	player.cam.rotation.x = -0.5
	yield(get_tree().create_timer(4.0), "timeout")
	_save(dir + "/cat_sleep.png")
	print("look=", player.looked_thing() != null and player.looked_thing().has_meta("cat"))
	player.press_thing()
	yield(get_tree().create_timer(0.3), "timeout")
	_save(dir + "/cat_pet1.png")
	player.press_thing()
	yield(get_tree().create_timer(0.15), "timeout")
	_save(dir + "/cat_pet2.png")
	for k in 4:
		player.press_thing()
		yield(get_tree().create_timer(0.2), "timeout")
	print("cat state=", cat.state, " angry=", cat.angry_t)
	_save(dir + "/cat_angry.png")
	get_tree().quit()


func _ret_test() -> void:
	# возврат: первый клиент — возвратный с испорченной коробкой; выгоняем; второй — кладём в лоток
	var dir := OS.get_environment("SHOT_DIR")
	var c = null
	for k in 40:
		yield(get_tree().create_timer(0.5), "timeout")
		for w in waiting():
			if w.has_meta("ret_box"):
				c = w
		if c:
			break
	if c == null:
		print("RET: no return customer")
		get_tree().quit()
		return
	var p = c.get_meta("ret_box")
	print("RET order=", c.order, " dmg=", p.get_meta("dmg") if p.has_meta("dmg") else "")
	player.global_transform.origin = Vector3(c.global_transform.origin.x, 0.05, -1.2)
	player.rotation.y = PI
	player.cam.rotation.x = -0.45
	yield(get_tree().create_timer(1.0), "timeout")
	_save(dir + "/ret_counter.png")
	# кладём коробку в лоток
	p.global_transform.origin = returns.TRAY_POS + Vector3(0, 0.4, 0)
	p.linear_velocity = Vector3.ZERO
	yield(get_tree().create_timer(0.6), "timeout")
	_save(dir + "/ret_stamp.png")
	yield(get_tree().create_timer(1.5), "timeout")
	print("RET money=", money, " box gone=", not is_instance_valid(p))
	get_tree().quit()


func _drink_coffee(_b) -> void:
	extras.drink()


func _up_test() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(2.0), "timeout")
	player.global_transform.origin = Vector3(5.4, 0.05, -1.6)
	player.rotation.y = PI + 0.3
	player.cam.rotation.x = -0.2
	yield(get_tree().create_timer(1.0), "timeout")
	_save(dir + "/up_counter.png")
	_drink_coffee(null)
	print("coffee_t=", player.coffee_t, " belt=", fun.belt_speed())
	Game.bank = 5000
	Game.upgrades = {}
	is_open = false
	_open_laptop(null)
	yield(get_tree().create_timer(1.0), "timeout")
	_save(dir + "/up_shop.png")
	get_tree().quit()


func _read_letter(_b) -> void:
	story.open()


func _story_test() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	yield(get_tree().create_timer(2.0), "timeout")
	for d in [2, 19]:
		Game.day = d
		Game.seen_kinds.erase("letter_%d" % d)
		story.on_closed()
		yield(get_tree().create_timer(0.3), "timeout")
		if d == 2:
			player.global_transform.origin = Vector3(0.9, 0.05, -1.0)
			player.rotation.y = PI
			player.cam.rotation.x = -0.5
			yield(get_tree().create_timer(0.5), "timeout")
			_save(dir + "/story_env.png")
		story.open()
		yield(get_tree().create_timer(0.5), "timeout")
		_save(dir + "/story_%d.png" % d)
		story.close()
	get_tree().quit()
