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
		if is_instance_valid(p) and not p.duo and p.box_type == "normal" and not p.delivered:
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
