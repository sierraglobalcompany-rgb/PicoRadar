# Garaje: single favorite checkpoint

Date: 2026-09-11. Status: PARTIAL / WAITING_OWNER_VISUAL_APPROVAL.

## Final preview verification
- Installed dev debug with simulation; install -r Success, user data preserved.
- Local APK and installed base.apk SHA256 match:
  E159B1C5F7E3B0D82783FA7A7E43F511ABB79D8E6E0D6C3E9CE698EC73508021.
- Home/data 265 PASS; Garage UI 94 PASS; detail 14 PASS; Garage performance 1 PASS;
  central Home entries 6 PASS; startup/Apps/widget 82 PASS; notifications 22 PASS.
- Downstream integration passed; its initial two Garage test failures were fixed
  and included in the final 94. Analyze PASS; source format 261 files / 0 changes;
  diff check PASS; debug simulation build PASS (33.8s).
- Physical: single favorite, independent Home priority, detail focus, no promotion
  on Drive, restored original BOG127 favorite and checked after restart. Three
  user vehicles retained. No destructive physical tests; undo is automated.
- Report and captures: temp/GARAGE_SINGLE_FAVORITE/INFORME_GARAJE_FAVORITO.md.
- APK: temp/GARAGE_SINGLE_FAVORITE/apk/picoradar-garaje-favorito-simulacion-preview.apk.
- All delegated agents closed. No needed execution sessions still running.
- Central shell branch state now covers direct Settings return, not only bar taps.
- Notifications test had expired fixed dates: test-only future dates replaced them.

## Worktree
- Branch: codex/garage-single-favorite.
- HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789.
- Created from dirty codex/plate-owner-fidelity; all earlier Home/plate/Personal
  Pico work preserved. No commits, staging, pushes or merges in this lot.
- Do not publish the entire worktree as a Garage-only patch. Prior Personal Pico
  remains a separate pending lot; separate changes before eventual publication.

## Implemented
- Existing active vehicle key is the sole favorite source; legacy multi-favorite
  migration, alphabetical fallback, serialized writes and deletion rollback.
- Garage Todos/Favorito; no active field/button. Detail follows same wording.
- Home uses local today phases, next seven days, unverified data then alphabetical
  priority. It selects a page, not a reordered list. No favorite writes on Drive.
- Tab return requests priority; detail return and minute/data updates preserve focus.
- Trip and existing preparation context are pinned above the favorite.

## Verification so far
- Initial persistence tests: 53 passed before extra deletion rollback tests.
- New priority unit cases: 5 passed.
- Home plus performance: 199 passed, one old midnight fixture corrected to account
  for the new next-day priority; that midnight test then passed independently.
- New Home navigation priority group: 12 passed.
- First integration pass: 308 passed, two Garage test failures under correction.
- Analysis first pass: one braces style warning, corrected; rerun pending.
- Captured existing Mi A3 Garage/detail before installing this lot. Installed app
  is still the earlier simulation-enabled debug build; do not replace silently.

## Undo decision
The existing deletion destroys private data and originally had no Undo. Added a
5-second precommit window to implement the approved plan without claiming private
document recovery. Cancel/dismiss/navigation/unmount preserves data and favorite;
only natural expiry commits cleanup. Optional owner clarification may still change
this presentation; never change it to fake post-deletion recovery.

## Next
Request visual approval of the installed preview. Full suite/publication follows
approval, not yet executed. Do not blindly commit all inherited WIP. Size audit,
performance targets and Personal Pico approval are separate; no global DONE.
