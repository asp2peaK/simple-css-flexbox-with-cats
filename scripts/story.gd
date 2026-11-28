extends Node
# Сюжетные записки от владельца сети пунктов, дракона Златочешуя (Goldscale).
# В закрытой фазе на стойке появляется конверт; клик — письмо с портретом. Только одиночная карьера.

const ENVELOPE_POS := Vector3(0.9, 0.98, -0.2)
# день: [настроение портрета 0 доволен / 1 зол / 2 хитрый, текст]
const LETTERS := {
	2: [0, "Работник!\n\nЯ Златочешуй, владелец сети пунктов «Край света» и всего, что блестит в радиусе ста миль.\n\nВчера ты не уронил ни одной стены. Это уже лучше, чем прошлый работник. Продолжай.\n\nP.S. Кота не продавай. Он древнее меня."],
	4: [2, "Работник!\n\nКлиенты жалуются, что ты кидаешь посылки. Я тоже кидал посылки, когда был молод. Однажды докинул до соседнего королевства.\n\nКидай, но в руки. Не в лицо. Лицо клиента — это наши деньги."],
	6: [1, "РАБОТНИК!\n\nМы переезжаем на Гнилое Болото. Не спрашивай почему. Это связано с налогами, одной ведьмой и моим плохим настроением.\n\nСапоги не снимай. Там что-то шевелится."],
	9: [2, "Работник!\n\nНа болоте кто-то скупает наши проклятые посылки. Все до одной. Платит чёрными монетами, холодными, как лёд.\n\nДеньги я взял. Но мне это не нравится. Почти."],
	11: [1, "РАБОТНИК!\n\nКладбище. Да, теперь мы на кладбище. Клиенты тут тихие, но некоторые уже мёртвые, учти это при выдаче.\n\nЧёрные монеты опять пришли. С запиской: «Скоро». Скоро ЧТО? Я дракон, я не люблю загадки, я люблю ответы и золото."],
	14: [0, "Работник!\n\nЗа месяц твой пункт заработал больше, чем все остальные мои пункты вместе. Я плакал. Драконьи слёзы — это расплавленное золото, так что я ещё и заработал.\n\nПремию не дам. Но горжусь."],
	16: [2, "Работник!\n\nКоролевский Замок! Король лично просил открыть пункт у его ворот. Он заказывает себе посылки от себя же, чтобы казалось, что его кто-то любит.\n\nБудь вежлив. И следи за ворами: в замке их больше, чем стражи."],
	19: [1, "РАБОТНИК!\n\nЯ выяснил, кто платит чёрными монетами. Тёмный Почтмейстер. Тот самый, что тысячу лет не получал ни одной своей посылки и потому ненавидит всех почтальонов.\n\nОн скупает наши посылки, чтобы мы разорились. Не дождётся."],
	21: [0, "Работник!\n\nЛедяные Горы. Холодно, я знаю. Я подложил тебе в ящик тёплые носки. Не благодари, это носки моей бабушки, она была ледяным драконом и не мёрзла, так что носки бесполезны.\n\nЗато великаны тут щедрые."],
	24: [2, "Работник!\n\nПочтмейстер прислал ещё одну записку. В ней сказано: «Я жду свои посылки. Тысячу лет жду». И адрес. Его логово.\n\nЯ подумал... а что если просто отдать ему посылки? Безумие. Но я дракон, мне можно."],
	26: [1, "РАБОТНИК!\n\nМы открываемся прямо в Логове Тёмного Почтмейстера. Я договорился. Не спрашивай, сколько это стоило. Много. Очень много. Я лёг на своё золото и понял, что его стало меньше, и мне было больно.\n\nТвоя задача: выдать ему ВСЁ. Каждую посылку. Без ошибок."],
	29: [0, "Работник!\n\nЗавтра последняя смена. Если Почтмейстер получит все свои посылки, проклятие спадёт, и он наконец перестанет пугать почтальонов по всем королевствам.\n\nЯ в тебя верю. Это странное чувство. Обычно я верю только в золото.\n\n— Златочешуй"],
	31: [0, "Работник!\n\nТы сделал это. Почтмейстер прислал мне цветы. Чёрные, но цветы.\n\nПункт теперь твой. Я оставлю себе только 90% прибыли, потому что я щедрый дракон.\n\nКота всё равно не продавай."],
}

var main
var env: Sprite3D
var panel: Control
var _day := 0


func setup(p_main) -> void:
	main = p_main


