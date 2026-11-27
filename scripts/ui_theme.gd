extends Reference
# Стиль интерфейса из листа 46: деревянные кнопки, пергаментные окна, вкладки-картонки.
# Если картинок нет — простые цветные плашки в тех же тонах.

const KIT := "res://assets/ui/kit/%s.png"
const TEXT_DARK := Color(0.24, 0.14, 0.07)
const TEXT_LIGHT := Color(1.0, 0.95, 0.82)


static func has_kit() -> bool:
	return ResourceLoader.exists(KIT % "btn_normal")


static func tex(name: String) -> Texture:
	var t: Texture = load(KIT % name)
	t.flags = 0
	return t


static func box(name: String, m: Array, c: Array) -> StyleBox:
	# m — края, которые не растягиваются (лево, верх, право, низ); c — отступы для текста
	if not ResourceLoader.exists(KIT % name):
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.45, 0.28, 0.16) if name.begins_with("btn") else Color(0.93, 0.85, 0.66)
		if name == "btn_hover":
			f.bg_color = Color(0.58, 0.37, 0.2)
		elif name == "btn_pressed":
			f.bg_color = Color(0.33, 0.2, 0.11)
		elif name == "btn_disabled":
			f.bg_color = Color(0.45, 0.43, 0.42)
		f.border_color = Color(0.15, 0.08, 0.04)
		f.set_border_width_all(2)
		f.set_corner_radius_all(3)
		f.content_margin_left = c[0]
		f.content_margin_top = c[1]
		f.content_margin_right = c[2]
		f.content_margin_bottom = c[3]
		return f
	var s := StyleBoxTexture.new()
	s.texture = tex(name)
	s.margin_left = m[0]
	s.margin_top = m[1]
	s.margin_right = m[2]
	s.margin_bottom = m[3]
	s.content_margin_left = c[0]
	s.content_margin_top = c[1]
	s.content_margin_right = c[2]
	s.content_margin_bottom = c[3]
	return s


static func make() -> Theme:
	var th := Theme.new()
	var bm := [9, 8, 9, 8]
	var bc := [12, 4, 12, 5]
	for t in ["Button", "OptionButton", "CheckBox"]:
		if t != "CheckBox":
			th.set_stylebox("normal", t, box("btn_normal", bm, bc))
			th.set_stylebox("hover", t, box("btn_hover", bm, bc))
			th.set_stylebox("pressed", t, box("btn_pressed", bm, bc))
			th.set_stylebox("disabled", t, box("btn_disabled", bm, bc))
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_color("font_color", t, TEXT_LIGHT)
		th.set_color("font_color_hover", t, Color(1, 0.86, 0.45))
		th.set_color("font_color_pressed", t, Color(0.95, 0.8, 0.55))
		th.set_color("font_color_disabled", t, Color(0.92, 0.9, 0.86))
	# галочки — на пергаменте, текст тёмный
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		th.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	th.set_color("font_color", "CheckBox", TEXT_DARK)
	th.set_color("font_color_hover", "CheckBox", Color(0.5, 0.25, 0.1))
	th.set_color("font_color_pressed", "CheckBox", TEXT_DARK)
	if has_kit():
		th.set_icon("checked", "CheckBox", tex("check_on"))
		th.set_icon("unchecked", "CheckBox", tex("check_off"))
		th.set_icon("grabber", "HSlider", tex("knob"))
		th.set_icon("grabber_highlight", "HSlider", tex("knob"))
	th.set_stylebox("slider", "HSlider", box("slider", [8, 6, 8, 6], [0, 6, 0, 6]))
	var ga := StyleBoxEmpty.new()
	th.set_stylebox("grabber_area", "HSlider", ga)
	th.set_stylebox("grabber_area_highlight", "HSlider", ga)
	th.set_stylebox("panel", "PanelContainer", box("panel", [14, 14, 14, 14], [16, 14, 16, 14]))
	th.set_stylebox("panel", "PopupMenu", box("panel", [14, 14, 14, 14], [10, 8, 10, 8]))
	th.set_color("font_color", "PopupMenu", TEXT_DARK)
	th.set_color("font_color_hover", "PopupMenu", Color(0.6, 0.2, 0.1))
	th.set_stylebox("hover", "PopupMenu", box("btn_hover", bm, [4, 2, 4, 2]))
	th.set_color("font_color", "Label", TEXT_DARK)
	th.set_stylebox("normal", "LineEdit", box("check_off", [5, 5, 5, 5], [6, 4, 6, 4]))
	th.set_stylebox("focus", "LineEdit", box("check_off", [5, 5, 5, 5], [6, 4, 6, 4]))
	th.set_color("font_color", "LineEdit", TEXT_DARK)
	th.set_color("cursor_color", "LineEdit", TEXT_DARK)
	return th


# вкладка магазина: активная — со штампом
static func tab_style(b: Button, active: bool) -> void:
	var s := box("tab_active" if active else "tab", [10, 14, 10, 8], [12, 12, 12, 5])
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_stylebox_override(st, s)
	b.add_color_override("font_color", TEXT_DARK)
	b.add_color_override("font_color_hover", Color(0.55, 0.2, 0.08))
	b.add_color_override("font_color_disabled", TEXT_DARK)


# заголовок на красной ленте
static func banner(l: Label) -> void:
	l.add_stylebox_override("normal", box("banner", [20, 6, 20, 6], [26, 4, 26, 5]))
	l.add_color_override("font_color", TEXT_LIGHT)
