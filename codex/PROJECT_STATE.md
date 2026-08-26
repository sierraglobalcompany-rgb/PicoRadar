# Project State

**Product name:** PicoRadar
**Store title:** PicoRadar: Pico y Placa

**Baseline:** Product v1.0 + Technical Architecture v1  
**Current lot:** C01 / C02 / C03 candidate  
**Last completed lot:** C00  
**Release target:** Free 1.0 Android-first  
**Monetization:** OFF  
**Account/cloud:** OFF  

## Frozen product navigation

`Inicio · Garaje · Apps · Viaje · Conducir`

Apps is always central.

## Expected next action

Open the next approved lot only after human kickoff; C01, C02 and C03 are the primary candidates after C00.

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

- Branch: `feat/C00-picoradar-repo-scaffold-flavors`
- Lot status: C00 DONE
- Test summary: Flutter pub get/analyze/test/dev debug APK passed; Laravel boot/test passed.
- Physical QA status: Not required for C00.
- Blockers: None.
- Next lots unblocked: C01, C02, C03; also C17, C22, C25 and C28 per dependency matrix.
