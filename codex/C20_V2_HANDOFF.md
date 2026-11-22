# PicoRadar C20 V2 — handoff de cierre local

Fecha: 2026-11-22 (America/Bogota)  
Estado: `PARTIAL` · `CODE_DONE` · `QA_PARTIAL_FAIL` · `APK_NOT_BUILT` · `RELEASE_NO_GO`

## Git y alcance

- Repositorio: `sierraglobalcompany-rgb/PicoRadar`.
- Rama remota autorizada: `feat/platform-integral-national-20261122`.
- Base verificada: `bd2c0055f4459b4f4f14a21efbefa0a3d111c8a0`; `main` observado en `e9ef37511df3110ffb0fc006ef06be781df432ac`.
- Worktree integrador: `C:\Users\felip\.codex\worktrees\picoradar-c20-integrator\PicoRadar-C17-V2` (HEAD detached para integración aislada; push explícito al único ref permitido).
- `HEAD_CODE=3bd214d2dc0e541fd30471450f7a212e068f276c`. `HEAD_FINAL` es este commit documental; su SHA confirmado por el push se registra en `GITHUB_STATE.md` del ZIP único.
- Commits integrados sobre la base, en orden:
  - B `d92bfce98b1883dc924ddf1a7d156786dcf1da97` — dos errores Dart localizados y presupuesto Gradle del proyecto.
  - C `76155940492dc13070f6ce10b4f8b6e951b6f75f` — compilación de fake/tests, solo bajo `mobile/test/`.
  - A `dbc1d75869bb88fb8d548569a3fff6373ce235cd` — tres archivos de tests PHP.
  - C Settings `3bd214d2dc0e541fd30471450f7a212e068f276c` — fixture vacía para fallback OTA y perfil activo sintético para expectativa de correo verificado.
- No se modificaron `server/app`, motor de restricciones, datasets, contratos API, `pubspec.yaml`, `pubspec.lock`, certificados, secretos ni base de datos. No se tocó teléfono, ADB, Hostinger, `main`, PR #88 ni Actions.

## Resultado de producto

- `mobile/lib/features/services/data/service_provider_catalog.dart`: `_requiredCode` escapa el `$` de Dart conservando el ancla `$` de la regex y longitud/dígitos exactos. El resto del delta del archivo es formateo Dart focal.
- `mobile/lib/features/home/presentation/home_vehicle_carousel.dart`: `_TodayDetail` dibuja el icono desde `evaluation.status`.
- `mobile/android/gradle.properties`: `-Xmx2048m`, metaspace `768m`, code cache `256m`, `org.gradle.workers.max=1`, `org.gradle.parallel=false`. Ajuste limitado al proyecto.
- `server/tests/Feature/RestrictionRouteIntegrationTest.php`: fixtures de país/departamento reusan clave estable de nivel+código; el test inspecciona hidden `0`, checkbox desmarcado y rechazo de POST malicioso; fixture sintética activa confirma explícitamente cobertura sin reglas.
- `server/tests/Feature/RestrictionRuleVersionServiceTest.php`: importa el modelo usado por el test.
- `server/tests/Feature/RestrictionMaterialApprovalWorkflowTest.php`: comparación recursiva ordena mapas asociativos sin cambiar el orden de listas ni valores.
- `mobile/test/features/settings/presentation/settings_screen_test.dart`: fake de cuenta cumple el contrato; fallback OTA se consulta con DB sintética sin instalación; perfil de cuenta sintético activo corresponde al texto de email verificado.
- `mobile/test/features/pico_placa/data/restriction_dataset_test.dart`: ruta real confirmada y argumento de matcher alineado con `reason:`; las aserciones UNKNOWN/stale quedan. Una expectativa de `restricted` en fixture `partial` continúa fallando y no se cambió el motor ni se maquilló la aserción.

## Gates y evidencia ejecutada

### A — PHPUnit focal

