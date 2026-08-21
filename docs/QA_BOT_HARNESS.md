# Gods & Liars — QA Bot Harness

## Purpose
QA bots exist to stress Mafia gameplay rules without requiring eight Steam accounts for every test run.

They do **not** replace the final Steam networking acceptance test. Synthetic bots do not create Steam identities, lobby members, relays, voice sessions, or independent network peers.

## Architecture
The bot harness is deliberately split from Steam transport:

`QABotBrain -> MatchSession / NightActionRules / VoteRules / NightResolver`

This lets CI run complete 8-player synthetic matches deterministically.

### QABotBrain profiles
- `BALANCED`: always chooses a legal action and is designed to make automated matches progress.
- `TIMEOUT`: deliberately submits no action. It is reserved for timeout/deadlock/failure-path testing.

More adversarial profiles can be added later without changing match rules.

## Current automated gate
`tests/unit/test_qa_bot_simulator.gd` validates:
- bot night targets are legal for their role;
- timeout bots submit no action;
- an 8-player synthetic match completes;
- 100 deterministic seeds complete without exceeding the round cap.

## LimboAI decision
LimboAI can later provide richer behavior trees/HSM decision logic behind the same bot-brain boundary.

For the current MVP, LimboAI is **optional**, not a runtime dependency. Gods & Liars already requires a GodotSteam-capable Godot 4.7 runtime exposing `SteamMultiplayerPeer`. Maintaining a combined custom engine only to add LimboAI for QA bots would increase build/runtime complexity without improving the transport tests that still require real Steam identities.

Therefore:
- deterministic QA brain: GDScript now;
- optional richer LimboAI adapter: later, if a combined GodotSteam + LimboAI runtime becomes justified;
- commercial game: bots remain disabled unless explicitly designed as a future gameplay feature.

## Test ladder
1. 1 real Steam account + synthetic bots: gameplay rules/stress.
2. 2 real Steam accounts: Party, lobby, transport, reservation, voice basics.
3. 2–4 real accounts + synthetic local gameplay simulation where useful.
4. 8 real Steam accounts: final commercial networking acceptance.
