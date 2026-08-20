# Gods & Liars — Tooling Lock

This file freezes the development tooling used by the 72-hour MVP.

## Engine
- Godot 4.7.x

## Godot addons
- GdUnit4 `v6.2.0`
- Godot State Charts `v0.22.5`
- GodotSteam: runtime dependency, validated separately with Steam
- Maaack Input Remapping: planned, but not promoted to mandatory until it passes a Godot 4.7 smoke test
- Sentry: deferred until before public alpha

Third-party Godot addons are installed locally by:

```powershell
./tools/setup-dev-tools.ps1
```

Use `-Force` to refresh the pinned versions.

## QA / security
- GdUnit4 for unit/integration/scene tests
- Existing Godot headless smoke tests remain enabled
- gdtoolkit / gdlint in CI
- Gitleaks in CI
- GitHub Actions as the quality gate

## CI order
1. Gitleaks secret scan
2. gdtoolkit / gdlint
3. Install pinned addons
4. Godot 4.7 headless import/parse
5. Existing smoke tests
6. GdUnit4 tests

## Why addons are not committed
`addons/gdUnit4/` and `addons/godot_state_charts/` are reproducibly downloaded from pinned GitHub tags. Keeping them out of the repository avoids thousands of third-party files while preserving deterministic setup in local development and CI.

## Current GdUnit4 coverage
- eight-player role distribution
- vote tie behavior
- healer preventing a night kill

Next tests should cover dead-player restrictions, win conditions, READY authority, illegal role actions, disconnects, and full simulated rounds.
