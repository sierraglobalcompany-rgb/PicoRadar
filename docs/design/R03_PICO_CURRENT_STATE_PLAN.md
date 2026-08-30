# R03 Pico Current-State Plan

Status: CURRENT_EVIDENCE_ONLY
Branch: fix/P01-startup-home-stability

P01 may capture current Pico, SOAT, and RTM surfaces as evidence, but it must not redesign those surfaces.

## Frozen Product Decisions

- The current Home strip labeled `MANANA` becomes conceptually `Pico y placa` in R03 because it is the entry point to the focused vehicle personal Pico y Placa detail.
- `/pico?vehicleId=<id>` will mean personal vehicle Pico y Placa detail.
- `/pico` will mean city Pico y Placa overview.
- Current code does not yet implement that route distinction.

## Future Personal Vehicle Pico

The future personal detail should include:

- real vehicle image;
- make, model, or nickname;
- Colombian plate badge;
- effective city;
- today's verdict;
- tomorrow;
- plate digit or rule basis explanation;
- usual restriction weekday or weekdays;
- next restriction date and time;
- compact 7-day calendar;
- official source and freshness.

## Future City Pico Overview

The future city overview should include:

- current or effective city;
- temporary city lookup without silently changing app configuration;
- explicit action to adopt a preview city globally;
- vehicle category where coverage exists: cars, motorcycles, taxis;
- today's restricted digits or rule;
- hours;
- weekly schedule;
- official source and freshness;
- compact saved-vehicle plate shortcuts;
- saved vehicle tap to `/pico?vehicleId=<id>`.

## City Preview Rule

Choosing another city for consultation inside Apps Pico must not silently change Home jurisdiction, notifications, or widget state.

Only an explicit `Usar esta ciudad en PicoRadar` action may change effective global jurisdiction.

## Evidence Required Before R03 Implementation

- `pico-current-from-home.png`
- `pico-current-from-apps.png`
- `pico-current-lower.png`
- `soat-current.png`
- `rtm-current.png`

No fake images, generated mockups, or inferred dimensions are allowed for R03.
