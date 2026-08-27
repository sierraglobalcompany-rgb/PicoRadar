# Project State

**Product name:** PicoRadar
**Store title:** PicoRadar: Pico y Placa

**Baseline:** Product v1.0 + Technical Architecture v1  
**Current lot:** C06 — DONE locally; pending PR review/merge
**Last completed lot:** C05 — merged to `main`
**Release target:** Free 1.0 Android-first  
**Monetization:** OFF  
**Account/cloud:** OFF  

## Frozen product navigation

`Inicio · Garaje · Apps · Viaje · Conducir`

Apps is always central.

## Expected next action

C06 adds local vehicle models, migration and repository only. Do not start C07 until C06 is reviewed/merged and a separate human kickoff is provided.

## Product decisions recorded during C05

- Free 1.0 widget: Android and iPhone widgets will show active vehicle, city, today circulation/restricted state, schedule, tomorrow status and stale-data state. No ads. Tapping opens the Pico y Placa flow. Implementation is deferred to the approved Home/Pico/notifications lots.
- Car screen mode: PicoRadar remains one APK that adapts to full Android radios; no separate APK. The future horizontal/large `Conducir` UI will prioritize speed, limit, next camera, alerts and pico status. No ads during driving. Official Android Auto/Automotive support remains deferred to a later approved lot.

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

- Branch: `feat/C06-vehicle-domain`
- Lot status: C06 DONE locally; pending PR review/merge.
- Test summary: Vehicle repository tests, migration v1 to v2 test, Flutter analyze/test and dev debug APK passed locally.
- Physical QA status: Not required for C06.
- Blockers: None.
- Next lots unblocked: None until C06 review/merge.

## GitHub state

- Canonical repo: `sierraglobalcompany-rgb/PicoRadar`
- Remote URL: `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
- Remote was empty at C01 kickoff.
- C00 approved SHA: `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`
- C01 merged to `main` by explicit human authorization.
- C02 merged to `main` by explicit human authorization.
- C03 merged to `main` by explicit human authorization.
- C04 merged to `main` by explicit human authorization.
- C05 merged to `main` by explicit human authorization.
