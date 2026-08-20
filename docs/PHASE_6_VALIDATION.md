# FASE 6 — Day, Voting and Sacrifice Gate

## Automated/code gate

- Host controls transition from DAY_DISCUSSION to VOTING.
- Only living players can vote.
- Votes may target only another living player.
- One authoritative vote per living voter is stored on the host.
- Vote resolution waits until every living player has submitted a valid vote.
- A unique highest vote target is sacrificed.
- A tie sacrifices nobody.
- Sacrifice updates host MatchSession and public alive state.
- Table refresh marks sacrificed players as dead.
- Flow ends at WIN_CHECK for FASE 7.
- Voice is open in lobby, muted during role reveal/night, and routed during day so living voices reach everyone while dead voices reach dead players only.

## Automated checks

Run locally from PowerShell:

```powershell
.\tools\verify-local.ps1
```

Expected result:

```text
GREEN: local quality gate passed.
```

GitHub CI must remain green for Gitleaks, gdlint, Godot import/parse, smoke tests and GdUnit4.

## Human gate

1. Finish one night and reach DAY_DISCUSSION on all clients.
2. Verify voice works between living players.
3. Verify a dead player can hear living players but living players cannot hear a dead player's voice.
4. Host presses `Abrir votación`; every client enters VOTING.
5. A living player cannot vote for self or a dead player.
6. Every living player submits one vote.
7. Unique winner: all clients show the same sacrificed player and the avatar gains the dead marker.
8. Tie case: all clients show that nobody was sacrificed.
9. After resolution all clients reach WIN_CHECK.

## Exit gate

FASE 6 is CLOSED when automated CI is green and steps 1–9 pass with real multiplayer clients.
