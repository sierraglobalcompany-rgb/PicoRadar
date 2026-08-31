# Pico Source Freeze C10B-B V1

Date: 2026-08-31

Scope: research-only freeze for the next official Pico y Placa source
candidates. This document does not promote jurisdictions, does not add runtime
rules, and does not edit active catalog availability.

Classification vocabulary:

- READY_FOR_RULE_PACK
- NEEDS_CONDITIONAL_EXEMPTION_SUPPORT
- TEMPORARY_EVENT_ONLY
- INSUFFICIENT_CURRENT_SOURCE
- NO_CURRENT_RULE_FOUND

## Summary

| City | Department | Recommended runtime status | Confidence | Reason |
|---|---|---|---|---|
| Armenia | Quindio | READY_FOR_RULE_PACK | Medium | Official municipal news lists the 2026 extension; exact decree extraction remains the next rule-pack step. |
| Cucuta / metropolitan scope | Norte de Santander | NEEDS_CONDITIONAL_EXEMPTION_SUPPORT | Medium | Official source separates metropolitan Pico y Placa and national/foreign Placa-Dia perimeter behavior. |
| Pereira | Risaralda | READY_FOR_RULE_PACK | Medium | Official Pereira sources identify Decreto 540 de 2024 and continuing current measure, but final rule pack must re-check source accessibility. |
| Pasto | Narino | INSUFFICIENT_CURRENT_SOURCE | Medium | Official decree index identifies Decreto 0122 of 2026, but exact schedule/category text was not extracted in this freeze. |
| Monteria | Cordoba | NO_CURRENT_RULE_FOUND | Medium | Official portal/decree index searched; no current ordinary Pico y Placa rule located. |
| Santa Marta | Magdalena | READY_FOR_RULE_PACK | Medium | Official Decreto 213 of 2026 exists for private vehicles; PDF/OCR extraction is still required before runtime encoding. |
| Tunja | Boyaca | NEEDS_CONDITIONAL_EXEMPTION_SUPPORT | Medium | Official/municipal source indicates dual center-historic vs rest-city time windows and exemptions. |
| Manizales | Caldas | TEMPORARY_EVENT_ONLY | High | Official emergency measure is date-bounded after the August 2026 earthquake. |
| Barranquilla | Atlantico | TEMPORARY_EVENT_ONLY | High | Official source found for Carnival/event-only private-vehicle restrictions. |

## Armenia

- City: Armenia
- Department: Quindio
- Official authority: Alcaldia de Armenia / SETTA
- Official URL:
  https://repository.armenia.gov.co/?start=135
- Controlling decree/resolution if found: Decreto 135 de 2026 referenced by
  official municipal news; third-party discovery also references Gaceta
  Municipal publication.
- Publication date: 2026-05-26 official news listing
- validFrom: pending exact decree extraction
- validUntil: six-month extension window pending exact decree extraction
- Vehicle categories: private vehicles, motorcycles, motocarros,
  mototriciclos, cuatrimotos reported by discovery sources; confirm against
  decree before runtime.
- Digit position: last digit, pending decree confirmation
- Digits/schedule: Mon 5/6, Tue 7/8, Wed 9/0, Thu 1/2, Fri 3/4 reported by
  discovery sources; confirm against official decree before runtime.
- Time windows: 07:00-19:00 reported by discovery sources; confirm against
  official decree before runtime.
- Weekend/holiday behavior: weekends reportedly not restricted for private
  vehicles; confirm against decree.
- Known conditional exemptions: standard emergency/public-service exemptions.
- Confidence: Medium
- Recommended runtime status: READY_FOR_RULE_PACK

## Cucuta / Metropolitan Scope

- City: Cucuta / relevant metropolitan scope
- Department: Norte de Santander
- Official authority: Alcaldia de San Jose de Cucuta
- Official URLs:
  https://cucuta.gov.co/
  https://cucuta.gov.co/comenzo-a-regir-nuevo-decreto-que-regula-el-pico-y-placa-y-placa-dia-en-cucuta/
- Controlling decree/resolution if found: Decreto 0212 del 26 de abril de
  2024; current homepage publishes daily Pico y Placa and 2026 normative links.
- Publication date: 2024-04-28 for Decreto 0212 article; current homepage
  verified 2026-08-31.
- validFrom: current ordinary operation indicated by municipal homepage.
- validUntil: not found in this freeze.
- Vehicle categories: private vehicles, motorcycles/cars in metropolitan area;
  Placa-Dia covers Colombian national and foreign plates; public transport
  has separate schedules.