- PHP `8.5.8`, PHPUnit `12.5.33`, SQLite/PDO habilitado solo en el proceso, `APP_ENV=testing`, SQLite `:memory:`, `APP_KEY` efímera y almacenamiento temporal.
- Se ejecutaron solo los tres archivos autorizados: `RestrictionRouteIntegrationTest.php`, `RestrictionRuleVersionServiceTest.php` y `RestrictionMaterialApprovalWorkflowTest.php`.
- Primera ejecución integrada: 22 tests, 168 assertions; 12 métodos completaron y 10 fallaron por `InvalidArgumentException: Please provide a valid cache path` al faltar el directorio temporal de compilación Blade. Exit 1. No fue fallo de reglas ni de datos.
- Se creó el directorio de vistas dentro del storage temporal, fuera del repositorio. Se reejecutaron solo los 10 métodos afectados: 10 tests, 190 assertions, `OK`, exit 0. Los 12 métodos restantes ya habían pasado en la primera ejecución. Resultado agregado: los 22 métodos tuvieron resultado verde observado en las ejecuciones integradas; no se atribuyen assertions por archivo porque PHPUnit se lanzó combinado. No se repitieron los tres archivos completos.
- `php -l` en los tres archivos y `git -c core.whitespace=cr-at-eol diff --check`: exit 0.
- Log inicial integrado: `C:\Users\felip\AppData\Local\Temp\picoradar-c20-phpunit-final.txt`, SHA-256 `2EF21DBA693105113BFBAA1172014435B9C28550944B1DC48E8CF427825BA650`.
- Reejecución afectada: `C:\Users\felip\AppData\Local\Temp\picoradar-c20-phpunit-affected-rerun.txt`, SHA-256 `4A27C07FBD1B68EDF5BF03348E199A232DFF73F9A29C7CDFE439B8A466B1CA8C`.

### B/C — Flutter, Dart y Android

- Flutter `3.50.0`, Dart `3.14.0`, Java `21.0.12`, AGP `9.1.1`.
- `dart format --output=none --set-exit-if-changed` sobre los dos ficheros C modificados: exit 0, 0 cambios. `git diff --check` con `cr-at-eol`: exit 0.
- `flutter analyze --no-pub` se ejecutó una vez. El log contiene **0 errors, 1 warning y 155 infos** (156 issues de severidad mixta); el exit code no quedó capturado por el límite de sesión, así que no se declara PASS de proceso. Log SHA-256 `7BCA28AD098A727CE19EED3B73790568052A9676A71BF1C3F6E6AB841F219219`.
- `flutter pub get --enforce-lockfile` se intentó una vez porque faltaba `.dart_tool`; el comando creó configuración de paquetes pero salió 1 porque Windows no tiene soporte de symlinks habilitado. No se activó Developer Mode ni se repitió. `pubspec.lock` conserva SHA-256 `9D68CE85ABA7E40C4E484D34B0F449E3BFFB98BE3D9F0118B7775ECC1E5F4834`.
- Batch Flutter permitido (`service_provider_catalog_test.dart`, `restriction_dataset_test.dart`, `settings_screen_test.dart`, `manual_dataset_refresh_test.dart`): 76 PASS y 3 FAIL iniciales. El catálogo y el refresh manual no tuvieron fallos; el test de refresh emitió un warning de tap fuera de superficie. Los 3 fallos fueron: una expectativa de fallback OTA con dataset instalado, expectativa de email con fake de cuenta `unknown`, y una expectativa `restricted` con cobertura `partial`.
- Se repitieron solo los tres métodos que fallaron: los dos Settings pasaron tras corregir fixtures; la aserción de restricciones volvió a fallar con `expected restricted, actual unknown`. La fuente explica `unknown`: la evaluación del día contiene intervalos sin regla con cobertura declarada parcial, y el motor conserva el cierre seguro. No existe evidencia para cambiar el motor ni para afirmar que esta expectativa de estado diario sea válida. `C_FLUTTER_TESTS=PARTIAL_FAIL`.
- Pruebas C18 añadidas por la instrucción, todas PASS, una vez cada una: Inicio escala 1.5; Inicio escala 2.0; mantenimiento con texto grande. Logs `C:\Users\felip\AppData\Local\Temp\picoradar-c20-home-scale-15.txt`, `...home-scale-20.txt` y `...maintenance-large-text.txt`.
- Build debug, ejecutado solo por el integrador y sin concurrencia, dos intentos permitidos:
  1. `flutter build apk --debug --no-pub`: exit 1 en `:android_file_picker:compileDebugKotlin`; Kotlin informa que archivo del plugin bajo `D:\codex\_tool-cache\flutter-d5-20261022\pub-cache` y Android project bajo `C:\Users\...` tienen raíces diferentes. Log SHA-256 `C8A69F1E987F0811A33D02F9E4D2361DA5F3F48CBC7319D65C14CD3EBD679F44`.
  2. Único reintento con `ORG_GRADLE_PROJECT_kotlin.incremental=false` solo en proceso: exit 1 en la misma tarea, con `Storage for [...] is already registered` en caches Kotlin. Log SHA-256 `E4A7D4D20B6D30D074B175D7BA6B2C7C5F059B926A5268C6254B3E59CEB3E3BC`.
