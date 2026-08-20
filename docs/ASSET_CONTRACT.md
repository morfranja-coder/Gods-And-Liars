# Gods & Liars — Blender → Godot asset contract

This contract keeps the base character, tunic and mask interchangeable in the runtime avatar slots.

## Format
- Export as `.glb` (glTF 2.0).
- Apply transforms before export: scale `1,1,1`, rotation clean, origin consistent.
- Godot world scale: 1 unit = 1 meter.
- Character should be approximately human scale (~1.7–1.9 m).

## Shared rig
- Body and wearable assets must target the SAME armature/rest pose whenever they need to deform together.
- Do not rename bones after animation production starts.
- Keep one canonical skeleton for the MVP.
- Root/armature should be at world origin.
- Forward direction must be consistent across Body, Tunic and Mask.

## Runtime slots
Godot composes the player as:
- `Body`
- `Tunic`
- `Mask`

The body is the canonical rig owner. Tunic/mask must align to it without per-character hand correction.

## Mesh budget
- Prefer the optimized body (~10k faces / ~17k vertices) when visually equivalent to the high-poly source.
- Do not export hidden high-poly source meshes.
- Avoid embedded lights/cameras.

## Materials
- Keep material count low.
- Use sensible texture sizes for the MVP.
- No duplicated materials with identical properties unless needed.

## Animation minimum for MVP
Target clips/names (final naming can be normalized once):
- `idle_seated`
- `point`
- `vote`
- `death`

A ghost state can initially be handled in Godot via visibility/material effects and does not require a unique rig animation.

## Import destination
- Body: `assets/characters/body/`
- Tunic: `assets/clothing/tunics/`
- Mask: `assets/masks/`

Do not overwrite source Blender files with Godot-imported assets.
