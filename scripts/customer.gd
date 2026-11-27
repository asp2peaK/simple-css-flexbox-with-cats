extends Spatial
# Клиент: плоский спрайт в 3D-мире. Подходит к стойке, ждёт посылку, уходит.
# Реплика рисуется в HUD (main.gd проецирует её над головой).

signal left(happy)
signal arrived
signal escaped

var order := ""
var kind := ""
var line := ""
var patience := 40.0
var max_patience := 40.0
var state := "walking_in"
var door := Vector3.ZERO
var slot := -1
var drain_mult := 1.0  # вампир на свету теряет терпение быстрее
var fired := false  # дракончик уже дыхнул огнём
var bubble_label = null
var sprite: Sprite3D
var bubble_text := ""
var bubble_color := Color(1, 1, 1)
var _t := 0.0
var _say_timer := 0.0
var frames := {}
var scammer := false  # мошенник: чужая посылка по поддельному чеку
var fake := ""  # "seal" (кривая печать) или "code" (на чеке другой номер)
var receipt_code := ""
var safe_pin := ""  # код сейфа на чеке (для ценных посылок)
var receipt = null  # узел чека на стойке
var kicked := false
var grabber := false  # вор, который хватает коробки со стойки
var loot = null  # украденная коробка над головой
var mischief := 6.0
var net_id := 0
var remote := false  # копия клиента у гостя: уходит только по команде хоста  # тролль-малыш: таймер пакостей
var base_y := 1.0
var _mood := ""
var _mood_timer := 0.0
const PIXEL := 0.02


func setup(p_kind: String, p_frames: Dictionary, p_order: String, p_line: String, p_patience: float) -> void:
	kind = p_kind
	order = p_order
	line = p_line
	patience = p_patience
	max_patience = p_patience

	frames = p_frames
	sprite = Sprite3D.new()
	sprite.texture = frames["idle"]
	sprite.pixel_size = PIXEL
	base_y = frames["idle"].get_height() * PIXEL / 2.0
	sprite.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.translation.y = base_y
	add_child(sprite)


var _move_tw: SceneTreeTween


func walk_to(p: Vector3, then: String, speed := 1.7) -> void:
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = create_tween()
	_move_tw.tween_property(self, "translation", p, max(0.1, translation.distance_to(p) / speed))
	_move_tw.tween_callback(self, then)


func run_off_with(box) -> void:
	# Вор схватил коробку и бежит к двери
	loot = box
	state = "running"
	voice(false)
	_say(tr("ХА! Моё теперь!"), Color(1, 0.8, 0.3), 99.0)
	walk_to(door, "_escaped", 3.6)


func drop_loot():
	var b = loot
	loot = null
	return b


func _escaped() -> void:
	emit_signal("escaped")
	queue_free()


func leave_kicked(text: String) -> void:
	if state == "leaving":
		return
	kicked = true
	state = "leaving"
	voice(true)
	set_mood("angry", 99.0)
	_say(text, Color(1, 0.6, 0.3), 99.0)
	emit_signal("left", false)
	walk_to(door, "queue_free", 2.6)


func arrive() -> void:
	state = "at_counter"
	emit_signal("arrived")
	voice(false)


func voice(angry: bool) -> void:
	var n: String = ("angry_" if angry else "voice_") + kind
	Sfx.play_at(n, global_transform.origin + Vector3(0, 1.6, 0), 0.08, 2.0)


func reject() -> void:
	patience -= 6.0
	Sfx.play("reject", 0.0, -4.0)
	voice(true)
	set_mood("angry", 1.6)
	_say(tr("Это не моё!"), Color(1, 0.4, 0.3), 1.6)


func on_hit() -> void:
	# Попали коробкой в лицо
	Sfx.play_at("bonk", global_transform.origin + Vector3(0, 1.6, 0), 0.1, 4.0)
	voice(kind != "orc")
	var tw := create_tween()
	sprite.modulate = Color(1, 0.3, 0.3)
	tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.6)
	var tw2 := create_tween()
	tw2.tween_property(sprite, "translation:x", 0.15, 0.05)
	tw2.tween_property(sprite, "translation:x", -0.15, 0.08)
	tw2.tween_property(sprite, "translation:x", 0.0, 0.05)
	set_mood("happy" if kind == "orc" else "angry", 2.0)
	if kind == "orc":
		patience = min(max_patience, patience + 10.0)
		_say(tr("ХА! КРЕПКО! ОРК УВАЖАТЬ!"), Color(0.5, 1, 0.5), 2.0)
	else:
		patience -= 15.0
		var lines := [tr("АЙ! Ты чё творишь?!"), tr("МОЁ ЛИЦО!!"), tr("Я на тебя жалобу напишу!"), tr("Это так у вас выдают?!")]
		_say(lines[randi() % lines.size()], Color(1, 0.35, 0.3), 2.0)


