extends RigidBody

signal exploded(parcel)
signal cracked(parcel)
signal melted(parcel)
# Посылка: коробка с номером. Проклятые посылки сами прыгают.

var code := ""
var cursed := false
var box_type := "normal"
var held := false
var delivered := false
var size := Vector3(0.5, 0.4, 0.5)
var home := Vector3.ZERO
var rejected_by := 0
var thrown := false  # летит после броска (может попасть в клиента)
var hit_done := false
var hall_time := 0.0
var _hop := 0.0
var _thrown_t := 0.0
var _last_speed := 0.0
var cracks := 0
var bonus_catch := false
var _mat: SpatialMaterial
var _boom_cd := 0.0
var _thud_cd := 0.0
var fuse := -1.0  # таймер: запускается, когда берёшь в руки
var _tick := 0.0
var melt := 1.0  # заморозка: 1 = ледяная, 0 = растаяла
var in_freezer := false
var melted := false
var calm := 0.0  # мимик успокоился после укуса
var sorted := false  # уже разложена на правильный стеллаж
var from_portal := false
var stolen := false
var valuable := false  # ценная: лежит в сейфе
var in_safe := false


func setup(p_code: String, p_cursed: bool, p_size: Vector3, tex: Texture) -> void:
	code = p_code
	cursed = p_cursed
	size = p_size
	mass = 2.0
	collision_layer = 8
	collision_mask = 1 | 4 | 8
	continuous_cd = true
	can_sleep = not cursed
	contact_monitor = true
	contacts_reported = 4
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.0
	pm.rough = true
	physics_material_override = pm
	angular_damp = 1.5

	var cs := CollisionShape.new()
	var sh := BoxShape.new()
	sh.extents = size / 2.0
	cs.shape = sh
	add_child(cs)

	var mi := MeshInstance.new()
	var cm := CubeMesh.new()
	cm.size = size
	mi.mesh = cm
	var m := SpatialMaterial.new()
	m.albedo_texture = tex
	mi.material_override = m
	_mat = m
	add_child(mi)


func _ready() -> void:
	add_to_group("parcel")
	connect("body_entered", self, "_on_body_entered")
	_hop = rand_range(3.0, 7.0)


func _physics_process(delta: float) -> void:
	if global_transform.origin.y < -3.0:
		# Улетела за карту: возвращаем на полку
		linear_velocity = Vector3.ZERO
		global_transform.origin = home
	if thrown:
		_thrown_t += delta
		if _thrown_t > 0.25 and linear_velocity.length() < 1.0:
			thrown = false
			hit_done = false
			_thrown_t = 0.0
	if fuse > 0.0 and not delivered:
		fuse -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5 if fuse < 8.0 else 1.0
			Sfx.play_at("tick", global_transform.origin, 0.0, -2.0 if fuse < 8.0 else -6.0)
			_mat.emission_enabled = true
			_mat.emission = Color(1, 0.2, 0.1)
			_mat.emission_energy = 0.6 if int(fuse * 2.0) % 2 == 0 else 0.0
		if fuse <= 0.0:
			fuse = 0.0
			_mat.emission_enabled = false
			emit_signal("exploded", self)
	if box_type == "frozen" and not delivered and not melted:
		if in_freezer:
			melt = min(1.0, melt + delta * 0.2)
		else:
			melt -= delta / 50.0
			_mat.albedo_color = Color(0.75, 0.9, 1.0).linear_interpolate(Color(0.6, 0.55, 0.5), 1.0 - melt)
			if melt <= 0.0:
				melted = true
				emit_signal("melted", self)
	calm -= delta
	if (box_type == "living" or box_type == "mimic") and not held and not delivered and mode == RigidBody.MODE_RIGID and calm <= 0.0:
		_hop -= delta
		if _hop <= 0.0:
			_hop = rand_range(2.5, 5.0)
			# живая посылка семенит к выходу, мимик просто скачет
			var d2 := Vector3(rand_range(-0.5, 0.5), 0, 1.0 if box_type == "living" else rand_range(-1, 1)).normalized()
			Sfx.play_at("step1" if box_type == "living" else "bite", global_transform.origin, 0.2, -4.0)
			apply_central_impulse((d2 * 1.6 + Vector3.UP * 2.0) * mass * 0.5)
	if cursed and not held and not delivered and calm <= 0.0 and mode == RigidBody.MODE_RIGID:
		_hop -= delta
		if _hop <= 0.0:
			_hop = rand_range(2.5, 6.0) * (3.0 if Game.lvl("amulet") > 0 else 1.0) * (1.6 if Game.lvl("golem") > 0 else 1.0)
			var dir := Vector3(rand_range(-1, 1), 0, rand_range(-1, 1)).normalized()
			Sfx.play_at("boing", global_transform.origin, 0.2, -2.0)
			apply_central_impulse((dir * 1.2 + Vector3.UP * 3.5) * mass * 0.5)
			apply_torque_impulse(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.6)
	_thud_cd -= delta
	_boom_cd -= delta
	_last_speed = linear_velocity.length()


func _on_body_entered(_body) -> void:
	if held or delivered or _thud_cd > 0.0 or _last_speed < 1.2:
		return
	_thud_cd = 0.12
	# Взрывная: сильный удар = БАБАХ
	if box_type == "explosive" and _last_speed > 6.0 and _boom_cd <= 0.0:
		_boom_cd = 3.0
		_mat.albedo_color = _mat.albedo_color.darkened(0.25)
		emit_signal("exploded", self)
		return
	# Хрупкая: удар посильнее = трещина
	if box_type == "fragile" and _last_speed > 4.0:
		cracks += 1
		_mat.albedo_color = Color(0.85, 0.8, 0.75).darkened(0.12 * cracks)
		Sfx.play_at("crack", global_transform.origin, 0.1, 2.0)
		emit_signal("cracked", self)
	var vol := linear2db(clamp(_last_speed / 7.0, 0.15, 1.0))
	Sfx.play_at("thud%d" % (randi() % 3 + 1), global_transform.origin, 0.15, vol + 4.0)


func set_highlight(on: bool) -> void:
	_mat.emission_enabled = on
	_mat.emission = Color(1.0, 0.85, 0.3)
	_mat.emission_energy = 0.45


func try_bite() -> bool:
	# Мимик кусает, когда его хватают (если не успокоился)
	if box_type != "mimic" or calm > 0.0 or randf() > 0.6:
		return false
	calm = 8.0
	Sfx.play_at("bite", global_transform.origin, 0.1, 4.0)
	apply_central_impulse((Vector3(rand_range(-1, 1), 0, rand_range(-1, 1)).normalized() * 2.0 + Vector3.UP * 3.0) * mass * 0.5)
	return true


func on_grabbed() -> void:
	if box_type == "timer" and fuse < 0.0:
		fuse = 35.0
