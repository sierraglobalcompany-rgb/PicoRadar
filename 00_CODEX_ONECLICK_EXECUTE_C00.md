# ONE-CLICK C00 — PICORADAR

This package is self-contained for the first implementation lot.

## Your job

You are working on **PicoRadar**.
Store title: **PicoRadar: Pico y Placa**.

You must autonomously:

1. Inspect the current workspace/repository.
2. If this package is still compressed, extract it.
3. Place/copy the CONTENTS of this package into the Git repository root, at the same level as `.git`.
4. Do not overwrite an existing conflicting file blindly; inspect first.
5. Read, in order:
   - `README_START_HERE.md`
   - `AGENTS.md`
   - `00_NOMBRE_OFICIAL_PICORADAR.md`
   - `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`
   - `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`
   - `codex/TECH_BASELINE.md`
   - `codex/GLOBAL_DOD_STOP_CONDITIONS.md`
   - `codex/PROJECT_STATE.md`
   - `codex/lots/C00_REPO_SCAFFOLD_FLAVORS.md`
   - `C00_EXACT_PROMPT_PICORADAR_FOR_CODEX.md`
6. Execute **C00 only**.
7. Create the branch required by C00 if appropriate.
8. Build the Flutter + Laravel foundation, flavors, tests and Android dev APK.
9. Run every required acceptance command.
10. Do not execute C01.
11. Do not merge.
12. Return a complete C00 handoff.

## Brand / IDs

- Product: `PicoRadar`
- Store title: `PicoRadar: Pico y Placa`
- Prod ID: `co.picoradar.app`
- Staging ID: `co.picoradar.app.staging`
- Dev ID: `co.picoradar.app.dev`

## Important autonomy rule

Do not ask the user to manually unzip, copy, rename, initialize folders, or run preliminary checks if you can do those operations yourself in the workspace.

Only stop if there is a genuine Stop Condition defined by the project documentation.

## Final response

Start with exactly one of:

`C00: DONE`
`C00: PARTIAL`
`C00: BLOCKED`

Then include:
- branch;
- HEAD SHA;
- relevant final repo tree;
- application IDs and labels;
- exact commands/tests/builds and results;
- warnings;
- stop conditions;
- `git status`;
- what C01/C02/C03 are now unblocked;
- explicit `NO MERGE REALIZADO`.
