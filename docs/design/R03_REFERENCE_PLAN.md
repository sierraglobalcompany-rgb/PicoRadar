# R03 Reference Plan

Status: R03A_MERGED_R03B_REFERENCE_BLOCKED
Last updated: 2026-08-30

R03A Pico y Placa visual recovery is merged and implemented from exact owner-selected reference images. Codex must not generate, infer, or invent SOAT/RTM references for R03B.

## Route Semantics

- `/pico?vehicleId=<id>` means **Mi Pico y Placa**, the personalized vehicle detail.
- `/pico` means **Pico y Placa de la ciudad**, the city/regulation overview.
- R03A implements this route distinction for Pico y Placa only and is merged on `main`.

## Home Card Decision

- The Home card is labeled `Pico y placa`.
- Its secondary content keeps contextual information, for example `Mañana · Puede circular` or the next relevant restriction state.
- Tapping this Home card continues to use the focused vehicle.
- Further Home changes remain out of R03B scope.

## Personal Vehicle Pico

The personalized vehicle detail implemented in R03A includes:

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

The Apps Pico city experience implemented in R03A includes:

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

- `pico_personal_owner_v1.png`: IMPLEMENTED for R03A.
- `pico_city_owner_v1.png`: IMPLEMENTED for R03A.
- `soat_owner_v1.png`: PENDING_OWNER_SELECTION.
- `rtm_owner_v1.png`: PENDING_OWNER_SELECTION.

## R03A Scope

- R03A_PICO = MERGED / IMPLEMENTED.
- `/pico?vehicleId=<id>` is **Mi Pico y Placa**.
- `/pico` is **Pico y placa de la ciudad**.
- The Home Pico card copy is `Pico y placa` while keeping truthful contextual secondary content.
- Exact owner-selected Pico references are in `docs/design/reference/`.
- Runtime values remain derived from local vehicles, jurisdiction preferences, `RestrictionStore`, `RestrictionRuleSet`, `RestrictionDayEvaluation` and source metadata.

## R03B Pending

- R03B_UI_IMPLEMENTATION = BLOCKED_ON_OWNER_REFERENCES.
- SOAT visual recovery from owner-selected reference.
- RTM visual recovery from owner-selected reference.

## Explicit Non-Scope

- No changes to SOAT, RTM, Garage root visuals, Apps launcher visuals, backend or database schema in R03A.
- Home changes in R03A are limited to the Pico y placa entry/card copy and route target.
- No backend.
- No database migration.
- No C14, Maintenance, or C17B execution.
