# PicoRadar: guía del panel de contenidos

Esta guía corresponde al lote B07. El panel se instala con el asistente B06 y permite administrar contenido sin editar JSON ni ejecutar comandos en la operación cotidiana.

## 1. Acceso y roles

1. Abre la dirección privada de PicoRadar e inicia sesión.
2. Mantén activa la protección por contraseña del staging.
3. Usa `super_admin` o `admin` para publicar reglas y campañas.
4. `reviewer` puede revisar contenido, pero no publicarlo.
5. `commercial` administra patrocinadores y borradores de campaña, pero no publica reglas de circulación.

Todas las acciones relevantes quedan registradas en Auditoría. Guardar un borrador no cambia lo que recibe la aplicación.

## 2. Crear o corregir pico y placa

1. Entra a **Pico y placa**.
2. Filtra por departamento, ciudad o tipo de vehículo.
3. Abre la jurisdicción que deseas trabajar.
4. Crea un borrador o duplica la última versión para una nueva vigencia.
5. Registra únicamente datos respaldados: días o fechas, dígitos, horarios, vigencia, fuente y fecha de revisión.
6. Guarda y usa **Validar**. Los conflictos, fechas imposibles y datos incompletos deben corregirse antes de publicar.
7. Revisa la previsualización. Abrir o validar una regla no la publica.

Los estados pendiente, vencido o sin información nunca significan libre circulación. La hora de operación es `America/Bogota`.

## 3. Importar XLSX, CSV o JSON

1. En **Pico y placa**, elige **Importar archivo**.
2. Selecciona el archivo. Para XLSX puedes indicar la hoja.
3. Pulsa **Analizar** y revisa filas válidas, excluidas y errores por fila.
4. Corrige el archivo si hay errores bloqueantes. El panel no adivina ciudades, dígitos ni horarios ambiguos.
5. Selecciona expresamente las filas válidas y crea los borradores.
6. Revisa y valida esos borradores antes de publicarlos.

El archivo original queda privado. Volver a importar exactamente el mismo archivo no duplica el lote. Una celda vacía no elimina datos activos por sí sola.

## 4. Publicar una, varias o todas las ciudades seleccionadas

1. En la lista de reglas marca las ciudades que deseas publicar.
2. Elige **Revisar selección**.
3. Comprueba el alcance y las versiones concretas.
4. Confirma con **Publicar ciudades seleccionadas**.

El sistema crea una nueva instantánea nacional: sustituye únicamente las ciudades seleccionadas y conserva las demás. Si otra publicación cambió la base después de la validación, el borrador queda obsoleto y debe revisarse de nuevo.

Para publicar todas, usa la misma selección múltiple. No publiques ciudades pendientes o vencidas solo para completar el conteo.

## 5. Historial y reversión

1. Abre **Historial de publicaciones**.
2. Revisa versión, fecha, operador y ciudades afectadas.
3. Para revertir una ciudad, elige la versión anterior de esa jurisdicción y confirma el alcance.
4. Para una reversión global, confirma expresamente todo el conjunto.

La reversión de una ciudad genera una publicación nueva que conserva las versiones actuales de las demás. No borra el historial.

## 6. Patrocinadores y campañas

1. Crea el patrocinador en **Patrocinadores**. Sus datos de contacto son privados.
2. Crea una campaña asociada con etiqueta, título, subtítulo, CTA HTTPS, prioridad, alcance, vigencia e imagen.
3. Usa una imagen compatible con las dimensiones C11. El panel valida tipo real, dimensiones y peso.
4. Previsualiza antes de activar.
5. **Activar** publica un catálogo nuevo; **Pausar** lo vuelve a publicar sin esa campaña; **Archivar** es terminal.

El carrusel móvil conserva su diseño C11. Si la red falla o el catálogo es inválido, la aplicación conserva las campañas locales aprobadas. La caché puede retrasar la retirada hasta una hora en clientes conectados; sin red se mantiene el último estado válido o el fallback local.

## 7. Comprobar que la aplicación recibió la versión

Después de publicar:

1. Comprueba que el historial muestre la nueva revisión.
2. Abre el manifiesto de datasets desde la sección de publicación y confirma su versión y fecha.
3. En una instalación de QA, fuerza una actualización normal de contenidos.
4. Prueba una placa y fecha cubiertas por la regla publicada.
5. Verifica que una ciudad no seleccionada conserve el mismo resultado.

Para campañas, actualiza Inicio en QA y confirma título, imagen y CTA. No edites assets manualmente para simular la actualización.

## 8. Otros catálogos

- **Geografía y jurisdicciones:** base operativa del panel; se inicializa durante la instalación.
- **Fuentes y datasets:** administrables con trazabilidad. Solo se publican tipos cuyo validador los admita.
- **Cámaras:** mantienen su registro y flujo especializado existente.
- **Calendarios tributarios:** conservan el publicador genérico validado existente.
- **Solicitudes de aliados:** son contactos privados; nunca se convierten automáticamente en campañas.
- **Peajes/tarifas y CDA:** sus datos actuales se conservan, pero B07 no habilita un editor genérico para ellos. Requieren validadores y contratos específicos antes de publicarse desde este panel.

## 9. Recuperación y copias

Una copia coherente incluye, en el mismo punto temporal:

- volcado MariaDB;
- `storage/app/public`, incluidos manifiestos, releases e imágenes de campaña;
- configuración privada fuera del webroot.

Restaura primero en una copia aislada. Comprueba conteos, hashes y login antes de sustituir un entorno. El asistente B06 es solo para primera instalación; no es un actualizador ni una herramienta de restauración.

## 10. Límites vigentes

- No hay scraping automático de decretos.
- No hay anuncios comerciales reales, cobros, Pro, WhatsApp ni cuentas móviles activadas.
- Publicar contenido no actualiza el código Laravel ni reinstala la aplicación móvil.
- El staging real de Hostinger permanece pendiente de autorización y smoke test.
