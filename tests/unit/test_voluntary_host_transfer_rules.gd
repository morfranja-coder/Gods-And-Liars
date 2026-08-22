class_name VoluntaryHostTransferRulesTest
extends GdUnitTestSuite

func test_valid_backup_can_receive_voluntary_transfer() -> void:
	var roster := {
		1: {"steam_id": 1001},
		2: {"steam_id": 1002},
	}
	assert_bool(
		VoluntaryHostTransferRules.can_transfer(77, 1001, 1002, 2, roster, true)
	).is_true()

func test_transfer_requires_valid_backup_snapshot() -> void:
	var roster := {
		1: {"steam_id": 1001},
		2: {"steam_id": 1002},
	}
	assert_bool(
		VoluntaryHostTransferRules.can_transfer(77, 1001, 1002, 2, roster, false)
	).is_false()

func test_transfer_rejects_missing_or_mismatched_backup_member() -> void:
	var roster := {
		1: {"steam_id": 1001},
		2: {"steam_id": 1003},
	}
	assert_bool(
		VoluntaryHostTransferRules.can_transfer(77, 1001, 1002, 2, roster, true)
	).is_false()
	assert_bool(
		VoluntaryHostTransferRules.can_transfer(77, 1001, 1002, 3, roster, true)
	).is_false()

func test_transfer_rejects_current_host_as_successor() -> void:
	var roster := {
		1: {"steam_id": 1001},
	}
	assert_bool(
		VoluntaryHostTransferRules.can_transfer(77, 1001, 1001, 1, roster, true)
	).is_false()
