extends Spatial
# Звёздочки над головой оглушённого: 3 штуки кружат и мигают (кадры assets/fx/star_N.png, если нарисованы).

var _t := 0.0
var stars := []
var frames := []


static func star_texture() -> Texture:
	# запасная звёздочка, нарисованная кодом (пока нет арта)
	var img := Image.new()
	img.create(15, 15, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in 15:
		for x in 15:
			var d := Vector2(x - 7, y - 7)
			var a := atan2(d.y, d.x) + PI / 2.0
			var r := 3.0 + 4.5 * pow(abs(cos(a * 2.5)), 3.0)
			if d.length() <= r:
				var c := Color(1, 0.88, 0.2) if d.length() < r - 1.2 else Color(0.35, 0.2, 0.05)
				img.set_pixel(x, y, c)
	img.unlock()
	var t := ImageTexture.new()
	t.create_from_image(img, 0)
	return t


func _ready() -> void:
	for k in 4:
		var p: String = "res://assets/fx/star_%d.png" % k
		if ResourceLoader.exists(p):
			var t: Texture = load(p)
			t.flags = 0
			frames.append(t)
	if frames.empty():
		frames.append(star_texture())
	for k in 3:
		var s := Sprite3D.new()
		s.texture = frames[0]
		s.pixel_size = 0.018
		s.billboard = SpatialMaterial.BILLBOARD_ENABLED
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.render_priority = 5
		add_child(s)
		stars.append(s)


func _process(delta: float) -> void:
	_t += delta
	for k in stars.size():
		var a: float = _t * 4.0 + k * TAU / 3.0
		var s: Sprite3D = stars[k]
		s.translation = Vector3(cos(a) * 0.32, sin(_t * 6.0 + k) * 0.05, sin(a) * 0.32)
		s.texture = frames[int(_t * 8.0 + k) % frames.size()]
