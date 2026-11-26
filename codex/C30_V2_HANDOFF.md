# C30 V2 — cierre local, respaldo y HTTPS de laboratorio

Fecha: 2026-11-26 (America/Bogota). Estado: **PARTIAL, sin release**.

## Resultado

- **A — `LOCAL_TOOL=PASS`, `INSTANCE_SCOPE=PASS`, `DB_PERSISTENT=PASS`, `START_STOP=PASS`, `HTTP_PANEL=PASS`, `RESTART_STATE=PASS`, `ALIAS_SAFE=PASS`, `A_HANDOFF=READY_STOPPED`.** PHP 8.5.8 cargó SQLite 3.53.2 por proceso. Laravel resolvió PDO y sus rutas de DB, sesiones, cachés, vistas, logs y discos bajo `runtime/instance-a`. El panel autenticado y filas sintéticas Free/Pro/Banned se vieron antes y después de Stop/Start; catálogo OFF 404. Privado y traversal dieron 403 sin sentinelas; dotfile 404. La base tiene 26 migraciones y los datos/identidad sobrevivieron el reinicio sin nueva migración o seed.
- **B — `BACKUP_TOOL=PASS`, `RESTORE_TOOL=PASS`, `CORRUPT_REJECT=PASS`, `OVERWRITE_REJECT=PASS`, `TRAVERSAL_REJECT=PASS`, `ACTIVE_REJECT=PASS`, `RESTORED_DB=PASS`, `RESTORED_PANEL=PASS`.** Backup mediante SQLite read-only snapshot: 17.364 bytes, 3 archivos de datos, SHA-256 `C765EB04117DF3991EDB89C5DF17A9C007874889AC6D2DC7FAA3C1F0A13E95A5`. Restauración independiente ID `da5286c2-0a14-4464-b5ca-2c8024e19d8f`; las filas canónicas, 26 migraciones y hashes privado/público coinciden; login, admin y usuarios responden 200. La prueba final integrada tiene 8/8 PASS y limpia su propio fixture temporal.
- **C — `C29_BYTES=PASS`, `TLS_TRUST=PASS`, `TLS_UNTRUSTED_REJECT=PASS`, `HTTPS_ENDPOINTS=PASS`, `DART_HTTPS_SYNC=PASS`, `HTTPS_SCOPE=HTTPS_QA_STATIC_PASS`.** El manifest C29 (424 bytes, SHA-256 `F244CEB0CEE6C56AB3D1F7FFB72EA78190BE14AA0D38804052A107EF1F0676FA`) y payload (936 bytes, SHA-256 `AF1955879EDC63725FB8C8332CDDD627C6D8B5116A15BD0FEEFB1ECC358CFD7E`) llegaron sin cambios por TLS y DatasetSyncService. Resultado `r2-7f969a248a68`, revisión 2, OFF/partial y UNKNOWN. La conexión sin CA tuvo error de validación de certificado, cero GET y cero import; el servidor siguió sano.

## Integridad y alcance

- Base de la rama objetivo en el inicio: `efc2f7c7b4633efe7d323fb00bfcbbc6c360688c`; `main`: `e9ef37511df3110ffb0fc006ef06be781df432ac`. Al inicio había solo `mobile/qa/c30/` y `scripts/local/` sin seguimiento; el checkout C29/canónico se mantuvo intacto.
- No se tocaron reglas, dataset, motor productivo, API, dependencias, lockfiles, certificados globales, APK, ADB, teléfono, MariaDB, producción o Hostinger. APK `C28_REUSED_NO_BUILD`; APK OTA, Laravel-live OTA y HTTPS de producción `NOT_RUN`.
- Backup/restore exige relación Git de ancestro y árbol `server/` exactamente igual y limpio; mantiene el HEAD original en el manifiesto. Un destino de restauración es nuevo y directo bajo `runtime`, y puede llevar sufijo para recuperación posterior.
- `DB_TARGET_FINAL=NOT_CERTIFIED`; la prueba es exclusivamente SQLite sintético local. `MAIN_BRIDGE=HOLD`, `LEGAL=NO_GO`, `RELEASE=NO_GO`.

## Incidentes y límites reales

- Un typo inicial en el helper PHP impidió el primer `Init` antes de migraciones. La DB quedó con cero tablas según la consulta PDO de solo lectura; se corrigió la ruta y se reanudó el mismo root de forma segura. Los logs preliminares se conservan fuera del retorno.
- La primera aserción HTTP esperaba 404 para privado/traversal. La ruta se negó correctamente con 403 sin bytes privados; el smoke repetido con criterio de no exposición pasó. El log inicial se conserva como evidencia no autoritativa.
- Primer TLS falló por separador LF ausente entre bloques PEM; se usó una sola cadena corregida y el intento condicionado pasó con validación normal. El test mostró una advertencia diagnóstica de Drift al crear la segunda DB en memoria independiente; la negativa siguió vacía y pasó.
- El entorno bloqueó el borrado de cuatro archivos TLS propios en la carpeta privada. Se detuvo ese intento sin cambiar el método; no están en repo/ZIP. Nombres: `c30-loopback-ca.pem`, `c30-loopback-chain.pem`, `c30-loopback-chain-fixed.pem`, `c30-loopback-leaf.key.pem`.

## Evidencia

Comandos, rutas y recuperación están en [PicoRadar_LOCAL_QA.md](../docs/operations/PicoRadar_LOCAL_QA.md). El estado de pruebas, hashes y Git remoto se entrega en el ZIP único C30 V2. Logs originales completos permanecen en `D:\codex\_REPORTES\PicoRadar\C30-V2-20261126\logs`; se empaqueta únicamente evidencia focal saneada.
