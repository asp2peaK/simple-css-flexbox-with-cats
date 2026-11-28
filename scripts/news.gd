extends Reference
# Кнопка «Новости» в меню: последние обновления на русском и английском.
# Новая версия — добавь запись в начало списка (не больше 5 штук показываем).

const NEWS := [
	["0.15.1", "Моды и полировка",
		"- Поддержка модов: папка mods рядом с игрой, кнопка «Моды» в меню. Можно добавить язык, фразы клиентов или заменить любую картинку и звук.\n- Новая шкала терпения над клиентами с рожицами.\n- Значок улучшения «Краски».\n- Шлем орка и наушники теперь сидят как надо.\n- Аккуратные картинки на коробках возвратов.",
		"Mods and polish",
		"- Mod support: a mods folder next to the game and a Mods button in the menu. Add a language, customer lines, or replace any picture and sound.\n- New patience meter with mood faces above customers.\n- Shelf paints upgrade icon.\n- The orc's helmet and the headphones now fit properly.\n- Neater pictures on returned boxes."],
	["0.15", "Языки и свой склад",
		"- Немецкий и испанский языки. Язык сам берётся из Steam или системы.\n- Стеллажи можно передвигать, пока пункт закрыт (с коробками!).\n- Декор переставляется только туда, где он к месту: цветы на пол, мелочь на стол.\n- Улучшение «Краски для стеллажей»: перекрашивай секции в свои цвета.\n- Зеркало повесили на уровень глаз и починили отражение.\n- Кот теперь лежит прямо в лежанке.\n- Письма дракона написаны от руки.",
		"Languages and your own storeroom",
		"- German and Spanish. The language is picked from Steam or your system.\n- Move shelves while the point is closed (boxes ride along!).\n- Decor only goes where it makes sense: plants on the floor, small things on tables.\n- New upgrade: shelf paints, recolor sections the way you like.\n- The mirror now hangs at eye level and reflects properly.\n- The cat now lies right in its bed.\n- The dragon's letters are handwritten."],
	["0.14", "Большое обновление пункта",
		"- Кота на стойке можно гладить: мурчит, и клиенты становятся терпеливее. Не перегладь!\n- Стол возвратов: клиенты приносят посылки назад. Целую коробку в лоток, испорченную не принимай.\n- Письма от владельца сети, дракона Златочешуя: сюжет на всю карьеру.\n- Редкие события посреди смены: инспектор, крысы, потоп, мимик на полке, VIP-клиент.\n- Новые улучшения: быстрая лента, кофемашина, камера от воров, лежанка для кота.\n- Режим ХАРДКОР: 3 злых клиента за смену, и ты уволен.\n- Геймпад, переназначение всех клавиш (и кнопок мыши), режим стримера.\n- Кооп: можно переподключиться в идущую смену, хост ставит паузу для всех.\n- Лог ошибок пишется в файл (Настройки → Папка с логами).",
		"Big pickup point update",
		"- You can pet the cat on the counter: it purrs and customers get more patient. Don't overdo it!\n- Returns desk: customers bring parcels back. Intact box goes in the tray, damaged ones get refused.\n- Letters from the network owner, the dragon Goldscale: a story across the whole career.\n- Rare mid-shift events: inspector, rats, flood, a mimic on the shelf, a VIP customer.\n- New upgrades: fast belt, coffee machine, security camera, cat bed.\n- HARDCORE mode: 3 angry customers in one shift and you're fired.\n- Gamepad support, rebind every key (and mouse buttons), streamer mode.\n- Co-op: rejoin a running shift, the host's pause pauses everyone.\n- Errors are logged to a file (Settings → Logs folder)."],
	["0.13", "Кооп-хаос",
		"- Огонь по своим: брошенная коробка сбивает напарника с ног.\n- Доска позора в конце кооп-смены: MVP, косорукий, главный обманутый.\n- Грузы на двоих: огромный сундук и коробка с коровой носятся только вместе.\n- Проклятые посылки проклинают носильщика: управление наоборот, большая голова, хрюканье.\n- Событие «Перегрузка портала»: 20 коробок и быстрая лента.\n- Голосование чата Twitch за события.",
		"Co-op chaos",
		"- Friendly fire: a thrown box knocks your teammate down.\n- Wall of shame after a co-op shift: MVP, butterfingers, biggest scam victim.\n- Two-person loads: a huge chest and a cow crate can only be carried together.\n- Cursed parcels curse the carrier: inverted controls, big head, oinking steps.\n- Portal overload event: 20 boxes and a fast belt.\n- Twitch chat votes for events."],
	["0.12", "Демоверсия",
		"- Демо: первые 3 смены и экран со ссылкой на страницу в Steam.\n- Ник по умолчанию берётся из Steam.",
		"Demo",
		"- Demo build: the first 3 shifts and a wishlist screen.\n- Your Steam name is used as the default nickname."],
	["0.11", "Достижения",
		"- 24 достижения: в игре и в Steam.\n- Иконки достижений.\n- Исправлены аксессуары и перекраска персонажа.",
		"Achievements",
		"- 24 achievements, in game and on Steam.\n- Achievement icons.\n- Accessory and recolor fixes."],
	["0.10", "Свой персонаж",
		"- Свой персонаж игрока: внешность, цвета, аксессуары.\n- Зеркало: переодевайся и меняй аксессуары прямо в пункте.\n- Клетка у стены и пара секретов.",
		"Your own character",
		"- Your own player character: looks, colors, accessories.\n- The mirror: change outfits and accessories right in the shop.\n- A cage by the wall and a couple of secrets."],
]


static func build(font: Font, theme: Theme) -> Control:
	var en: bool = Settings.latin()
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.rect_position = Vector2(20, 8)
	panel.rect_min_size = Vector2(600, 344)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "NEWS" if en else "НОВОСТИ"
	title.align = Label.ALIGN_CENTER
	title.add_font_override("font", font)
	load("res://scripts/ui_theme.gd").banner(title)
	v.add_child(title)
	var sc := ScrollContainer.new()
	sc.rect_min_size = Vector2(590, 262)
	sc.scroll_horizontal_enabled = false
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_constant_override("separation", 10)
	sc.add_child(list)
	var plain: DynamicFont = font.duplicate()
	plain.outline_size = 0
	var small: DynamicFont = plain.duplicate()
	small.size = 11
	for k in min(5, NEWS.size()):
		var e: Array = NEWS[k]
		var h := Label.new()
		h.text = "v%s  —  %s" % [e[0], e[3] if en else e[1]]
		h.add_font_override("font", plain)
		h.add_color_override("font_color", Color(0.55, 0.2, 0.08))
		list.add_child(h)
		var b := Label.new()
		b.text = e[4] if en else e[2]
		b.autowrap = true
		b.rect_min_size = Vector2(570, 0)
		b.add_font_override("font", small)
		b.add_color_override("font_color", Color(0.24, 0.14, 0.07))
		list.add_child(b)
	return panel
