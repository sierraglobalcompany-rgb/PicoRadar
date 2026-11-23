# C23-V2 handoff — cierre runtime/editor/HTTP

## Estado

`PARTIAL` — B y C tienen resultados focales; A se bloqueó antes de generar artefactos Android.

## Git

- Rama integradora local: `codex/c23-integrator`.
- Base: `f4f6c9a3ce8e9ae764c131db5e7d34194e78642c`.
- Código B: `bc2d1c1d956c7c9f0f25e9e376c9ada26e3053e8` (vista y test OFF, commit acotado).
- Runbook C: `84f0bf45278c90424aef321a3e9dbc93c853293e` (solo `codex/C23_V2_LOCAL_HTTP_RUNBOOK.md`).
- Rama remota objetivo única: `feat/platform-integral-national-20261122`; `main=e9ef37511df3110ffb0fc006ef06be781df432ac`, no tocar.
- El commit documental de este handoff y el estado remoto final se registran en el paquete de retorno C23.

## Resultado por carril

### B — Blade/editor

`B_VIEW=PASS`, `B_C1_ACTIVE=PASS`, `B_OFF=PASS`.

- Vista renderizada en GET autenticado.
- Método C1 activo conservado sin cambios: `test_editor_onboards_an_unassigned_municipality_and_saves_a_schema2_draft_without_publication`, 1 test/37 assertions/exit 0.
- Caso OFF independiente: `test_editor_creates_an_off_schema2_draft_from_national_queue_without_enabling_consultation`, 1 test/23 assertions/exit 0.
- El actor Editor recorre cola nacional → formulario OFF → POST falsificado con consulta/coberturas ON. Persiste OFF global y en cada cobertura, jurisdicción deshabilitada, schema 2/Draft, sin `restriction_publications`, `dataset_releases` ni solicitudes HTTP externas.
- Archivos de código y SHA-256: `show.blade.php` `4AE2975FBA489D7B9116BA49873B487CD18B7AC25146CE3DF8E74687859CA912`; `C11NationalEditorialFlowTest.php` `A3D131F61A8DAA13630F07275CC2F2F55940A7D108601BC3FCBAD965BD7BCD61`.
- PHP 8.5.8, PHPUnit 12.5.33. Logs focales `EDITOR_C1_QA/` incluidos en ZIP. Las fallas iniciales fueron errores del harness de vistas/autoload; el autoload final se comprobó apuntando al worktree C23 y los casos rojos focales pasaron una vez cada uno.

### C — HTTP local

`C_HTTP=PASS`, limitado a los endpoints y al render HTML.

- Copia de HEAD en D:, sin `.env`; `composer.lock` SHA-256 `7469B7EB9E72A79C92C69908AB22B7965FCB3E39019B1BBF6C6CB1C84423B983`. Vendor local reutilizado vía junction por coincidencia del lock; contiene registros adicionales, por lo que no se declara instalación limpia.
- PHP 8.5.8. SQLite vacío; preflight comprobó `base_path`, `storage_path`, caches default y `PRAGMA database_list` bajo la copia. Sin migraciones ni seeders.
- Primer intento: login 500 por `ViteManifestNotFoundException`; los otros dos GET dieron 302 y 404. Sin bundle versionado ni caché npm completo (87/158 URLs lock), no se ejecutó `npm install` ni se llamó a registry.
- Único retry autorizado: manifiesto temporal dentro de `public/build` ignorado para permitir el render de Blade. Resultados: `/login=200`, cola nacional `302` a login y campañas OFF `404`. PID propio detenido y listener cerrado. SHA fixture `BEED62E806F04C98A4C8AE25C43CA12990A5519339B7545323B8857898039FB0`.
- CSS/JS y comportamiento visual no probados; la limitación y receta reproducible constan en el runbook y `LOCAL_HTTP_QA.md` del ZIP.

### A — Android

`A_APK=BLOCKED_OS_SYMLINK`; no existe APK nuevo.

- No se encontró `flutter`/`dart` en PATH, `FLUTTER_ROOT` ni rutas SDK locales conocidas. WSL Ubuntu preinstalado fue la única alternativa revisada: no contiene Flutter; sí pudo leer el mismo lock (SHA-256 `9D68CE85ABA7E40C4E484D34B0F449E3BFFB98BE3D9F0118B7775ECC1E5F4834`).
- No hay metadatos generados de plugins ni `GeneratedPluginRegistrant` en el checkout limpio. No se realizó `flutter pub get`, build, auditoría APK ni ADB/AVD. El APK C21 histórico no es candidato y no se adjunta.
- No se tocó Windows Developer Mode, registro, políticas de symlinks, permisos ni SDKs globales.

## Preservación y límites

- El checkout moderno `D:\codex\PicoRadar` sigue en `recovery/20261019-modern` SHA `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, con su eliminación preexistente de `scripts/tests/test_hostinger_installer_browser.ps1` intacta.
- El checkout `D:\codex\PicoRadar-C17-V2` sigue en `codex/c17-v2` SHA `bd2c0055f4459b4f4f14a21efbefa0a3d111c8a0`, limpio. El worktree C22 admin conserva su modificación WIP de un único test; el worktree C22 server conserva su runbook sin seguimiento. No se alteraron.
- Sin cambios a motor, normas, catálogos, dependencias, migraciones o datos reales. Sin teléfono, producción, Hostinger, commits en `main`, PR #88, merge, release o publicación.
- `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`.

## Verificación ejecutada

- B: métodos focales C1 activo y OFF, PHP lint focal y diff check; resultados y salidas en ZIP.
- C: un preflight y una tanda HTTP inicial, seguida por la única repetición autorizada tras identificar la causa Vite; sin repetir C2/C3 ni suites históricas.
- A: inspección estática dirigida y comprobación de una alternativa WSL preinstalada. No hubo build ni inicio sin gates.
- Estado final remoto, hashes del ZIP, CRC y manifiesto: `GITHUB_STATE.md`, `FINAL_REPORT.md` y `MANIFEST_SHA256.txt` del único ZIP local.

## Siguiente actor

`CHATGPT_DIRECTOR` revisa el ZIP; después se requiere un Flutter SDK ya instalado y compatible para desbloquear A. No se solicita ni se asume aprobación de release.
