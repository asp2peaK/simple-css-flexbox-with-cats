extends Node
# Чат Twitch только на чтение (автозагрузка Twitch): анонимный вход justinfan, без токенов и паролей.
# Канал задаётся в настройках. Сообщения чата приходят сигналом chat(user, text) — для голосования.

signal chat(user, text)
signal status_changed(text)

const URLS := ["wss://irc-ws.chat.twitch.tv:443", "ws://irc-ws.chat.twitch.tv:80"]  # если TLS не прошёл — без него

var ws: WebSocketClient
var channel := ""
var connected := false
var status := ""
var _retry := -1.0
var _url_i := 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("start", Settings.twitch)


func start(ch: String) -> void:
	stop()
	channel = ch.strip_edges().to_lower().trim_prefix("#").trim_prefix("https://www.twitch.tv/").trim_prefix("twitch.tv/")
	if channel == "":
		_set_status("")
		return
	ws = WebSocketClient.new()
	ws.connect("connection_established", self, "_on_open")
	ws.connect("connection_closed", self, "_on_closed")
	ws.connect("connection_error", self, "_on_error")
	ws.connect("data_received", self, "_on_data")
	if ws.connect_to_url(URLS[_url_i % URLS.size()]) != OK:
		_on_error()
		return
	_set_status(tr("Twitch: подключаемся к %s...") % channel)


func stop() -> void:
	if ws:
		ws.disconnect_from_host()
	ws = null
	connected = false
	_retry = -1.0


func _set_status(t: String) -> void:
	status = t
	emit_signal("status_changed", t)


func _send(line: String) -> void:
	if ws and ws.get_peer(1).is_connected_to_host():
		ws.get_peer(1).put_packet((line + "\r\n").to_utf8())


func _on_open(_proto := "") -> void:
	ws.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	_send("PASS SCHMOOPIIE")
	_send("NICK justinfan%d" % (10000 + randi() % 80000))
	_send("JOIN #" + channel)


func _on_closed(_clean := false) -> void:
	connected = false
	_set_status(tr("Twitch: отключено, переподключение..."))
	_retry = 10.0


func _on_error() -> void:
	connected = false
	_url_i += 1
	_set_status(tr("Twitch: не удалось подключиться, ещё попытка через 10 с"))
	_retry = 10.0 if _url_i % URLS.size() == 0 else 1.0


func _on_data() -> void:
	var text := ws.get_peer(1).get_packet().get_string_from_utf8()
	for line in text.split("\r\n", false):
		handle_line(line)


func handle_line(line: String) -> void:
	if line.begins_with("PING"):
		_send("PONG" + line.substr(4))
		return
	var parts := line.split(" ", false, 3)
	if parts.size() >= 3 and parts[1] == "JOIN":
		connected = true
		_set_status(tr("Twitch: подключено к %s, чат может голосовать") % channel)
		return
	if parts.size() >= 4 and parts[1] == "PRIVMSG":
		var user: String = parts[0].trim_prefix(":").split("!")[0]
		var msg: String = parts[3]
		var i := msg.find(":")
		if i >= 0:
			msg = msg.substr(i + 1)
		emit_signal("chat", user, msg)


func _process(delta: float) -> void:
	if ws:
		ws.poll()
	if _retry > 0.0:
		_retry -= delta
		if _retry <= 0.0 and channel != "":
			start(channel)
