extends Node
# Геймпад (автозагрузка Pad): что сейчас в руках у игрока (мышь/клавиатура или геймпад),
# подсказки с нужными кнопками и управление меню без мыши.

const LOOK_SPEED := 2.6  # рад/с при полностью отклонённом правом стике
const DEADZONE := 0.18

var active := false  # последний ввод был с геймпада


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_set_active(true)
		_menu_focus(event)
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		_set_active(true)
		_menu_focus(event)
	elif (event is InputEventMouseMotion and event.relative.length() > 2.0) or (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
		_set_active(false)


func _set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	if on and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif not on and Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# правый стик: смещение камеры за кадр (x — поворот, y — наклон)
func look_vector(delta: float) -> Vector2:
	var pads := Input.get_connected_joypads()
	if pads.empty():
		return Vector2.ZERO
	var d: int = pads[0]
	var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_2), Input.get_joy_axis(d, JOY_AXIS_3))
	if v.length() < DEADZONE:
		return Vector2.ZERO
	v = v.normalized() * ((v.length() - DEADZONE) / (1.0 - DEADZONE))
	v = v * v.length()  # мягче в центре, быстро у края
	return v * LOOK_SPEED * delta


# меню: если ничего не выбрано, первое нажатие выбирает первую видимую кнопку
func _menu_focus(event: InputEvent) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	var vp := get_viewport()
	if vp.gui_get_focus_owner() != null:
		return
	var b = _first_button(get_tree().root)
	if b:
		b.grab_focus()
		get_tree().set_input_as_handled()


func _first_button(n: Node):
	if n is CanvasItem and not n.is_visible_in_tree():
		return null
	if n is BaseButton and not n.disabled and n.focus_mode != Control.FOCUS_NONE:
		return n
	for ch in n.get_children():
		var r = _first_button(ch)
		if r:
			return r
	return null


func grab_name() -> String:
	return "RT" if active else Settings.bind_name(int(Settings.keys["grab"]))


func place_name() -> String:
	return "LT" if active else Settings.bind_name(int(Settings.keys["place"]))


func interact_name() -> String:
	return "A" if active else Settings.bind_name(int(Settings.keys["interact"]))


# подсказки в тексте пишутся под мышь (ЛКМ/ПКМ/E) — подставляем текущие кнопки
func prompt(t: String) -> String:
	if t == "":
		return t
	var g := grab_name()
	var p := place_name()
	var i := interact_name()
	for k in ["ЛКМ", "LMB"]:
		t = t.replace(k, g)
	for k in ["ПКМ", "RMB"]:
		t = t.replace(k, p)
	t = t.replace("/E]", "/" + i + "]").replace(" E)", " " + i + ")").replace("[E]", "[" + i + "]")
	if active:
		t = t.replace("ESC", "Start").replace("WASD", tr("левый стик")).replace(tr("мышь"), tr("правый стик"))
	return t
