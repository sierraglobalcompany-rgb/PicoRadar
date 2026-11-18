# PicoRadar — Acta M1A postejecución, conciliación documental y siguiente M1B

**Fecha:** 2026-11-07. **Estado:** `M1A_RESULT=PARTIAL` (reporte de Codex); `G0_INPUT_RECOVERED_OFFLINE=PASS` y `G2_SOURCE_RELATIONS_RECONCILED_OFFLINE=PASS` (trabajo independiente del director); `G3_NATIONAL_DISCOVERY=PARTIAL`; `RELEASE=NOT_APPROVED`.

## Hallazgo que elimina una vuelta de Codex

Codex declaró `G0_INPUT_INTEGRITY=BLOCKED` porque el ZIP de insumos M1A no estaba accesible en su Windows. En el contexto de dirección sí estaban ambos ZIP originales, con hash y CRC íntegros. La conciliación se ejecutó directamente, sin intervención sobre repositorio, servidor ni dispositivo:

| Artefacto | Resultado | Estado jurídico |
|---|---|---|
| DIVIPOLA MGN 2025 rastreado | 1.104 únicos | Actualidad 2026 no confirmada |
| Semilla y mapping | 73/73 iguales; 1.031 fuera de semilla | Solo identidad territorial |
| Clases vehículo históricas | 219 | No todas operativas |
| Fuentes únicas normalizadas | 93 | Todas como candidatas (`allowed_for_runtime=NO`) |
| Relaciones municipio–fuente | 174 | 0 huérfanas / 0 URL incongruentes |
| Observaciones de historial | 179 | Cinco pares tienen dos entradas, preservados |
| Investigación Codex M1A | 2 jurisdicciones revisadas parcialmente | 0 reglas nuevas completas / 0 activaciones |

**Evidencia original M1A V2 ZIP:** `e8191f717df2288ed2ed1d5775081ee239839dbc9ebb011b5bf8d433b64d4173`; **ZIP Codex M1A:** `cb99385e8c365a923f9013aa2b793207a684fa5233a41baed1a206ecbd88109b`. Se cotejaron 12 + 11 registros de manifiesto por SHA-256 y tamaño. Los archivos de salida enriquecidos y el detalle completo están en el ZIP de entrega del director; **no se commitean a GitHub** porque son candidatos no aprobados para runtime.

## Riesgo detectado con alcance acotado

El status hash del checkout protegido en M1A (`68598761c63af03a435d697e938c3eef0058b6067196901f000e2c7736a52e10`) difiere de su preflight registrado (`ad7bb66f6f04cc9d6aaa08870f35d0edd21e6724c9a401a7dd7d69d4025cbc12`). Se conserva conteo de 101 rutas, pero un mismo conteo no prueba identidad de bytes. Las 101 huellas individuales del checkpoint R21 permiten cotejo futuro focal READ-ONLY. Sin atribuir culpa ni declarar corrupción. Este riesgo NO bloquea investigación documental aislada.

## Próxima orden de ejecución

**M1B**: investigar fuentes oficiales, comenzar por P0 Medellín TTL técnico del 10 de noviembre y ciudades P1; continuar URLs existentes antes de búsquedas nuevas; registrar fecha, autoridad, clase, territorio, dígitos, horarios, vigencia, excepciones, fuente exacta y hash si es recuperable. No exigir decreto por defecto cuando el comunicado oficial sea suficiente. No confundir `NOT_SEARCHED` con permiso de circular, y no activar reglas automáticamente.

**Dirección:** usar el ZIP que contiene todos los insumos físicamente y el prompt `CODEX LUNA — M1B`, no rutas `D:` ajenas. Codex devuelve un ZIP único con pruebas focales y datos; ChatGPT auditor conserva la responsabilidad.

## Integridad GitHub / límites

Esta acta se añade exclusivamente al PR documental #79 en Draft, base `recovery/20261019-modern`. No modifica `main`, PR #71, Laravel, Flutter, datasets runtime, CI, dispositivo ni Hostinger. No autoriza merge, release ni publicación.