# Mi Pico y Placa - recovery checkpoint

Date: 2026-09-11. Status: PARTIAL / WAITING_OWNER_VISUAL_APPROVAL.

## Current state
- Repository: temp/VIAJE-R1-real-planner.
- Branch: codex/plate-owner-fidelity.
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Existing Home/plates WIP preserved; nothing staged/committed/pushed by this sublot.
- Latest owner request: audit after Codex restart and continue. Completed resume
  checks, repeated focused tests, physical QA and report. Cause of app/Codex hang
  is not established; do not attribute it to corruption or to a specific component.

## Implemented
- Extracted TodayRestrictionSummary from approved Home presentation.
- Personal Pico compact identity, single summary, rule reason, calendar, sources.
- Stable calendar key fixes loss of monthly state during reload/date changes.
- 48 dp month cells at 360 dp; Material ancestor for expanded source list.
- Home appearance/action and temporary jurisdiction semantics preserved.

## Verification
- 378 focused tests PASS after restart (40 seconds), log pico-clarity-resume-focused.txt.
- 12 layout exports PASS, log pico-clarity-final-layout.txt.
- Analyze PASS after restart; source format 256 files / 0 changes; diff check PASS.
- Release build previously PASS (55.1 s); no runtime edits after this build.
- APK local hash independently matches installed base.apk on Mi A3.
- Phone restricted/allowed, day/month, source and temporary city/back tested.
- Physical final captures named pico-clarity-final-*.png under evidence screenshots.
- The accidental lockscreen file pico-clarity-final-restricted.png was replaced
  with a real app capture after unlock. Never use incidental notification captures.

## Artifact
temp/PLATE_OWNER_FIDELITY/apk/picoradar-pico-personal-preview-dev-release.apk

SHA256: 0E6B80C23BC62B9311553E59E7570B0EFFE5834C044D733786C7488777F83DE8

Report: temp/PLATE_OWNER_FIDELITY/INFORME_PICO_PERSONAL_VISTA_PREVIA.md

## Next
1. Present physical preview and wait for owner visual approval.
2. Correct any rejected detail and repeat relevant tests/build/physical comparison.
3. After approval: full Flutter suite, final Home/Pico city regressions and isolate
   Pico sublot from earlier Home/plate WIP before commits/publication.
4. Normal push and CI according to approved lot. Never merge.

No new dependencies, data/schema/backend/GPS/Conducir changes. Earlier performance
acceptance remains open; focused performance guards are not physical FPS evidence.
