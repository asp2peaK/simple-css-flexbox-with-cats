extends Node
# Автотесты кооп/стрим-фишек (только для разработки):
#   кооп: menu --nethost --funtest=host  +  menu --netjoin=127.0.0.1 --funtest=client
#   одиночные: main --funtest=solo  (проклятия, перегруз портала, голосование Twitch)

var main
var role := ""


func _shot(n: String) -> void:
	main._save(OS.get_environment("SHOT_DIR") + "/" + n + ".png")


func _wait(s: float):
	return get_tree().create_timer(s)


func run(m, r: String) -> void:
	main = m
	role = r
	call(r)


func _place(pos: Vector3, rot: float, pitch := 0.0) -> void:
	main.player.global_transform.origin = pos
	main.player.rotation.y = rot
	main.player.cam.rotation.x = pitch


func _duo_parcel():
	for p in main.parcels:
		if is_instance_valid(p) and p.box_type == "cow" and not p.delivered:
			return p
	for p in main.parcels:
		if is_instance_valid(p) and p.duo and not p.delivered and not p.from_portal:
			return p
	return null


func host() -> void:
	var f = main.fun
	while main.avatars.empty():
		yield(_wait(0.5), "timeout")
	yield(_wait(3.0), "timeout")
	# 1) огонь по своим: гость стоит на (0, -3.2), хост кидает коробку в него
	_place(Vector3(0, 0.05, -1.0), 0.0, -0.05)
	var box = null
	for p in main.parcels:
		if is_instance_valid(p) and not p.duo and p.box_type in ["normal", "gift", "fragile", "heavy"] and not p.delivered and p.mode == RigidBody.MODE_RIGID:
			box = p
			break
	main.player.grab(box)
	yield(_wait(0.4), "timeout")
	main.player.charge = 0.55
	main.player.release(true)
	yield(_wait(0.7), "timeout")
	_shot("f1_knock")
	print("HOST board after hit: ", f.board)
	yield(_wait(5.5), "timeout")
	_shot("f2_bighead")
	# 3) сундук/корова на двоих
	var d = _duo_parcel()
	print("HOST duo parcel: ", d.code if d else "none", " type=", d.box_type if d else "")
	if d:
		var dp: Vector3 = d.global_transform.origin
		_place(Vector3(dp.x, 0.05, dp.z + 1.0), 0.0, -0.3)
		yield(_wait(0.5), "timeout")
		f.duo_grab(d)
		yield(_wait(0.6), "timeout")
		print("HOST duo one holder: held=", d.held, " holders=", f.duo.get(d.code, []), " lifted=", main.player.duo_lifted)
		yield(_wait(1.5), "timeout")
		print("HOST duo two holders: held=", d.held, " holders=", f.duo.get(d.code, []), " lifted=", main.player.duo_lifted, " y=", d.global_transform.origin.y)
		_place(Vector3(dp.x + 0.8, 0.05, dp.z + 1.8), 0.4, -0.15)
		yield(_wait(0.8), "timeout")
		print("HOST duo carried: y=", d.global_transform.origin.y, " moved=", d.global_transform.origin.distance_to(dp))
		_shot("f3_duo")
		f.duo_release_local()
		yield(_wait(1.0), "timeout")
		print("HOST duo released: held=", d.held, " mode=", d.mode)
	yield(_wait(1.0), "timeout")
	main._end_shift()
	print("HOST board: ", f.board)
	yield(_wait(0.5), "timeout")
	print("HOST END TEXT:\n", main.hud_panel_side.text)
	_shot("f4_board")
	yield(_wait(2.0), "timeout")
	get_tree().quit()


func client() -> void:
	var f = main.fun
	yield(_wait(2.0), "timeout")
	_place(Vector3(0, 0.05, -3.2), PI, 0.0)
	yield(_wait(5.5), "timeout")
	print("CLIENT stun=", main.player.stun_t, " down=", main.player.down_dir)
	yield(_wait(0.5), "timeout")
	f.apply_curse("bighead")
	yield(_wait(3.3), "timeout")
	var d = _duo_parcel()
	print("CLIENT duo parcel: ", d.code if d else "none")
	if d:
		var dp: Vector3 = d.global_transform.origin
		_place(Vector3(dp.x + 1.0, 0.05, dp.z), PI / 2.0, -0.3)
		yield(_wait(0.3), "timeout")
		f.duo_grab(d)
		yield(_wait(0.8), "timeout")
		print("CLIENT duo: lifted=", main.player.duo_lifted, " duo=", main.player.duo != null)
		yield(_wait(0.9), "timeout")
		_place(Vector3(dp.x + 1.8, 0.05, dp.z + 0.8), PI / 2.0, -0.3)
	yield(_wait(3.0), "timeout")
	print("CLIENT end text: ", main.hud_panel_text.text.right(max(0, main.hud_panel_text.text.length() - 300)))
	get_tree().quit()


