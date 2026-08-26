# Codex Build Pack — PicoRadar: Pico y Placa

**Versión:** 1.0  
**Fecha:** 2026-08-26  
**Objetivo:** ejecutar el desarrollo Android-first de Free 1.0 en lotes C00–C29, sin reinterpretar el producto.

## Empieza aquí

1. Lee `AGENTS.md`.
2. Lee `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`.
3. Lee `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`.
4. Consulta `codex/DEPENDENCY_MATRIX.md` y `codex/EXECUTION_ORDER.md`.
5. Ejecuta **un solo lote** desde `codex/lots/`.
6. Al cerrar, completa `codex/templates/HANDOFF_TEMPLATE.md`.
7. No hagas merge sin aprobación humana.

## Precedencia de documentación

1. `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`
2. `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`
3. Flujos 01–08
4. Wireframes + Design System
5. Screen Map
6. Plan Maestro v2

Si un documento antiguo dice **Vehículo**, la UI final dice **Garaje**.

## Navegación no negociable

`Inicio · Garaje · Apps · Viaje · Conducir`

**Apps siempre va en el centro.**

## Modelo de release

Primero se construye **Free 1.0 completa**. En Free 1.0 están apagados:

- anuncios;
- interstitials;
- pagos;
- suscripción;
- nube/cuenta;
- email/WhatsApp premium;
- paywalls.

## Regla KISS

Construir lo mínimo robusto que satisfaga el lote. No introducir microservicios, engines geoespaciales complejos, codegen innecesario o plugins dudosos si una solución estándar/simple resuelve el caso.

## Carpeta del pack

- `AGENTS.md`: reglas permanentes.
- `codex/lots/C00...C29`: prompts ejecutables.
- `codex/templates`: handoff, PR, ADR y QA.
- `contracts`: contratos de manifest/API/datasets.
- `docs/baseline`: documentación fuente.
- `manifest_sha256.txt`: integridad del pack.
