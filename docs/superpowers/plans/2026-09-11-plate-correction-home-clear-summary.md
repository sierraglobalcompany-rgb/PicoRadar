# Placas compactas y resumen de Inicio: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. No declarar fidelidad por tests verdes.

**Goal:** Corregir la placa sobredimensionada y el emblema ausente, y aplicar la nueva referencia del estado sin restriccion diaria en Inicio.

**Architecture:** Reutilizar ColombianPlateBadge, VehiclePlateBadge y _TodayRestrictionSummary. Cambios de presentacion acotados; no introducir servicios, caches globales ni consultas nuevas. La agrupacion de caracteres no es validacion legal ni modifica el registro.

**Tech Stack:** Flutter, widgets e iconos existentes, CustomPainter y Riverpod actuales.

**Spec:** Plan de placas aprobado y correcciones del propietario del 11 de septiembre de 2026. Referencia de placa: docs/design/reference/plate_owner_20260910.png. Nueva referencia de resumen: C:/Users/felip/AppData/Local/Temp/codex-clipboard-e015853a-2d0f-4ea7-93c9-f8ca1a029f08.png.

## Estado Auditado

- Branch: codex/plate-owner-fidelity; base ddf60407174e3ee8d447b7eff3ca45e0fd983789. WIP conservado, sin commit nuevo ni PR de este lote.
- La primera APK de placas esta instalada pero NO esta aceptada visualmente. Capturas: temp/PLATE_OWNER_FIDELITY/screenshots/home-after.png, home-second-after.png y garage-after.png.
- El ancho compacto actual de 160 dp da demasiado protagonismo a la placa frente al vehiculo. El emblema aparece en el segundo vehiculo pero no en el primero.
- Causa del emblema ausente: la expresion de formato exige tres letras iniciales; la primera placa guardada contiene un numero en ese grupo. No debe corregirse el dato para satisfacer el dibujo.
- La tarjeta sin restriccion usa un carrito, check secundario, etiqueta generica y subrayado; no corresponde a la nueva referencia.
- Antes de estas nuevas correcciones: suite 1843 aprobadas, 10 omitidas. Estos resultados NO validan el diseno solicitado ahora.
- Ya existe una nueva prueba roja, `owner correction keeps compact size and legacy six-character emblem`; falla por el ancho actual. Registro: temp/PLATE_OWNER_FIDELITY/logs/owner-correction-red.txt. Falta implementar la correccion.

## Limites Globales

- No modificar numeros de placa, municipio guardado, GPS, jurisdiccion, reloj ni motor de restricciones.
- No cambiar estados restringidos, desconocidos o vencidos para presentarlos como permitidos.
- No cambiar Conducir, backend, dependencias, permisos ni datos.
- Conservar variantes simples de placa fuera del alcance y .planning/.
- La extension de alcance autorizada es SOLO la tarjeta sin restriccion de Inicio; mantener cambios revisables separados de la placa.
- PR dirigido a codex/app-performance-kiss, push normal, SIN MERGE. Preservar vehiculos y configuracion al instalar.

## Tarea 1: Reducir la placa y conservar el emblema

**Files:** mobile/lib/core/design_system/branding.dart; mobile/lib/features/garage/presentation/vehicle_plate_badge.dart; mobile/test/core/design_system/plate_fidelity_test.dart; mobile/test/core/design_system/design_system_test.dart.

- [ ] Fijar ancho compacto objetivo de 136 dp, altura normal aproximada de 63-66 dp y relacion cercana a 2.15:1; compararlo con los 160 dp rechazados. No encoger todo con FittedBox.
- [ ] Ajustar numero a 24 sp en compacto, conservando fuente condensada existente, pie de 10 sp y emblema de 9 dp. Reequilibrar espacios internos antes de reducir texto adicionalmente. Respetar escala del sistema.
- [ ] Usar agrupacion visual de seis caracteres alfanumericos (tres + tres), incluidos registros antiguos; no exigir tres letras para dibujar el separador. Conservar el numero completo y ordenado, sin reemplazos ni inferir tipo de vehiculo. Formatos de otra longitud quedan completos, sin division inventada.
- [ ] Mantener un unico borde negro interior, margen de color exterior y cuatro ranuras. Actualizar medicion de altura para usar el ancho efectivo limitado, no el ancho mayor del padre.
- [ ] Completar prueba roja con casos habituales, seis caracteres antiguos y caracteres anchos; comprobar ancho <=136, altura <=66 a texto normal, emblema entre grupos y concatenacion identica al valor recibido. Cubrir ampliacion de texto sin recortes.
- [ ] Ejecutar pruebas de branding, adaptador y los consumidores. No cambiar expectativas para ocultar un desbordamiento.

## Tarea 2: Nueva tarjeta de Inicio sin restriccion diaria

