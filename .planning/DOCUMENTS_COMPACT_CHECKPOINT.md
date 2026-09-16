# C15 Compact Documents Checkpoint

2026-09-13. Owner approved compact no-scroll Documents front page.
Worktree: temp/VIAJE-R1-real-planner; branch codex/documents-owner-vault.
HEAD ddf60407174e3ee8d447b7eff3ca45e0fd983789. Existing C15 and unrelated WIP
preserved. No reset, staging, commit, push or merge.

Installed before this change: C15 preview SHA256
d4ec8f5cd0d43640c8422afeb7da628e9b928c0d15054b8bde6e0b2ded8f9b01.
Before physical screenshots: ../C15_DOCUMENTS_QA_20260913/physical-overview.png
and physical-vehicles.png. Existing scanner/import/positive-auth QA remains open.

Scope: per-driver rows in two compact personal cards; no global driver selector;
manage drivers in sheet; flexible vehicle carousel; no vertical front-page scroll;
Conductor/Vehiculos internal views when content cannot fit. Keep all security,
storage, IDs, profile limit, viewer and document actions intact.

Implementation split: main owns screen layout/integration; widget worker owns
documents_widgets.dart; management worker owns driver sheet only. Flutter tests
and builds serialized by main to avoid Windows SQLite/native locks.

Pending: focused and geometric tests, format/analyze, automated snapshots,
pre-install checkpoint, dev release, physical visual preview. No final C15 closure
or publication before visual approval and prior physical gates.

## Pre-build / pre-install checkpoint

2026-09-13: compact candidate implemented and automated preview inspected.
434 focused tests PASS, including 69 screen/owner tests and 50 compact-widget
tests; migration, wallet lock, delayed-write invalidation and shared document
consumers included. Scoped format PASS (6 files, zero changes). Flutter analyze
PASS with no issues after four brace-style warnings were fixed.

Owner approved fixed horizontal 96 dp plate graphic plus a separate scalable
number when text is enlarged. Shared plate renderer remains unchanged.
New before and automated screenshots: ../C15_DOCUMENTS_COMPACT_QA_20260913/.
This checkpoint authorizes the already requested dev release build and Mi A3
replace-install, preserving app data. Physical visual approval remains pending;
no commit/push/merge or closure of scanner/import/positive-auth debt.

## Preview installed

Build dev release PASS; 98,870,407 bytes; SHA256
0e93d52dab025b49df910e008a17b5a35360db69e9c7a3d3b958dc7fb6b7edc3.
Mi A3 replace-install returned Success. New physical one/two-driver front pages,
management, driver document sheet, vehicle sheet and privacy sheet inspected.
QA_COMPACTO was created and then removed; Principal and all four vehicles remain.
No private documents used; no security setting disabled. Phone left on Documents.
See codex/C15_DOCUMENTS_COMPACT_HANDOFF.md for commands, results, evidence and
remaining approval/security gates. No publication or merge.
