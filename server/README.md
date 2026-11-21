# PicoRadar: control plane Laravel

Preparación y reconstrucción: [README raíz](../README.md). Estado único: [CURRENT](../docs/CURRENT.md). Operación: [guía B07](../docs/operations/PicoRadar_GUIA_PANEL_ADMIN_CONTENIDOS.md).

Laravel 13 administra contenido y publica datasets versionados. La app evalúa reglas/cámaras localmente; no envía GPS continuo ni documentos privados por defecto.

Instalar desde los lockfiles. Tests y migraciones de comprobación usan SQLite efímero o MariaDB sintética aislada. B06 es un instalador de primera instalación, no un actualizador ni una herramienta de restauración.

Builders recuperables desde Git; `.env`, tokens, bases, logs y paquetes privados fuera del repositorio. Este rescate no despliega ni consulta Hostinger.
