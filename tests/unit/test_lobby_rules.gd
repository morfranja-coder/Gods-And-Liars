class_name LobbyRulesTest
extends GdUnitTestSuite

func test_start_requires_two_players() -> void:
	var peers := {1: LobbyRules.make_peer(1001, "Host", true)}
	assert_bool(LobbyRules.can_start(true, true, peers)).is_false()

func test_start_requires_everyone_ready() -> void:
	var peers := {
		1: LobbyRules.make_peer(1001, "Host", true),
		2: LobbyRules.make_peer(1002, "Guest", false),
	}
	assert_bool(LobbyRules.can_start(true, true, peers)).is_false()
	peers[2]["ready"] = true
	assert_bool(LobbyRules.can_start(true, true, peers)).is_true()

func test_gameplay_start_requires_exactly_eight_ready_players() -> void:
	var peers: Dictionary = {}
	for peer_id in range(1, QuickMatchRules.TARGET_PLAYERS):
		peers[peer_id] = LobbyRules.make_peer(1000 + peer_id, "P%d" % peer_id, true)
	assert_bool(LobbyRules.can_start(true, true, peers, MatchSession.MIN_PLAYERS)).is_false()
	peers[QuickMatchRules.TARGET_PLAYERS] = LobbyRules.make_peer(1008, "P8", true)
	assert_bool(LobbyRules.can_start(true, true, peers, MatchSession.MIN_PLAYERS)).is_true()

func test_client_cannot_start_even_when_everyone_ready() -> void:
	var peers := {
		1: LobbyRules.make_peer(1001, "Host", true),
		2: LobbyRules.make_peer(1002, "Guest", true),
	}
	assert_bool(LobbyRules.can_start(false, false, peers)).is_false()

func test_missing_ready_defaults_to_not_ready() -> void:
	var peers := {
		1: {"steam_id": 1001, "display_name": "Host"},
		2: LobbyRules.make_peer(1002, "Guest", true),
	}
	assert_bool(LobbyRules.all_ready(peers)).is_false()

func test_new_peer_is_rejected_when_lobby_is_full() -> void:
	var peers := {
		1: LobbyRules.make_peer(1001, "One"),
		2: LobbyRules.make_peer(1002, "Two"),
	}
	assert_bool(LobbyRules.can_register_peer(peers, 3, 2)).is_false()

func test_existing_peer_can_be_refreshed_when_lobby_is_full() -> void:
	var peers := {
		1: LobbyRules.make_peer(1001, "One"),
		2: LobbyRules.make_peer(1002, "Two"),
	}
	assert_bool(LobbyRules.can_register_peer(peers, 2, 2)).is_true()

func test_match_roster_is_capped_at_eight_even_if_transport_allows_more() -> void:
	var peers: Dictionary = {}
	for peer_id in range(1, QuickMatchRules.TARGET_PLAYERS + 1):
		peers[peer_id] = LobbyRules.make_peer(2000 + peer_id, "P%d" % peer_id)
	assert_bool(LobbyRules.can_register_peer(peers, 9, 10)).is_false()
