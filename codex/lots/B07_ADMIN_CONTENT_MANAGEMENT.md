# B07 - Administracion de contenidos de extremo a extremo

## Objetivo

Permitir que un operador autorizado gestione reglas de pico y placa por ciudad,
importe XLSX/CSV/JSON, revise y publique alcances selectivos, revierta una ciudad
sin afectar las demas y administre patrocinadores/campanas. Las publicaciones se
validan contra los consumidores reales y se prueban desde el ZIP instalable en un
entorno local aislado.

## Base y conservacion

- Base: `c9dbaf156eaed58a410c82c9363db5abb042f3f1`.
- B06 aceptado permanece inmutable como referencia.
- C11 y su geometria visual permanecen protegidos.
- No Hostinger, telefono, push, merge, gasto ni activacion comercial.

## Scope IN

- Borradores versionados de restricciones por jurisdiccion y tipo de vehiculo.
- Importacion segura desde navegador de JSON, CSV y XLSX.
- Revision, publicacion selectiva/multiple, historial y restauracion por ciudad.
- Patrocinadores y campanas propias con catalogo publico versionado.
- Panel en espanol, roles, operadores, cambio de contrasena y auditoria.
- Publicacion HTTP local y consumo por las capas reales de PicoRadar.
- Instalacion limpia, MariaDB sintetica, navegador y paquete final fuera del repo.

## Scope OUT

- Datos productivos o reglas inventadas presentadas como reales.
- Hostinger, despliegue, publicidad comercial activa, cuentas moviles, Lite/Pro,
  pagos, WhatsApp, tracking o cambios en el telefono.
- Redisenar Inicio/C11 o recuperar el banner inferior retirado.

## Criterios de cierre

- Una ciudad puede cambiar sin alterar otra y su consumidor instala los bytes
  publicados; la publicacion multiple conserva el alcance confirmado.
- JSON/CSV/XLSX pasan por previsualizacion y validacion antes de crear borradores;
  reimportar el mismo archivo es idempotente.
- La restauracion de una ciudad crea una publicacion nueva y no retrocede cambios
  ajenos.
- Campanas pausadas, vencidas o fuera de alcance no se sirven; el fallo comercial
  conserva el fallback C11 y no bloquea Pico.
- El ZIP final se instala y verifica desde una carpeta externa con MariaDB y
  navegador, manteniendo las regresiones B06.

## Stop conditions

- Riesgo de perdida de datos existentes o ruptura del contrato movil.
- Necesidad de credenciales, datos productivos o acceso al hosting.
- Cambio visual protegido de C11 no imprescindible para consumir datos.
