extends Node
# Состояние игры между сменами (автозагрузка Game): день, касса, улучшения, сохранение.

const SAVE_PATH := "user://save.json"
const VERSION := "0.9.1"

# id: [название, описание, макс. уровень, цены по уровням]
const UPGRADES := {
	"cart": ["Тележка", "+1 коробка в руки за раз", 2, [60, 140]],
	"patience": ["Табличка «Мы стараемся»", "Клиенты ждут на 20% дольше", 2, [50, 120]],
	"sorter": ["Волшебная подсветка", "Нужная посылка светится", 1, [90]],
	"amulet": ["Амулет от проклятий", "Проклятые прыгают в 3 раза реже", 1, [70]],
	"shoes": ["Кроссовки скорохода", "Бегаешь на 25% быстрее", 2, [60, 130]],
	"bell": ["Медный колокольчик", "Злые клиенты штрафуют на 2 меньше", 1, [40]],
	"window": ["Окно выдачи", "+1 окно: больше клиентов и денег", 2, [80, 170]],
	"shelf": ["Новый стеллаж", "+12 мест на складе", 3, [50, 110, 180]],
	"expand": ["Снести стену склада", "Склад в 2 раза больше", 1, [150]],
	"freezer": ["Морозильный ларь", "Замороженные посылки (дороже)", 1, [100]],
	"golem": ["Голем-охранник", "Ловит воров, держит проклятые", 1, [200]],
	"helper": ["Гоблин-помощник", "Сам носит посылки (иногда ворует)", 1, [220]],
}
const ORDER := ["window", "shelf", "expand", "cart", "shoes", "patience", "sorter", "freezer",
	"amulet", "bell", "golem", "helper"]

var day := 1
var bank := 0
var upgrades := {}
var seen_kinds := []
var tutorial_done := false
var splash_done := false  # заставка студии показана в этом запуске
var event := ""  # событие текущей смены
var mode := "career"  # career / chaos
var rep := 50  # репутация пункта 0..100
var tokens := 0  # жетоны за задания дня
var decor := {}  # купленный декор: id -> true
var record := ""  # пластинка на проигрывателе ("" = обычная музыка)
var tasks := []  # задания текущей смены
var tasks_day := 0
var career_done := false
var phase := "open"  # closed = пункт закрыт между сменами
var decor_pos := {}  # куда игрок переставил декор: ключ -> [x, y, z]
var last_reviews := []  # отзывы прошлой смены (для доски объявлений)
var chaos_best := 0
var _backup := {}

const CAREER_DAYS := 30
# Районы по 5 смен: название, музыка, свет, туман, любимые клиенты, частые посылки, частое событие
const DISTRICTS := [
	{"name": "Деревня Тихие Ухабы", "music": "music_game", "amb": Color(0.55, 0.5, 0.6),
		"fog": Color(0.12, 0.09, 0.1), "kinds": [], "boxes": [], "event": ""},
	{"name": "Гнилое Болото", "music": "music_swamp", "amb": Color(0.45, 0.62, 0.42),
		"fog": Color(0.07, 0.13, 0.06), "kinds": ["witch", "goblin", "troll", "dragon"],
		"boxes": ["cursed", "living"], "event": "rush"},
	{"name": "Старое Кладбище", "music": "music_crypt", "amb": Color(0.42, 0.44, 0.66),
		"fog": Color(0.05, 0.05, 0.12), "kinds": ["skeleton", "ghost", "vampire", "werewolf"],
		"boxes": ["mimic", "timer"], "event": "blackout"},
	{"name": "Королевский Замок", "music": "music_castle", "amb": Color(0.7, 0.6, 0.45),
		"fog": Color(0.14, 0.1, 0.05), "kinds": ["king", "dwarf", "thief", "orc"],
		"boxes": ["gift", "chest"], "event": "inspector"},
	{"name": "Ледяные Горы", "music": "music_ice", "amb": Color(0.55, 0.66, 0.82),
		"fog": Color(0.12, 0.15, 0.2), "kinds": ["giant", "dwarf", "troll", "orc"],
		"boxes": ["frozen", "heavy"], "event": ""},
	{"name": "Логово Тёмного Почтмейстера", "music": "music_boss", "amb": Color(0.6, 0.36, 0.52),
		"fog": Color(0.1, 0.02, 0.06), "kinds": ["vampire", "thief", "werewolf", "king"],
		"boxes": ["cursed", "explosive", "mimic"], "event": "blackout"},
]


func lvl(id: String) -> int:
	var l := int(upgrades.get(id, 0))
	if id == "freezer" and district_idx() == 4:
		l = int(max(l, 1))  # в Ледяных Горах ларь выдают бесплатно
	return l


