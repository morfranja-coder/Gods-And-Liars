class_name RoleRevealCopy
extends RefCounted

const TITLES := {
	"es": ["Sin revelar", "Fiel", "Hereje", "Sacerdote", "Inquisidor"],
	"en": ["Unrevealed", "Faithful", "Heretic", "Priest", "Inquisitor"],
	"pt": ["Não revelado", "Fiel", "Herege", "Sacerdote", "Inquisidor"],
	"fr": ["Non révélé", "Fidèle", "Hérétique", "Prêtre", "Inquisiteur"]
}
const DETAILS := {
	"es":
	[
		"",
		"Descubrí a los herejes. Tus votos deciden el ritual.",
		"Eliminá a los fieles sin revelar tu rol.",
		"Protegé a un jugador cada noche. La primera protección es automática.",
		"Investigá una máscara desde la segunda noche. El resultado es privado."
	],
	"en":
	[
		"",
		"Find the heretics. Your votes decide the ritual.",
		"Eliminate the faithful without revealing your role.",
		"Protect one player each night. The first protection is automatic.",
		"Investigate a mask from the second night. The result is private."
	],
	"pt":
	[
		"",
		"Descubra os hereges. Seus votos decidem o ritual.",
		"Elimine os fiéis sem revelar seu papel.",
		"Proteja um jogador por noite. A primeira proteção é automática.",
		"Investigue uma máscara a partir da segunda noite. O resultado é privado."
	],
	"fr":
	[
		"",
		"Trouvez les hérétiques. Vos votes décident du rituel.",
		"Éliminez les fidèles sans révéler votre rôle.",
		"Protégez un joueur chaque nuit. La première protection est automatique.",
		"Enquêtez sur un masque dès la deuxième nuit. Le résultat est privé."
	]
}


static func title(role: int, language: String) -> String:
	return TITLES.get(language, TITLES.es)[clampi(role, 0, 4)]


static func description(role: int, language: String, teammate: String = "") -> String:
	var text: String = DETAILS.get(language, DETAILS.es)[clampi(role, 0, 4)]
	if role == PlayerState.Role.HERETIC and not teammate.is_empty():
		var formats := {"es": " Tu compañero: %s.", "en": " Your teammate: %s.", "pt": " Seu parceiro: %s.", "fr": " Votre partenaire : %s."}
		text += str(formats.get(language, formats.es)) % teammate
	return text


static func tint(role: int) -> Color:
	match role:
		PlayerState.Role.HERETIC:
			return Color("e05c48")
		PlayerState.Role.HEALER:
			return Color("f3dfaf")
		PlayerState.Role.INQUISITOR:
			return Color("e5d5b4")
		_:
			return Color("b8d2f6")
