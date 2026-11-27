# C31 V2 — editoría sintética por formularios HTTP

`editorial.php` prepara una única ejecución local sobre la instancia que lane A
marque como `EDITORIAL_QA`. Recorre login con sesiones independientes de Editor
y SuperAdmin, importación schema2, selección de la fila válida, creación de
borrador, validación, aprobación editorial, publicación OFF/partial, lectura
viva de manifest/payload y alta/edición manual mediante los formularios
Laravel, incluido `POST` con `_method=PUT`.

El runner nunca llama servicios Laravel directamente. Solo usa HTTP en
`127.0.0.1`, conserva las cookies en memoria por sesión y consulta SQLite con
`mode=ro` y `PRAGMA query_only=ON`. Los GET públicos de manifest/payload usan
un tercer cliente sin sesión. La URL `https://example.test/c31-synthetic-restrictions`
es una referencia sintética local; el runner no la solicita ni la presenta
como fuente legal.

## Preparación y ejecución futura

No ejecutar `--run` durante la preparación del lane C. El integrador lo habilita
solo después de que lane A complete `PrepareEditorial` y `Start -EditorialQa`
para la instancia verificada. Antes de iniciar mutaciones, el runner exige:

- `PICORADAR_EDITORIAL_QA=1` y coincidencia entre el ID esperado, el ID de
  instancia, `instance.json`, `runtime/editorial-qa.json` y
  `runtime/process.json` en modo `EDITORIAL_QA`;
- `PICORADAR_C31_BASE_URL=http://127.0.0.1:<puerto reportado por A>`;
- `PICORADAR_C31_PRIVATE_ROOT` fuera del repositorio y de la instancia;
- los passwords sintéticos únicamente en el entorno del proceso:
  `PICORADAR_EDITOR_PASSWORD` y `PICORADAR_OPERATOR_PASSWORD` (o las variantes
  `PICORADAR_C31_EDITOR_PASSWORD` y `PICORADAR_C31_SUPERADMIN_PASSWORD`).

Los identificadores sintéticos predeterminados son `editor-c31@picoradar.test`
y `superadmin@picoradar.test`; se pueden sustituir con las variables
`PICORADAR_C31_EDITOR_EMAIL` y `PICORADAR_C31_SUPERADMIN_EMAIL`. El runner no
imprime emails ni passwords. Lane A conserva el aprovisionamiento de usuarios,
fuente y jurisdicción; este runner no restaura, migra ni siembra.

Usar el PHP 8.5.8 con PDO SQLite del entorno C31 indicado por el runbook. El
runner obtiene la DB y el storage bajo el `PICORADAR_INSTANCE_ROOT` validado.
El puerto nunca se supone; se toma del marcador y del resultado de `Start`.
No reejecutar tras encontrar un fixture/import C31 previo: el script falla
cerrado y no borra ni sobrescribe los restos de una ejecución parcial.

## Validación focal de los helpers

```powershell
php -l codex/qa/c31/editorial.php
php -l codex/qa/c31/editorial_test.php
php codex/qa/c31/editorial_test.php
```

Estas pruebas no contactan Laravel, no crean base, no escriben fixture y no
requieren credenciales. Ejecutar el flujo real más tarde requiere `--run` y la
autorización operativa ya contenida en el prompt C31, con lane A listo.

El resultado público se mantiene `OFF` y `partial`; los datos solo son QA
sintética y no afirman cobertura ni regla jurídica real. No hay cambios en
`server/`, `mobile/`, dependencias ni APIs.
