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
