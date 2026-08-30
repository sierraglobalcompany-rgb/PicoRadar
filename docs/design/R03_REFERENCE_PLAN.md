# R03 Reference Plan

Status: R03A_OWNER_SELECTED
Last updated: 2026-08-30

R03 implements Pico y Placa visual recovery only after exact owner-selected reference images are supplied. Codex must not generate, infer, or invent these references.

## Route Semantics

- `/pico?vehicleId=<id>` means **Mi Pico y Placa**, the personalized vehicle detail.
- `/pico` means **Pico y Placa de la ciudad**, the city/regulation overview.
- R03A implements this route distinction for Pico y Placa only.

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
- compact 14-day future calendar, horizontally scrollable only inside the calendar module;
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

SOAT and RTM logic remains valid, but the current presentation is owner-rejected visual debt for R03B. Future owner references must define:

- real vehicle visual;
- Colombian plate;
- status hierarchy;
- dates;
- reminder;
- official verification CTA;
- edit/save action;
- no bottom-nav overlap.

## Required Owner References

R03 references are split by implementation slice:

- `pico_personal_owner_v1.png`: OWNER_SELECTED for R03A.
- `pico_city_owner_v1.png`: OWNER_SELECTED for R03A.
- `soat_owner_v1.png`: pending owner selection.
- `rtm_owner_v1.png`: pending owner selection.

## R03A Scope

- Implement `/pico?vehicleId=<id>` as **Mi Pico y Placa**.
- Implement `/pico` as **Pico y placa de la ciudad**.
- Update the Home Pico card copy to `Pico y placa` while keeping truthful contextual secondary content.
- Copy the exact owner-selected Pico references into `docs/design/reference/`.
- Keep all runtime values derived from local vehicles, jurisdiction preferences, `RestrictionStore`, `RestrictionRuleSet`, `RestrictionDayEvaluation` and source metadata.

## R03B Pending

- SOAT visual recovery from owner-selected reference.
- RTM visual recovery from owner-selected reference.

## Explicit Non-Scope

- No changes to SOAT, RTM, Garage root visuals, Apps launcher visuals, backend or database schema in R03A.
- Home changes in R03A are limited to the Pico y placa entry/card copy and route target.
- No backend.
- No database migration.
- No C14, Maintenance, or C17B execution.