- `mobile/build/app/outputs/flutter-apk/app-debug.apk` no existe: `APK_NOT_BUILT`, sin tamaño/hash/package/version. No hubo tercer build, ADB, teléfono ni instalación.

## Preservación, privacidad y estado remoto

- Los hashes WIP del checkout C19 protegido permanecieron: `RestrictionRouteIntegrationTest.php` `70F0BE0713E2CAB83445DDDEEE70690D945FE520BBB1B2D17B253BBF15549F5D`; `RestrictionRuleVersionServiceTest.php` `4D0AD4BA60A699E88DDC15C7E500CCFC4C0B2C410FF103D4111595FE5294C2CE`.
- PHPUnit dejó cinco JSON sintéticos ignorados en `D:\codex\PicoRadar-C17-V2\server\storage\framework\testing\disks`; no se borraron. SHA-256 por ruta:
  - `local/dataset-drafts/restrictions/r1-22c3971e92fd.json` — `8774F23EE81B4568136A305C08BFFE5B07CDC999CA22EAEAFAD1D05A50638FF8`.
  - `local/dataset-drafts/restrictions/r2-6c2724e35315.json` — `ACF1DE656C005ADFE60DBF0F6144A7C30C411AA2FB42F81AE5E3ECCEF8FF825A`.
  - `public/datasets/restrictions/r1-22c3971e92fd/restrictions-r1-22c3971e92fd.json` — `8774F23EE81B4568136A305C08BFFE5B07CDC999CA22EAEAFAD1D05A50638FF8`.
  - `public/datasets/restrictions/r2-6c2724e35315/restrictions-r2-6c2724e35315.json` — `ACF1DE656C005ADFE60DBF0F6144A7C30C411AA2FB42F81AE5E3ECCEF8FF825A`.
  - `public/manifest/v1/manifest.json` — `1371C53A901BFC2711238F83E4147B97C50227B9A2CABF8BE060B37A6EABF2C0`.
- C20 no crea cobertura legal certificada. `LEGAL=NO_GO`, `MAIN_BRIDGE=HOLD`, `RELEASE=NO_GO`; ads/pagos continúan OFF.
- Antes del push se vuelve a comparar el ref remoto autorizado con la base `bd2c005...`; cualquier divergencia detiene el push. Después se verifica `git ls-remote`. No se toca `main`, PR #88, Actions, Hostinger ni otros refs. El SHA remoto final queda en el paquete C20.

## Bloqueos y próximos pasos

1. **APK debug:** causa inmediata es la raíz de rutas del plugin Kotlin y el registro duplicado de caché; falta investigar solución aislada al checkout sin actualizar dependencias ni limpiar cachés ajenos. Luego un único build autorizado en nuevo alcance.
2. **QA Flutter:** corregir/confirmar el contrato de la expectativa diaria con cobertura parcial mediante prueba de comportamiento aprobada; mantener UNKNOWN hasta que exista evidencia suficiente. No tocar motor con la evidencia actual.
3. **Certificación del producto:** revisión humana/jurídica de fuentes y cobertura por municipio, seguida de QA física Android; C20 no autoriza ni ejecuta esas puertas.

## Plantilla de cierre

- QA manual: no ejecutada; C20 fue pruebas focales automatizadas.
- QA física: `Blocked / Not authorized by C20`; ningún dispositivo conectado ni ADB consultado.
- Datos/migración: sin cambios; PHP usó SQLite efímera en memoria.
- Seguridad/privacidad: placas, GPS, datos reales, credenciales y bases reales no se utilizaron ni se registraron.
- Dependencias: ninguna añadida o actualizada; lock preservado.
- Riesgo/deuda: build aún no generado; un test Flutter permanece rojo por discrepancia fixture/contrato parcial; certificación legal no otorgada.
- Siguiente lote desbloqueado: resolver el entorno de compilación Kotlin con caché aislada y cerrar la semántica de esa expectativa, sin repetir suites verdes históricas.
