# G34 — resultados de QA atribuibles

Todos los comandos PHP se ejecutaron en `server/` con PHP 8.5.8, PHPUnit 12.5.33 y SQLite en memoria. Los tests HTTP recibieron un `APP_KEY` temporal en el proceso; no se escribió `.env`. No se ejecutaron pruebas sobre producción ni sobre un teléfono.

## PASS

| Comando | Resultado |
|---|---|
| `php -d extension=php_pdo_sqlite.dll vendor/bin/phpunit tests/Feature/DatasetReleaseValidationTest.php` | 6 tests, 31 assertions |
| `php -d extension=php_pdo_sqlite.dll vendor/bin/phpunit tests/Feature/RestrictionPublicationServiceTest.php` | 6 tests, 25 assertions; regresión de publicación schema1 |
| `php -d extension=php_pdo_sqlite.dll vendor/bin/phpunit tests/Feature/RestrictionMaterialApprovalWorkflowTest.php` | 5 tests, 49 assertions; ruta HTTP, Gate, dos actores, auditoría, revisión obsoleta y controles negativos |
| `php -d extension=php_pdo_sqlite.dll vendor/bin/phpunit tests/Feature/RestrictionG34EditorialImportLabTest.php` | 2 tests, 197 assertions; oráculos de 5 pares y ciclo import→confirm→validate en fake DB |
| Filtro focal de `RestrictionSchemaV2LabRoundTripTest.php` para retiro, `complete` y expansión de vigencia | 3 tests, 25 assertions |
| `python -m unittest scripts.tests.test_import_dane_divipola_sidecar -v` | 2 tests PASS |
| `python -m py_compile scripts/import_dane_divipola_sidecar.py scripts/tests/test_import_dane_divipola_sidecar.py` | PASS |
| `php -l` en 9 PHP modificados + `php vendor/bin/pint --test <archivos>` | 9/9 sintaxis PASS; Pint PASS |
| `git diff --check` | PASS |

El caso PHP de `expiresAt` se observó primero rojo: el valor sin zona `2026-11-11T00:00:00` se aceptaba. Después de exigir zona en `expiresAt` pasó con `Z` y `-05:00`; tipos, fechas inválidas e imposibles se rechazan. La regla de zona se limita a `expiresAt`; los demás campos de fecha no cambiaron su contrato.

## BLOQUEADO por precondiciones externas al código

La ejecución de la clase completa `RestrictionSchemaV2LabRoundTripTest.php` terminó con 4/7 tests pasando y 3 fallos de precondición:

- Falta `PICORADAR_G2_EVIDENCE_DIR` para capturar bytes de release/manifest del caso histórico.
- Falta `PICORADAR_G2_R2_RELEASE`, que debe ser el payload exacto SHA-256 `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`.
- Fallos observados como `assertIsString(false)` en líneas 77, 132 y 182. No se usó R4, R2 sintético ni se creó un sustituto.

No se generó release/manifest G34. Los bytes del fake publish del test de aprobación no se exportan y no representan el payload R2 ni el dataset de ciudades.

## NOT_RUN

- `dart format`, `flutter analyze`, `flutter test`, migración/Drift y round-trip PHP→Flutter: Flutter y Dart no están instalados/disponibles (`Get-Command flutter` y `Get-Command dart` no encontraron ejecutables).
- Suite Flutter completa y build Android: no ejecutados.
- Pruebas de engine/fecha/placa/ciudad/trip, festivos y `UNKNOWN` sin falsa autorización: requieren Dart/Flutter y el dataset raíz R2; no se atribuyen como PASS.
- Restauración de bundle a repositorio vacío y comparación de artefacto G34: no ejecutada; no existe commit G34 y no se alcanzaron todos los gates de release.

No se omitió ni se eliminó ninguna aserción para conseguir un resultado verde.
