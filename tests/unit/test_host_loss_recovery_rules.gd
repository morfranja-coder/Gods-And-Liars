class_name HostLossRecoveryRulesTest
extends GdUnitTestSuite

func test_backup_with_snapshot_can_promote() -> void:
	assert_int(
		int(HostLossRecoveryRules.role_for(1002, 1002, 1002, true))
	).is_equal(int(HostLossRecoveryRules.RecoveryRole.BACKUP))

func test_backup_without_snapshot_cannot_promote() -> void:
	assert_int(
		int(HostLossRecoveryRules.role_for(1002, 1002, 1002, false))
	).is_equal(int(HostLossRecoveryRules.RecoveryRole.NONE))

func test_temporary_owner_is_identified_for_handoff() -> void:
	assert_int(
		int(HostLossRecoveryRules.role_for(1003, 1002, 1003, false))
	).is_equal(int(HostLossRecoveryRules.RecoveryRole.TEMPORARY_OWNER))
	assert_bool(
		HostLossRecoveryRules.should_handoff_temporary_owner(1003, 1002, 1003)
	).is_true()

func test_observer_waits_for_backup_owner() -> void:
	assert_int(
		int(HostLossRecoveryRules.role_for(1004, 1002, 1003, false))
	).is_equal(int(HostLossRecoveryRules.RecoveryRole.OBSERVER))

func test_owner_confirmation_requires_backup_identity() -> void:
	assert_bool(HostLossRecoveryRules.owner_confirms_backup(1002, 1002)).is_true()
	assert_bool(HostLossRecoveryRules.owner_confirms_backup(1003, 1002)).is_false()
	assert_bool(HostLossRecoveryRules.owner_confirms_backup(0, 1002)).is_false()

func test_invalid_backup_disables_recovery_role() -> void:
	assert_int(
		int(HostLossRecoveryRules.role_for(1003, 0, 1003, true))
	).is_equal(int(HostLossRecoveryRules.RecoveryRole.NONE))
	assert_bool(
		HostLossRecoveryRules.should_handoff_temporary_owner(1003, 0, 1003)
	).is_false()
