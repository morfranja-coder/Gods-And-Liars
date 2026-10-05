# Gods & Liars

Social deduction game built with Godot 4.7.

## Current milestone

Core multiplayer hardening is complete on the current validation branch.

The project now moves into:

1. local practice QA with one human + seven bots;
2. real Steam smoke testing with independent accounts;
3. structural/UI polish;
4. final exact-8 human Steam acceptance before calling the MVP release-ready.

Canonical local QA instructions live in `docs/LOCAL_TESTING.md`.

## Current commercial Mafia rules

- exactly 8 players;
- 2 Heretics, 1 Priest, 1 Inquisitor, 4 Faithful;
- one Heretic decider acts each night and rotates by round;
- Night 1: Heretic attacks, God warns the Priest, Priest auto-protects that target, Inquisitor rests, nobody dies;
- later nights: Priest and Inquisitor act normally;
- Priest may self-save once per match;
- each living player has one non-replaceable vote per voting window;
- tied top vote targets are resolved authoritatively with the server RNG;
- host migration is disabled for the MVP; if the host leaves, the current match ends cleanly.
