# C21 V2 — handoff local

## Status

`PARTIAL` — APK dev compilado y auditado estáticamente; QA focal Flutter y Laravel verde con la cronología indicada; runtime Android y release no aprobados.

## Lot

`C21 V2 - APK dev, UNKNOWN seguro y QA nacional`

## Git

- Destino remoto autorizado: `feat/platform-integral-national-20261122`.
- Base: `f2575af7829d33d0506d252856f4daa4b4e8f949`.
- `HEAD_CODE`: `356ed5e1b9b08226c04cd9859bb84aac2613367d`.
- Commits integrados localmente: B `a584c04c37b6355046d1eb715aee43820deadfd6`; C `356ed5e1b9b08226c04cd9859bb84aac2613367d`.
- Worktree integrador: `C:\Users\felip\.codex\worktrees\picoradar-c20-integrator\PicoRadar-C17-V2` (checkout detached durante esta ejecución).
- `HEAD_FINAL` y confirmación posterior de `git ls-remote`: informados en el paquete C21 después del commit documental.

## Outcome

- B corrigió solo una expectativa de prueba: con `coverageCompleteness='partial'`, la evaluación de ese fixture devuelve `RestrictionDayStatus.unknown`. Se mantuvieron moto OFF y jurisdicción OFF como UNKNOWN. El motor, las reglas legales y datos de producción no se modificaron.
- C corrigió en `NationalOperationsReadService` dos fallos confirmados por la corrida inicial: acceso a `per_page` cuando no se proporciona y anotación del eager-load callback como `Builder` cuando Laravel pasa `HasMany`.
- A generó un APK debug del flavor `dev`. Su revisión estática no equivale a ejecución de la app.

## Files / areas changed

- `mobile/test/features/pico_placa/data/restriction_dataset_test.dart`: expectativa focal `restricted` → `unknown`.
- `server/app/Services/NationalOperationsReadService.php`: default seguro de `per_page` y callback tipado `HasMany`.
- `docs/CURRENT.md` y este handoff.
- No se cambiaron dependencias, lockfiles, esquema, motor, datasets, permisos ni normas. El APK solo está en el paquete externo; no se agregó al repositorio.

## Tests executed

| Command / test | Result |
| --- | --- |
| `flutter build apk --debug --flavor dev --no-pub` desde `D:\codex\_build\PicoRadar-C21V2-APK\mobile`, HEAD `f2575af...` | exit 0; APK dev verificado estáticamente |
| `flutter pub get --offline --enforce-lockfile` en el worktree A | exit 1 por soporte de symlinks Windows; no se cambió configuración global; lockfile SHA sin cambio |
| `flutter test --no-pub --plain-name "schema2 modality and jurisdiction toggles produce only safe evaluation states" test/features/pico_placa/data/restriction_dataset_test.dart` | primera llamada: exit 1 porque faltaba `package_graph.json`; reutilizado metadato de C20 con mismo lock; única repetición permitida: 1 test PASS, exit 0 |
| PHPUnit conjunto `NationalOperationsTest.php` + `NationalDatasetIntegrityTest.php` | inicial: 9 tests/16 assertions, 2 PASS y 7 FAIL (exit 1); rerun de solo siete métodos rojos: 7/7, 34 assertions, exit 0. Resultado verde observado para los nueve métodos sin volver a ejecutar los dos iniciales verdes. |
| `C:\xampphp\php\php.exe -l server\app\Services\NationalOperationsReadService.php` en el integrador | exit 0; salida `No syntax errors detected`; log SHA-256 `DE57E59CCCCA6DBE626BEFA226A0602CFC87907E51AA25435EB73CBD9A83A4BE`. |
| `git -c core.whitespace=cr-at-eol diff --check f2575af7829d33d0506d252856f4daa4b4e8f949..HEAD` | PASS; se respeta CRLF existente. |

Los logs originales incluidos en el ZIP contienen comandos, resultados y exit codes; el log PHP deja explícito que la invocación envolvente PowerShell retornó 1 después de registrar PHPUnit `RERUN_EXIT=0`. No se llama a las 28 pruebas ya ejecutadas en C19/C20, ni a analyze o suite Flutter completa.

## Manual QA

- APK estático: package `co.picoradar.app.dev`; versionName `1.0.1`; versionCode `2`; firma debug v2 con un signer, certificado SHA-256 `5435a892a30b3e5387e9ef6272f3b1c073ff1a9fe19741f1d5060200f680b78e`.
- Tamaño `209315497` bytes; SHA-256 `556B17C5D4174552D9F556BC5BBCBF57FF33287BD82E01535C073FA98DE8C65F`; ZIP/CRC íntegro, 21 DEX, 13 `.so`, 616 assets de proyecto. `restrictions_v1.json` dentro del APK y fuente tienen SHA-256 idéntico `68642A2E8FDA49CF89C45D8439C6CBF5064AA176AEEFE2FA3C4083C8201C4D16`.
- APK no instalado ni iniciado; sin ADB ni dispositivos. No se afirma runtime, cobertura nacional legal o release.

## Physical Android QA

`Not required by C21 scope / not performed`

- Device: ninguno.
- Evidencia: prohibido por C21; no se inició ADB.

## Data / migration impact

Ninguno. PHPUnit usó SQLite en memoria y fixtures sintéticas; directorios temporales Blade y clave de prueba solo en proceso. Sin DB persistente, migración o datos reales.

## Security / privacy review

Sin credenciales incluidas; APP_KEY efímera redactada en log; sin PII, matrículas, GPS, servicios remotos o instalaciones. Ads/payments/commercial actions siguen OFF. `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`.

## Dependencies added/changed

Ninguna. `pubspec.lock` SHA conservado: `9D68CE85ABA7E40C4E484D34B0F449E3BFFB98BE3D9F0118B7775ECC1E5F4834`.

## Known risks / debt

- El APK es debug y solo estático; falta QA runtime. No representa aprobación de instalación ni release.
- `pub get` sigue bloqueado por soporte local de symlinks, aunque no impidió el build `--no-pub` con metadatos locales compatibles.
- Cobertura legal/editorial nacional pendiente de validación humana. Las estimaciones 89% heredada y 90–91% preparación técnica no son certificación.
- Avisos de compatibilidad futura de Flutter para Gradle 9.3.1, AGP 9.1.1 y Kotlin 2.4.10; sin cambios porque no bloquearon build.

## Stop conditions encountered

- Symlink Windows bloqueó `pub get`; el límite de C21 fue respetado y no se tocó configuración global.
- No hubo bloqueo de build. PHPUnit inicial mostró siete fallos del servicio, reparados mínimamente y verificados en los siete métodos rojos.

## Next lot(s) unblocked

- Revisión del ChatGPT Director de evidencia C21. Separadamente, el usuario puede autorizar QA runtime DEV; hasta entonces no instalar. La validación legal y aprobación de release permanecen pendientes.
