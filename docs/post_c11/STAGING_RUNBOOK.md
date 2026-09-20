# Staging privado: preparacion sin despliegue

## Preflight Laravel/panel

Ejecutar `scripts/server_preflight.ps1 -Profile laravel -AsJson`. El modo
predeterminado solo lee capacidades: no instala paquetes, no crea `.env`, no
migra, no abre puertos, no se conecta a la base y no inicia Laravel ni OSRM.
`-RequireReady` falla tanto ante `FAIL` como ante `UNKNOWN`.

El perfil Laravel usa PHP y extensiones derivadas de `composer.json` y
`composer.lock`. La presencia de `pdo_mysql` solo demuestra transporte; la
conectividad de la base es una comprobacion independiente. La estrategia
inicial es `bounded-cron`: requiere cron, procesa lotes acotados y debe usar
prevencion de solapamiento; no requiere un daemon persistente. Tambien se puede
evaluar `sync` o `persistent-worker` de forma explicita.

## Preflight OSRM

Ejecutar `scripts/server_preflight.ps1 -Profile osrm -AsJson`. Este perfil
evalua por separado runtime, grafo, memoria, almacenamiento y proceso
persistente. Un Laravel apto no acredita OSRM, ni un OSRM apto acredita Laravel.
OSRM permanece apagado y sin despliegue en este cierre.

Para pruebas deterministas se admite `-FixturePath` con capacidades sinteticas;
su procedencia queda marcada como fixture y nunca acredita el host objetivo.
`-TargetHostEvidencePath` acepta un inventario recogido con las herramientas
nativas del hosting; Hostinger no necesita PowerShell. Los estados son `PASS`,
`FAIL`, `UNKNOWN` y `NOT_APPLICABLE`.

La prueba `scripts/tests/test_server_preflight.ps1` cubre dependencias ausentes,
host desconocido, fixture no productivo, Laravel sin daemon bajo cron acotado,
OSRM sin recursos, driver sin conectividad y ausencia de escrituras.

## Primera prueba privada

1. Crear un subdominio de staging con HTTPS y acceso restringido.
2. Crear una DB independiente sin datos reales.
3. Copiar `server/.env.staging.example` fuera del repositorio y completar secretos
   solo en el host.
4. Usar `MAIL_MAILER=array` o una bandeja de captura local; no enviar correo real.
5. Instalar dependencias bloqueadas por `composer.lock`, ejecutar pruebas y luego
   migrar exclusivamente la DB de staging.
6. Importar solo fixtures sinteticos y comprobar `/api/v1/health`.
7. Mantener partner inquiries, cuentas moviles, viajes externos y OSRM apagados.
8. Probar backup y restauracion en otra DB aislada antes de admitir PII.

## Recoleccion pendiente del hosting

La siguiente accion autorizada es solicitar o exportar, sin secretos: plan
exacto, tipo de acceso, version PHP, Composer, extensiones, MariaDB, HTTPS,
cron, almacenamiento escribible y posibilidad de procesos persistentes. El
resultado se guarda como JSON fuera de credenciales y se evalua con
`-TargetHostEvidencePath`. Hasta entonces el host es `UNKNOWN`, no `FAIL` y no
`PASS`.

## Logs y rollback

- Sanitizar placa, documento, GPS exacto y textos privados.
- Registrar release, commit, manifiesto y hashes publicados.
- El rollback cambia al release anterior y restaura la DB solo desde un backup
  ensayado; no reutiliza una DB de produccion.
- Se conserva la procedencia OSRM y su script. El grafo pesado no esta presente
  en los worktrees comprobados; no se descarga ni reconstruye por rutina. Un
  lote aprobado debe decidir su almacenamiento, hash y restauracion.