- Digit position: last digit.
- Digits/schedule: Mon 1/2, Tue 3/4, Wed 5/6, Thu 7/8, Fri 9/0 in the official
  2024 source; homepage daily widget matched Monday 1/2 on 2026-08-31.
- Time windows: Pico y Placa windows 07:00-08:30, 11:30-14:30, 17:30-19:30;
  Placa-Dia 07:00-20:00 for applicable national/foreign plates.
- Weekend/holiday behavior: weekday schedule; final decree review required.
- Known conditional exemptions: vehicle registration/origin area,
  national/foreign plate class, perimeter/anillo-vial carve-outs, public
  transport schedule separation.
- Confidence: Medium
- Recommended runtime status: NEEDS_CONDITIONAL_EXEMPTION_SUPPORT

## Pereira

- City: Pereira
- Department: Risaralda
- Official authority: Alcaldia de Pereira
- Official URLs:
  https://www.pereira.gov.co/publicaciones/9061/medida-de-pico-y-placa-en-pereira-se-mantiene-sin-modificaciones/
  https://www.pereira.gov.co/loader.php?id=139829&lFuncion=visorpdf&lServicio=Tools2&lTipo=descargas&pdf=1
- Controlling decree/resolution if found: Decreto 000540 de 26 febrero 2024.
- Publication date: 2024 decree; official current page references unchanged
  operation.
- validFrom: current operation under Decreto 540, exact runtime window to be
  confirmed before implementation.
- validUntil: not found in this freeze.
- Vehicle categories: private and official vehicles, motorcycles, motocarros,
  mototriciclos and cuatrimotos from official source discovery; confirm before
  runtime.
- Digit position: last digit, pending final decree parse.
- Digits/schedule: pending final decree parse.
- Time windows: official source discovery indicates 06:00-20:00.
- Weekend/holiday behavior: pending final decree parse.
- Known conditional exemptions: electric/hybrid/gas vehicles reported in
  official source snippet; final legal list must be parsed.
- Confidence: Medium
- Recommended runtime status: READY_FOR_RULE_PACK

## Pasto

- City: San Juan de Pasto
- Department: Narino
- Official authority: Alcaldia de Pasto
- Official URL:
  https://www.pasto.gov.co/index.php/decretos-2026
- Controlling decree/resolution if found: Decreto No. 0122 del 24 de julio de
  2026, restricting motor-vehicle transit in San Juan de Pasto.
- Publication date: 2026-07-24
- validFrom: pending decree extraction.
- validUntil: pending decree extraction.
- Vehicle categories: motor vehicles; exact category list pending.
- Digit position: pending decree extraction.
- Digits/schedule: pending decree extraction.
- Time windows: pending decree extraction.
- Weekend/holiday behavior: pending decree extraction.
- Known conditional exemptions: pending decree extraction.
- Confidence: Medium
- Recommended runtime status: INSUFFICIENT_CURRENT_SOURCE

## Monteria

- City: Monteria
- Department: Cordoba
- Official authority: Alcaldia de Monteria
- Official URLs:
  https://www.monteria.gov.co/
  https://www.monteria.gov.co/documentos/1007/decretos-2026/
- Controlling decree/resolution if found: none for ordinary Pico y Placa in
  this freeze.
- Publication date: not applicable.
- validFrom: not applicable.
- validUntil: not applicable.
- Vehicle categories: unknown.
- Digit position: unknown.
- Digits/schedule: unknown.
- Time windows: unknown.
- Weekend/holiday behavior: unknown.
- Known conditional exemptions: unknown.
- Confidence: Medium
- Recommended runtime status: NO_CURRENT_RULE_FOUND

## Santa Marta

- City: Santa Marta
- Department: Magdalena
- Official authority: Alcaldia Distrital de Santa Marta
- Official URLs:
  https://www.santamarta.gov.co/documentos/decretos-no-213-del-08-de-mayo-de-2026
  https://www.santamarta.gov.co/sites/default/files/decretos_no._213_del_08_de_mayo_de_2026.pdf
  https://www.santamarta.gov.co/documentos/decretos-no-212-del-08-de-mayo-de-2026
- Controlling decree/resolution if found: Decreto No. 213 del 08 de mayo de
  2026 for private vehicles; Decreto No. 212 del 08 de mayo de 2026 for special
  public-service vehicles.
- Publication date: 2026-05-08
- validFrom: pending decree extraction.
- validUntil: pending decree extraction.
- Vehicle categories: private automobiles, camperos, camionetas, microbuses and
  related vehicles; special public-service vehicles have separate decree.