func leave(happy: bool) -> void:
	if state == "leaving":
		return
	state = "leaving"
	voice(not happy)
	set_mood("happy" if happy else "angry", 99.0)
	if happy:
		_say(tr("Спасибо, дорогуша!"), Color(0.5, 1, 0.5), 99.0)
	else:
		_say(tr("Безобразие! Отзыв напишу!"), Color(1, 0.35, 0.3), 99.0)
	emit_signal("left", happy)
	walk_to(door, "queue_free")


func set_mood(m: String, dur: float) -> void:
	_mood = m
	_mood_timer = dur


func _frame(name: String) -> Texture:
	if frames.has(name):
		return frames[name]
	return frames["idle"]


func _update_frame() -> void:
	var f := "idle"
	var walking := state != "at_counter"
	if _mood_timer > 0.0:
		f = _mood
	elif state == "at_counter" and patience < max_patience * 0.25:
		f = "angry"
	# Цикл шагов: левая нога, правая нога, без кадра «стоя» между ними
	var step := int(_t / 0.22) % 2
	var second := walking and step == 1
	if walking and _mood_timer <= 0.0:
		f = "walk"
	elif walking and state == "leaving":
		f = "walk"
	if state == "running" and frames.has("run"):
		f = "run" if step == 1 else "walk"
		second = false
	# Уходит: показываем спину, если она нарисована
	if (state == "leaving" or state == "running") and frames.has("back") and f != "run":
		f = "back_walk" if (f == "walk" and frames.has("back_walk")) else "back"
	# Второй шаг: отдельный кадр, если нарисован, иначе зеркалим
	sprite.flip_h = false
	if second and (f == "walk" or f == "back_walk"):
		if frames.has(f + "2"):
			f = f + "2"
		else:
			sprite.flip_h = true
	sprite.texture = _frame(f)
	# у новых клиентов пока нет кадра злости: краснеют
	if f == "angry" and not frames.has("angry"):
		sprite.modulate = Color(1, 0.55, 0.5)
	elif not frames.has("angry") and sprite.modulate != Color(1, 1, 1) and f != "angry":
		sprite.modulate = Color(1, 1, 1)


func scare() -> void:
	# Рядом бахнула взрывная посылка
	if state == "leaving":
		return
	patience -= 10.0
	set_mood("angry", 2.0)
	voice(true)
	_say(tr("ВЫ ТАМ С УМА СОШЛИ?!"), Color(1, 0.35, 0.3), 2.0)


func leave_with(text: String, happy_face: bool) -> void:
	# Посылку забрал, но со своей репликой (разбитая, подарок)
	if state == "leaving":
		return
	state = "leaving"
	voice(not happy_face)
	set_mood("happy" if happy_face else "angry", 99.0)
	_say(text, Color(0.5, 1, 0.5) if happy_face else Color(1, 0.6, 0.3), 99.0)
	emit_signal("left", true)
	walk_to(door, "queue_free")


func _say(t: String, col: Color, dur: float) -> void:
	bubble_text = t
	bubble_color = col
	_say_timer = dur


func _process(delta: float) -> void:
	_t += delta
	if loot and is_instance_valid(loot):
		loot.global_transform.origin = global_transform.origin + Vector3(0, base_y * 2.0 + 0.3, 0)
	if _mood_timer > 0.0:
		_mood_timer -= delta
	_update_frame()
	var float_y := 0.15 + sin(_t * 2.5) * 0.08 if kind == "ghost" else 0.0
	if state == "at_counter":
		sprite.translation.y = base_y + float_y + sin(_t * 2.0) * 0.015
		patience -= delta * drain_mult
		if remote:
			patience = max(patience, 0.5)
		elif patience <= 0.0:
			leave(false)
			return
	else:
		var sp := 16.0 if state == "running" else 9.0
		sprite.translation.y = base_y + float_y + abs(sin(_t * sp)) * 0.04

	if _say_timer > 0.0:
		_say_timer -= delta
		return
	if state == "at_counter":
		var k := patience / max_patience
		var n := int(ceil(k * 8.0))
		var bar := ""
		for i in 8:
			bar += "■" if i < n else "□"
		bubble_text = "%s\n%s" % [line, bar]
		bubble_color = Color(1, 1, 1).linear_interpolate(Color(1, 0.3, 0.2), 1.0 - k)
	elif state == "walking_in":
		bubble_text = "..."
		bubble_color = Color(0.8, 0.8, 0.8)
