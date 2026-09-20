# Reconciliacion posterior a C11

Fecha: 2026-09-19

## Identidad

- Base efectiva: `fix/C11-home-sponsor-carousel` en `2e8f2ed`.
- Rama de trabajo: `chore/C11-post-server-contracts`.
- La auditoria de 188 acciones en `13190d0` es antecedente, no base de
  restauracion.
- La matriz versionada conserva sus 188 filas y agrega la accion nueva de opt-in
  de mantenimiento. Por eso el inventario corregido no se presenta como una
  recertificacion fisica de 189 acciones.

## Delta confirmado

| Hallazgo | Estado posterior a C11 | Evidencia |
|---|---|---|
| H21, dos conceptos comerciales en Inicio | `SUPERADO_POR_C11` | No existe `HomeBannerSlot`; Inicio usa un solo carrusel superior. |
| H03, URL demo del slot anterior | `NO_ALCANZABLE_EN_INICIO_ACTUAL` | `home_banner_config.json` permanece porque SOAT/RTM lo consumen; Inicio no lo renderiza. |
| H10, lanzador del slot anterior | `NO_ALCANZABLE_EN_INICIO_ACTUAL` | El widget anterior fue retirado. Las demos C11 abren explicaciones locales y no transmiten datos. |
| H04, mantenimiento sin opt-in y con placa | `CORREGIDO_LOCALMENTE` | Opt-in por vehiculo, desactivado por defecto; aviso generico con visibilidad secreta. |
| H01, privacidad de teselas | `CONTRATO_PRECISADO` | La documentacion distingue backend de PicoRadar y proveedor remoto de teselas. |

## Contrato C11 preservado

No se modifican el carrusel comercial, sus cuatro campañas, flechas, puntos,
CTA, carrusel adaptable del vehiculo ni la visibilidad de SOAT/Tecnomecanica.
El banner inferior anterior no se restaura. Registro, modos y publicidad real
siguen apagados.

## Evidencia

`FUENTE_INSPECCIONADA` significa que el codigo y su alcanzabilidad fueron
revisados. `PRUEBA_AUTOMATIZADA` cubre un contrato ejecutado localmente o en
fixtures. `DISPOSITIVO_HISTORICO_C11` identifica las capturas del carrusel con
capsula ovalada; son anteriores al cierre visual. `DISPOSITIVO_FINAL_C11`
identifica las capturas `home-light-controls-*`, donde se ven flechas y puntos
sin capsula, vehiculo adaptable y SOAT/Tecnomecanica completos. Ninguna captura
prueba por si sola que el binario y el codigo sean iguales: esa relacion exige
identidad de build adicional. `SERVICIO_PRODUCTIVO` solo se usara despues de un
despliegue real; no aplica a esta entrega.

Los hashes y el diff de los cuatro archivos protegidos C11 se registran en el
handoff de coherencia. Un checkpoint Git local permite recuperar el trabajo en
este equipo, pero no constituye respaldo remoto.

## Datos que no se reinterpretan

- Peajes conserva 184 estaciones, 1.300 tarifas generales y 1.007 importes
  numericos en el corte declarado de 2026-09-08.
- Pico y placa conserva 73 municipios catalogados, pero solo cinco paquetes
  afirmativos vigentes estan habilitados en el motor. Catalogo no equivale a
  cobertura nacional afirmativa.
- Esta entrega no modifica, extiende ni refecha esos datasets.
