# PicoRadar — Desarrollo directo del Director N5/01: suspensión segura por modalidad

**Corte:** 2026-11-18 America/Bogota. **Resultado:** `CODE_IMPLEMENTED_LOCAL_PASS_SCOPED`; **release:** `NO_GO`.

## Base y delta verificados
- Base N3-R1 reconstruida independientemente: `a883b64fffb53d3d9ec263739c169561ddf8b49d`.
- Candidato N5/01 final (índice aislado): `7e8cc4dba1c93cba31bac408051c285b17802aad`.
- Patch binario `PICORADAR_N5_PAUSA_SEGURA_MODALIDAD_N3R1.patch` aplica con `git apply --index` sobre N3-R1 y reproduce exactamente el árbol final; `git diff --check` PASS.
- Delta: **5 archivos**, 118 líneas insertadas y 7 retiradas. No se tocaron Flutter, Drift, archivos jurídicos, usuarios, N4 ni datos de producción.

## Implementación real
- El editor Laravel schema2 ahora admite `suspend_consultation=1` **solo** para una cobertura que existía en el borrador de origen. Conserva la identidad y metadatos, pone `coverageCompleteness=partial` y `rules=[]`, sin introducir nuevos campos OTA. Los cambios de otras modalidades quedan intactos.
- Esto suspende **la consulta fiable**, no elimina una medida jurídica. Flutter schema2 con `partial` + sin reglas debe devolver `UNKNOWN`; nunca `ALLOWED`. No aplicar a schema1 ni a cobertura nueva.
- La interfaz explica esa diferencia y distingue expresamente la declaración «fuente no publica restricciones» de la suspensión.
- Publicar una retirada de reglas continúa pasando por la guardia original de revisión editorial/material; se añadió prueba que exige aprobación independiente, publicación con la segunda jurisdicción intacta y rollback.
- Para reactivar, restaurar la versión con reglas y fuente verificadas o introducir de nuevo dichas reglas; la historia conserva las versiones anteriores.

## Pruebas y límites
- Ejecutado en este entorno: `php -l` sobre 3 PHP PASS; prueba directa de la clase real `RestrictionFormPayloadBuilder` y validador schema2 mediante stub mínimo de Laravel/Carbon: **12/12 PASS**; `git diff --check`: PASS; recuperación `git apply --index` y SHA tree exacto: PASS.
- Agregados al código: 3 tests unitarios Laravel + extensión del test feature N3 de suspensión/revisión/publicación/rollback. **NO ejecutados aquí**: `php artisan test` (sin `vendor`, `mbstring`, `pdo_sqlite` en entorno), `flutter test` (sin Dart/Flutter), HTTP OTA HTTPS, APK real, QA Android.
- No se generó nueva APK; reutilizar V5 DEV como evidencia anterior, no como aprobación N5.

## Cómo integrar sin Codex ni perder N4
- Este parche se basa en N3-R1 exacto; N4-R2 de Codex estaba en curso y su estado local actual es **desconocido**. **No aplicar ciegamente sobre un checkout Windows con WIP**; antes cotejar archivos y árbol y usar rama/clon aislado. Como el delta se restringe al editor Laravel, no debería solaparse con el módulo de cuentas, pero eso requiere comprobarse al integrarlo.
- El repositorio GitHub `main` público aún carece de servicios schema2 de N3-R1. No es seguro fusionar este parche sobre `main` ni publicar la cadena privada de recuperación con `GITHUB_PRODUCT=HOLD_SECURITY`.
- El artefacto GitHub debe conservar este parche como **candidato de código**, no commit del producto ni release; un merge posterior requiere base recuperada saneada y pruebas Laravel reales.

**NEXT_ACTOR=CHATGPT_DIRECTOR** para continuar avances independientes o integrar tras recibir el WIP N4. `GITHUB_PRODUCT=HOLD_SECURITY`; `PRODUCT_RELEASE=NO_GO`.