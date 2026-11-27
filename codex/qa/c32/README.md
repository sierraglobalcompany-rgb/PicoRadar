# PicoRadar C32 V2 — QA local TLS y MariaDB

Utilidades para pruebas locales y sintéticas. No configuran una base productiva, no publican datos, no modifican el motor móvil ni instalan certificados en almacenes globales.

## TLS loopback

`new-loopback-tls.ps1` crea una CA efímera y un certificado de servidor para `127.0.0.1`. Requiere OpenSSL local y un `PrivateRoot` existente en NTFS, sin reparse points y con ACL privada. Genera cada ejecución en un directorio nuevo. El cliente debe confiar únicamente en `ca.pem` mediante un `SecurityContext` explícito; el relay usa `chain.pem` y `leaf.key.pem`. No uses `badCertificateCallback`, `-k`, trust global ni claves de CA como claves del servidor.

```powershell
$result = .\codex\qa\c32\new-loopback-tls.ps1 -PrivateRoot $privateRoot | ConvertFrom-Json
```

Las claves, certificados y configuraciones permanecen en ese root privado, fuera de Git y del paquete de retorno.

## MariaDB QA

`mariadb-qa.ps1` requiere MariaDB portable 11.8.8 y PHP con `pdo_mysql`. `Start` crea una instancia nueva, con datadir exclusivo y bind `127.0.0.1`; no instala servicios Windows ni lee `my.ini` global. `Migrate` valida el destino y permite una sola migración protegida. `Status` comprueba proceso, PID, datadir, puerto, DB y usuario. `Stop` solicita shutdown normal y confirma puerto cerrado. `Resume` solo reabre la instancia ya creada: exige marcador, datadir y puerto exactos y no ejecuta migraciones, bootstrap ni seed.

```powershell
$qa = '.\codex\qa\c32\mariadb-qa.ps1'
& $qa -Action Start  -PrivateRoot $privateRoot -MariaDbRoot $mariaDbRoot
& $qa -Action Status -PrivateRoot $privateRoot -MariaDbRoot $mariaDbRoot
& $qa -Action Migrate -PrivateRoot $privateRoot -MariaDbRoot $mariaDbRoot -PhpPath $phpPath
# Tras cargar y reconciliar el catálogo, preparar schema2 OFF solo en la DB QA nueva.
& $qa -Action Stop -PrivateRoot $privateRoot -MariaDbRoot $mariaDbRoot
# En una sesión posterior, reabrir la misma DB sin migrar ni sembrar:
& $qa -Action Resume -PrivateRoot $privateRoot -MariaDbRoot $mariaDbRoot
& $qa -Action Status -PrivateRoot $privateRoot -MariaDbRoot $mariaDbRoot
```

Las credenciales están en archivos ACL privados que administra el helper. No las imprimas, pases por argumentos visibles, copies al repositorio ni incluyas en evidencias. Laravel debe ejecutarse con variables de proceso aisladas, `DB_URL`/`DATABASE_URL` vacías, flags comerciales y correo OFF, y storage/cache propios. No uses `migrate:fresh`, `db:wipe`, `db:seed` ni una segunda migración.

## Catálogo y preparación editorial

Usa el comando de producto existente `php artisan picoradar:geography:bootstrap --dry-run` y, solo si valida las fuentes y destino vacío, una vez `php artisan picoradar:geography:bootstrap`. Reconciliar mediante consultas de solo lectura. `prepare-schema2.php` se ejecuta una sola vez después de reconciliar, en el mismo proceso Laravel aislado; crea o valida únicamente `restrictions` / `Restricciones` / schema 2 / OFF / sin versión ni publicación. No crea reglas. Los conteos geográficos describen catálogo administrativo, no cobertura legal ni permiso para circular.

El árbol del datadir y los logs privados deben conservarse fuera de Git/ZIP. Al cerrar, detener por identidad con el helper.