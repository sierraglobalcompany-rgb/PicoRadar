# R03 — Pico + Vehicle Status UI Recovery

## Goal

Aplicar el Design System recuperado a las superficies secundarias ya implementadas sin cambiar sus motores.

## Scope IN

- PicoDetail;
- SOAT;
- RTM;
- Seguro/asistencia;
- Impuestos;
- Vehicle detail status section;
- source/verified/stale presentation.

## Principles

- status is dominant, forms are secondary;
- source/verified metadata visible but not visually louder than the answer;
- stale/unknown are unmistakable;
- local/manual data says `según la fecha guardada`;
- no fake official state;
- one CTA primary per screen when possible;
- external official actions visually distinct and labeled by authority.

## Pico Detail

Target:

- hoy dominant;
- mañana;
- horarios;
- próximo 7 días;
- source/verification;
- alert preferences entry;
- no giant generic ListView appearance.

## SOAT/RTM

Target:

- state/date at top;
- reminder compact;
- edit action;
- RUNT verification CTA;
- manual-data disclaimer.

## Insurance

Target:

- provider/policy context;
- assistance actions large enough for emergency use;
- explicit `depende de tu póliza`;
- no advertising surface.

## Taxes

Target:

- authority/year;
- verified calendar dates;
- stale state;
- official portal CTA;
- never monetary estimate.

## Scope OUT

- new data models;
- new official sources unless correcting a factual defect;
- backend;
- payments/ads.

## Evidence

At least one screenshot per primary state and visual mismatch ledger.