func enabled() -> bool:
	return Game.mode == "career" and not Net.active and (Game.tutorial_done or "--storytest" in OS.get_cmdline_args())


# пункт закрылся: если для этой смены есть письмо и его ещё не читали — конверт на стойке
func on_closed() -> void:
	if not enabled():
		return
	var d := Game.day
	if Game.career_done and Game.day > Game.CAREER_DAYS:
		d = 31
	if not LETTERS.has(d) or ("letter_%d" % d) in Game.seen_kinds:
		return
	_day = d
	if env and is_instance_valid(env):
		env.queue_free()
	var name := "envelope" if ResourceLoader.exists("res://assets/props/envelope.png") else "receipt"
	env = main.prop(name, ENVELOPE_POS, 0, 0.14, true)
	main._clickable(env, Vector3(0.14, 0.1, 0.1), tr("[ЛКМ/E] Письмо от владельца сети"), "_read_letter")
	Sfx.play("paper", 0.1, -6.0)


func open() -> void:
	if _day == 0:
		return
	if not ("letter_%d" % _day) in Game.seen_kinds:
		Game.seen_kinds.append("letter_%d" % _day)
		Game.save_game()
	if env and is_instance_valid(env):
		env.queue_free()
	Sfx.play("paper", 0.05, 0.0)
	_show(_day)


func _show(d: int) -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
	var root: Control = main.hud_center.get_parent()
	panel = Control.new()
	panel.pause_mode = Node.PAUSE_MODE_PROCESS
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	panel.set_meta("keep", true)  # письмо видно и в трейлере
	root.add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1
	dim.anchor_bottom = 1
	panel.add_child(dim)
	var paper := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/letter.png"):
		paper.texture = load("res://assets/ui/letter.png")
		paper.expand = true
		paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.rect_position = Vector2(200, 8)
	paper.rect_size = Vector2(250, 336)
	panel.add_child(paper)
	var e: Array = LETTERS[d]
	var face := TextureRect.new()
	var fp := "res://assets/ui/owner_%d.png" % int(e[0])
	if ResourceLoader.exists(fp):
		face.texture = load(fp)
	face.rect_position = Vector2(88, 40)
	panel.add_child(face)
	var nm := Label.new()
	nm.text = tr("Златочешуй,\nвладелец сети")
	nm.align = Label.ALIGN_CENTER
	nm.add_font_override("font", main.font_small if main.get("font_small") else main.font_big)
	panel.add_child(nm)
	nm.rect_position = Vector2(80, 140)
	nm.rect_size = Vector2(118, 30)
	var txt := Label.new()
	txt.text = tr(e[1])
	txt.autowrap = true
	txt.add_font_override("font", letter_font(txt.text, 210.0, 200.0))
	txt.add_color_override("font_color", Color(0.25, 0.15, 0.08))
	panel.add_child(txt)
	txt.rect_position = Vector2(220, 28)
	txt.rect_min_size = Vector2(210, 0)
	txt.rect_size = Vector2(210, 200)
	# Caveat тонковат: лёгкая тень на полпикселя вбок делает чернила чуть жирнее
	txt.add_color_override("font_color_shadow", Color(0.25, 0.15, 0.08, 0.45))
	txt.add_constant_override("shadow_offset_x", 1)
	txt.add_constant_override("shadow_offset_y", 0)
	var ok := Button.new()
	ok.text = tr("Закрыть")
	ok.add_font_override("font", main.font_big)
	ok.rect_position = Vector2(280, 318)
	ok.connect("pressed", self, "close")
	panel.add_child(ok)
	main.ui_block = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ok.call_deferred("grab_focus")


# рукописный шрифт письма (Caveat, OFL): крупнее, но уменьшаем, пока текст не влезет в лист
func letter_font(text: String, w: float, h: float) -> DynamicFont:
	var f := DynamicFont.new()
	if ResourceLoader.exists("res://fonts/Caveat.ttf"):
		f.font_data = load("res://fonts/Caveat.ttf")
	else:
		f = (main.font_small if main.get("font_small") else main.font_big).duplicate()
		f.outline_size = 0
		return f
	f.use_filter = true
	f.extra_spacing_top = -3
	for sz in [19, 18, 17, 16, 15, 14, 13]:
		f.size = sz
		var lines := 0
		for para in text.split("\n"):
			lines += max(1, int(ceil(f.get_string_size(para).x / (w - 28.0))))
		if lines * f.get_height() <= h:
			break
	return f


func close() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null
	main.ui_block = main.carrying != null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func is_open() -> bool:
	return panel != null and is_instance_valid(panel)
