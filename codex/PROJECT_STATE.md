# Project State

**Product name:** PicoRadar
**Store title:** PicoRadar: Pico y Placa

**Baseline:** Product v1.0 + Technical Architecture v1  
**Current lot:** C01 — DONE locally; pending PR review/merge
**Last completed lot:** C01 — DONE locally
**Release target:** Free 1.0 Android-first  
**Monetization:** OFF  
**Account/cloud:** OFF  

## Frozen product navigation

`Inicio · Garaje · Apps · Viaje · Conducir`

Apps is always central.

## Expected next action

Open the next approved lot only after human kickoff and C01 review. Do not start C02 from this handoff.

## State update rule

At the end of every lot update:
- current branch;
- HEAD SHA;
- lot status;
- test summary;
- physical QA status;
- blockers;
- next lot(s) unblocked.

## Latest lot handoff summary

- Branch: `feat/C01-app-shell-router`
- Lot status: C01 DONE locally; pending PR review/merge.
- Test summary: Flutter pub get/format/analyze/test/dev debug APK passed; Laravel boot/test passed.
- Physical QA status: Passed on Mi A3 Android 11/API 30 via USB install.
- Blockers: None.
- Next lots unblocked: C02 and C03 after human kickoff and PR review; C12 remains blocked until its lot.

## GitHub state

- Canonical repo: `sierraglobalcompany-rgb/PicoRadar`
- Remote URL: `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
- Remote was empty at C01 kickoff.
- C00 approved SHA: `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`
- C01 must bootstrap `main` at that exact SHA, then branch from `main`.
