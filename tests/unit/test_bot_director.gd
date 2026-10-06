# gdlint: disable=max-public-methods
extends GdUnitTestSuite


func before_test() -> void:
	PracticeManager.stop_practice()
	PracticeManager.start_seven_bot_match()


func after_test() -> void:
	PracticeManager.stop_practice()


func test_private_discoveries_do_not_leak_between_bots() -> void:
	BotDirector.record_investigation(2, 3, true)
	var own := BotDirector.build_prompt(2)
	var other := BotDirector.build_prompt(4)
	assert_str(own).contains('"3":true')
	assert_str(other).not_contains('"3":true')


func test_investigation_changes_vote_without_reading_other_roles() -> void:
	BotDirector.record_investigation(2, 3, true)
	BotDirector.record_investigation(2, 4, false)
	var candidates: Array[int] = [3, 4, 5]
	assert_int(BotDirector.preferred_vote(2, candidates)).is_equal(3)
	assert_int(BotDirector.preferred_vote(2, [4, 5])).is_equal(5)


func test_memory_is_bounded_and_names_unique() -> void:
	for index in range(40):
		BotDirector.remember(2, "message %d" % index)
	assert_int(BotDirector.history.size()).is_equal(18)
	var unique := {}
	for name_text in BotDirector.NAMES:
		unique[name_text] = true
	assert_int(unique.size()).is_equal(7)


func test_fallback_uses_server_language() -> void:
	var original: String = BotDirector.server_language
	BotDirector.server_language = "en"
	assert_str(BotDirector.build_prompt(2)).contains("Speak only English")
	BotDirector.server_language = "es"
	assert_str(BotDirector.build_prompt(2)).contains("Speak only Spanish")
	BotDirector.server_language = original


func test_direct_accusation_prompts_a_defense_instead_of_generic_speech() -> void:
	BotDirector.remember(1, "Bruno es un hereje.")
	var plan: Dictionary = BotDirector.turn_plan(3)
	assert_str(plan.intent).is_equal("defend")
	assert_str(plan.last_text).contains("Bruno")
	assert_str(BotDirector.turn_plan(2).intent).is_equal("ask_basis")


func test_public_vote_mismatch_produces_a_specific_follow_up() -> void:
	BotDirector.remember(6, "Voy a votar por Mateo.")
	BotDirector._on_vote(6, 3)
	var plan: Dictionary = BotDirector.turn_plan(2)
	assert_str(plan.intent).is_equal("vote_mismatch")
	assert_str(plan.target).is_equal("Inés")
	assert_str(plan.declared).is_equal("Mateo")
	assert_str(plan.actual).is_equal("Bruno")


func test_competing_role_claims_are_uncertain_public_evidence() -> void:
	BotDirector.remember(3, "Soy el inquisidor.")
	BotDirector.remember(4, "Soy el inquisidor.")
	var plan: Dictionary = BotDirector.turn_plan(2)
	assert_str(plan.intent).is_equal("competing_role_claim")
	assert_str(plan.confidence).contains("not proof")


func test_own_investigation_beats_rumors_without_leaking_to_other_bots() -> void:
	BotDirector.record_investigation(2, 3, true)
	BotDirector.remember(4, "Desconfío de Mateo.")
	assert_str(BotDirector.turn_plan(2).intent).is_equal("investigation_guilty")
	assert_str(BotDirector.turn_plan(4).confidence).is_not_equal("verified")
	assert_int(BotDirector.preferred_vote(2, [3, 5])).is_equal(3)


func test_verified_innocent_is_not_outvoted_by_repeated_rumors() -> void:
	BotDirector.record_investigation(2, 3, false)
	for id in range(4, 9):
		BotDirector.remember(id, "Bruno es hereje.")
	assert_int(BotDirector.preferred_vote(2, [3, 5])).is_equal(5)


