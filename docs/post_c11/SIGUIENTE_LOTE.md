# Siguiente lote propuesto

## Staging privado Laravel

Dependencia: conocer el nombre exacto del plan Hostinger existente y confirmar,
sin compartir credenciales, si ofrece SSH, cron, PHP/Composer, MariaDB,
almacenamiento escribible y HTTPS.

Alcance futuro sujeto a autorizacion: provision privada, HTTPS, DB aislada,
despliegue de Laravel, health, fixtures sinteticos, correo capturado,
backup/restauracion y rollback. Cuentas, PII, anuncios, Pro, pagos, WhatsApp y
partner leads permanecen apagados.

Aceptacion: preflight Laravel con evidencia del host en `PASS`; secretos solo en
el host; pruebas Laravel verdes; health restringido; restauracion demostrada en
DB desechable; logs sanitizados; release identificado por
commit/manifiesto/hash; ningun dato del telefono.

## OSRM separado

OSRM no forma parte automatica del staging Laravel. Solo se evaluara despues,
con evidencia independiente de Docker/runtime, grafo, al menos 8 GB de RAM,
20 GB libres y proceso persistente supervisado. Un plan apto para Laravel no se
considera apto para OSRM por inferencia.

Este lote no se ejecuta automaticamente.
