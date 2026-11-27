extends KinematicBody
# Игрок от первого лица: ходит, берёт, кладёт и швыряет посылки.

signal look_changed(text)

const SPEED := 3.6
const SENS := 0.0025
const THROW_MIN := 2.5
const THROW_MAX := 13.0
const CHARGE_TIME := 1.0

var cam: Camera
var ray: RayCast
var hold_point: Spatial
var held = null  # верхняя коробка в руках
var stack := []  # все коробки в руках/на тележке
var velocity := Vector3.ZERO
var _bob := 0.0
var _last_look := ""
var charging := false
var charge := 0.0
var ghost: MeshInstance  # контур, куда встанет коробка


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	var cs := CollisionShape.new()
	var sh := CapsuleShape.new()
	sh.radius = 0.3
	sh.height = 1.1
	cs.shape = sh
	cs.rotation_degrees.x = 90
	cs.translation.y = 0.85
	add_child(cs)

	cam = Camera.new()
	cam.translation.y = 1.6
	cam.fov = 75
	cam.near = 0.05
	cam.current = true
	add_child(cam)

	ray = RayCast.new()
	ray.enabled = true
	ray.cast_to = Vector3(0, 0, -2.4)
	ray.collision_mask = 1 | 8 | 16
	ray.add_exception(self)
	cam.add_child(ray)

	hold_point = Spatial.new()
	hold_point.translation = Vector3(0.0, -0.35, -1.1)
	cam.add_child(hold_point)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ghost = MeshInstance.new()
	ghost.mesh = CubeMesh.new()
	var gm := SpatialMaterial.new()
	gm.flags_unshaded = true
	gm.flags_transparent = true
	gm.albedo_color = Color(0.5, 1.0, 0.6, 0.28)
	ghost.material_override = gm
	ghost.visible = false
	ghost.set_as_toplevel(true)
	add_child(ghost)


func _unhandled_input(event: InputEvent) -> void:
	if get_parent().get("shift_over"):
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS * Settings.sens)
		cam.rotate_x(-event.relative.y * SENS * Settings.sens)
		cam.rotation.x = clamp(cam.rotation.x, -1.4, 1.4)
	elif get_parent().get("ui_block") and ((event is InputEventMouseButton and event.pressed) or event.is_action_pressed("interact")):
		# несём декор или читаем доску: клик обрабатывает пункт
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
		get_parent().ui_click(event)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == BUTTON_LEFT:
		if charging and held:
			release(true)
		charging = false
		charge = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
		if event.button_index == BUTTON_LEFT:
			if looked_thing() and not held:
				press_thing()
			elif can_grab_more() and looked_parcel():
				try_grab()
			elif held:
				charging = true  # зажал: копим силу, отпустил: бросок
				charge = 0.0
		elif event.button_index == BUTTON_RIGHT and held:
			release(false)
	elif event.is_action_pressed("interact"):
		if looked_thing():
			press_thing()
		elif can_grab_more() and looked_parcel():
			try_grab()
		elif held:
			release(false)


func looked_parcel():
	if ray.is_colliding():
		var c = ray.get_collider()
		if c and c.is_in_group("parcel") and not c.delivered and (not c.held or c in stack):
			return c
	return null


# чек, кнопка и прочее, на что можно посмотреть или нажать
func looked_thing():
	if ray.is_colliding():
		var c = ray.get_collider()
		if c and c.has_meta("look"):
			return c
	return null


func press_thing() -> void:
	var c = looked_thing()
	if c and c.has_meta("press"):
		get_parent().call(c.get_meta("press"), c)


func can_grab_more() -> bool:
	for b in stack:
		if is_instance_valid(b) and b.box_type == "chest":
			return false  # сундук занимает обе руки
	return stack.size() < Game.carry_capacity()


func try_grab() -> void:
	var p = looked_parcel()
	if p == null:
		return
	if Net.active and not Net.is_host:
		get_parent().rpc_id(1, "net_req_grab", p.code)  # хост решит и ответит
		return
	grab(p)