func test_human_message_interrupts_old_reply_and_prioritizes_first_named_bot() -> void:
	BotDirector._on_phase(GameManager.MatchPhase.DAY_DISCUSSION)
	BotDirector._pending = 3
	BotDirector._set_typing(3)
	var previous_epoch: int = BotDirector._epoch
	BotDirector.submit_human_message("Lucia, ¿qué pensás de Bruno?")
	assert_int(BotDirector._requested_speaker).is_equal(4)
	assert_int(BotDirector._pending).is_equal(0)
	assert_int(BotDirector._typing_id).is_equal(0)
	assert_int(BotDirector._epoch).is_greater(previous_epoch)


func test_grounding_rejects_fake_sightings_and_investigations() -> void:
	assert_bool(BotDirector.reply_is_grounded(2, "Lo vi acercarse a Bruno anoche.")).is_false()
	assert_bool(BotDirector.reply_is_grounded(2, "Investigué a Bruno y es hereje.")).is_false()
	assert_bool(BotDirector.reply_is_grounded(2, "Sospecho de Bruno, pero no tengo una prueba.")).is_true()


func test_phase_change_clears_typing() -> void:
	var events: Array = []
	var listener := func(id): events.append(id)
	BotDirector.typing_changed.connect(listener)
	BotDirector._set_typing(3)
	BotDirector._on_phase(GameManager.MatchPhase.NIGHT_START)
	assert_array(events).contains_exactly([3, 0])
	BotDirector.typing_changed.disconnect(listener)


func test_bot_messages_are_text_only_and_do_not_emit_voice_events() -> void:
	BotDirector._on_phase(GameManager.MatchPhase.DAY_DISCUSSION)
	var voice_events: Array = []
	var listener := func(id): voice_events.append(id)
	VoiceChat.remote_talking.connect(listener)
	BotDirector._say(3, "Quiero comparar esos votos.")
	assert_array(voice_events).is_empty()
	assert_bool(get_tree().root.has_node("VoiceManager")).is_false()
	VoiceChat.remote_talking.disconnect(listener)


func test_replies_preserve_full_sentences_and_remove_name_prefix() -> void:
	assert_str(BotDirector.clean_reply("Bruno: No estoy seguro. ¿Qué pruebas tenés?", 3)).is_equal("No estoy seguro. ¿Qué pruebas tenés?")
	BotDirector.remember(2, "Una frase repetida.")
	assert_bool(BotDirector.reply_is_repeated(2, "Una frase repetida.")).is_true()


func test_questions_negations_and_quoted_roles_are_not_asserted_facts() -> void:
	var roster: Dictionary = NetworkManager.peers
	assert_array(BotDialogueReasoning.claims_from(2, "¿Bruno es hereje?", roster, 1)).is_empty()
	assert_array(BotDialogueReasoning.claims_from(2, "No desconfío de Bruno.", roster, 1)).is_empty()
	assert_array(BotDialogueReasoning.claims_from(2, "No voy a votar por Bruno.", roster, 1)).is_empty()
	assert_array(BotDialogueReasoning.claims_from(2, "Valeria dijo: soy el inquisidor.", roster, 1)).is_empty()


func test_names_are_literal_and_mentions_keep_text_order() -> void:
	var roster := {2: {"display_name": "A.*"}, 3: {"display_name": "Bruno"}, 5: {"display_name": "Mateo"}}
	assert_array(BotDialogueReasoning.mentions("Anything", roster)).is_empty()
	assert_array(BotDialogueReasoning.mentions("Mateo, preguntale a Bruno.", roster)).contains_exactly([5, 3])


func test_public_claim_memory_is_bounded() -> void:
	for index in range(100):
		BotDirector.remember(3, "Desconfío de Mateo.")
	assert_int(BotDirector.public_claims.size()).is_equal(64)
	assert_int(BotDirector.history.size()).is_equal(18)


