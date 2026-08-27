# Project State

**Product name:** PicoRadar
**Store title:** PicoRadar: Pico y Placa

**Baseline:** Product v1.0 + Technical Architecture v1  
**Current lot:** C13 — DONE locally; PR open, CI pending infrastructure billing availability
**Last completed lot:** C12 — merged to `main`
**Release target:** Free 1.0 Android-first  
**Monetization:** OFF  
**Account/cloud:** OFF  

## Frozen product navigation

`Inicio · Garaje · Apps · Viaje · Conducir`

Apps is always central.

## Expected next action

C13 adds local user-managed SOAT/RTM/insurance dates, official vehicle-status/tax links, and obligation reminders. Do not start C14 until C13 is reviewed/merged and a separate human kickoff is provided.

## Product decisions recorded during C05

- Taxi in Free 1.0: Taxi is included from Free 1.0 using the same app and VehicleRepository. Future Pico y Placa evaluation must use jurisdiction + kind + serviceType + date/time because taxis may have different rules than private cars.
- Free 1.0 widget: Android and iPhone widgets exist as quick access only. They must not directly reveal today's Pico y Placa state, exact schedule or tomorrow status. They present PicoRadar with copy such as "Consulta tu Pico y Placa de hoy"; tapping opens Pico y Placa directly. No ads inside the widget and no mandatory interstitial before showing the result; a normal in-app banner remains allowed.
- Premium future widget: may show vehicle, plate, city, exact state ("HOY PUEDES CIRCULAR" or "HOY TIENES PICO Y PLACA"), schedule and tomorrow state, with no ads.
- Android Free 1.0 widget: implemented in C11 with Glance as quick access only; it stays neutral and opens `/pico`.
- iOS WidgetKit Free 1.0: `IOS_WIDGETKIT_PENDING_FREE_1_0` remains mandatory before iPhone release.
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
- C09 merged to `main` by explicit human authorization with temporary CI infrastructure exception authorized only for C09: `CI_INFRA_EXCEPTION_GITHUB_BILLING`.
- C10 merged to `main` by explicit human authorization with temporary CI infrastructure exception authorized only for C10: `CI_INFRA_EXCEPTION_GITHUB_BILLING`.
- C11 merged to `main` by explicit human authorization with temporary CI infrastructure exception authorized only for C11: `CI_INFRA_BLOCKED_GITHUB_BILLING`.
- C12 merged to `main` by explicit human authorization with temporary CI infrastructure exception authorized only for C12: `CI_INFRA_BLOCKED_GITHUB_BILLING`.

## Latest lot handoff summary

- Branch: `feat/C13-vehicle-status-modules`
- Lot status: C13 DONE locally; PR pending review/merge.
- Test summary: Flutter pub get, build_runner, C13-scoped format, analyze, full Flutter tests, and dev debug APK passed locally.
- Physical QA status: Mi A3/USB device not available; ADB listed no connected device after server restart. C13 physical QA is optional.
- Blockers: GitHub Actions may remain blocked by account billing/spending limit infrastructure; local gates are green.
- Next lots unblocked: C14 after C13 review/merge only.

## C13 product state

- SOAT and RTM status is derived from locally saved dates and must be presented as "segun la fecha guardada".
- RUNT remains the external verification authority for SOAT/RTM; PicoRadar does not scrape RUNT or store document IDs.
- Insurance is voluntary coverage only; assistance availability depends on the user's policy and phone numbers are user-entered.
- Tax module provides verified pilot links/calendars for Bogota and Antioquia 2026 only; PicoRadar does not estimate tax values, rates, sanctions, or debts.