# гость: хост разрешил взять
func grab_local(p) -> void:
	if p in stack:
		return
	stack.append(p)
	held = p
	p.held = true
	Sfx.play("pickup", 0.15, -4.0)


func grab(p) -> void:
	if p in stack:
		return
	if p.box_type == "chest" and not stack.empty():
		emit_signal("look_changed", tr("Сундук только в пустые руки!"))
		return
	if p.try_bite():
		get_parent()._on_mimic_bite(p)
		return
	p.on_grabbed()
	stack.append(p)
	held = p
	p.held = true
	p.mode = RigidBody.MODE_KINEMATIC
	add_collision_exception_with(p)
	p.add_collision_exception_with(self)
	Sfx.play("pickup", 0.15, -4.0)


func release(throw: bool) -> void:
	var p = held
	if p != null:
		stack.erase(p)
	held = stack.back() if not stack.empty() else null
	if p == null or not is_instance_valid(p):
		return
	p.held = false
	if Net.active and not Net.is_host:
		get_parent().rpc_id(1, "net_req_release", p.code, throw, charge, -cam.global_transform.basis.z, velocity)
		if throw:
			Sfx.play("whoosh", 0.1, linear2db(lerp(0.4, 1.0, charge)))
		charging = false
		charge = 0.0
		return
	p.mode = RigidBody.MODE_RIGID
	p.sleeping = false
	p.linear_velocity = Vector3(velocity.x, 0, velocity.z)
	if not throw:
		# Аккуратно ставим туда, куда смотришь (полка, стойка, пол, другая коробка)
		var spot = place_spot(p)
		if spot != null:
			p.global_transform = Transform(Basis(Vector3.UP, rotation.y), spot)
			p.linear_velocity = Vector3.ZERO
			p.angular_velocity = Vector3.ZERO
	if throw:
		var force: float = lerp(THROW_MIN, THROW_MAX, charge)
		p.thrown = true
		Sfx.play("whoosh", 0.1, linear2db(lerp(0.4, 1.0, charge)))
		p.apply_central_impulse(-cam.global_transform.basis.z * force * min(p.mass, 2.0))
	charging = false
	charge = 0.0
	yield(get_tree().create_timer(0.35), "timeout")
	if is_instance_valid(p):
		remove_collision_exception_with(p)
		p.remove_collision_exception_with(self)


# точка, куда встанет коробка: луч из глаз до горизонтальной поверхности
func place_spot(p):
	var space := get_world().direct_space_state
	var from := cam.global_transform.origin
	var dir := -cam.global_transform.basis.z
	var excl := [self]
	for b in stack:
		excl.append(b)
	excl.append(p)
	var hit := space.intersect_ray(from, from + dir * 2.8, excl, 1 | 8)
	var reach := 2.8
	if not hit.empty():
		reach = from.distance_to(hit.position)
	if hit.empty() or hit.normal.y < 0.7:
		# смотрим в щель между полками или в стенку: идём вдоль взгляда и ищем полку под точкой
		var found := {}
		var t := 0.5
		while t <= reach + 0.15:
			var pt: Vector3 = from + dir * t
			var h2 := space.intersect_ray(pt, pt + Vector3.DOWN * 0.7, excl, 1 | 8)
			if not h2.empty() and h2.normal.y >= 0.7 and h2.position.y > 0.3:
				found = h2
				found["position"] = Vector3(pt.x, h2.position.y, pt.z) + Vector3(dir.x, 0, dir.z).normalized() * (p.size.z / 2.0 + 0.04)
				break
			t += 0.06
		if found.empty():
			return null
		hit = found
	var base: Vector3 = hit.position + Vector3.UP * (p.size.y / 2.0 + 0.02)
	var h := Vector3(dir.x, 0, dir.z).normalized()
	var q := PhysicsShapeQueryParameters.new()
	var bs := BoxShape.new()
	bs.extents = p.size / 2.0 * 0.95
	q.set_shape(bs)
	q.collision_mask = 1 | 8
	q.exclude = excl
	# если место занято бортиком или соседней коробкой, чуть сдвигаем
	for off in [0.0, 0.1, -0.1, 0.2, -0.2, 0.3]:
		var pos: Vector3 = base + h * off
		q.transform = Transform(Basis(Vector3.UP, rotation.y), pos)
		if space.intersect_shape(q, 1).empty():
			return pos
	return null