func test_question_about_changing_opinion_is_answered_without_fake_accusation() -> void:
	BotDirector.remember(1, "Bruno, nadie te acusa ahora. ¿Cambiarías de opinión si hubiera una prueba?")
	assert_str(BotDirector.turn_plan(3).intent).is_equal("change_mind")
	assert_str(BotDirector.fallback_line(3)).not_contains("no me acuses")


func test_human_pronoun_is_not_confused_with_a_suspects_name() -> void:
	BotDirector.remember(1, "Bruno, ¿por qué tendría que confiar en vos?")
	var plan: Dictionary = BotDirector.turn_plan(3)
	assert_str(plan.intent).is_equal("defend")
	assert_int(plan.target_id).is_equal(0)


func test_reported_accusation_is_uncertain_and_uses_the_accused_target() -> void:
	BotDirector.remember(1, "Valeria, Bruno acusó a Mateo pero no explicó por qué. ¿Eso alcanza para votarlo?")
	var plan: Dictionary = BotDirector.turn_plan(2)
	assert_str(plan.intent).is_equal("evaluate_accusation")
	assert_str(plan.target).is_equal("Mateo")
	assert_array(BotDirector.public_claims).is_empty()


func test_question_only_reply_cannot_replace_answer_about_changing_opinion() -> void:
	assert_bool(BotDirector.reply_answers_plan("¿Qué pruebas tenés?", {"intent": "change_mind"})).is_false()
	assert_bool(BotDirector.reply_answers_plan("Sí, cambiaría si aparece una prueba confiable.", {"intent": "change_mind"})).is_true()


func test_direct_answer_fallbacks_exist_in_every_supported_language() -> void:
	for language in ["es", "en", "pt", "fr"]:
		var change := BotDialogueReasoning.compose({"intent": "change_mind"}, language, 0, 0)
		var accusation := BotDialogueReasoning.compose({"intent": "evaluate_accusation", "target": "Mateo"}, language, 0, 0)
		var opening := BotDialogueReasoning.compose({"intent": "opening"}, language, 0, 0)
		assert_str(change).is_not_equal(opening)
		assert_str(accusation).contains("Mateo")
		assert_bool(BotDirector.reply_answers_plan(change, {"intent": "change_mind"})).is_true()


func test_fake_witness_question_is_rejected() -> void:
	assert_bool(BotDirector.reply_is_grounded(2, "¿Has visto a Mateo salir de la habitación con un libro?")).is_false()


func test_confidence_question_requires_a_relevant_defense() -> void:
	assert_bool(BotDirector.reply_answers_plan("¿Por qué no confío en mí misma? El corazón me dice que soy honesta.", {"intent": "defend"})).is_false()
	assert_bool(BotDirector.reply_answers_plan("No te pido confianza a ciegas. Compará mis palabras y votos.", {"intent": "defend"})).is_true()


func test_bots_understand_stationary_avatars_and_abstract_night_actions() -> void:
	var prompt := BotDirector.build_prompt(3)
	assert_str(prompt).contains("Avatars stay in place")
	assert_str(prompt).contains("Night actions are abstract choices")
	assert_bool(BotDirector.reply_is_grounded(3, "Mateo me persiguió anoche y me escondí.")).is_false()
	assert_bool(BotDirector.reply_is_grounded(3, "Bruno corrió hacia la puerta.")).is_false()
	assert_bool(BotDirector.reply_is_grounded(3, "Mateo cambió de voto y no explicó por qué.")).is_true()


func test_impossible_night_encounter_is_corrected_instead_of_used_as_evidence() -> void:
	BotDirector.remember(1, "Bruno, ¿viste a Mateo correr o perseguir a alguien anoche?")
	assert_str(BotDirector.turn_plan(3).intent).is_equal("game_rules")
	assert_str(BotDirector.fallback_line(3)).contains("noche")
	assert_bool(BotDirector.reply_answers_plan("La confianza es un derecho, no un derecho de sospechar.", {"intent": "change_mind"})).is_false()
