# C10 restrictions pilot data sources

Consulted on 2026-08-27. Only official Alcaldia/Secretaria sources were used.

## Medellin

- Source: Alcaldia de Medellin / Secretaria de Movilidad, "Pico y Placa Medellin 2026, segundo semestre".
- URL: https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/
- Cross-check source: https://www.medellin.gov.co/es/sala-de-prensa/noticias/la-nueva-rotacion-del-pico-y-placa-en-medellin-comenzara-a-regir-a-partir-del-lunes-3-de-agosto/
- Coverage included:
  - `co-ant-medellin` + `car/private`: Monday 5,8; Tuesday 1,4; Wednesday 0,2; Thursday 3,6; Friday 7,9. Last numeric digit. Monday-Friday, 05:00-20:00. validFrom 2026-08-03. staleAfter 2027-01-01.
  - `co-ant-medellin` + `motorcycle/private`: same digits by weekday, first numeric digit. Monday-Friday, 05:00-20:00. validFrom 2026-08-03. staleAfter 2027-01-01.
- Coverage omitted:
  - `co-ant-medellin` + `car/taxi`: official page verifies taxi methodology and hours, but not the concrete current digit calendar needed for deterministic import. Omitted for fail-closed data quality.

## Bogota

- Source: Bogota.gov.co / Secretaria Distrital de Movilidad, "Pico y placa Bogota vehiculos particulares 1 a 31 de agosto de 2026".
- URL: https://bogota.gov.co/mi-ciudad/movilidad/pico-y-placa-bogota-vehiculos-particulares-1-31-de-agosto-de-2026
- Cross-check source: https://www.movilidadbogota.gov.co/pico-y-placa
- Coverage included:
  - `co-dc-bogota` + `car/private`: odd days allow 1-5, so 0,6,7,8,9 are restricted; even days allow 6-0, so 1,2,3,4,5 are restricted. Monday-Friday, 06:00-21:00, excluding holidays. validFrom 2026-08-01; validUntil 2026-08-31; staleAfter 2026-09-01.

- Taxi pilot sources:
  - 2026-08-24: https://bogota.gov.co/mi-ciudad/movilidad/pico-y-placa-en-bogota-de-particulares-y-taxis-lunes-24-agosto-2026
  - 2026-08-25: https://bogota.gov.co/mi-ciudad/movilidad/pico-y-placa-bogota-martes-25-de-agosto-de-2026-particulares-y-taxis
  - 2026-08-26: https://bogota.gov.co/mi-ciudad/movilidad/pico-y-placa-en-bogota-26-de-agosto-de-2026-particulares-y-taxis
  - 2026-08-27: https://bogota.gov.co/mi-ciudad/movilidad/pico-y-placa-en-bogota-jueves-27-de-agosto-de-2026-particulares-y-taxi
- Coverage included:
  - `co-dc-bogota` + `car/taxi`: pilot daily restriction rules only for 2026-08-24 through 2026-08-27, 05:30-21:00, last numeric digit. staleAfter 2026-09-01.
- Limitation:
  - The taxi coverage is intentionally a bounded pilot, not a full-month claim.

## Non-production fixtures

Tests may use `synthetic_test_jurisdiction` only with `NON_PRODUCTION_FIXTURE`; it is not included in the bundled production asset.