func _physics_process(delta: float) -> void:
	velocity.y -= 9.8 * delta
	var inp := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward"))
	if inp.length() > 1.0:
		inp = inp.normalized()
	var dir := transform.basis.xform(Vector3(inp.x, 0, inp.y))
	dir.y = 0
	dir = dir.normalized() * inp.length()
	var spd := SPEED * (1.0 + 0.25 * Game.lvl("shoes"))
	for b in stack:
		if is_instance_valid(b) and b.box_type == "heavy":
			spd *= 0.55  # тяжёлый ящик: еле тащишь
			break
		if is_instance_valid(b) and b.box_type == "chest":
			spd *= 0.4  # сундук: еле-еле
			break
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	velocity = move_and_slide(velocity, Vector3.UP, true)

	for i in get_slide_count():
		var c := get_slide_collision(i)
		var body = c.collider
		if body is RigidBody and body != held:
			body.apply_central_impulse(-c.normal * 0.25)

	# Покачивание камеры при ходьбе
	if inp.length() > 0.1 and is_on_floor():
		_bob += delta * 9.0
		if int(_bob / PI) != int((_bob - delta * 9.0) / PI):
			Sfx.play("step%d" % (randi() % 2 + 1), 0.15, -8.0)
	cam.translation.y = 1.6 + sin(_bob) * 0.03

	if charging and held:
		charge = min(1.0, charge + delta / CHARGE_TIME)
	for b in stack.duplicate():
		if not is_instance_valid(b) or b.delivered:
			stack.erase(b)
	held = stack.back() if not stack.empty() else null
	var h := 0.0
	for b in stack:
		var target := hold_point.global_transform
		target.origin += Vector3.UP * h
		b.global_transform = b.global_transform.interpolate_with(target, min(1.0, 18.0 * delta))
		h += b.size.y + 0.02

	ghost.visible = false
	if held and not charging and is_instance_valid(held):
		var sp = place_spot(held)
		if sp != null:
			ghost.visible = true
			(ghost.mesh as CubeMesh).size = held.size
			ghost.global_transform = Transform(Basis(Vector3.UP, rotation.y), sp)
	var txt := ""
	if held:
		var codes := []
		for b in stack:
			codes.append(b.code)
		txt = tr("Несёшь %s   [зажми ЛКМ] швырнуть   [ПКМ/E] поставить") % PoolStringArray(codes).join(", ")
		if held.fuse > 0.0:
			txt = tr("ТИКАЕТ: %d сек!   ") % int(ceil(held.fuse)) + txt
		elif held.box_type == "frozen" and not held.melted:
			txt = tr("Тает: %d%%   ") % int(held.melt * 100.0) + txt
		var lp = looked_parcel()
		if lp and can_grab_more() and not lp in stack:
			txt = tr("[ЛКМ/E] взять ещё %s (%d/%d)") % [Game.disp(lp.code), stack.size(), Game.carry_capacity()]
	else:
		var p = looked_parcel()
		var th = looked_thing()
		if th:
			txt = th.get_meta("look")
		elif p:
			var extra: String = tr("  (ОНА ШЕВЕЛИТСЯ)") if p.cursed else ""
			match p.box_type:
				"mimic":
					extra = tr("  (у неё ЗУБЫ?)")
				"timer":
					extra = tr("  (таймер: возьмёшь — пойдёт отсчёт)") if p.fuse < 0.0 else tr("  (ТИКАЕТ: %d)") % int(ceil(p.fuse))
				"chest":
					extra = tr("  (тяжеленный сундук)")
				"frozen":
					extra = tr("  (РАСТАЯЛА)") if p.melted else tr("  (холодная: %d%%)") % int(p.melt * 100.0)
				"living":
					extra = tr("  (у неё ножки!)")
			txt = tr("[ЛКМ/E] взять %s%s") % [Game.disp(p.code), extra]
	if txt != _last_look:
		_last_look = txt
		emit_signal("look_changed", txt)