# номер посылки для показа: в английской версии латиницей
func disp(code: String) -> String:
	if Settings.lang != "en" or code.length() < 1:
		return code
	var m := {"А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "К": "K", "М": "M"}
	var first: String = code.substr(0, 1)
	return m.get(first, first) + code.substr(1)


func bought(id: String) -> int:
	return int(upgrades.get(id, 0))


func district_idx() -> int:
	if mode == "chaos":
		return 5
	return int(min(DISTRICTS.size() - 1, (day - 1) / 5))


func district() -> Dictionary:
	return DISTRICTS[district_idx()]


func is_boss_day() -> bool:
	return mode == "career" and day == CAREER_DAYS


func pay_mult() -> float:
	if mode == "chaos":
		return 1.0
	return 0.8 + rep * 0.004


# репутация после смены; true = пункт закрыли
func add_rep(d: int) -> bool:
	rep = int(clamp(rep + d, 0, 100))
	if rep <= 0 and mode == "career":
		day = int(max(1, district_idx() * 5 + 1))
		rep = 30
		return true
	return false


func start_chaos() -> void:
	_backup = {"day": day, "bank": bank, "upgrades": upgrades.duplicate(), "event": event, "rep": rep,
		"tasks": tasks.duplicate(), "tasks_day": tasks_day}
	mode = "chaos"
	day = 12
	bank = 0
	upgrades = {"window": 2, "shelf": 3, "expand": 1, "cart": 2, "shoes": 2, "freezer": 1, "sorter": 1}
	event = "rush"
	tasks = []


func end_chaos(score: int) -> void:
	if mode != "chaos":
		return
	mode = "career"
	for k in _backup:
		set(k, _backup[k])
	_backup = {}
	chaos_best = int(max(chaos_best, score))
	save_game()


func price(id: String) -> int:
	var l := bought(id)
	var prices: Array = UPGRADES[id][3]
	if l >= prices.size():
		return -1
	return prices[l]


# что мешает купить (пустая строка, если можно)
func blocked(id: String) -> String:
	if id == "shelf" and lvl("shelf") >= 1 and lvl("expand") == 0:
		return tr("сначала снеси стену")
	return ""


func windows() -> int:
	return 1 + lvl("window")


func shelves() -> int:
	return 1 + lvl("shelf")


func buy(id: String) -> bool:
	var p := price(id)
	if p < 0 or bank < p or blocked(id) != "":
		return false
	bank -= p
	upgrades[id] = bought(id) + 1
	save_game()
	return true


func customers_total() -> int:
	if mode == "chaos":
		return 24
	var n := 3 + int(min(day, 14)) + 3 * windows()
	if event == "rush":
		n += 4
	return n


func max_at_once() -> int:
	return windows()


func patience() -> float:
	if mode == "chaos":
		return 32.0  # хаос: суета от посылок, а не от нервных клиентов
	var p: float = max(22.0, 50.0 - day * 4.0) * (1.0 + 0.2 * lvl("patience"))
	if event == "rush":
		p *= 0.8
	return p


func carry_capacity() -> int:
	return 1 + lvl("cart")


func roll_event() -> void:
	event = ""
	if mode == "chaos" or is_boss_day():
		return
	var fav: String = district()["event"]
	if day >= 2 and randf() < 0.55:
		event = ["blackout", "rush", "inspector"][randi() % 3]
		if fav != "" and randf() < 0.4:
			event = fav


func new_game() -> void:
	day = 1
	bank = 0
	upgrades = {}
	seen_kinds = []
	tutorial_done = false
	event = ""
	mode = "career"
	rep = 50
	tokens = 0
	decor = {}
	record = ""
	tasks = []
	tasks_day = 0
	career_done = false
	decor_pos = {}
	last_reviews = []


func has_save() -> bool:
	return File.new().file_exists(SAVE_PATH)


func save_game() -> void:
	if Net.active and not Net.is_host:
		return  # в гостях у хоста свой сейв не трогаем
	if mode == "chaos":
		return  # хаос не трогает карьеру
	var f := File.new()
	if f.open(SAVE_PATH, File.WRITE) != OK:
		return
	f.store_string(to_json({"day": day, "bank": bank, "upgrades": upgrades,
		"seen_kinds": seen_kinds, "tutorial_done": tutorial_done, "rep": rep, "tokens": tokens,
		"decor": decor, "record": record, "tasks": tasks, "tasks_day": tasks_day,
		"career_done": career_done, "chaos_best": chaos_best, "decor_pos": decor_pos,
		"last_reviews": last_reviews}))
	f.close()


func load_game() -> bool:
	var f := File.new()
	if not f.file_exists(SAVE_PATH) or f.open(SAVE_PATH, File.READ) != OK:
		return false
	var d = parse_json(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return false
	day = int(d.get("day", 1))
	bank = int(d.get("bank", 0))
	upgrades = d.get("upgrades", {})
	seen_kinds = d.get("seen_kinds", [])
	tutorial_done = bool(d.get("tutorial_done", false))
	rep = int(d.get("rep", 50))
	tokens = int(d.get("tokens", 0))
	decor = d.get("decor", {})
	record = str(d.get("record", ""))
	tasks = d.get("tasks", [])
	tasks_day = int(d.get("tasks_day", 0))
	career_done = bool(d.get("career_done", false))
	chaos_best = int(d.get("chaos_best", 0))
	decor_pos = d.get("decor_pos", {})
	last_reviews = d.get("last_reviews", [])
	mode = "career"
	return true
