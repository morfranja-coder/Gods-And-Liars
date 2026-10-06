class_name BotDialogueReasoning
extends RefCounted


static func fold(text: String) -> String:
	var result := text.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"]]:
		result = result.replace(pair[0], pair[1])
	return result


static func regex_name(text: String) -> String:
	var escaped := text
	for character in ["\\", ".", "+", "*", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|"]:
		escaped = escaped.replace(character, "\\" + character)
	return escaped


static func mentions(text: String, roster: Dictionary) -> Array[int]:
	var found: Array[int] = []
	var normalized := fold(text)
	for raw_id in roster:
		var id := int(raw_id)
		var name_text := fold(str(roster[id].get("display_name", "")))
		if name_text.is_empty() or name_text in ["vos", "yo", "you", "me", "moi", "voce", "tu"]:
			continue
		var pattern := RegEx.new()
		pattern.compile("(?<![\\p{L}\\p{N}_])" + regex_name(name_text) + "(?![\\p{L}\\p{N}_])")
		if pattern.search(normalized) != null:
			found.append(id)
	found.sort_custom(func(a, b): return normalized.find(fold(str(roster[a].display_name))) < normalized.find(fold(str(roster[b].display_name))))
	return found


static func claims_from(speaker: int, text: String, roster: Dictionary, round_id: int) -> Array[Dictionary]:
	var claims: Array[Dictionary] = []
	var normalized := fold(text)
	for target in mentions(text, roster):
		var name_text := regex_name(fold(str(roster[target].get("display_name", ""))))
		var reported := " dijo" in normalized or " said" in normalized or " disse" in normalized or " dit" in normalized
		for mentioned in mentions(text, roster):
			if fold(str(roster[mentioned].display_name)) + " acuso a " in normalized:
				reported = true
		var accusation := RegEx.new()
		accusation.compile(
			(
				"(?:desconfio de |sospecho de |acuso a |i suspect |i distrust |suspeito de |je soupconne )"
				+ name_text
				+ "|"
				+ name_text
				+ " (?:es (?:un )?hereje|miente|is (?:a )?heretic|is lying|e herege|est heretique)"
			)
		)
		if (
			not reported
			and accusation.search(normalized) != null
			and not normalized.contains("?")
			and target != speaker
			and not ("no desconfio de" in normalized or "no sospecho de" in normalized)
		):
			claims.append({"kind": "accusation", "speaker": speaker, "target": target, "round": round_id, "text": text.left(280)})
		var intention := RegEx.new()
		intention.compile(
			"(?:voy a votar (?:a |por )|votare (?:a |por )|mi voto (?:es para |va para )|i(?:'m| am) voting for |i will vote for |vou votar (?:em |no )|je vote pour )" + name_text
		)
		if intention.search(normalized) != null and not normalized.contains("?") and not ("no voy a votar" in normalized or "no votare" in normalized):
			claims.append({"kind": "intention", "speaker": speaker, "target": target, "round": round_id, "text": text.left(280)})
	for role in ["inquisitor", "healer"]:
		var terms: Array = (
			["soy el inquisidor", "soy inquisidor", "i am the inquisitor", "i'm the inquisitor", "sou o inquisidor", "je suis l'inquisiteur"]
			if role == "inquisitor"
			else ["soy el sanador", "soy sanador", "i am the healer", "i'm the healer", "sou o curandeiro", "je suis le guerisseur"]
		)
		for term in terms:
			if (normalized.begins_with(term) or normalized.begins_with("yo " + term)) and not normalized.contains("?"):
				claims.append({"kind": "role_claim", "speaker": speaker, "role": role, "round": round_id, "text": text.left(280)})
				break
	return claims


static func accusation_topic(text: String, roster: Dictionary) -> int:
	var normalized := fold(text)
	for target in mentions(text, roster):
		var pattern := RegEx.new()
		pattern.compile("(?:acus(?:a|o) a |desconfio de |sospecho de |accus(?:ed|es) |suspect )" + regex_name(fold(str(roster[target].display_name))))
		if pattern.search(normalized) != null:
			return target
	return 0


static func assess(actor: int, facts: Dictionary, claims: Array[Dictionary], votes: Array[Dictionary], candidates: Array[int], round_id: int) -> Dictionary:
	var assessment: Dictionary = {}
	for candidate in candidates:
		if candidate != actor:
			assessment[candidate] = {"score": 0.0, "reasons": []}
	var accusers: Dictionary = {}
	var intentions: Dictionary = {}
	var role_claims: Dictionary = {}
	for claim in claims:
		var speaker := int(claim.speaker)
		match claim.kind:
			"accusation":
				var target := int(claim.target)
				if assessment.has(target) and speaker != actor:
					accusers[str(speaker) + ":" + str(target)] = target
			"intention":
				var key := str(speaker) + ":" + str(claim.round)
				if intentions.has(key) and int(intentions[key].target) != int(claim.target) and int(claim.round) == round_id:
					_add(assessment, speaker, 0.35, {"kind": "changed_intention", "target": claim.target})
				intentions[key] = claim
			"role_claim":
				role_claims[speaker] = str(claim.role)
	for target in accusers.values():
		_add(assessment, int(target), 0.12, {"kind": "unverified_accusation"})
	for vote in votes:
		var key := str(vote.voter) + ":" + str(vote.round)
		if intentions.has(key) and int(intentions[key].target) != int(vote.target):
			_add(assessment, int(vote.voter), 0.8, {"kind": "vote_mismatch", "declared": intentions[key].target, "actual": vote.target, "round": vote.round})
	for speaker in role_claims:
		for other in role_claims:
			if int(speaker) < int(other) and role_claims[speaker] == role_claims[other]:
				_add(assessment, int(speaker), 0.6, {"kind": "competing_role_claim", "other": other, "role": role_claims[speaker]})
				_add(assessment, int(other), 0.6, {"kind": "competing_role_claim", "other": speaker, "role": role_claims[speaker]})
	for target in facts:
		if assessment.has(int(target)):
			assessment[int(target)].score = 100.0 if bool(facts[target]) else -100.0
			assessment[int(target)].reasons.push_front({"kind": "investigation_guilty" if bool(facts[target]) else "investigation_clear"})
	return assessment


static func _add(assessment: Dictionary, target: int, score: float, reason: Dictionary) -> void:
	if not assessment.has(target):
		return
	assessment[target].score = minf(2.0, float(assessment[target].score) + score)
	assessment[target].reasons.append(reason)


static func compose(plan: Dictionary, language: String, style: int, variant: int) -> String:
	var lines: Dictionary = {
		"es":
		{
			"game_rules":
			[
				"Eso no puede pasar acá: los jugadores no se desplazan. La noche se resuelve con acciones del rol, así que no podemos usar una persecución como prueba.",
				"No, nadie corre ni persigue a otro durante la noche. Para sospechar de Mateo necesito algo del chat, los votos o un resultado del juego."
			],
			"change_mind":
			[
				"Sí, cambiaría de opinión si aparece una prueba que contradiga lo que pienso. No tiene sentido aferrarme a una sospecha.",
				"Si aparece un dato confiable, lo reviso. Prefiero corregirme antes que votar por orgullo."
			],
			"evaluate_accusation":
			[
				"No, acusar a {target} sin explicar el motivo no alcanza para votarlo. Quiero saber qué dato sostiene esa acusación.",
				"Por ahora no votaría a {target} solo por eso. Una sospecha sin fundamento todavía no es una prueba."
			],
			"uncertain":
			[
				"Todavía no tengo un dato que me permita asegurarlo. Prefiero admitir la duda antes que inventar una explicación.",
				"No estoy seguro; con lo que sabemos ahora no puedo afirmarlo. Podemos comparar lo que dijeron y cómo votaron."
			],
			"defend":
			[
				"Pará, ¿en qué te basás? Si hay una contradicción, decime cuál.",
				"No te pido confianza a ciegas. ¿Qué dije o voté que te hace sospechar?",
				"Entiendo la duda, pero nombrarme no es una prueba. Discutamos algo concreto."
			],
			"investigation_guilty":
			[
				"Tengo un resultado de investigación sobre {target}: es hereje. Voy a votarlo.",
				"Investigué a {target} y el resultado fue hereje. Para mí ese dato pesa más que una sospecha."
			],
			"investigation_clear":
			["Mi investigación dio inocente para {target}. Esa acusación no me cierra.", "Con el dato que tengo, {target} no es hereje. No lo votaría solo por esa sospecha."],
			"vote_mismatch":
			[
				"{target}, dijiste que votarías a {declared}, pero votaste a {actual}. ¿Qué te hizo cambiar?",
				"No entiendo ese voto, {target}. Habías elegido a {declared} y terminaste votando a {actual}. ¿Por qué?"
			],
			"changed_intention":
			[
				"{target}, cambiaste de candidato. ¿Qué dato nuevo te convenció?",
				"Antes elegías a otra persona, {target}. Puede tener sentido cambiar, pero quiero entender el motivo."
			],
			"competing_role_claim":
			[
				"{target} y {other} dicen tener el mismo rol. No pueden ser ambos. ¿Cómo sostienen esa versión?",
				"Las versiones de {target} y {other} no encajan: los dos reclaman {role}. Eso hay que aclararlo."
			],
			"ask_basis":
			[
				"¿Qué dato concreto te hace sospechar de {target}? Quiero separar una acusación de una prueba.",
				"Lo de {target} por ahora es una sospecha. ¿Qué dijo o votó que no encaja?",
				"No descarto a {target}, pero todavía no hay una prueba. ¿En qué se basa esa acusación?"
			],
			"follow_up":
			[
				"¿Por qué decís eso? Quiero entender qué dato te llevó a esa conclusión.",
				"No estoy tan seguro. ¿Estamos hablando de un hecho o de algo que alguien supuso?",
				"Eso puede tener sentido, pero falta explicar el motivo. ¿Qué cambió desde lo que dijiste antes?"
			],
			"opening":
			[
				"Todavía no tengo una acusación firme. ¿Quién quiere explicar sus sospechas primero?",
				"Antes de votar, quiero escuchar qué sabe cada uno y qué está suponiendo.",
				"No voy a elegir a alguien porque sí. ¿Hay algún voto o versión que no encaje?",
				"A ver, ¿qué sabemos de verdad hasta ahora? Prefiero una duda concreta a señalar por señalar."
			]
		},
		"en":
		{
			"game_rules": ["That cannot happen here: avatars stay in place. Night actions are resolved by game rules, so a chase cannot be evidence."],
			"change_mind": ["Yes, I would change my mind if reliable evidence contradicted my suspicion. Being stubborn helps nobody."],
			"evaluate_accusation": ["No, accusing {target} without explaining why is not enough to vote them out. I want a concrete reason."],
			"uncertain": ["I do not have enough information to be sure yet. Let's compare statements and votes."],
			"defend":
			[
				"What exactly makes you suspect me? Tell me which statement or vote doesn't add up.",
				"I get why you're unsure, but naming me isn't evidence. What are you basing this on?"
			],
			"investigation_guilty": ["I investigated {target}: the result was heretic. That's who I'm voting for."],
			"investigation_clear": ["My investigation cleared {target}. I wouldn't vote for them based on that suspicion."],
			"vote_mismatch": ["{target}, you said you'd vote for {declared}, but voted for {actual}. What changed?"],
			"changed_intention": ["{target}, you changed your candidate. What new evidence convinced you?"],
			"competing_role_claim": ["{target} and {other} both claim the same unique role. Both can't be right. Explain that."],
			"ask_basis": ["What evidence supports the accusation against {target}?", "I'm not ruling out {target}, but suspicion alone isn't proof."],
			"follow_up": ["Why do you think that? Which fact led you there?", "Is that something we know, or someone's guess?"],
			"opening": ["I'm not sure yet. Who wants to explain their suspicions?", "Let's compare what people said with how they voted."]
		},
		"pt":
		{
			"game_rules": ["Isso não acontece aqui: os avatares ficam no lugar. A noite é resolvida pelas ações dos papéis, não por perseguições."],
			"change_mind": ["Sim, mudaria de opinião se uma prova confiável contradissesse minha suspeita. Prefiro me corrigir."],
			"evaluate_accusation": ["Não, acusar {target} sem explicar o motivo não basta para votar nele. Falta uma razão concreta."],
			"uncertain": ["Ainda não tenho informação suficiente para afirmar isso. Vamos comparar as falas e os votos."],
			"defend": ["Por que você suspeita de mim? Qual fala ou voto não faz sentido?", "Entendo a dúvida, mas citar meu nome não é uma prova."],
			"investigation_guilty": ["Investiguei {target}: o resultado foi herege. Vou votar nele."],
			"investigation_clear": ["Minha investigação inocentou {target}. Essa acusação não me convence."],
			"vote_mismatch": ["{target}, você disse que votaria em {declared}, mas votou em {actual}. O que mudou?"],
			"changed_intention": ["{target}, você mudou de candidato. Que informação nova te convenceu?"],
			"competing_role_claim": ["{target} e {other} dizem ter o mesmo papel único. Os dois não podem estar certos."],
			"ask_basis": ["Que prova sustenta a acusação contra {target}?", "Suspeitar de {target} não basta. Qual fato não encaixa?"],
			"follow_up": ["Por que você acha isso? Qual foi a informação?", "Isso é um fato ou apenas uma suposição?"],
			"opening": ["Ainda não tenho certeza. Quem quer explicar suas suspeitas?", "Vamos comparar as falas com os votos."]
		},
		"fr":
		{
			"game_rules": ["Cela ne peut pas arriver ici : les avatars restent sur place. La nuit se résout par les actions des rôles, pas par des poursuites."],
			"change_mind": ["Oui, je changerais d'avis si une preuve fiable contredisait mon soupçon. Je préfère me corriger."],
			"evaluate_accusation": ["Non, accuser {target} sans expliquer pourquoi ne suffit pas pour voter contre lui. Il faut une raison concrète."],
			"uncertain": ["Je n'ai pas assez d'informations pour en être sûr. Comparons les déclarations et les votes."],
			"defend": ["Pourquoi me soupçonnes-tu ? Quelle déclaration ou quel vote ne colle pas ?", "Je comprends le doute, mais citer mon nom ne prouve rien."],
			"investigation_guilty": ["J'ai enquêté sur {target} : le résultat était hérétique. Je voterai contre lui."],
			"investigation_clear": ["Mon enquête a innocenté {target}. Cette accusation ne me convainc pas."],
			"vote_mismatch": ["{target}, tu annonçais un vote contre {declared}, mais tu as voté contre {actual}. Pourquoi ?"],
			"changed_intention": ["{target}, tu as changé de candidat. Quel nouveau fait t'a convaincu ?"],
			"competing_role_claim": ["{target} et {other} revendiquent le même rôle unique. Ils ne peuvent pas avoir raison tous les deux."],
			"ask_basis": ["Quelle preuve soutient l'accusation contre {target} ?", "Soupçonner {target} ne suffit pas. Quel fait ne colle pas ?"],
			"follow_up": ["Pourquoi penses-tu cela ? Quel fait t'a convaincu ?", "Est-ce un fait ou une supposition ?"],
			"opening": ["Je ne suis pas encore sûr. Qui veut expliquer ses soupçons ?", "Comparons les déclarations avec les votes."]
		}
	}
	var choices: Array = lines.get(language, lines.es).get(plan.intent, lines.get(language, lines.es).opening)
	var text: String = str(choices[(variant + style) % choices.size()]).format(plan)
	return text
