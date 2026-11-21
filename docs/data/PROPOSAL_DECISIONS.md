# PROPOSAL_DECISIONS — 2026-11-11

## F3: NO_NEW_LEGAL_READY_CANDIDATES

No se generó JSON de runtime, no se cambió el seed estático ni se ejecutó importación/aprobación/publicación: ninguna combinación focal tiene conjuntamente acto íntegro, vigencia, excepciones y ámbito comprobados.

| Autoridad | Estado | Decisión |
|---|---|---|
| Cali | LEGAL_UNRESOLVED | Retorno habitual desde 01-sep, pero tabla, horario, excepciones y acto no completos; la fuente oficial de rotación da HTTP 403. No proponer. |
| Ibagué | PARTIAL | Noticia H2 aporta rotación, horario y hora valle local; Decreto 0768/2025 y excepciones faltan. |
| Armenia | PARTIAL / ENGINE_GAP | Decreto 135/2026 referido, no íntegro; taxi con número interno, Cuadrante Norte sin geometría; mototriciclo/cuatrimoto fuera de pares. |
| Pereira | PARTIAL | Retorno desde 28-sep y páginas que citan Decreto 540/2024; texto íntegro/modificaciones no capturados. |

## Contrato de motor
- Diez filas están dentro de los nueve pares existentes; ninguna alcanza ENGINE_READY.
- Cinco ENGINE_GAP: taxi Armenia por número interno, dos regímenes Cuadrante Norte sin geometría certificada, mototriciclo y cuatrimoto fuera del contrato.
- inside_scope_ref sin geometría no autoriza a mostrar permiso fuera del ámbito.
- No se modificaron motor, enum, esquema, validador, permisos ni estados UNKNOWN/STALE.

## Resultado
- Propuestas schema2: 0.
- Importador/publicación fake: NOT_RUN_NO_LEGAL_READY_JSON.
- Publicaciones públicas nuevas: 0.
- consultationEnabled y autorización de circulación: sin cambios.
