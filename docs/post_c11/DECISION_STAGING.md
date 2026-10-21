# Decision de staging

Fecha de precios: 2026-09-19. No se contrato ni desplego ningun servicio.

## Referencias, no decision automatica

Antes de elegir un plan se inspeccionara el plan que el propietario ya posee.
**Hostinger KVM 2** queda solo como referencia comparativa para un staging
privado que eventualmente reuniera Laravel, MariaDB y OSRM. Publica 2 vCPU,
8 GB RAM, 100 GB NVMe y 8 TB de transferencia por COP 28.900/mes
promocionales; renovacion publicada de COP 50.900/mes por dos anos. Incluye
backups semanales. Fuente:
https://www.hostinger.com/co/vps-servidor-web

El primer ensayo no necesita correo pagado, proveedor de peajes ni mapas de pago:
correo en captura local, tarifas propias y OSRM apagado. El precio promocional
supone prepago/condiciones del proveedor; impuestos, dominio adicional y correo
productivo no estan cotizados para la cuenta del propietario.

La metadata de la fuente OSRM esta versionada, pero el grafo pesado no esta en
los worktrees comprobados. No se cuenta como activo disponible ni se reconstruye
en esta preparacion.

## Alternativa

Hetzner CX33 europeo: 4 vCPU, 8 GB RAM y 80 GB NVMe. La tarifa publicada para
nuevas ordenes desde 2026-06-15 es EUR 8,49/mes sin IVA ni IPv4. Backups cuestan
20% adicional y el trafico incluido en UE es 20 TB. La disponibilidad mostrada
puede variar y debe confirmarse antes de contratar. Fuentes:
https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/
https://docs.hetzner.com/cloud/billing/faq/
https://docs.hetzner.com/robot/general/traffic/

## Alcance aprobado para la primera prueba

Laravel y panel con fixtures sinteticos, DB aislada, HTTPS, correo capturado,
health, migracion/rollback y backup/restauracion ensayados. Sin cuentas moviles,
PII, partner leads, anuncios, pagos, WhatsApp, DNS productivo ni OSRM publico.

## Unica decision pendiente

Confirmar el **nombre exacto del plan Hostinger que ya posee** y si ofrece
VPS/root, SSH, cron, Docker/procesos persistentes, PHP/Composer, MariaDB, dominio
y HTTPS. Con ese inventario se decide si sirve para Laravel, para OSRM, para
ambos o para ninguno. No se solicitan contrasenas y la falta de esta respuesta
no bloquea el cierre de coherencia local.
