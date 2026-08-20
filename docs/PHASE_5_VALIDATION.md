# FASE 5 — Night Loop Validation Gate

FASE 5 covers the authoritative night cycle after private role reveal.

## Automated/code gate

- Every player must acknowledge the private role before night starts.
- Host synchronizes the phase order: NIGHT_START → HERETIC_ACTION → HEALER_ACTION → INQUISITOR_ACTION → NIGHT_RESOLUTION → DAY_DISCUSSION.
- Clients submit only a target intention; host validates actor, role, phase, alive state and target.
- Heretics cannot target another Heretic or themselves.
- Healer may protect any living player, including self.
- Inquisitor cannot investigate self.
- 7–10 player matches support two living Heretics and therefore up to two distinct night victims.
- Duplicate Heretic targets resolve to one victim.
- Healer protection blocks the protected target even during a double kill.
- Night deaths are public and replicated to all peers.
- Inquisitor result is delivered only to the Inquisitor.
- Dead state is reflected on the table without continuous transform replication.
- Night UI is mounted in the table scene and only enables Confirm during the local player's role phase.

## Automated checks

Run locally from PowerShell:

```powershell
.\tools\verify-local.ps1
```

Expected final line:

```text
GREEN: local quality gate passed.
```

GitHub CI must also remain green.

## Human multiplayer gate

Use at least 4 Steam clients/accounts for the real role loop. For the 2-Heretic double-kill case, use 7+ players or synthetic peers later.

1. Start a 4+ player match.
2. Every client receives exactly one private role.
3. Every client presses `Entendido`.
4. All clients enter the same Heretic phase.
5. Only Heretic clients see an enabled Confirm button after selecting a valid target.
6. Wrong-role clients remain waiting.
7. After all living Heretics act, all clients move to Healer phase.
8. After Healer acts, all clients move to Inquisitor phase.
9. Inquisitor receives its result privately.
10. Resolution marks killed players with `†` on every client.
11. Protected target remains alive.
12. All clients end in DAY_DISCUSSION.

## Exit gate

FASE 5 is CLOSED when CI/local quality gates are green and steps 1–12 pass on real multiplayer clients.
