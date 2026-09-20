# Staging privado en Hostinger: instalacion manual guiada

## Alcance aprobado

El lote B06 prepara un paquete autocontenido para
`https://picoradar.bodegadigitalmedellin.com`. No despliega, no cambia Flutter,
no modifica C11 y no activa registro movil, Lite, anuncios, Pro, pagos,
WhatsApp, solicitudes publicas de aliados ni OSRM.

El paquete se construye localmente con Composer y los recursos web compilados.
Hostinger no necesita SSH, Composer, Node ni un proceso persistente.

## Distribucion en el hosting

```text
/home/u390570745/domains/bodegadigitalmedellin.com/
|-- picoradar_app/
|   `-- current/                  # Laravel, vendor, .env y storage privados
`-- public_html/
    `-- picoradar/                # index, assets, setup y enlaces publicos
```

El ZIP solo contiene esas dos areas y sus archivos de instalacion. El `.env`,
los logs, las caches y Laravel permanecen fuera de `public_html`.

## Preparacion obligatoria

1. Activar PHP 8.5 para el subdominio y confirmar HTTPS valido.
2. Proteger `public_html/picoradar` con contrasena desde hPanel.
3. Crear una base MySQL/MariaDB exclusiva y vacia.
4. Subir el ZIP a la raiz del dominio y extraerlo alli.
5. Conservar `PicoRadar-INSTALL_TOKEN.txt` solo en el computador del propietario.
6. Abrir `/_setup/`, introducir el token y seguir las etapas del asistente.

El instalador se detiene antes de migrar si falla integridad, HTTPS, permisos,
extensiones, enlaces simbolicos, conexion o vaciedad de la base. Nunca solicita
permisos `777`.

## Flujo del asistente

1. Valida token, sesion segura, CSRF y limite de intentos.
2. Diagnostica PHP 8.3-8.5, extensiones, rutas, escritura e integridad.
3. Comprueba las credenciales y que la base este vacia.
4. Crea `.env` y `APP_KEY` fuera del webroot con staging y funciones publicas
   apagadas.
5. Ejecuta migraciones sin datos personales ni datasets productivos.
6. Crea un unico `super_admin` con contrasena minima de 12 caracteres.
7. Crea y verifica los enlaces `storage` y `v1`, las caches, Health y Login.
8. Escribe `installed.lock`; desde entonces `/_setup/` responde 404.

Al finalizar se elimina manualmente `public_html/picoradar/_setup` desde File
Manager. Este asistente no se reutiliza para actualizaciones ni restauraciones.

## Cron en hPanel

Crear un cron de tipo PHP cada cinco minutos, en UTC, apuntando a:

```text
/home/u390570745/domains/bodegadigitalmedellin.com/picoradar_app/current/bin/cron.php
```

El ejecutor usa bloqueo de archivo, corre `schedule:run` y una cola acotada. Su
salida publica solo `OK`, `SKIPPED_LOCKED` o un codigo de error sanitizado.

## Preflight y recuperacion

`scripts/server_preflight.ps1 -Profile laravel -DeploymentStrategy prebuilt-package`
evalua el paquete precompilado. Composer es obligatorio en el constructor, no
en Hostinger. OSRM conserva un perfil independiente y permanece apagado.

Si una migracion falla no se eliminan tablas automaticamente: se crea otra base
vacia y se reinicia. Si falla despues de migrar, el estado permite retomar la
creacion del operador o el cierre sin duplicarlo y sin guardar credenciales.

## Evidencia local

El paquete final se verifica por manifiesto y SHA-256 y se instala desde cero
contra MariaDB temporal. La prueba exige migraciones, operador, Login y Health
HTTP reales, enlaces publicos al destino privado, cron y rollback. Esta prueba
local no acredita Hostinger: el diagnostico del host se ejecuta en el asistente
antes de tocar la base.

