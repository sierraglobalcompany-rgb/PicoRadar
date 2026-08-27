# Project State

**Product name:** PicoRadar
**Store title:** PicoRadar: Pico y Placa

**Baseline:** Product v1.0 + Technical Architecture v1  
**Current lot:** C09 — DONE locally; pending PR review/merge
**Last completed lot:** C08 — merged to `main`
**Release target:** Free 1.0 Android-first  
**Monetization:** OFF  
**Account/cloud:** OFF  

## Frozen product navigation

`Inicio · Garaje · Apps · Viaje · Conducir`

Apps is always central.

## Expected next action

C09 adds the pure local Pico y Placa rule engine. Do not start C10 until C09 is reviewed/merged and a separate human kickoff is provided.

## Product decisions recorded during C05

- Taxi in Free 1.0: Taxi is included from Free 1.0 using the same app and VehicleRepository. Future Pico y Placa evaluation must use jurisdiction + kind + serviceType + date/time because taxis may have different rules than private cars.
- Free 1.0 widget: Android and iPhone widgets exist as quick access only. They must not directly reveal today's Pico y Placa state, exact schedule or tomorrow status. They present PicoRadar with copy such as "Consulta tu Pico y Placa de hoy"; tapping opens Pico y Placa directly. No ads inside the widget and no mandatory interstitial before showing the result; a normal in-app banner remains allowed.
- Premium future widget: may show vehicle, plate, city, exact state ("HOY PUEDES CIRCULAR" or "HOY TIENES PICO Y PLACA"), schedule and tomorrow state, with no ads.
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

- Branch: `feat/C09-pico-rule-engine`
- Lot status: C09 DONE locally; pending PR review/merge.
- Test summary: Pico y Placa rule engine unit tests, Flutter analyze/test and dev debug APK passed locally.
- Physical QA status: Not required for C09.
- Blockers: None.
- Next lots unblocked: None until C09 review/merge.

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
- C06 merged to `main` by explicit human authorization.
- C07 merged to `main` by explicit human authorization.
- C08 merged to `main` by explicit human authorization.