- Digit position: pending decree extraction.
- Digits/schedule: pending decree extraction.
- Time windows: pending decree extraction.
- Weekend/holiday behavior: pending decree extraction.
- Known conditional exemptions: public-service/special-service separation and
  decree-level exemptions.
- Confidence: Medium
- Recommended runtime status: READY_FOR_RULE_PACK

## Tunja

- City: Tunja
- Department: Boyaca
- Official authority: Alcaldia Mayor de Tunja / Secretaria de Movilidad y Vida
  Territorial
- Official URLs:
  https://www.tunja-boyaca.gov.co/noticias/desde-el-13-de-enero-vuelve-el-pico-y-placa-en-tunja
  https://www.tunja-boyaca.gov.co/videos-institucionales/cambio-de-pico-y-placa-en-tunja-2024
- Controlling decree/resolution if found: 2024 municipal restriction remains
  the referenced base; 2026 official news says operation resumed 2026-01-13.
- Publication date: 2026-01 official news discovery; 2024 video/source for
  center vs rest-city behavior.
- validFrom: 2026-01-13
- validUntil: not found in this freeze.
- Vehicle categories: private vehicles; motorcycles/exemptions require final
  decree review.
- Digit position: last digit.
- Digits/schedule: current official search discovery reports Mon 3/4, Tue 5/6,
  Wed 7/8, Thu 9/0, Fri 1/2.
- Time windows: center historic zone continuous 06:00-20:00; rest of city
  06:00-09:00, 12:00-14:00, 17:00-20:00.
- Weekend/holiday behavior: weekday operation; holiday behavior pending final
  decree review.
- Known conditional exemptions: zone/perimeter-based windows, electric/hybrid
  and other legal exemptions, registered service-specific exceptions.
- Confidence: Medium
- Recommended runtime status: NEEDS_CONDITIONAL_EXEMPTION_SUPPORT

## Manizales

- City: Manizales
- Department: Caldas
- Official authority: Alcaldia de Manizales / Secretaria de Movilidad
- Official URL:
  https://centrodeinformacion.manizales.gov.co/manizales-extiende-el-pico-y-placa-temporal-hasta-el-15-de-septiembre-por-la-continuidad-de-las-labores-de-recuperacion-tras-el-sismo/
- Controlling decree/resolution if found: emergency temporary measure after
  August 2026 earthquake.
- Publication date: 2026-08-28
- validFrom: 2026-09-01 for extension.
- validUntil: 2026-09-15 for extension.
- Vehicle categories: private vehicles; motorcycles excepted.
- Digit position: last digit.
- Digits/schedule: day-by-day temporary sequence in official article.
- Time windows: 05:00-22:00.
- Weekend/holiday behavior: applies every day, including Saturdays, Sundays and
  holidays during the emergency window.
- Known conditional exemptions: emergency/service categories; out-of-municipality
  transit with proof; national-road carve-outs.
- Confidence: High
- Recommended runtime status: TEMPORARY_EVENT_ONLY

## Barranquilla

- City: Barranquilla
- Department: Atlantico
- Official authority: Alcaldia Distrital de Barranquilla
- Official URLs:
  https://barranquilla.gov.co/mi-barranquilla/pico-y-placa-para-vehiculos-particulares-en-toda-la-ciudad-viernes-sabado-domingo-y-lunes-de-carnaval
  https://barranquilla.gov.co/mi-barranquilla/inicio-pico-y-placa-para-particulares-en-la-via-40
  https://barranquilla.gov.co/mi-barranquilla/este-es-el-pico-y-placa-para-particulares-en-la-via-40-a-partir-del-lunes-2-de-febrero
- Controlling decree/resolution if found: Decreto Distrital 0036 del 26 de enero
  de 2026 for Carnival restriction.
- Publication date: 2026-02-09 for city-wide Carnival article.
- validFrom: Carnival/event dates, including 2026-02-13 through 2026-02-16 for
  the city-wide private-vehicle article.
- validUntil: event-bounded.
- Vehicle categories: private vehicles for city-wide Carnival source; other
  local road/event restrictions found for Via 40.
- Digit position: last digit.
- Digits/schedule: event-specific day-by-day schedule in official article.
- Time windows: event-specific.
- Weekend/holiday behavior: explicitly event/weekend/holiday period.
- Known conditional exemptions: event zones and event-only enforcement windows.
- Confidence: High
- Recommended runtime status: TEMPORARY_EVENT_ONLY

## Runtime Freeze

- Runtime rule implementation added in C10B-B: 0
- Active catalog availability changes in C10B-B: 0
- `mobile/assets/datasets/restrictions/restrictions_v1.json` edited: no
- Source URLs verified on: 2026-08-31
