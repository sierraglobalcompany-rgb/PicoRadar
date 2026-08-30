# Pico Jurisdiction Coverage Audit - 2026-08-30

Scope: research-only artifact for future C10B / NATIONAL_PICO_COVERAGE. This
does not add runtime jurisdictions, rules, selectors, notifications, widgets or
datasets.

Audit status: COMPLETE_FOR_RESEARCHED_CITIES. This document covers the defined
city set below; it is not an exhaustive national municipality audit.

Runtime status after this audit:

- Existing supported jurisdictions preserved: Bogota, Medellin / Valle de Aburra.
- New Pico jurisdictions implemented in this lot: 0.
- Registration municipality catalog remains separate from Pico jurisdiction.
- Registration catalog scope is separate: municipalities represented by
  currently certified RUNT Organismos de Transito under the applied source
  filter, not all Colombian municipalities.

| City / jurisdiction | Department | Official source | Source date | Rule status | Vehicle categories | Classification |
|---|---|---|---|---|---|---|
| Bogota | Bogota D.C. | https://bogota.gov.co/mi-ciudad/movilidad/pico-y-placa-bogota-vehiculos-particulares-1-31-de-agosto-de-2026 | 2026-08-01 | Current monthly/weekly official calendar; weekday restrictions documented. | Private vehicles; taxis documented in daily official posts. | SUPPORTED_CURRENT |
| Medellin / Valle de Aburra | Antioquia | https://www.metropol.gov.co/Paginas/Noticias/Nueva%20rotacion%20del%20Pico%20y%20Placa%20en%20Medellin%20y%20el%20Valle%20de%20Aburra%202026.aspx | 2026-01-23 | Metropolitan rotation for Medellin and the nine other Valle de Aburra municipalities. | Private cars, motorcycles and taxis. | SUPPORTED_CURRENT |
| Cali | Valle del Cauca | https://intranet.cali.gov.co/2026/07/01/pico-y-placa-rota-en-cali-para-el-segundo-semestre-de-2026-nueva-medida-rige-desde-el-1-de-julio/ | 2026-07-01 | Second-semester 2026 ordinary rotation found; emergency focused/solidary measures also appeared in August 2026 and require separate temporal modeling. | Private vehicles; verify motorcycles/taxis before implementation. | VERIFIED_CANDIDATE |
| Cartagena | Bolivar | https://www.cartagena.gov.co/noticias/nuevo-rotacion-pico-placa-para-motos-vehiculos-particulares-cartagena | 2026-06-26 | Current 2026 rotations found; separate taxi rotations are published periodically. | Private vehicles, motorcycles, taxis. | VERIFIED_CANDIDATE |
| Bucaramanga | Santander | https://www.bucaramanga.gov.co/noticias/conozca-la-nueva-rotacion-de-pico-y-placa-para-vehiculos-particulares-que-regira-desde-el-6-de-julio/ | 2026-06-23 | New rotation from 2026-07-06 found in official news. | Private vehicles; verify taxi/motorcycle scope before implementation. | VERIFIED_CANDIDATE |
| Armenia | Quindio | https://www.armenia.gov.co/se-extiende-por-6-meses-medida-de-pico-y-placa-para-mitigar-impactos-de-obras-y-mejorar-la-movilidad and https://ftp.armenia.gov.co/secretaria-de-transito-anuncia-medidas-para-garantizar-la-movilidad-en-armenia | 2026-05 and 2026-08-11 | Decreto 135 de 2026 extends Pico y Placa for six months in Armenia's urban perimeter; August 2026 official confirmation says the measure remains in force under existing regulation. Exact digit/time/category extraction must still occur before runtime implementation. | Exact categories pending decree extraction. | VERIFIED_CANDIDATE |
| Ibague | Tolima | https://www.ibague.gov.co/portal/noticias/22523-asi-sera-el-pico-y-placa-para-el-segundo-semestre-de-este-ano-en-ibague | 2026-06-18 | Second-semester 2026 rotation found in official news. | Private vehicles; taxis have separate 2026 decree updates. | VERIFIED_CANDIDATE |
| Cucuta / metropolitan area | Norte de Santander | https://cucuta.gov.co/ | 2026-08-30 | Official home publishes "Pico y placa hoy" and current 2026 normative references; older official pages describe pico y placa and placa-dia mechanics. | Private vehicles, motorcycles and metropolitan-area vehicles; verify 2026 decree details before implementation. | VERIFIED_CANDIDATE |
| Santa Marta | Magdalena | https://www.santamarta.gov.co/documentos/decreto-160-del-07-de-mayo-de-2025 | 2025-05-07 | Decree for restriction of private vehicles found; official home also exposes taxi pico entry. Needs 2026 confirmation before runtime. | Private vehicles, taxis; motorcycles require separate verification. | STALE_SOURCE |
| Villavicencio | Meta | https://villavicencio.gov.co/con-jornadas-pedagogicas-inicio-el-pico-y-placa-2026-para-vehiculos-particulares-en-villavicencio/ | 2026-01-23 | 2026 measure started 2026-01-26 and official portal lists Decreto 015 de 2026. | Private vehicles; verify exact end date and categories before implementation. | VERIFIED_CANDIDATE |
| Pereira | Risaralda | https://www.pereira.gov.co/publicaciones/1041/cambio-de-horario-en-la-medida-de-pico-y-placa-para-particulares-en-pereira/ | Current page, source date not explicit in search result | Official page says the measure for private, official vehicles and motorcycles changes to 7:00 a.m.-7:00 p.m.; decree/PDF should be reviewed before rule encoding. | Private vehicles, official vehicles, motorcycles. | VERIFIED_CANDIDATE |
| Manizales | Caldas | https://centrodeinformacion.manizales.gov.co/manizales-tendra-pico-y-placa-temporal-durante-la-emergencia-por-el-sismo-asi-funcionara-la-medida-desde-este-viernes/ | 2026-08-13 | Temporary emergency restriction from 2026-08-14 to 2026-08-31; official portal also reports extension into September 2026. Not a permanent city rule. | Private vehicles during emergency; taxis have separate local measures. | TEMPORARY_EVENT |
| Barranquilla | Atlantico | https://barranquilla.gov.co/mi-barranquilla/pico-y-placa-para-vehiculos-particulares-en-toda-la-ciudad-viernes-sabado-domingo-y-lunes-de-carnaval | 2026-02-09 | Carnival city-wide private-vehicle restriction found; additional Via 40 teardown measure found. Treat as event-only unless separate regular taxi/current rule is verified. | Private vehicles during Carnival; taxis have separate historical calendars. | EVENT_ONLY |
| Pasto | Narino | https://www.pasto.gov.co/index.php/decretos-2026 | 2026-07-24 | Decree 0122 of 2026 restricts motor vehicles in San Juan de Pasto; requires decree review before implementation. | Motor vehicles; exact categories pending decree extraction. | VERIFIED_CANDIDATE |
| Monteria | Cordoba | https://www.monteria.gov.co/ | 2026-08-30 | Official portal searched; no current pico y placa rule located in this pass. | Unknown. | NO_CURRENT_RULE_FOUND |

Recommended C10B candidate order:

1. Cali, Cartagena, Bucaramanga, Armenia, Ibague, Villavicencio and Pasto because current official 2026 sources were found.
2. Cucuta after extracting the referenced 2026 decrees from the official portal.
3. Pereira after verifying source date and decree text.
4. Santa Marta only after a current 2026 source is found.
5. Manizales and Barranquilla must be modeled as temporary/event rules, not permanent coverage.
