# Steam production release — Gods & Liars

## Product identity

- Steam AppID: `5395580`
- Local transport QA AppID: `480` (Spacewar)
- Godot: 4.7
- Current pinned GodotSteam runtime: 4.20
- Current pinned Steamworks SDK inside that GodotSteam runtime: 1.64

The repository now treats AppID 480 as a local/direct-development fallback only. A launch performed by the real Steam client must keep the AppID supplied by Steam. For explicit local QA, `GODS_LIARS_STEAM_APP_ID` may override the bootstrap AppID.

## Important: steam_appid.txt

`steam_appid.txt` is a development convenience. It is intentionally valid for the Spacewar QA flow and must not be included in the production Steam depot.

Local QA artifacts opt in with:

```powershell
./tools/build-windows.ps1 -GodotBinary <godotsteam-editor> -Output build/steam-windows/GodsAndLiars.exe -IncludeSteamAppIdFile -ExpectedSteamAppId 480
```

Production artifacts must omit the switch. The build script removes a stale `steam_appid.txt` from the output directory when the switch is absent.

## Steamworks SDK 1.65

A Steamworks SDK 1.65 archive may be used later for SteamPipe tooling and, if needed, for a custom native rebuild. It must **not** be mixed blindly into the currently pinned GodotSteam 4.20 runtime, which is distributed as a Godot 4.7 / Steamworks 1.64 build.

Updating the SDK ZIP alone does not update the native GodotSteam binary. Move the runtime to 1.65 only when one of these is true:

1. an official GodotSteam build explicitly targets Godot 4.7 + Steamworks 1.65; or
2. the extension is rebuilt from source against 1.65 and the resulting editor/export templates pass the same Steam runtime and multiplayer gates.

Until then, keep the runtime internally consistent at the pinned 1.64 build.

## SteamPipe / depot status

The production AppID is known, but this repository must not invent a depot ID. Obtain the Windows depot ID from Steamworks and then add the SteamPipe VDF configuration using the real value.

Expected production upload contents:

- `GodsAndLiars.exe`
- `GodsAndLiars.pck`
- `steam_api64.dll`
- packaged runtime files required by the game/bot runtime

Must not be uploaded:

- `steam_appid.txt`
- tests
- reports
- docs
- development tools
- QA-only scenes or secrets

## Release validation order

1. GitHub CI green on the exact commit.
2. Steam-capable Windows export produced from that commit.
3. Production package contains no `steam_appid.txt`.
4. Upload to the real AppID/depot through SteamPipe.
5. Install the build through the Steam client, not by copying the local QA artifact.
6. Confirm Steam initializes under AppID 5395580.
7. Run two-account smoke test.
8. Run final exact-8 acceptance before release readiness.

The commercial gameplay rules are unchanged by this release work.
