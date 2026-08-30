# R03 Reference Plan

Status: REFERENCE_SELECTION_BLOCKED
Last updated: 2026-08-30

R03 will implement Pico y Placa visual recovery only after exact owner-selected reference images are supplied. Codex must not generate, infer, or invent these references.

## Route Semantics

- `/pico?vehicleId=<id>` means **Mi Pico y Placa**, the personalized vehicle detail.
- `/pico` means **Pico y Placa de la ciudad**, the city/regulation overview.
- Current code does not implement this route distinction yet.

## Home Card Decision

- The current Home card labeled `MAÑANA` will become `Pico y placa` in R03.
- Its secondary content may keep contextual information, for example `Mañana · Puede circular` or the next relevant restriction state.
- Tapping this Home card continues to use the focused vehicle.
- Do not change the current Home UI before the R03 implementation lot.

## Personal Vehicle Pico

The future personalized vehicle detail must include:

- real audited vehicle visual;
- make/model/nickname where available;
- `ColombianPlateBadge`;
- effective city;
- today's verdict;
- tomorrow;
- relevant plate digit or rule basis;
- usual restriction weekday or weekdays;
- next restriction date and time;
- compact 7-day calendar;
- official source;
- verified/freshness state.

No fake rules and no hardcoded digit schedule are allowed.

## City Pico Module

The future Apps Pico experience must include:

- current consultation city;
- temporary city selector;
- Cars / Motorcycles / Taxis according to available coverage;
- today's restricted digits or rule;
- hours;
- compact weekly schedule;
- official source and freshness;
- small saved-vehicle shortcuts.

Temporary city lookup must not mutate Home effective jurisdiction, notifications, or widget state. Only an explicit `Usar esta ciudad como mi ubicación` action may change global configuration.

## SOAT / RTM Visual Debt

SOAT and RTM logic remains valid, but the current presentation is owner-rejected visual debt. Future owner references must define:

- real vehicle visual;
- Colombian plate;
- status hierarchy;
- dates;
- reminder;
- official verification CTA;
- edit/save action;
- no bottom-nav overlap.

## Required Owner References

R03 implementation remains blocked until all of these exact owner-selected references are supplied:

- `pico_personal_owner_v1.png`: pending owner selection.
- `pico_city_owner_v1.png`: pending owner selection.
- `soat_owner_v1.png`: pending owner selection.
- `rtm_owner_v1.png`: pending owner selection.

## Explicit Non-Scope

- No R03 UI implementation in this documentation freeze.
- No changes to `PicoDetailScreen`, SOAT, RTM, Home, Garage, or Apps launcher in this task.
- No backend.
- No database migration.
- No C14, Maintenance, or C17B execution.
