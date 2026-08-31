# GODS & LIARS — Moderation Plan (Alpha)

## Goal
Reduce abusive text and give players immediate control over disruptive voice chat without overblocking normal gameplay language.

## Alpha scope
- Local per-player voice mute.
- Editable push-to-talk key.
- Text moderation layer for any future free-text fields (chat, custom lobby names, reports, etc.).
- Do not attempt automatic live voice censorship in the alpha: reliable multilingual voice moderation would require speech-to-text plus moderation and latency handling.

## Text moderation architecture
1. Normalize Unicode and case before matching.
2. Evaluate the declared UI/game language plus a language-agnostic severe-term layer.
3. Detect obfuscation variants conservatively (spacing, repeated punctuation, common substitutions) without aggressive fuzzy matching that creates false positives.
4. Separate categories:
   - profanity / insults;
   - identity-targeted hate or slurs;
   - threats / severe abuse;
   - sexual harassment;
   - spam.
5. Use action levels rather than one universal block:
   - allow;
   - mask term;
   - reject message;
   - flag for report telemetry.
6. Keep language packs as data files, not hard-coded in UI scripts, so supported languages can be added independently.
7. Never expose hidden dictionaries to clients if server-side enforcement is introduced later.

## Language policy
Support every language the game officially ships with. Do not promise every language worldwide unless that language is actually supported by the game. Each supported language needs reviewed terms and context exceptions; machine-translated slur lists are not sufficient.

## Voice safety
- Muting is local and immediate.
- Muted peers' packets are discarded before decompression/playback.
- Mutes are session-scoped for alpha.
- Later: add report/block integration and optionally persistent Steam-ID mutes.
- Later live moderation, if desired: voice -> STT -> moderation -> enforcement, designed separately because it changes latency, privacy disclosures, cost, and false-positive risk.