func solo() -> void:
	var f = main.fun
	yield(_wait(3.0), "timeout")
	# проклятия
	for c in f.CURSES:
		f.apply_curse(c)
		yield(_wait(0.6), "timeout")
		print("curse ", c, " fov=", main.player.cam.fov)
	_shot("s1_curse_hud")
	main.player.curse = "glue"
	main.player.curse_t = 5.0
	var box = main.parcels[0]
	main.player.grab(box)
	main.player.release(false)
	print("glue: still holding=", main.player.held == box)
	main.player.curse = ""
	main.player.release(false)
	# перегруз портала
	var n0: int = main.parcels.size()
	f.overload()
	yield(_wait(10.0), "timeout")
	_place(Vector3(-3.5, 0.05, -0.6), deg2rad(70), -0.25)
	yield(_wait(0.3), "timeout")
	_shot("s2_overload")
	print("overload: parcels ", n0, " -> ", main.parcels.size(), " belt=", f.belt_speed())
	# голосование Twitch (чат подставной)
	Twitch.connected = true
	Twitch.handle_line(":tmi.twitch.tv 001 justinfan1 :Welcome")
	f.vote_cd = 0.1
	yield(_wait(0.5), "timeout")
	for u in ["anna", "bob", "cat", "dan", "bob"]:
		Twitch.handle_line(":%s!%s@%s.tmi.twitch.tv PRIVMSG #test :%s" % [u, u, u, "2" if u != "dan" else "!1"])
	yield(_wait(0.5), "timeout")
	print("vote opts=", f.vote_opts, " counts=", f.vote_counts)
	_shot("s3_vote")
	f.vote_left = 0.05
	yield(_wait(0.5), "timeout")
	print("vote done, money=", main.money, " curse=", main.player.curse)
	yield(_wait(1.0), "timeout")
	_shot("s4_vote_result")
	get_tree().quit()


# ---- показ коровы на двоих: menu --nethost --funtest=cowhost --cowfirst + menu --netjoin=... --funtest=cowclient
var _t0 := 0
var side_cam: Camera


func _at(t: float):
	while (OS.get_ticks_msec() - _t0) / 1000.0 < t:
		yield(get_tree(), "idle_frame")
	return true


func _side_shot(n: String, target: Vector3) -> void:
	if side_cam == null:
		side_cam = Camera.new()
		side_cam.fov = 60
		main.add_child(side_cam)
	side_cam.global_transform.origin = target + Vector3(2.6, 2.0, 3.0)
	side_cam.look_at(target, Vector3.UP)
	side_cam.current = true
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	_shot(n)
	main.player.cam.current = true


func _walk(from: Vector3, to: Vector3, t1: float, t2: float) -> void:
	while true:
		var t: float = (OS.get_ticks_msec() - _t0) / 1000.0
		var k: float = clamp((t - t1) / (t2 - t1), 0.0, 1.0)
		main.player.global_transform.origin = from.linear_interpolate(to, k)
		if k >= 1.0:
			return
		yield(get_tree().create_timer(0.03), "timeout")


func cowhost() -> void:
	_t0 = OS.get_ticks_msec()
	var f = main.fun
	var cow = _duo_parcel()
	var cp: Vector3 = cow.global_transform.origin
	print("COW at ", cp, " ", cow.box_type)
	yield(_at(4.0), "completed")
	var start := Vector3(cp.x - 0.55, 0.05, cp.z + 1.4)
	_place(start, 0.0, -0.45)
	yield(_at(4.6), "completed")
	_shot("c1_look")
	f.duo_grab(cow)
	yield(_at(6.0), "completed")
	_shot("c2_one")
	_side_shot("c2_one_side", cp)
	yield(_at(8.5), "completed")
	print("lifted=", main.player.duo_lifted, " holders=", f.duo.get(cow.code, []))
	_shot("c3_lift")
	_side_shot("c3_lift_side", cow.global_transform.origin)
	main.player.rotation.y = PI
	main.player.cam.rotation.x = -0.25
	var end := Vector3(0.55, 0.05, -1.4)
	_walk(start, end, 9.0, 15.0)
	yield(_at(12.0), "completed")
	_shot("c4_walk")
	_side_shot("c4_walk_side", cow.global_transform.origin)
	yield(_at(15.5), "completed")
	_shot("c5_counter")
	_side_shot("c5_counter_side", cow.global_transform.origin)
	yield(_at(16.0), "completed")
	f.duo_release_local()
	yield(_at(16.6), "completed")
	_side_shot("c6_drop_side", Vector3(0, 1.0, 0))
	yield(_at(19.0), "completed")
	print("served=", main.served, " money=", main.money, " cow delivered=", not is_instance_valid(cow) or cow.delivered)
	_side_shot("c7_after_side", Vector3(0, 1.0, 0))
	yield(_at(21.0), "completed")
	get_tree().quit()


func cowclient() -> void:
	_t0 = OS.get_ticks_msec()
	var f = main.fun
	var cow = _duo_parcel()
	var cp: Vector3 = cow.global_transform.origin
	yield(_at(4.0), "completed")
	var start := Vector3(cp.x + 0.55, 0.05, cp.z + 1.4)
	_place(start, 0.0, -0.45)
	yield(_at(7.0), "completed")
	f.duo_grab(cow)
	yield(_at(8.6), "completed")
	_shot("c3_lift_client")
	main.player.rotation.y = PI
	main.player.cam.rotation.x = -0.25
	var end := Vector3(-0.55, 0.05, -1.4)
	_walk(start, end, 9.0, 15.0)
	yield(_at(12.1), "completed")
	_shot("c4_walk_client")
	yield(_at(16.0), "completed")
	f.duo_release_local()
	yield(_at(18.0), "completed")
	get_tree().quit()