**Files:** mobile/lib/features/home/presentation/home_status_section.dart; mobile/test/features/home/presentation/home_screen_test.dart; docs/DESIGN_CONTRACT.md.

**Entrada:** fase calculada por restrictionPhaseAt y jurisdiccion efectiva existentes. No modificar esos resultados.

- [ ] Aplicar nueva composicion exclusivamente cuando phase == RestrictionDayPhase.unrestricted.
- [ ] Conservar fondo navy y accion de toda la tarjeta. Izquierda: disco verde muy claro con check circular verde grande, sin carrito ni insignia pequena superpuesta.
- [ ] Derecha, alineacion izquierda: etiqueta verde clara `Sin pico y placa hoy`; mensaje blanco `Puede circular`, SIN subrayado; debajo pin y ciudad efectiva en color claro.
- [ ] Mantener altura normal objetivo 100-108 dp, icono de 52-56 dp, mensaje 18 sp, etiqueta 13 sp y ciudad al menos 14 sp. Espaciado interior 10-12 dp. No copiar la escala del poster como tamano en telefono.
- [ ] Permitir que etiqueta y ciudad ocupen mas lineas con texto ampliado o nombres largos; no truncar, comprimir fuentes o imponer altura fija. Inicio solo desplaza cuando los minimos legibles no caben.
- [ ] Preservar todos los otros mensajes: antes de comenzar, durante restriccion, entre ventanas, finalizada, desconocido y vencido. En un dia restringido NO mostrar `Sin pico y placa hoy` aunque en ese instante no haya prohibicion.
- [ ] Escribir primero pruebas que fallen: etiqueta nueva/check principal/blanco sin subrayado en permitido; misma navegacion al vehiculo enfocado; prohibicion del estado verde en desconocido/vencido y en dias con ventanas. Mantener pruebas de medianoche y cambio de ciudad.
- [ ] Copiar referencia al directorio de diseno y actualizar contrato solo tras implementar y comprobar.

## Tarea 3: Comparacion visual real

**Files:** pruebas existentes de Inicio/Garaje/Pico y temp/PLATE_OWNER_FIDELITY/.

- [ ] Validar 360/390/412/430 dp y escalas 1/1.5/2. En normal: placa mas pequena que captura rechazada, grupos horizontales y emblema visible. En ampliado: caracteres y ciudad completos.
- [ ] Comprobar carro particular amarillo, taxi blanco y moto con COLOMBIA. Municipio conocido sin departamento; vacio COLOMBIA; texto antiguo sin correspondencia conservado.
- [ ] Recalcular solo las reservas de altura necesarias de Garaje/Pico; mantener mayor presencia de la imagen del vehiculo, sin huecos causados por reservar ancho no utilizado.
- [ ] Instalar release dev con -r, sin borrar datos. En Mi A3 capturar ambos primeros vehiculos en Inicio, Garaje, Pico personal y accesos de Pico ciudad. Comprobar regreso, foco y conteo de vehiculos.
- [ ] Comparar referencia, resultado rechazado y corregido con recortes equivalentes; anotar dimensiones de la placa y de la tarjeta. No etiquetar capturas de tests como fisicas.
- [ ] Exportar taxi/moto y ciudades largas como casos automatizados si no existen en el telefono. No crear vehiculos del usuario sin necesidad.
- [ ] Si falta emblema, la placa vuelve a dominar el vehiculo o la tarjeta no coincide en orden/textos, corregir y recapturar ANTES de aprobar. Documentar que la tipografia y monograma son adaptaciones, no reproduccion oficial exacta.

## Tarea 4: Gates y entrega

- [ ] Formato de lib/test, flutter analyze, pruebas focalizadas, suite completa y build dev release, secuenciales. Repetir pruebas de rendimiento de Inicio para detectar regresiones de reconstruccion/consultas.
- [ ] Registrar por separado el fallo conocido de formatear toda la carpeta causado por una ruta generada rota en build; verificar formato completo en CI limpio. No borrar evidencia ni datos para ocultarlo.
- [ ] Commits separados de placa y tarjeta, push normal, PR al destino autorizado y verificar CI; sin merge.
- [ ] Entregar informe Markdown individual, capturas antes/despues, APK y SHA256. Verificar hash instalado igual al APK entregado; dejar la APK normal optimizada, no harness.
- [ ] Actualizar checkpoint con resultados reales. Separar implementacion, pruebas tecnicas, comparacion visual y aceptacion del propietario. No declarar resueltos los pendientes globales de rendimiento anteriores.

## Aceptacion

La entrega no se acepta solo por compilar: debe mostrar la placa compacta con emblema en el primer vehiculo y la tarjeta nueva fiel en simbolo, textos, colores y orden, sin alterar resultados de pico y placa. La aprobacion visual anterior queda retirada.
