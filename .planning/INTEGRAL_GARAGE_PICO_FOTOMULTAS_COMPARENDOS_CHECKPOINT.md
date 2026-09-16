# Checkpoint - Plan integral Garage/Pico/Fotomultas/Comparendos

Fecha: 2026-09-12
Branch: codex/garage-single-favorite
HEAD observado: ddf60407174e3ee8d447b7eff3ca45e0fd983789

## Estado de entrada

El worktree ya contiene WIP previo en Inicio, Garaje, Mi Pico, Detalle, placas,
rendimiento y modulos relacionados. Ese WIP se preserva y no se reinicia desde
el SHA base. El SHA observado por si solo no representa la APK/diseños instalados
previamente.

## Alcance autorizado

Ejecutar el plan integral en este orden:

1. Garaje adaptable y vehiculo protagonista.
2. Pico por ciudad compacto y coherente.
3. Fotomultas por departamentos.
4. Comparendos claro y con consulta territorial temporal.

Fuera de alcance: Inicio, Mi Pico personal, Detalle del vehiculo, Conducir,
motor de restricciones, backend, schema, permisos nuevos y dependencias runtime
nuevas.

## Rulings iniciales

- Ruling: Fotomultas tendra una excepcion limitada al baseline "sin mapa" solo
  dentro de Apps/Fotomultas como explorador manual del inventario parcial actual.
  No habilita mapa en Conducir, navegacion, GPS continuo, hot path backend ni
  ampliacion nacional de datos. Costo si es incorrecto: habria que retirar el
  explorador de mapa y volver a un selector/listado sin mapa.
- Ruling: la geometria DANE se tratara como asset local derivado/documentado y
  no como dependencia runtime o servicio remoto. Costo si es incorrecto: habria
  que reemplazar la fuente geometrica o pedir aprobacion de licencia/alcance.

## Verificacion previa leida

- AGENTS.md.
- Cierre Global baseline v1.0.
- Arquitectura Tecnica Android First.
- Flujos 02, 03, 04 y 05.
- Lotes C08, C09, C12, C14 y C16.
- docs/CURRENT.md, docs/DESIGN_CONTRACT.md y docs/SOP.md.

## Notas de ejecucion

- Se usaran cambios acotados por lote y pruebas focalizadas.
- Antes de instalar o usar el Mi A3 para validacion fisica se generara un nuevo
  checkpoint especifico del candidato.
- No merge ni push sin autorizacion explicita.
