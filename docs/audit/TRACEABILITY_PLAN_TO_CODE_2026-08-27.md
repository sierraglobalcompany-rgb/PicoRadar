# PicoRadar — Trazabilidad Plan → Código → Brecha

Fecha: 2026-08-27

Estados:

- `DONE`: capacidad implementada y razonablemente alineada.
- `PARTIAL`: existe capacidad funcional pero falta alcance/UX/datos/gate.
- `NOT_STARTED`: todavía no existe.
- `RECOVERY`: existe, pero debe corregirse antes de seguir extendiendo la superficie.

## Épicas del Cierre Global

| Épica | Baseline | Implementación actual | Estado | Brecha principal | Próximo bloque |
|---|---|---|---|---|---|
| E00 Fundación | repo, flavors, CI, shell, **Design System** | C00–C02 + tokens/theme mínimos | `RECOVERY` | Design System Flutter incompleto; fidelity gate inexistente | R01–R04 |
| E01 Datos locales | SQLite, settings, cifrado, manifest | C03–C05 + migrations hasta v4 en C13 | `DONE/PARTIAL` | falta hardening final y cleanup; base sólida | C15/C29 |
| E02 Garaje/onboarding | Flujo 01 + núcleo vehículo | C06–C08; taxi añadido | `RECOVERY` | comportamiento fuerte, visual desviado | R02 |
| E03 Inicio/Pico | Flujo 02 + notifications | C09–C11 + Android widget | `RECOVERY` | UI no alcanza mockup; cobertura nacional aún piloto; iOS widget pendiente | R02/R03 + data expansion |
| E04 Apps launcher | Flujo 04 | C12 | `RECOVERY` | funcional; necesita visual system R01/R02 | R02 |
| E05 Estado vehículo | SOAT/RTM/seguro/impuestos/comparendos/docs | C13 cubre 4 primeros; comparendos/docs pendientes | `PARTIAL/RECOVERY` | visual + CM + wallet/docs | R03 + C14/C15 |
| E06 Conducir | cámaras, GPS, matcher, voz, HUD, background | solo shell/placeholder | `NOT_STARTED` | núcleo diferenciador de producto todavía falta | C16–C20 |
| E07 Viaje | rutas, ETA, peajes, restricciones, estado vial | placeholder/tab/shortcut | `NOT_STARTED` | UI + provider + proxy backend | C21–C23 + B03 |
| E08 Defensa | rule engine, plantillas, PDF, seguimiento | placeholder | `NOT_STARTED` | dominio jurídico completo | C26–C27 |
| E09 Servicios | CDA, talleres, peritajes, directorios/leads básicos | placeholders/CTA | `NOT_STARTED` | dataset/directorio + UI | C24–C25 |
| E10 Backend/control plane | admin, datasets, publisher, API mínima | Laravel scaffold únicamente | `NOT_STARTED` | control plane casi completo | B00–B06 |
| E11 Hardening | físico, accesibilidad, seguridad, performance, stores | gates parciales | `PARTIAL` | CI billing bloqueado; visual/physical/store readiness incompletos | R04 + C29 |

## Lotes C00–C13

| Lote | Capacidad | Estado técnico | Estado producto |
|---|---|---|---|
| C00 | scaffold/flavors | DONE | DONE |
| C01 | shell/router | DONE | visual RECOVERY |
| C02 | CI | implementado | infra billing bloqueada |
| C03 | Drift base | DONE | DONE |
| C04 | prefs/secure/crypto | DONE | DONE |
| C05 | manifest sync | DONE | falta publisher server |
| C06 | vehicle domain | DONE | DONE |
| C07 | onboarding | DONE | visual RECOVERY |
| C08 | garage | DONE | visual RECOVERY |
| C09 | pico engine | DONE | DONE core |
| C10 | restrictions pilot | DONE | cobertura piloto, no nacional |
| C11 | Home/notifications/widget Android | DONE | visual RECOVERY + iOS widget pendiente |
| C12 | Apps launcher | DONE | visual RECOVERY |
| C13 | vehicle status modules | PR abierto | visual RECOVERY; CM/docs fuera de C13 |

## Superficies del Screen Map

### G — Global/Onboarding

Implementado:

- alta vehículo;
- carro/moto/taxi;
- draft;
- primer activo;
- permisos no adelantados.

Brechas:

- bienvenida inicial no reproduce completamente G-002/G-010;
- seguro inicial y alertas iniciales fueron simplificados y movidos a módulos posteriores;
- fidelity visual.

Decisión: no reabrir arquitectura. Recuperar visualmente en R02 y aceptar simplificación KISS donde la capacidad final existe en C11/C13.

