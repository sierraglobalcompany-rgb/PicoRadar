# Propuesta de modos, no activa

Esta matriz expresa intencion de producto. No agrega registro, gates, anuncios,
pagos ni sincronizacion.

| Capacidad | Lite propuesto | Completo gratuito | Pro propuesto |
|---|---|---|---|
| Pico colectivo por ciudad y fuentes | Disponible | Disponible | Disponible |
| Placa, Garaje, Apps, Viaje y Conducir | Invitacion cerrable; no usa vehiculo personal | Disponible | Igual que Completo |
| Avisos y notificaciones | No pide permiso ni programa | Opt-in | Opt-in |
| Privacidad y soporte | Disponible | Disponible | Disponible |
| Funciones personales de Alertas | No disponibles | Opt-in | Opt-in |
| Cuenta | Solo entrada futura; no esta activa | Disponible cuando se implemente | Disponible cuando se implemente |
| Espacios comerciales aprobados | Permitidos | Permitidos | No se cargan ni dejan hueco |
| Directorios organicos | Segun acceso funcional | Disponibles | Disponibles |
| Solicitud voluntaria para ser aliado | Disponible | Disponible | Disponible |
| Administracion | Solo rol administrador separado | Solo rol administrador separado | Solo rol administrador separado |

## Roles

- `publico`: contenido sin cuenta y sin datos personales.
- `consumidor`: funciones personales locales; una cuenta futura necesita una
  finalidad real y transicion no destructiva.
- `administrador`: panel de servidor separado; pagar Pro nunca concede acceso.

## Requisitos y decisiones

- Requisito del propietario: nombre completo, correo y telefono; sin direccion
  postal.
- Recomendacion pendiente: que telefono sea opcional hasta existir una finalidad
  necesaria y documentada.
- Correo/contrasena es la primera opcion propia a estudiar. Google, Apple y
  WhatsApp no se activan.
- USD 1/mes es referencia, no precio aprobado.
- Pro futuro excluye tambien el carrusel C11 y otras superficies patrocinadas
  sin cargarlas ni dejar un espacio vacio. No elimina directorios organicos ni
  la solicitud voluntaria para ser aliado.
- Los endpoints publicos o autenticados describen permisos del servicio, no
  beneficios de un modo movil.
- Una prueba HTTP local de `/api/v1/health` demuestra el contrato local, no la
  disponibilidad de un servicio productivo.
- Cerrar sesion, eliminar cuenta, cancelar Pro y borrar datos locales son actos
  distintos y deben conservar datos de forma explicita y predecible.
