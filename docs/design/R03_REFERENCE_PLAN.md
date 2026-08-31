# R03 Reference Plan

Status: P03_MERGED_R03B_BLOCKED_ON_RTM_REFERENCE
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
- `soat_owner_v1.png`: OWNER_SELECTED.
  - Reference package: `PICORADAR_R03B_SOAT_OWNER_V1_REFERENCE.zip`.
  - Reference package SHA-256: `5e064fa5c6a72ba1e8dc3eeb44cbc17ac4308ad8705328bb4de3922ba32d6216`.
  - Image SHA-256: `2e08d64c68a69b179b81d87c9a0f322df9d86fd3233f63605efd700f1228ef57`.
- `rtm_owner_v1.png`: PENDING_OWNER_SELECTION.

## R03A Scope

- R03A_PICO = MERGED / IMPLEMENTED.
- `/pico?vehicleId=<id>` is **Mi Pico y Placa**.
- `/pico` is **Pico y placa de la ciudad**.
- The Home Pico card copy is `Pico y placa` while keeping truthful contextual secondary content.
- Exact owner-selected Pico references are in `docs/design/reference/`.
- Runtime values remain derived from local vehicles, jurisdiction preferences, `RestrictionStore`, `RestrictionRuleSet`, `RestrictionDayEvaluation` and source metadata.

## R03B Pending

- SOAT_REFERENCE = OWNER_SELECTED.
- RTM_REFERENCE = PENDING_OWNER_SELECTION.
- R03B_UI_IMPLEMENTATION = BLOCKED_ON_RTM_REFERENCE.
- SOAT visual recovery from owner-selected reference.
- RTM visual recovery from owner-selected reference.

## P03 City Catalog Freeze

- P03 = MERGED.
- `pico_jurisdiction_catalog_v1` is a Pico coverage/discovery catalog, not a vehicle registration city catalog.
- Current catalog count is 15 researched jurisdictions.
- Runtime `Disponible` calculation remains limited to actual implemented rule jurisdictions: Bogota and Medellin / Valle de Aburra.
- Catalog-only jurisdictions remain non-calculating and visibly `Proximamente` until future validated rule packs exist.

## C10B Boundary

- C10B_NATIONAL_PICO = NOT_STARTED.
- Future C10B may expand the catalog and implement validated rule packs in controlled batches.
- No catalog-only jurisdiction may be promoted to runtime available without verified local rules.

## SOAT Product Contract Freeze

Future SOAT states are:

- NOT_CONFIGURED.
- ACTIVE.
- DUE_SOON.
- EXPIRED.
- UNKNOWN.

SOAT data and attached documents are distinct concepts. Local data may support status, dates, reminders and insurer/policy metadata. An optional local PDF/image only means the user has a local copy; it does not mean official RUNT verification.

Future SOAT document actions:

- No document: `Adjuntar SOAT`.
- Document exists: `Ver SOAT` and `Reemplazar`.

Future primary CTAs:

- NOT_CONFIGURED: `Agregar datos del SOAT`.
- ACTIVE without document: `Adjuntar SOAT`.
- ACTIVE with document: `Ver SOAT`.
- DUE_SOON: `Renovar SOAT`.
- EXPIRED: `Renovar SOAT`.
- Official external check: `Consultar / Verificar en RUNT`.

Future document storage must use the reusable private vehicle-document storage architecture, not obligation JSON.

## RTM Product Contract Freeze

RTM reference is still pending owner selection. Future RTM belongs to the same information family as SOAT and should support expiration/status, CDA, certificate number, reminder, optional local PDF/image certificate, `Consultar en RUNT` and real history when it exists.

Future RTM commercial/utility CTA is `Buscar CDA`, not `Renovar tecnomecanica`.

## Future CDA And Ads Boundaries

`Buscar CDA` will later be a separate reusable module reachable from Tecnomecanica and Apps. Sponsored CDA placements must remain visually separated from organic proximity results and must never be presented as official preference or best because paid.

Commercial banners may later appear on SOAT/RTM dashboards only after legal/functional information. Ads are not allowed inside private document viewers, legal/status heroes, or as blockers to SOAT/RTM information.

## Explicit Non-Scope

- No changes to SOAT, RTM, Garage root visuals, Apps launcher visuals, backend or database schema in R03A.
- Home changes in R03A are limited to the Pico y placa entry/card copy and route target.
- No backend.
- No database migration.
- No C14, Maintenance, or C17B execution.
