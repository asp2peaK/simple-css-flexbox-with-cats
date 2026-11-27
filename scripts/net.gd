extends Node
# Кооп по сети (автозагрузка Net): хост держит физику посылок и клиентов, остальные шлют свои действия.
# Два способа:
#  - Steam-лобби (если игра запущена через Steam / GodotSteam): создать лобби, позвать друга,
#    трафик идёт через Steam P2P (релей Steam), порты открывать не надо;
#  - по IP (ENet, порт PORT UDP) — для LAN или VPN.
# Оба дают обычный network_peer, поэтому rpc() в игре работает одинаково.

signal status(text)
signal peers_changed
signal lobby_ready  # лобби создано или мы в него вошли (меню показывает кнопку «Пригласить»)

const PORT := 24680
const MAX_PLAYERS := 4
const GAME_TAG := "notmyparcel"
const CH_GAME := 0
const CH_CTRL := 1
const SEND_UNRELIABLE := 0
const SEND_RELIABLE := 2
const UNRELIABLE_MAX := 1150

var active := false
var is_host := false
var seed_value := 0
var peers := []  # id подключённых (кроме себя)

# --- Steam
var mode := ""  # "enet" | "steam"
var lobby_id := 0
var pending_lobby := 0  # приглашение, принятое вне меню / из командной строки
var _sp: NetworkedMultiplayerCustom
var _host_sid := 0
var _sid_of := {}  # peer id -> steam id
var _pid_of := {}  # steam id -> peer id (только те, с кем связь установлена)
var _hello_t := 0.0
var _join_t := 0.0
var _steam_hooked := false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	for a in OS.get_cmdline_args():
		if a.begins_with("--fakesteam="):  # локальный тест Steam-кооперации, см. tools/test/fake_steam.gd
			_fake = load("res://tools/test/fake_steam.gd").new(a.substr(12))


var _fake = null


func steam():
	if _fake:
		return _fake
	return Ach.steam if Ach.steam else null


func has_steam() -> bool:
	return steam() != null


func _hook_steam() -> void:
	if _steam_hooked or not has_steam():
		return
	_steam_hooked = true
	var s = steam()
	s.allowP2PPacketRelay(true)
	for pair in [["lobby_created", "_on_lobby_created"], ["lobby_joined", "_on_lobby_joined"],
			["join_requested", "_on_join_requested"], ["lobby_chat_update", "_on_lobby_update"],
			["p2p_session_request", "_on_p2p_request"], ["p2p_session_connect_fail", "_on_p2p_fail"]]:
		if s.has_signal(pair[0]) and not s.is_connected(pair[0], self, pair[1]):
			s.connect(pair[0], self, pair[1])
	# игру запустили кликом «Присоединиться» в Steam: +connect_lobby <id>
	var args: Array = Array(OS.get_cmdline_args())
	var line: String = String(s.getLaunchCommandLine()) if s.has_method("getLaunchCommandLine") else ""
	args += Array(line.split(" ", false))
	for i in args.size():
		if args[i] == "+connect_lobby" and i + 1 < args.size() and String(args[i + 1]).is_valid_integer():
			pending_lobby = int(args[i + 1])


func host() -> bool:
	mode = "enet"
	var p := NetworkedMultiplayerENet.new()
	if p.create_server(PORT, MAX_PLAYERS - 1) != OK:
		emit_signal("status", tr("Не получилось открыть порт %d") % PORT)
		return false
	get_tree().network_peer = p
	active = true
	is_host = true
	peers = []
	_connect_signals()
	emit_signal("status", tr("Игра создана. Ждём друзей... (порт %d)") % PORT)
	return true


func join(ip: String) -> bool:
	mode = "enet"
	var p := NetworkedMultiplayerENet.new()
	if p.create_client(ip.strip_edges(), PORT) != OK:
		emit_signal("status", tr("Не получилось подключиться"))
		return false
	get_tree().network_peer = p
	active = true
	is_host = false
	peers = []
	_connect_signals()
	emit_signal("status", tr("Подключаемся к %s...") % ip)
	return true


