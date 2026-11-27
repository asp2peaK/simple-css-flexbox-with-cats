extends Spatial
# Помощник (голем или гоблин-работник): спрайт, который ходит по точкам и несёт коробку.

signal arrived

var frames := {}
var sprite: Sprite3D
var base_y := 1.0
var carry = null  # коробка над головой
var busy := false
var pose := ""  # особая поза: hold/point/steal, иначе idle/walk
var bubble_text := ""
var bubble_color := Color(1, 1, 1)
var _say_timer := 0.0
var _t := 0.0
var _walking := false
var _tw: SceneTreeTween
var _last_pos := Vector3.ZERO
var _away := false  # идёт от камеры: показываем спину
const PIXEL := 0.02


func setup(p_frames: Dictionary) -> void:
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


func go(points: Array, speed := 2.0) -> void:
	# идёт по точкам по очереди, в конце шлёт arrived
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	var from := translation
	for p in points:
		_tw.tween_property(self, "translation", p, max(0.05, from.distance_to(p) / speed))
		from = p
	_tw.tween_callback(self, "_done")
	_walking = true


func _done() -> void:
	_walking = false
	emit_signal("arrived")


func say(t: String, col := Color(1, 1, 1), dur := 2.0) -> void:
	bubble_text = t
	bubble_color = col
	_say_timer = dur


func _process(delta: float) -> void:
	_t += delta
	if _say_timer > 0.0:
		_say_timer -= delta
		if _say_timer <= 0.0:
			bubble_text = ""
	var mv := translation - _last_pos
	_last_pos = translation
	var cam := get_viewport().get_camera()
	if _walking and cam and mv.length() > 0.0005:
		var to_me := global_transform.origin - cam.global_transform.origin
		_away = mv.dot(to_me) > 0.0  # уходит от камеры: видим спину
	var back := _walking and _away and frames.has("back")
	var f := "idle"
	if pose != "" and frames.has(pose):
		f = pose
	elif carry and frames.has("carry"):
		f = "back_carry" if back and frames.has("back_carry") else "carry"
	elif back:
		f = "back"
	sprite.flip_h = false
	if _walking:
		var step := int(_t / 0.22) % 2
		var base := f
		if f == "idle":
			base = "walk"
		elif f == "back":
			base = "back_walk"
		var second := step == 1
		if base == "carry":
			f = "carry2" if second and frames.has("carry2") else "carry"
		elif base in ["walk", "back_walk"] and frames.has(base):
			f = base + "2" if second and frames.has(base + "2") else base
			sprite.flip_h = second and not frames.has(base + "2")
		sprite.translation.y = base_y + abs(sin(_t * 9.0)) * 0.04
	else:
		sprite.translation.y = base_y
	sprite.texture = frames.get(f, frames["idle"])
	if carry and is_instance_valid(carry):
		carry.global_transform.origin = global_transform.origin + Vector3(0, base_y * 2.0 + 0.25, 0)
