extends Spatial
# Другой игрок в кооперативе: простая фигурка своего цвета, плавно идёт за сетевыми координатами.

const COLORS := [Color(0.3, 0.6, 1.0), Color(0.4, 0.9, 0.4), Color(1.0, 0.6, 0.2), Color(0.9, 0.4, 0.9)]
var bubble_text := ""
var bubble_color := Color(1, 1, 1)
var base_y := 0.95
var _to := Vector3.ZERO
var _rot := 0.0
var _pitch := 0.0


var doll = null
var _prev := Vector3.ZERO


func setup(id: int, n: int) -> void:
	bubble_text = tr("Игрок %d") % (n + 1)
	var Doll = load("res://scripts/paperdoll.gd")
	if Doll.available():
		# персонаж из слоёв; пока не пришёл внешний вид — человек с фартуком своего цвета
		doll = Doll.new()
		add_child(doll)
		doll.set_look({"race": "human", "skin": 0, "apron": n % 8, "hat": "", "face": ""})
		bubble_color = Color(1, 1, 1)
		return
	var col: Color = COLORS[n % COLORS.size()]
	var m := SpatialMaterial.new()
	m.albedo_color = col
	var body := MeshInstance.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.mid_height = 0.9
	body.mesh = cap
	body.material_override = m
	body.rotation_degrees.x = 90
	body.translation.y = 0.75
	add_child(body)
	var head := MeshInstance.new()
	var sp := SphereMesh.new()
	sp.radius = 0.2
	sp.height = 0.4
	head.mesh = sp
	var hm := SpatialMaterial.new()
	hm.albedo_color = Color(1.0, 0.85, 0.7)
	head.material_override = hm
	head.translation.y = 1.55
	add_child(head)
	var cap_m := MeshInstance.new()
	var cm := CubeMesh.new()
	cm.size = Vector3(0.42, 0.1, 0.42)
	cap_m.mesh = cm
	cap_m.material_override = m
	cap_m.translation = Vector3(0, 1.72, -0.05)
	add_child(cap_m)
	bubble_text = tr("Игрок %d") % (n + 1)
	bubble_color = col.lightened(0.3)


func net_set(pos: Vector3, rot_y: float, pitch: float) -> void:
	if _to == Vector3.ZERO:
		translation = pos
	_to = pos
	_rot = rot_y
	_pitch = pitch


func hold_point() -> Vector3:
	var fwd := Vector3(-sin(_rot) * cos(_pitch), sin(_pitch), -cos(_rot) * cos(_pitch))
	return global_transform.origin + Vector3(0, 1.25, 0) + fwd * 1.1


func set_look(l: Dictionary) -> void:
	if doll:
		doll.set_look(l)
	var nick: String = l.get("nick", "")
	if nick != "":
		bubble_text = nick


func _process(delta: float) -> void:
	translation = translation.linear_interpolate(_to, min(1.0, 12.0 * delta))
	if doll:
		doll.walking = translation.distance_to(_prev) > 0.6 * delta
		_prev = translation
	rotation.y = lerp_angle(rotation.y, _rot, min(1.0, 12.0 * delta))
