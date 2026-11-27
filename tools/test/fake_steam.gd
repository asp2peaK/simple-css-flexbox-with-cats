extends Reference
# Подделка GodotSteam для локальной проверки Steam-кооперации без Steam:
# два процесса на одном ПК, «P2P» = UDP на localhost. Запуск: --fakesteam=host / --fakesteam=join
# (только для тестов, в игре не используется).

signal lobby_created(connect, lobby_id)
signal lobby_joined(lobby, permissions, locked, response)
signal join_requested(lobby_id, steam_id)
signal lobby_chat_update(lobby_id, changed_id, making_change_id, chat_state)
signal p2p_session_request(remote_steam_id)
signal p2p_session_connect_fail(remote_steam_id, session_error)

const HOST_SID := 76561198000000101
const JOIN_SID := 76561198000000202
const LOBBY := 109775240000000555

var me := 0
var udp := PacketPeerUDP.new()
var queues := {0: [], 1: []}
var accepted := {}


func _init(role: String) -> void:
	me = HOST_SID if role == "host" else JOIN_SID
	udp.listen(_port(me), "127.0.0.1")


func _port(sid: int) -> int:
	return 31000 + (sid % 1000)


func run_callbacks() -> void:
	while udp.get_available_packet_count() > 0:
		var b: PoolByteArray = udp.get_packet()
		var ch: int = b[0]
		var from: int = HOST_SID if b[1] == 1 else JOIN_SID
		if not accepted.has(from):
			accepted[from] = true
			emit_signal("p2p_session_request", from)
		queues[ch].append({"data": b.subarray(2, b.size() - 1) if b.size() > 2 else PoolByteArray(), "remote_steam_id": from})


func sendP2PPacket(sid: int, data: PoolByteArray, _mode: int, ch: int) -> bool:
	var b := PoolByteArray([ch, 1 if me == HOST_SID else 2])
	b.append_array(data)
	udp.set_dest_address("127.0.0.1", _port(sid))
	return udp.put_packet(b) == OK


func getAvailableP2PPacketSize(ch: int) -> int:
	run_callbacks()
	return 0 if queues[ch].empty() else max(1, queues[ch][0]["data"].size())


func readP2PPacket(_n: int, ch: int) -> Dictionary:
	return queues[ch].pop_front() if not queues[ch].empty() else {}


func createLobby(_t: int, _m: int) -> void:
	call_deferred("emit_signal", "lobby_created", 1, LOBBY)


func joinLobby(lid: int) -> void:
	call_deferred("emit_signal", "lobby_joined", lid, 0, false, 1)


func getSteamID() -> int: return me
func getLobbyOwner(_l: int) -> int: return HOST_SID
func getNumLobbyMembers(_l: int) -> int: return 2
func getLobbyMemberByIndex(_l: int, i: int) -> int: return HOST_SID if i == 0 else JOIN_SID
func getLobbyData(_l: int, _k: String) -> String: return "notmyparcel"
func getPersonaName() -> String: return "Host" if me == HOST_SID else "Guest"
func getFriendPersonaName(sid: int) -> String: return "Host" if sid == HOST_SID else "Guest"
func getAppID() -> int: return 480
func getFriendCount(_f: int) -> int: return 0
func getFriendByIndex(_i: int, _f: int) -> int: return 0
func getFriendGamePlayed(_s: int) -> Dictionary: return {}
func getLaunchCommandLine() -> String: return ""
func allowP2PPacketRelay(_a: bool) -> bool: return true
func acceptP2PSessionWithUser(_s: int) -> bool: return true
func closeP2PSessionWithUser(_s: int) -> bool: return true
func setLobbyData(_l: int, _k: String, _v: String) -> bool: return true
func setLobbyJoinable(_l: int, _j: bool) -> bool: return true
func setRichPresence(_k: String, _v: String) -> bool: return true
func leaveLobby(_l: int) -> void: pass
func activateGameOverlayInviteDialog(_l: int) -> void: pass
func setAchievement(_id: String) -> bool: return true
func storeStats() -> bool: return true