### H — Inicio

Implementado:

- active vehicle;
- manual jurisdiction;
- today/tomorrow;
- allowed/restricted/unknown/stale;
- alerts.

Brechas contra H-001/002:

- CTA dominante `Iniciar conducción` todavía no es la composición principal;
- obligaciones rápidas no están integradas con la jerarquía del mockup;
- selector rápido de vehículo usa Garaje en lugar de H-005 compacto;
- skeleton/offline visual incompleto;
- visual geometry/typography.

R02.

### V — Garaje

Implementado:

- múltiples vehículos;
- activo/fallback;
- detail/edit/delete;
- C13 conecta estados de obligaciones.

Brechas:

- VehicleCard no presenta todavía la composición aprobada con circulación+SOAT+RTM+impuestos al primer vistazo;
- representación genérica visual provisional;
- servicios rápidos visuales incompletos.

R02/R03.

### A — Apps

Implementado:

- 9 primarios;
- 6 secundarios;
- guard;
- feature flags;
- placeholders.

Brecha:

- visual tile system/material-default feeling.

R02.

### PP — Pico y Placa

Implementado:

- engine;
- source metadata;
- detail today/tomorrow/7 días;
- alerts;
- Android Free widget.

Brechas:

- PP-002 calendario mensual/fecha detalle todavía simplificado a lista 7 días;
- PP-003 abrir fuente oficial no está completo como pantalla/acción dedicada;
- diseño visual;
- dataset nacional incompleto;
- WidgetKit iOS pendiente.

R03 + data expansion + iOS stage.

### CM — Comparendos

`NOT_STARTED` funcionalmente.

C14.

### SO / RT / IN / TX

C13 implementa núcleo local.

Brechas:

- visual R03;
- directorio CDA real queda C24;
- tax coverage nacional queda dataset/catalog expansion;
- no RUNT automated data por diseño.

### W — Billetera

Crypto foundation existe desde C04.

UI/scanner/biometric/document model: `NOT_STARTED`.

C15.

### T — Viaje

`NOT_STARTED` salvo root placeholder.

C21–C23 + B03.

### D — Conducir

`NOT_STARTED` salvo shell/root placeholder y decisión visual.

C16–C20.

### SV / CDA / PER / TAL

`NOT_STARTED` salvo navegación provisional.

C24.

### BS — Compra/Venta/Trámites

Placeholders únicamente.

C25/C27 según capacidad documental/lead.

### DF — Defensa

Placeholders únicamente.

C26–C27.

### N / S — Centro de notificaciones y Ajustes

Preferencias y scheduling existen técnicamente, pero las superficies globales completas del Screen Map aún no están implementadas como centro/ajustes.

Deben incorporarse antes de C29, idealmente como pequeño lote transversal después de los módulos principales para evitar duplicar settings screens.

## Backend por necesidad de producto

| Necesidad | Local/CDN/API | Backend actual | Bloque |
|---|---|---|---|
| Pico restrictions | CDN dataset | app tiene consumer, server no publisher | B01 |
| Cameras | regional CDN packs | no publisher | B02 |
| Tolls | CDN dataset | no publisher | B02/B03 según contrato |
| Service directories | CDN/cache + optional API | no catalog server | C24/B01 extension |
| Legal templates | versioned dataset/asset | no publisher | B01/C26 |
| Routes/Places | dynamic API proxy | no endpoint | B03 |
| Urgent invalidation | push trigger | none | B05 |
| Admin publishing | control plane web | none | B04 |
| Mobile users/accounts | not required | none | CORRECT |
| GPS history | forbidden by default | none | CORRECT |

## Critical path actualizado

```text
C13 review/merge
  ├─ R01 → R02 → R03 → R04
  ├─ B00 → B01
  └─ luego retomar C14/C15

C16 → C17 → C18 → C19 → C20  = Driving Core
B02 debe llegar antes de datos reales C16/C19

C21 → B03/C22 → C23 = Viaje

C24 → C25
C26 → C27
B04/C28 se unifican para no construir dos admins
C29 cierre
```

## Stop-the-line conditions nuevas

No avanzar masivamente pantallas visibles si:

- R01 no está mergeado;
- una pantalla nueva no tiene referencia visual;
- C13/R03 no han estabilizado el patrón de status screens.

No avanzar Driving productivo si:

- camera dataset contract/pilot no está verificado;
- physical device QA no está disponible.

No publicar Free 1.0 si:

- CI billing sigue impidiendo ejecutar gates;
- iOS widget requerido sigue pendiente para release iPhone;
- visual root gate R04 no está aprobado.