func leave() -> void:
	if mode == "steam" and has_steam():
		for sid in _pid_of.keys():
			steam().sendP2PPacket(sid, _ctrl("bye"), SEND_RELIABLE, CH_CTRL)
			steam().closeP2PSessionWithUser(sid)
		if lobby_id != 0:
			steam().leaveLobby(lobby_id)
		steam().setRichPresence("status", "")
	lobby_id = 0
	_host_sid = 0
	_sid_of = {}
	_pid_of = {}
	_sp = null
	mode = ""
	get_tree().network_peer = null
	active = false
	is_host = false
	peers = []


func _connect_signals() -> void:
	var t := get_tree()
	for pair in [["network_peer_connected", "_on_peer_in"], ["network_peer_disconnected", "_on_peer_out"],
			["connected_to_server", "_on_connected"], ["connection_failed", "_on_failed"],
			["server_disconnected", "_on_server_gone"]]:
		if not t.is_connected(pair[0], self, pair[1]):
			t.connect(pair[0], self, pair[1])


func _on_peer_in(id: int) -> void:
	if not id in peers:
		peers.append(id)
	emit_signal("peers_changed")
	emit_signal("status", tr("Игроков: %d") % (peers.size() + 1))


func _on_peer_out(id: int) -> void:
	peers.erase(id)
	emit_signal("peers_changed")
	emit_signal("status", tr("Игрок вышел. Игроков: %d") % (peers.size() + 1))


func _on_connected() -> void:
	emit_signal("status", tr("Подключено! Ждём, когда хост начнёт смену."))


func _on_failed() -> void:
	leave()
	emit_signal("status", tr("Не удалось подключиться."))


func _on_server_gone() -> void:
	leave()
	emit_signal("status", tr("Хост отключился."))
	if get_tree().current_scene and get_tree().current_scene.name != "Menu":
		get_tree().paused = false
		get_tree().change_scene("res://menu.tscn")


func my_id() -> int:
	return get_tree().get_network_unique_id() if active else 1


# Хост запускает смену у всех: одинаковое зерно и улучшения = одинаковый склад
func start_shift() -> void:
	if not is_host:
		return
	randomize()
	seed_value = randi()
	rpc("_start", seed_value, Game.day, Game.upgrades, Game.event)
	_start(seed_value, Game.day, Game.upgrades, Game.event)


remote func _start(s: int, day: int, ups: Dictionary, ev: String) -> void:
	seed_value = s
	if not is_host:
		Game.day = day
		Game.upgrades = ups.duplicate()
		Game.event = ev
		Game.tutorial_done = true
	get_tree().paused = false
	get_tree().change_scene("res://main.tscn")


# ================================================================ Steam-лобби

func steam_host() -> bool:
	_hook_steam()
	if not has_steam():
		emit_signal("status", tr("Steam не запущен. Запусти игру через Steam или играй по IP."))
		return false
	leave()
	steam().createLobby(1, MAX_PLAYERS)  # 1 = только для друзей
	emit_signal("status", tr("Создаём лобби Steam..."))
	return true


func steam_join(lid: int) -> void:
	_hook_steam()
	if not has_steam() or lid == 0:
		return
	leave()
	pending_lobby = 0
	steam().joinLobby(lid)
	emit_signal("status", tr("Входим в лобби друга..."))


func invite() -> void:
	if has_steam() and lobby_id != 0:
		steam().activateGameOverlayInviteDialog(lobby_id)


