extends Node
# Кооп по сети (автозагрузка Net): хост держит физику посылок и клиентов, остальные шлют свои действия.
# ENet, порт PORT (UDP). Для игры через интернет нужен проброс порта или VPN (Radmin VPN, Hamachi).

signal status(text)
signal peers_changed

const PORT := 24680
const MAX_PLAYERS := 4

var active := false
var is_host := false
var seed_value := 0
var peers := []  # id подключённых (кроме себя)


func host() -> bool:
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
