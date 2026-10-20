# PicoRadar: Pico y Placa

App Android-first en Flutter y control plane Laravel. Funciona sin cuenta. Inicio · Garaje · **Apps** · Viaje · Conducir.

## Retomar desde otro chat o equipo

1. Clonar `https://github.com/sierraglobalcompany-rgb/PicoRadar.git` con acceso autorizado y seleccionar **`recovery/20261019-modern`**. El `main` histórico no representa el estado moderno.
2. Leer `AGENTS.md`, `docs/CURRENT.md`, Baseline y Arquitectura en `docs/baseline/`, después el contrato del lote. UI: `docs/DESIGN_CONTRACT.md`; procedimientos: `docs/SOP.md`.
3. Consultar `PicoRadar_RECOVERY_HANDOFF.md` para evidencias y NEXT, y `PicoRadar_FORENSE_10_PASADAS.md` para procedencia. Confirmar HEAD antes de trabajar.
4. Reconstruir con los lockfiles. Secretos, claves de firma y datos privados se aprovisionan aparte; no son necesarios para las suites sintéticas.

Checkout canónico de esta máquina: `D:/Dev/PicoRadar`, directamente en exFAT. Reconstrucción independiente: `D:/Verification/PicoRadar`. Los originales de C: permanecen preservados.

## Requisitos

- Flutter **3.47.1**, Dart **3.13.1**, Java **17**, Android compile API **37**, target **36**, min **24** y componentes definidos por Gradle.
- PHP **8.3–8.5**, Composer 2 y extensiones del lockfile. Pruebas SQLite: `pdo_sqlite`, `sqlite3`; XLSX/paquete: `zip`, `SimpleXML`, `libxml`; imágenes: `gd`.
- Node 22 o 24 y npm. Conservar los tres lockfiles; instalar dependencias sin actualizarlas.
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
Set-Location mobile
flutter --version
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev
```

APK: `mobile/build/app/outputs/flutter-apk/app-dev-debug.apk`. No instalar ni conectar el teléfono durante el rescate. QA física pendiente no se aprueba mediante estas suites.

## Reconstruir servidor

```powershell
Set-Location server
composer install --no-interaction --prefer-dist
npm ci
npm run build
php vendor/bin/pint --test
```

Para tests, configurar `APP_ENV=testing`, una `APP_KEY` aleatoria solo para el proceso, `DB_CONNECTION=sqlite` y `DB_DATABASE=:memory:`. Ejecutar:

```powershell
php -d extension=pdo_sqlite -d extension=sqlite3 vendor/bin/phpunit --colors=never
```

Si SQLite ya está habilitado, omitir los dos argumentos `-d`. Para comprobar migraciones, crear un archivo SQLite **nuevo** dentro del clon de verificación, asignarlo a `DB_DATABASE` y ejecutar `php artisan migrate --env=testing --no-interaction` con esas extensiones. No usar una base existente del propietario.

## Panel y fuentes

B06 y B07 están en la fuente moderna recuperada. Operación: `docs/operations/PicoRadar_GUIA_PANEL_ADMIN_CONTENIDOS.md`. Los builders/verificadores existentes en `scripts/` generan instalables locales; los paquetes privados permanecen fuera de Git. No desplegar en Hostinger.

Fuentes, contratos y fixtures: `data/`, `contracts/`, `mobile/assets/`. El grafo pesado OSRM es externo y opcional; `data/sources/osrm/source.json` fija su URL, imagen, hash y atribución. Su ausencia no se suple inventando rutas ni acredita operación real del proveedor.

Recuperar no activa ads, pagos, cuentas, Lite/Pro, WhatsApp ni nube. Sin configuración remota, el catálogo de campañas conserva el fallback C11.