# Друзья, которые сейчас в нашей игре и сидят в лобби: [[имя, lobby_id], ...]
func friends_in_lobbies() -> Array:
	var out := []
	if not has_steam():
		return out
	var s = steam()
	var app: int = int(s.getAppID())
	var n: int = int(s.getFriendCount(4))  # 4 = обычные друзья
	for i in n:
		var fid: int = int(s.getFriendByIndex(i, 4))
		var g: Dictionary = s.getFriendGamePlayed(fid)
		if g.empty() or int(g.get("id", 0)) != app:
			continue
		var lid: int = int(g.get("lobby", 0))
		if lid != 0 and lid != lobby_id:
			out.append([String(s.getFriendPersonaName(fid)), lid])
	return out


func my_steam_name() -> String:
	return String(steam().getPersonaName()) if has_steam() else ""


func _pid_for(sid: int) -> int:
	if sid == _host_sid:
		return 1
	var p: int = sid & 0x7FFFFFFF  # account id: у каждого свой
	if p <= 1:
		p += 2
	return p


func _start_peer(host_sid: int) -> void:
	_host_sid = host_sid
	_sp = NetworkedMultiplayerCustom.new()
	_sp.set_connection_status(NetworkedMultiplayerPeer.CONNECTION_CONNECTING)
	var me: int = int(steam().getSteamID())
	_sp.initialize(_pid_for(me))
	_sp.connect("packet_generated", self, "_on_packet_out")
	get_tree().network_peer = _sp
	mode = "steam"
	active = true
	is_host = me == host_sid
	peers = []
	_sid_of = {}
	_pid_of = {}
	_connect_signals()


func _on_lobby_created(result: int, lid: int) -> void:
	if result != 1:
		emit_signal("status", tr("Steam не дал создать лобби (код %d).") % result)
		return
	lobby_id = lid
	var s = steam()
	s.setLobbyData(lid, "game", GAME_TAG)
	s.setLobbyData(lid, "host", my_steam_name())
	s.setLobbyJoinable(lid, true)
	s.setRichPresence("status", tr("Хост пункта выдачи"))
	_start_peer(int(s.getSteamID()))
	emit_signal("status", tr("Лобби создано! Жми «Пригласить друга» или друг заходит через список друзей Steam."))
	emit_signal("lobby_ready")


func _on_lobby_joined(lid: int, _perm: int, _locked: bool, response: int) -> void:
	var s = steam()
	if response != 1:
		emit_signal("status", tr("Не получилось войти в лобби (код %d).") % response)
		return
	var owner: int = int(s.getLobbyOwner(lid))
	if owner == int(s.getSteamID()):
		return  # это наше же лобби (сигнал приходит и хосту)
	if s.getLobbyData(lid, "game") != GAME_TAG:
		s.leaveLobby(lid)
		emit_signal("status", tr("Это лобби не от NOT MY PARCEL!"))
		return
	lobby_id = lid
	s.setRichPresence("status", tr("В гостях на пункте выдачи"))
	_start_peer(owner)
	_join_t = 0.0
	_say_hello_all()
	emit_signal("status", tr("Подключаемся к %s...") % s.getFriendPersonaName(owner))
	emit_signal("lobby_ready")


func _on_join_requested(lid: int, _friend: int) -> void:
	# друг позвал / нажали «Присоединиться» в Steam, пока игра открыта
	if get_tree().current_scene and get_tree().current_scene.name != "Menu":
		leave()
		pending_lobby = lid
		get_tree().paused = false
		get_tree().change_scene("res://menu.tscn")
		return
	pending_lobby = lid
	emit_signal("status", tr("Приглашение принято"))
	emit_signal("lobby_ready")  # меню откроет панель кооп и войдёт


func _members() -> Array:
	var out := []
	if lobby_id == 0:
		return out
	var s = steam()
	var me: int = int(s.getSteamID())
	for i in int(s.getNumLobbyMembers(lobby_id)):
		var m: int = int(s.getLobbyMemberByIndex(lobby_id, i))
		if m != me and m != 0:
			out.append(m)
	return out


func _say_hello_all() -> void:
	for m in _members():
		if not _pid_of.has(m):
			steam().sendP2PPacket(m, _ctrl("hello"), SEND_RELIABLE, CH_CTRL)


