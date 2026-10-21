# Auditoría de cobertura nacional — 2026-09-19

## Matriz de cobertura

| Dominio | Activo canónico | Cobertura | Estado que puede mostrar la app | Estado que no puede inferir |
|---|---|---:|---|---|
| Trámites | `comparendos_authorities_v1.json` | 769 autoridades / 1.003 filas fuente | 2 autoridades con enlaces directos revisados; 5 fallbacks institucionales; 762 fallbacks RUNT | Capacidad para tramitar en las 767 autoridades sin enlaces directos |
| Pico y placa | `pico_jurisdiction_catalog_v1.json` | 73 municipios | 6 verificados, 36 condicionales, 2 expirados, 29 pendientes | Regla afirmativa en municipios sin paquete local vigente |
| Cámaras | `cameras_v1.json` | 360 registros / 13 departamentos o territorios | Snapshot ANSV; 293 con velocidad y 67 sin velocidad reportada | Operación actual, velocidad cero o ausencia de cámaras fuera del snapshot |
| Peajes inventario | `tolls_inventory_v1.json` | 184 estaciones físicas | 180 inventariadas sin operación confirmada, 1 reportada operando por la fuente, 2 históricas no operativas, 1 dañada en revisión | Cobro actual, ruta gratuita o tarifa cero |
| Peajes tarifas | `tolls_tariffs_v1.json` | 184 estaciones / 1.300 tarifas generales | 1.007 valores numéricos; corte declarado 2026-09-08 | Vigencia actual o reverificación externa independiente |

## Fuentes y fijación de bytes

### Trámites

- FCM, Directorio de Organismos de Tránsito: `https://www.fcm.org.co/wp-content/uploads/2021/07/Directorio-Organismos-de-Transito.pdf` — 398 filas, SHA-256 `9edec22a4b685792cad305291a946865be6ab3d1f071b11a52ba68c225fde6fb`.
- FCM, Base de Datos Autoridades de Tránsito: `https://www.fcm.org.co/wp-content/uploads/2021/08/Base-de-Datos-Autoridades-de-Transito.pdf` — 308 filas, SHA-256 `3eda7e000d03f2a264a6995782f862eda40f0577d5925f9ee8bc79f2f3fc5a3e`.
- RUNT, listado de extensiones y organismos: `https://www.runt.gov.co/sites/default/files/documentos/LISTADO%20EXTENSIONES%20IP%20ORGANISMOS%20DE%20TRANSITO.pdf` — 297 filas, SHA-256 `8b98ceb526a34befa25f69878c9607c380c269d98e939dbbaac4900c096c6a55`.
- Fallback oficial de registro: `https://www.runt.gov.co/directorio-de-actores`.

Los enlaces directos de procedimientos permanecen limitados a Bogotá y Medellín. La revisión territorial de una institución no acredita por sí sola un procedimiento registral.

### Pico y placa

- Fuente local: `data/sources/restrictions/PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx`, hoja `Estado_al_corte`.
- SHA-256: `6ce34e9437138ec2585c0e27df7c30de56be31292b71763ca6dcceaf1c337d0e`.
- Corte documental de la fuente: 2026-09-10. Fecha de evaluación operativa: 2026-09-19.
- El asset de reglas existente conserva SHA-256 `68642a2e8fda49cf89c45d8439c6cbf5064aa176aeefe2fa3c4083c8201c4d16`.

`engineEnabled` es una decisión separada del estado documental. Solo Bogotá, Medellín, Bucaramanga, Popayán y Villavicencio están habilitados. Itagüí tiene evidencia documental verificada, pero no un paquete local específico.

### Cámaras

- Fuente ANSV: `https://fotodeteccion.ansv.gov.co/ubicaciones-aprobadas.html`.
- Captura fuente: 2026-08-31T15:44:00+00:00.
- Asset: 428.240 bytes, SHA-256 `c8a337ac7f2b63055ffded9209e87d0d7eccff3db43bbabb920608ffa393c43c`.

El valor `Operando` se conserva como valor observado en el snapshot. No se convierte en una confirmación en tiempo real.

### Peajes

- Inventario público referenciado por cada registro: `https://www.datos.gov.co/Transporte/Peajes/68qj-5xux`.
- Inventario: 330.905 bytes, SHA-256 `a991626ecc8893c050a60e71b27e8f803cbfe864978dced5e6b595f2fe02de93`.
- Tarifas: 1.838.432 bytes, SHA-256 `984f2ab202ff1de8befb3cbed2c48ee2a69dbb5e88c9bbb1ea8f6aa2cdecdd6f`.
- Workbook de tarifas declarado: `PicoRadar_Peajes_Colombia_AUDITADO_2026-09-08.xlsx`, SHA-256 `8863b418cdd4664fc4b0a2c7eaaafde73dd88b0eea9535db7c57fcbd7f1b5a4a`.
- JSON fuente de tarifas: SHA-256 `ebebeca817cb2487aa632a79c6c2de270550888253924250408936cb7db948f8`.

## Brechas editoriales no resueltas

- Trámites: faltan enlaces de procedimiento acreditados para 767 autoridades. Cinco tienen sitio institucional revisado, pero siguen `Por confirmar`; 762 usan el directorio RUNT.
- Pico: 36 municipios requieren validación local adicional, 29 no tienen evidencia suficiente y 2 tienen evidencia expirada o derogada. La hoja no contiene URL externa suficiente para Turbaco, Florencia, Fusagasugá, Soacha, Montería, Santa Cruz de Lorica, Neiva, Pitalito, Ipiales, Sincelejo, Palmira y Tuluá.
- Cámaras: 67 registros no informan velocidad y el snapshot solo representa 13 departamentos o territorios. No existe verificación en vivo de operación.
- Peajes: el inventario no confirma ningún evento de cobro ni informa tarifas; las 184 estaciones conservan tarifa desconocida en ese activo. El catálogo tarifario declara que no tuvo reverificación externa independiente y mantiene 9 candidatos fuera de la base.
- No se agregaron reglas, URLs, fechas de renovación ni estados actuales desde fuentes externas a los activos auditados del repositorio.

## Validación

Ejecutar:

```text
python scripts/validate_national_coverage.py
```

El validador recalcula conteos, distribuciones, hashes y el aislamiento del motor; falla si un valor desconocido se convierte en cero o si cambia un asset fijado.
