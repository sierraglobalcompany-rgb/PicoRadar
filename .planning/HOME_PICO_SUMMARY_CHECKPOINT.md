# Inicio/Pico correction checkpoint

Base: f4578f6043a6223df5d1a0c4e32c5055eb88da71
Branch: codex/home-owner-responsive
Target: integration/VIAJE-R1-real-planner
Status: implementation committed/pushed; CI SUCCESS; NO MERGE.
Final HEAD: af1845521c99d1a3587c3fc4e25e37309157bb23
PR: https://github.com/sierraglobalcompany-rgb/PicoRadar/pull/63
CI: Mobile CI #196, run 34508968573.
Latest full suite: 1614 PASS / 10 existing skips, exit 0. Analyze PASS.
APK final normal dev installed and SHA checked against installed base.apk:
AE573A071D966416B601C65894ACB2917D6FB49F1AF17E42395BD37A99B093F5.
Physical final captures 40-46; BOG126 restricted in Medellin; MED124 allowed.
font_scale restored 1.0. Vehicles unchanged, 3 rows same digest below.
No runtime edits pending. CI196 completed/success, PR63 open and not merged.
Final report: temp/HOME_PICO_SUMMARY/INFORME_HOME_PICO.md.
Final ZIP: temp/HOME_PICO_SUMMARY/home_pico_summary_handoff.zip.
Final packaging regenerates/validates all hashes. Existing banner ellipsis at
large text and unmeasured profile performance explicitly remain outside closure.
Earlier checkpoints below are history, not current failures.

Approved 2026-09-10 plan replaces all earlier Home summary proposals: no tomorrow
on Home; navy current-status summary; static icon carousel, centered plate;
shared foreground/resume UTC clock; actual instantaneous restriction in Pico.

Ownership: parent restriction_day_evaluation timing/format helpers and evidence;
Dalton clock/app providers; Russell Home files/tests; Plato Pico screen/tests.
No concurrent Flutter builds/tests. Parent runs validation sequentially.
Shared timing helpers: 13 domain tests PASS. Clock 11 PASS, Pico 55 PASS.
Focused final pass: 320 tests (clock, Home, Pico, location, bundled upgrade).
Full suite first attempt: interrupted after 1508 pass / 10 skipped / 5 failures;
Apps tests pumpAndSettle timeout, Garage test stalled. Logs preserved under
logs/flutter-test.log. Investigating bundle loading inside DB transaction;
Resolved: load/decode assets outside the DB transaction, then recheck metadata
inside it. Concurrent remote install regression passes. Final full suite before
latest owner UI correction: 1584 PASS, 10 existing skips, exit 0.
Normal dev APK built and installed preserving all three vehicles; bundle upgraded
to 2026.09.10-r4-a. Interim screenshots 10/11 are not final owner correction.
Latest owner UI correction in progress: compact summary min100/icon56; carousel
measures actual remaining space; header band nickname > brand > Mi vehiculo;
plates particular yellow/city, taxi white/city, motorcycle yellow/COLOMBIA.
No official seal reproduction, no inferred registration city. Parent owns
summary/docs/evidence; Russell carousel/screen/tests; Plato branding opt-in/tests.
Pending: final revised tests/build/physical capture, scoped commit/push/PR/CI,
individual report and verified ZIP. NO MERGE.
Phone before: 3 vehicles, digest e84657da7bd1b75f24ec9231aa12eb1e63f7c820fa94266843666a9e13672efa,
restriction bundle 2026.08.31-c10b-a. Read in memory only; no private DB exported.
Evidence root: project temp/HOME_PICO_SUMMARY (not operating-system temp).
Existing .planning files/history preserved. No merge or Driving edits.
