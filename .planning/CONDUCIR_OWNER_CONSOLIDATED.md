# Conducir: correcciones owner consolidadas

Base publicada: f985ebc891f5af4b1d32bc2ea7f7902970af45a8.
Branch: integration/VIAJE-R1-real-planner. PR #55. Sin merge.

## Decisiones vigentes (sustituyen propuestas contradictorias anteriores)

1. Pantalla activa sin scroll. Conservar direccion, autoridad, mapa/radar y controles. La tarjeta puede crecer hacia arriba; ajustar espacios antes de reducir texto. No esconder informacion ni agregar botones para compensar recortes.
2. Fondo oscuro conservado. Alerta visual opcional: repetir el ciclo suave azul/blanco atenuado mientras exista aproximacion valida de camara, despues del primer umbral. No strober rapido. Cancelar al pasar, descartar, finalizar, perder validez, desactivar o salir de primer plano; respetar movimiento reducido. Peajes conservan su secuencia por aviso y prioridad inferior.
3. Subir moderadamente el disco blanco/rojo desde el centro del numero (24 dp iniciales, sujeto a captura). Conservar la silueta vial aprobada y el velocimetro protagonista.
4. Eliminar '(reportado)' de la tarjeta compacta: mostrar distancia; estado/fuente permanecen en detalles. No afirmar limite de velocidad vigente.
5. Eliminar el acceso redundante de ubicacion de la fila de distancia. Conservar informacion junto a cerrar en la cabecera, separados y con objetivos de 48 dp.
6. Tocar el disco, el mapa/radar o informacion abre LA MISMA ficha 'Fuente de camara'. Ninguno abre Google Maps directamente. Solo el boton existente dentro de la ficha abre Google Maps mediante accion expresa.

## Orden de ejecucion

- [x] Consolidar ultima aclaracion y preservar WIP.
- [x] Unificar accesos de informacion y retirar copy redundante en codigo.
- [x] Validar encaje sin scroll y objetivos tactiles en matriz de telefonos/texto.
- [x] Validar ciclo continuo y cancelaciones sin regresiones.
- [x] Comparar captura fisica, probar los tres accesos y grabar pulsos repetidos.
- [x] Ejecutar gates frescos y builds; normal instalada al cierre.
- [x] Commit/push normal, CI e informe individual. Integridad del ZIP en ZIP_OWNER_VERIFICATION.json.

## Pendientes que no deben confundirse con aprobacion

HEAD publicado 6704fa60e8035e91a9f1cce34fca1e0c017353af. Suite fresca 1484 PASS / 10 skips; 100 focales PASS; ambos CI SUCCESS. Profile fresco: 93.91/90.00/70.76% frames combinados dentro de 16.7ms, por debajo de 95%. Cierre global PARTIAL. Normal instalada, hash verificado. No modificar backend, deteccion, dataset, dependencias o permisos para esta correccion visual. NO MERGE.
