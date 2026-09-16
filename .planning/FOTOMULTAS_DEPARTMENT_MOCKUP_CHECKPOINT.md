# Fotomultas departmental mockup checkpoint

Date: 2026-09-12. Scope: departmental explorer only.
Branch: codex/fotomultas-owner-map.
Base HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789; extensive pre-existing WIP is not represented by HEAD.

Before editing, copies of the screen, camera map and tests were retained in
temp/FOTOMULTAS_OWNER_MAP/department-before. Physical baseline:
temp/FOTOMULTAS_OWNER_MAP/physical/department-audit-current.png.
Reference: codex-clipboard-1b197f7f-5277-4066-80e4-041a200ca06b.png.

Approved scope: navy header; full map with search/count/filter overlays;
transactional search/filter sheets; small translucent controls; source sheet;
list toggle preserving camera, filters and records. National view, data and
grouping algorithm remain unchanged. No merge or publication before review.

Baseline installed release hash:
93ea8d2d5c9bc78ff0b72ea2f9e8df737617c6b16171be49c267611a7c0d6888.
Previous focused suite: 64 tests. New changes are not yet validated.

Next: implement, focused tests and geometry/screenshots, analyze, pre-install
checkpoint, dev release build/install retaining data, physical comparison.
Release does not expose debug-only driving simulation.

## Audit pause after user feedback

The user requested a deeper visual audit before continuing implementation.
Local prototype retained, no APK build or install performed.
Focused suite: 79 passed, 2 failed (long header truncation and 192 dp clear
map area at 360x800/text 2). Analyze clean. This is NOT a stable candidate.
Additional issue: icon-only footer surfaces stay expanded; tile-error and
empty-result banners can overlap.
See temp/FOTOMULTAS_OWNER_MAP/DEPARTMENT_VISUAL_AUDIT.md for evidence,
ten-point review and the concrete correction order. Preserve all local WIP.

## Approved polish implementation

User approved the replacement plan on 2026-09-12, including icon-only header
toggle when text needs more room. Snapshots of the failed candidate are in
temp/FOTOMULTAS_OWNER_MAP/polish-before. Correcting header text constraints,
complete inset budget, genuinely small icon actions and combined map notices.
No installed change yet. Tests and physical preview remain required.

## Pre-build / pre-install gate

84 focused tests passed in polish-tests.log; analyzer clean in
polish-analyze.log; touched Dart files formatted; git diff --check clean.
Fresh automated evidence in polish-final-automated. Header and count complete;
normal 360x780 test map=626 dp and clear area=405 dp (without physical system
bars). Physical measurements still required.
Building dev release with APP_ENV=dev. Mi A3 changed from offline to
unauthorized after targeted reconnect; waiting for owner USB authorization.
Do not uninstall, clear storage, switch device or claim physical acceptance.

## Upper-right controls: pre-build / pre-install checkpoint

Owner reviewed the installed polish preview and liked the composition, requesting
zoom/fit at the upper right instead of the lower right. Controls now start 12 dp
below the measured search/count/filter band. Their 36 dp translucent surfaces
and 48 dp targets remain unchanged. Explorer actions expose an explicit semantic
tap; the test invokes that action to open search. Filter counts no longer change
the layout variant. Combined tile/empty notices remain left of the controls.

2026-09-12: 84 focused tests passed (zoom-top-tests.log), analyze clean
(zoom-top-analyze.log), git diff --check clean. Fresh automated captures:
temp/FOTOMULTAS_OWNER_MAP/zoom-top-final-automated.
Mi A3 116f2191b19a authorized. Building dev release with APP_ENV=dev, then install
with -r only. Preserve storage, all prior WIP and .planning. Final physical
screenshots, hash verification and owner approval still pending at this gate.

## Installed upper-right preview

Build succeeded (54.8 s); exported APK 96,765,225 bytes. Installed -r on Mi A3;
export and device base.apk SHA256 both:
5d7322f4d6633a9b95c4119c93c6b14b59b264db3da49f7d6dd08db736d0f375.
Physical evidence: physical/department-final-*.png. Verified upper-right controls,
map/filter/list/source/search; restored Todas and department fit. No storage clear.
Actual map 543 dp high; center unobstructed span 342 dp excluding right column.
84 focused tests / analyze / format passed. Full suite, final visual approval,
publication and CI remain pending. Handoff: DEPARTMENT_POLISH_HANDOFF.md.
