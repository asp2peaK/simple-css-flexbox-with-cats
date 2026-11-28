extends Node
# Новые улучшения v0.14, которым нужен предмет в мире: кофемашина, камера, лежанка для кота.

var main
var coffee_used := false
var cam_on := false
var _t := 0.0


func setup(p_main) -> void:
	main = p_main
	if Game.lvl("coffee") > 0:
		var cm: Sprite3D = _icon_prop("up_coffee", Vector3(6.35, 0.98, -0.15), 0.42)
		if cm:
			main._clickable(cm, Vector3(0.16, 0.2, 0.16), tr("[ЛКМ/E] Кофемашина: чашка кофе (15 с бега, раз за смену)"), "_drink_coffee")
	if Game.lvl("camera") > 0:
		cam_on = true
		_icon_prop("up_camera", Vector3(6.75, 2.75, -0.6), 0.35)
	if Game.lvl("catbed") > 0 and main.cat and main.cat.spr:
		var bed: Sprite3D = _icon_prop("up_catbed", Vector3(4.8, 0.98, -0.24), 0.3)
		if bed:
			# кот лежит в лежанке: лежанка спереди, кот чуть выше и за ней
			main.cat.base_pos.y += 0.15
			main.cat.spr.translation.y += 0.15


func _icon_prop(name: String, pos: Vector3, h: float) -> Sprite3D:
	if not ResourceLoader.exists("res://assets/ui/%s.png" % name):
		return null
	var s := Sprite3D.new()
	var t: Texture = load("res://assets/ui/%s.png" % name)
	t.flags = 0
	s.texture = t
	s.pixel_size = h / t.get_height()
	s.billboard = SpatialMaterial.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.translation = pos + Vector3(0, h / 2.0, 0)
	main.add_child(s)
	return s


func drink() -> void:
	if coffee_used:
		main._flash(tr("Кофе на сегодня всё. Завтра ещё."), 1.5)
		return
	coffee_used = true
	main.player.coffee_t = 15.0
	Sfx.play("coffee", 0.05, -2.0)
	main._flash(tr("Кофе! 15 секунд бегаешь быстрее."), 2.0)


func _process(delta: float) -> void:
	if not cam_on:
		return
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * 6.0)
	var red := Color(1, 1, 1).linear_interpolate(Color(1, 0.35, 0.35), k)
	for c in main.customers:
		if is_instance_valid(c) and c.kind == "thief" and c.sprite:
			c.sprite.modulate = red
	for p in main.parcels:
		if is_instance_valid(p) and p.box_type == "mimic" and not p.delivered and p._mat:
			p._mat.albedo_color = red
