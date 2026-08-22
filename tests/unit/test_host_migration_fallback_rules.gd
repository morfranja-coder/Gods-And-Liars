class_name HostMigrationFallbackRulesTest
extends GdUnitTestSuite

func test_fallback_starts_only_once() -> void:
	assert_bool(HostMigrationFallbackRules.should_start(false)).is_true()
	assert_bool(HostMigrationFallbackRules.should_start(true)).is_false()

func test_empty_reason_uses_safe_default() -> void:
	assert_str(HostMigrationFallbackRules.normalize_reason("   ")).is_equal(
		HostMigrationFallbackRules.DEFAULT_REASON
	)

func test_reason_is_trimmed_but_preserved() -> void:
	assert_str(
		HostMigrationFallbackRules.normalize_reason("  No se pudo restaurar la partida.  ")
	).is_equal("No se pudo restaurar la partida.")
