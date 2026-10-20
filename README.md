# PicoRadar: Pico y Placa

App Android-first en Flutter y control plane Laravel. Funciona sin cuenta. Inicio · Garaje · **Apps** · Viaje · Conducir.

## Retomar desde otro chat o equipo

1. Clonar `https://github.com/sierraglobalcompany-rgb/PicoRadar.git` con acceso autorizado y seleccionar **`recovery/20261019-modern`**. El `main` histórico no representa el estado moderno.
2. Leer `AGENTS.md`, `docs/CURRENT.md`, Baseline y Arquitectura en `docs/baseline/`, después el contrato del lote. UI: `docs/DESIGN_CONTRACT.md`; procedimientos: `docs/SOP.md`.
3. Consultar `PicoRadar_RECOVERY_HANDOFF.md` para evidencias y NEXT, y `PicoRadar_FORENSE_10_PASADAS.md` para procedencia. Confirmar HEAD antes de trabajar.
4. Reconstruir con los lockfiles. Secretos, claves de firma y datos privados se aprovisionan aparte; no son necesarios para las suites sintéticas.

Checkout canónico de esta máquina: `D:/Dev/PicoRadar`, directamente en exFAT. Reconstrucción independiente: `D:/Verification/PicoRadar`. Los originales de C: permanecen preservados.

En un equipo o destino nuevo, clonar directamente la rama moderna, sin pasar por main. No sobrescribir un checkout existente:

```powershell
git -c checkout.workers=8 -c core.autocrlf=false -c core.longpaths=true clone --branch recovery/20261019-modern --single-branch https://github.com/sierraglobalcompany-rgb/PicoRadar.git D:/Dev/PicoRadar
Set-Location D:/Dev/PicoRadar
git rev-parse HEAD
```

## Requisitos

- Flutter **3.47.1**, Dart **3.13.1**, Java **17**, Android compile API **37**, target **36**, min **24** y componentes definidos por Gradle.
- PHP **8.3–8.5**, Composer 2 y extensiones del lockfile. Pruebas SQLite: `pdo_sqlite`, `sqlite3`; XLSX/paquete: `zip`, `SimpleXML`, `libxml`; imágenes: `gd`.
- Node 22 o 24 y npm. Conservar los tres lockfiles; instalar dependencias sin actualizarlas.
- Git; GitHub CLI `gh` con acceso autorizado al repositorio privado para recuperar el insumo OSRM opcional.
- SDK/JDK y cachés pueden estar fuera del checkout. No depender de archivos fuente de otro worktree en C:.

## Windows / exFAT

Herramientas en PATH y `JAVA_HOME` apuntando a Java 17. Desde la raíz del checkout, aplicar confianza solo a esa ruta en la terminal actual:

```powershell
$repo = (Get-Location).Path.Replace('\','/')
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = $repo
git config core.autocrlf false
git config core.longpaths true
git config core.filemode false
git config checkout.workers 8
New-Item -ItemType Directory -Path D:/PicoRadar_Rescue/scratch -Force | Out-Null
$env:TEMP = 'D:/PicoRadar_Rescue/scratch'
$env:TMP = $env:TEMP
```

No usar `safe.directory=*`. En otro equipo elegir su destino y temporal disponibles.

## Reconstruir móvil

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location mobile
flutter --version
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev
```

Codegen: según SOP-07, ejecutar `dart run build_runner build --delete-conflicting-outputs` solo si cambiaron sus entradas o faltan los archivos generados. Esta recuperación conserva entradas y generados rastreados: `CODEGEN_NOT_REQUIRED`.

APK: `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`. No instalar ni conectar el teléfono durante el rescate. QA física pendiente no se aprueba mediante estas suites. La configuración release aún usa firma debug: deuda histórica, no autorización de publicación.

En Windows con proyecto en D: y caché pública Kotlin/Flutter en C:, el build verificado necesitó desactivar la compilación incremental y ejecutar Kotlin en el proceso. Usar estas opciones de proceso, sin cambiar la configuración global ni mover el proyecto:

```powershell
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub --no-android-gradle-daemon --android-project-arg=kotlin.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process
Push-Location android
./gradlew.bat :app:testDevDebugUnitTest -Pkotlin.incremental=false -Pkotlin.compiler.execution.strategy=in-process --no-daemon --console=plain
Pop-Location
```

## Reconstruir servidor

```powershell
Set-Location (git rev-parse --show-toplevel)
Set-Location server
composer install --no-interaction --prefer-dist
npm ci
npm run build
php vendor/bin/pint --test
```

Para tests, usar configuración sintética solo en el proceso y crear `.env` desde el ejemplo únicamente si no existe:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
$env:APP_ENV = 'testing'
$env:APP_KEY = php -r 'echo "base64:".base64_encode(random_bytes(32));'
$env:DB_CONNECTION = 'sqlite'
$env:DB_DATABASE = ':memory:'
php -d extension=pdo_sqlite -d extension=sqlite3 vendor/bin/phpunit --colors=never
```

Si SQLite ya está habilitado, omitir los dos argumentos `-d`. Para comprobar migraciones, crear un archivo SQLite **nuevo** dentro del clon de verificación, asignarlo a `DB_DATABASE` y ejecutar `php artisan migrate --env=testing --no-interaction` con esas extensiones. No usar una base existente del propietario.

## Panel y fuentes

B06 y B07 están en la fuente moderna recuperada. Operación: `docs/operations/PicoRadar_GUIA_PANEL_ADMIN_CONTENIDOS.md`. Los builders/verificadores existentes en `scripts/` generan instalables locales; los paquetes privados permanecen fuera de Git. No desplegar en Hostinger.

Fuentes, contratos y fixtures: `data/`, `contracts/`, `mobile/assets/`. El grafo pesado OSRM es externo y opcional; `data/sources/osrm/source.json` conserva URL, imagen, hash y atribución históricos. La URL del PBF fechado respondió **404** al HEAD del 2026-10-20. Se recuperó el PBF original de hash coincidente y se conservó como asset del borrador GitHub **`recovery-osrm-input-20260907`** (329.060.219 bytes), con atribución OpenStreetMap/Geofabrik y [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). No sustituirlo por datos actuales y afirmar identidad.

Para recuperar ese insumo desde la raíz de un clon nuevo, cuando se necesite regenerar el piloto:

```powershell
gh release download recovery-osrm-input-20260907 --repo sierraglobalcompany-rgb/PicoRadar --pattern colombia-latest.osm.pbf --dir data/local/osrm
$actual = (Get-FileHash data/local/osrm/colombia-latest.osm.pbf -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne 'a71df1f2064d0536c053aa4bcd872e6aa0a4fa3e7b35964dd03de59793370a70') { throw 'El insumo OSRM no coincide' }
```

El nombre `latest` es el nombre local histórico; el borrador y hash fijan la instantánea del 2026-09-07. Usar el digest de imagen OSRM registrado en `source.json`. El grafo no es entrada del build móvil con fixtures; recuperarlo no inicia el proveedor ni acredita operación real de Viaje.

Recuperar no activa ads, pagos, cuentas, Lite/Pro, WhatsApp ni nube. Sin configuración remota, el catálogo de campañas conserva el fallback C11.
