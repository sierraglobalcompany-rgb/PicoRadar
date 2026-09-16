# C13 policy sheet refinement - 2026-09-14

## Pre-edit checkpoint

Branch: codex/insurance-owner-mockup
HEAD: ddf60407174e3ee8d447b7eff3ca45e0fd983789
Worktree: temp/VIAJE-R1-real-planner. Extensive previous tracked/untracked WIP
is preserved, including .planning and all other modules. HEAD alone is not the
installed design. No reset, staging of unrelated changes, merge or publication.

Approved installed home: banner 279 dp, vehicle slot 144 dp, native horizontal
80 dp plate with legible numeral. These files are outside this change.
Installed previous APK SHA256:
750e415b841cc2c0dd61130c43bb269ac977289dafebc44c9c3873391d8e6d76

## Authorized plan and write boundaries

Policy sheet/editor: searchable insurer with manual exception, Spanish calendar,
optional exact COP annual/monthly reference value, collapsed private contacts,
human-readable protected sheet. No new home, tabs, persistence table or server.
Directory: extend existing typed catalog with evidence-backed service scope;
audit every reference entity, retaining unknown/conflicting channels explicitly.
Public quote/monetization remains OFF. No calls/messages or user-policy writes.

SDK flutter_localizations and compatible intl are justified for Spanish Material
calendars and COP formatting. Flutter's standard calendar is preferred over a
third-party picker; both platforms use the same maintained Flutter localization
API. Licenses and compatibility will be recorded after dependency resolution.

## Execution ledger

- Preparation: branch/WIP and AGENTS, C13, SOP, current/design contract inspected.
- Task 1: directory audit/model pending.
- Task 2: exact monetary model implemented; 6/6 unit tests pass, independent
  read-only review reports no findings. Invalid/corrupt input rejected; source
  survives repeated presentation and persistence. Red run lacked the new model.
- Task 3: editor and protected sheet pending.
- Task 4: regression, review, physical QA and handoff pending.
- Previous physical authentication/import debts remain open.

## Pre-build checkpoint (2026-09-14)

Implementation candidate validated: 403/403 focused and regression tests pass
across 11 files, including insurance, SQLite persistence, plate and personal/city
Pico. Log: temp-insurance-policy-accepted-tests.log. Nine scoped Dart files pass
format with zero changes. flutter analyze --no-pub: no issues.
One obsolete regression expected the removed manual insurer field; it now checks
the single selector and absence of that field, preserving vehicle-tap coverage.
Independent read-only reviews: value model, directory and policy functional/
privacy paths report no findings. Latest fictional screenshots use real app
theme/Material icons; the rejected old calendar screenshots are not deliverables.
The 3 approved-home fingerprints below were rechecked and remain identical.
No prior WIP staged, reset or overwritten. No commit, publication or merge.
Build/install completed: dev release, APP_ENV=dev, 103318671 bytes.
Installed on Mi A3 with -r; exported and installed hash identical:
375935564b33535288220ac7f6226fd39c4b38fc61020fcff70e72cebd241090.
Physical home, empty editor, calendar and selector inspected; cancelled drafts.
Direct protected-surface owner approval remains pending. No protection bypass,
real policy writes, calls or messages. See final scoped handoff for limitations.

Dependency resolution added SDK flutter_localizations and promoted existing
intl 0.20.3 from transitive to direct; pinned exact after SDK inspection.
Both use BSD-style licenses (Flutter BSD-3-Clause, intl BSD-3-Clause), no native
plugin, permission or platform bridge. APK impact will be measured after build.
Graphify query ran but its old graph did not contain the current sheets; rg/code
inspection established the current dependencies. No graph/tool upgrade performed.
UI/UX Pro form guidance supports Form validation and progressive disclosure.
Physical pre-capture rejected by FLAG_SECURE; 0-byte file is not visual evidence.

Approved-home guard fingerprints (individual files, not a repository manifest):
- insurance_owner_content.dart: D30E1AA5BB1250E9471D6EB50EB4AA2758720EA1816A91E8C80B5D68D37183D5
- vehicle_plate_badge.dart: 2AF13ACEC3522929EA50A43063C68EEFBA6FE4C7B5C5A8582632727F13919B31
- insurance_owner_banner_v1.png: 5D773862FCF7F414C356EFC772EBB80DBDA1B75F97D55E76431F71591F6F3BFB
