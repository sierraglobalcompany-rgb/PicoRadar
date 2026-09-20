# Staging privado: preparacion sin despliegue

## Preflight

Ejecutar `scripts/server_preflight.ps1 -AsJson`. El modo predeterminado solo
lee capacidades: no instala paquetes, no crea `.env`, no migra, no abre puertos
y no inicia Laravel, DB u OSRM. `-RequireReady` falla si falta un requisito.

Para pruebas deterministas se admite `-FixturePath` con capacidades sinteticas.
La prueba `scripts/tests/test_server_preflight.ps1` cubre host listo, host
incompleto, fallo cerrado y ausencia de archivos nuevos.

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

## Logs y rollback

- Sanitizar placa, documento, GPS exacto y textos privados.
- Registrar release, commit, manifiesto y hashes publicados.
- El rollback cambia al release anterior y restaura la DB solo desde un backup
  ensayado; no reutiliza una DB de produccion.
- Se conserva la procedencia OSRM y su script. El grafo pesado no esta presente
  en los worktrees comprobados; no se descarga ni reconstruye por rutina. Un
  lote aprobado debe decidir su almacenamiento, hash y restauracion.