func _on_lobby_update(lid: int, changed: int, _by: int, state: int) -> void:
	if lid != lobby_id:
		return
	if state == 1:  # вошёл: он сам пришлёт hello
		return
	_drop(changed)  # вышел / отвалился / кикнут


func _on_p2p_request(sid: int) -> void:
	if sid in _members():
		steam().acceptP2PSessionWithUser(sid)


func _on_p2p_fail(sid: int, _err: int) -> void:
	_drop(sid)


func _ctrl(what: String) -> PoolByteArray:
	return what.to_utf8()


func _register(sid: int) -> void:
	if _pid_of.has(sid) or _sp == null:
		return
	var pid := _pid_for(sid)
	_pid_of[sid] = pid
	_sid_of[pid] = sid
	_sp.emit_signal("peer_connected", pid)
	if sid == _host_sid and not is_host:
		_sp.set_connection_status(NetworkedMultiplayerPeer.CONNECTION_CONNECTED)


func _drop(sid: int) -> void:
	if not _pid_of.has(sid) or _sp == null:
		return
	var pid: int = _pid_of[sid]
	_pid_of.erase(sid)
	_sid_of.erase(pid)
	if has_steam():
		steam().closeP2PSessionWithUser(sid)
	if sid == _host_sid and not is_host:
		_sp.set_connection_status(NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED)  # -> server_disconnected
	else:
		_sp.emit_signal("peer_disconnected", pid)


func _on_packet_out(target: int, buf: PoolByteArray, tmode: int) -> void:
	if not has_steam():
		return
	var send: int = SEND_RELIABLE
	if tmode != NetworkedMultiplayerPeer.TRANSFER_MODE_RELIABLE and buf.size() <= UNRELIABLE_MAX:
		send = SEND_UNRELIABLE
	if target > 0:
		if _sid_of.has(target):
			steam().sendP2PPacket(_sid_of[target], buf, send, CH_GAME)
		return
	for pid in _sid_of.keys():
		if target < 0 and pid == -target:
			continue
		steam().sendP2PPacket(_sid_of[pid], buf, send, CH_GAME)


func _process(delta: float) -> void:
	if not _steam_hooked:
		_hook_steam()
	if mode != "steam" or not has_steam():
		return
	var s = steam()
	if _sp == null:
		return
	# служебные: hello / ack / bye
	var n: int = int(s.getAvailableP2PPacketSize(CH_CTRL))
	while n > 0:
		var d: Dictionary = s.readP2PPacket(n, CH_CTRL)
		var sid: int = int(d.get("remote_steam_id", 0))
		var msg: String = PoolByteArray(d.get("data", PoolByteArray())).get_string_from_utf8()
		if sid != 0 and sid in _members():
			if msg == "hello":
				s.sendP2PPacket(sid, _ctrl("ack"), SEND_RELIABLE, CH_CTRL)
				_register(sid)
			elif msg == "ack":
				_register(sid)
			elif msg == "bye":
				_drop(sid)
		n = int(s.getAvailableP2PPacketSize(CH_CTRL))
	# игровые пакеты -> в Godot
	n = int(s.getAvailableP2PPacketSize(CH_GAME))
	while n > 0:
		var d2: Dictionary = s.readP2PPacket(n, CH_GAME)
		var sid2: int = int(d2.get("remote_steam_id", 0))
		if _pid_of.has(sid2):
			_sp.deliver_packet(d2.get("data", PoolByteArray()), _pid_of[sid2])
		n = int(s.getAvailableP2PPacketSize(CH_GAME))
	# клиент: пока хост не ответил, повторяем hello
	if not is_host:
		_hello_t += delta
		_join_t += delta
		if _hello_t > 1.0:
			_hello_t = 0.0
			_say_hello_all()
		if not _pid_of.has(_host_sid) and _join_t > 20.0:
			leave()
			emit_signal("status", tr("Хост не отвечает. Попробуй ещё раз."))
