# PicoRadar Design Contract

Este contrato traduce el baseline visual a reglas operables para Flutter. Autoridad: `docs/baseline/02_Wireframes_Design_System_v1.docx` y flujos 01-08, subordinados a seguridad, privacidad, store, Cierre Global y Arquitectura Tecnica.

## Rendimiento sin redisenar (2026-09-10)

- La ventana nativa de arranque muestra la marca existente y mantiene continuidad
  hacia Flutter; no agrega una espera artificial ni un porcentaje ficticio.
- Inicio puede presentar su contenido esencial antes de avatar, imagenes,
  obligaciones o banner. Los espacios permanecen estables y un dato pendiente
  no se interpreta como permiso para circular ni obligacion sin configurar.
- Optimizaciones de pintura, consultas o caches conservan dimensiones, sombras,
  efectos, texto accesible, controles y foco. Las capturas comparativas y la
  medicion fisica, no solo tests verdes, acreditan esta conservacion.
- No se apaga GPS al cambiar de pestana ni se elimina una alerta aprobada para
  aparentar mayor fluidez. Las limitaciones de rendimiento se declaran aparte.

## Inicio: vehiculos protagonistas y layout adaptable (2026-09-09)

### Auditoria Inicio/Garaje/Pico 2026-09-10

- Pico por ciudad describe la regulacion colectiva: "Restriccion hoy" con sus
  digitos y ventanas completas. No afirma "No puedes circular" sin evaluar un
  vehiculo. Mi Pico conserva los estados personales del dia y del instante.
- Nombre de ciudad, fuente, vigencia, selector y ventanas de 12 horas se
  reorganizan sin ellipsis. Texto ampliado admite mas altura y scroll util,
  nunca una fuente encogida para ocultar un recorte.
- Inicio conserva el ID enfocado al cambiar ciudad o recargar evaluaciones;
  los resultados pendientes son neutros, no una autorizacion anterior.
- Garaje espera el activo inicial antes de elegir foco, conserva titulos
  completos y ofrece 48 dp tactiles en Favoritos aunque el circulo sea menor.
  "Ciudad de matricula" identifica el dato registral, no la ciudad de Pico.
- El banner existente conserva contenido/destino y permite reflujo; no activa
  publicidad. No cambia la barra compartida ni el diseno de Conducir.

### Revision owner 2026-09-10: resumen unico y reloj vivo

Esta revision reemplaza la franja hoy/manana, la banda textual y el pie de horarios
del carrusel descritos en la referencia historica siguiente. Referencia owner:
[home_summary_owner_20260910.png](design/reference/home_summary_owner_20260910.png) (tarjeta navy,
simbolo circular de vehiculo, mensaje, horario de 12 horas y ciudad).

- Carrusel: asset aprobado completo y placa centrada; sin etiqueta Particular ni
  pie horario. La correccion owner posterior restaura una franja superior con el
  apodo guardado o, si falta, la marca; si ambos faltan, "Mi vehiculo". La franja,
  el indicador accesible y el borde son estaticos: rojo para dia restringido,
  verde permitido, ambar desconocido/vencido. Sombra suave del mismo color,
  estatica; sin glow animado ni texto de estado duplicado.
- Placa de Inicio: particular amarilla, taxi blanca, caracteres negros y borde
  interior redondeado; debajo del numero, ciudad de matricula guardada para carro
  y taxi, COLOMBIA para moto y tambien cuando falta ciudad registrada. Cuatro
  fijaciones y separador circular estilizado. No inferir ciudad de las letras
  de la placa ni del GPS. Referencias del owner del 2026-09-10;
  adaptacion grafica propia, sin sellos oficiales ni marcas de agua. Este opt-in
  no cambia las placas de otras pantallas ni la jurisdiccion de restricciones.
- Medir cabecera y secciones inferiores para asignar al carrusel el espacio
  restante: reducirlo en telefono pequeno y ampliarlo donde haya altura real.
  No rellenar con separadores ni permitir scroll sobrante en texto normal.
- Resumen: tarjeta navy tactil completa que abre Pico del vehiculo enfocado.
  Simbolo de carro/moto a la izquierda; etiqueta, estado, ventanas y ciudad a la
  derecha. No hay informacion de manana en Inicio ni accion separada en ciudad.
- Distinguir dia e instante: "No puede circular" solo durante ventana activa;
  antes: "Empieza a las ..."; entre ventanas: "Sin restriccion ahora";
  despues: "Restriccion finalizada". Sin ventanas: "Puede circular", con acento
  verde subrayado y vehiculo con verificacion para evitar repetir Pico y placa.
  Datos desconocidos/vencidos no autorizan circular.
- Horarios de 12 horas (5:00 a. m. - 8:00 p. m.), mensaje de 18 sp y horario/ciudad
  de al menos 14 sp. No reducir mensajes con FittedBox ni partir horas. Altura
  flexible para ciudad larga, multiples ventanas y escala accesible. Resumen
  compacto con minimo de 100 dp e icono de 56 dp; el texto nunca se reduce para
  forzar ese minimo. Scroll solo cuando los minimos legibles excedan la pantalla.
- Un reloj UTC compartido deriva la fecha de Bogota; se actualiza al reanudar y
  en cada minuto en primer plano. El calendario marca hoy real y "Estado inmediato"
  muestra fecha actual. Las fechas futuras se identifican como proxima restriccion.
- Los ticks no solicitan GPS/red ni reprograman notificaciones cada minuto.
  Jurisdiccion efectiva manual/GPS, placa editada y datasets actualizados deben
  invalidar los resultados correspondientes sin cambiar el foco del vehiculo.

### Referencia historica 2026-09-09 (sustituida donde contradiga la revision)

- Cabecera: marca PicoRadar a la izquierda; avatar, pin de ubicacion y notificaciones a la derecha, en ese orden. Los controles conservan objetivo tactil de 48 dp, pero el circulo visible es mas pequeno para no competir con el carrusel. El pin abre la hoja existente de ubicacion/manual/GPS, no solicita permisos por renderizar Inicio. Garaje y Viaje conservan su cabecera salvo que pasen explicitamente un control final.
- La tarjeta independiente de ciudad/GPS desaparece. La jurisdiccion que gobierna el calculo vive bajo "Pico y placa" en la franja inferior; sin ciudad seleccionada se muestra "Seleccionar ciudad" y no se tranquiliza al usuario.
- Las restricciones se calculan por la ciudad efectiva actual, ya sea manual o detectada por GPS, no por la ciudad de matricula del vehiculo. Una placa registrada en Bogota ubicada en Medellin usa las reglas de Medellin. La deteccion GPS solo selecciona ciudades con cobertura activa en el dataset local; ciudades en preparacion o evento temporal no se inventan como vigentes.
- Carrusel: vehiculo como protagonista, altura derivada del espacio real disponible, orientativa 236-360 dp. Primero intenta ajustar tarjetas y carrusel para evitar scroll en telefonos normales; con texto ampliado o alto insuficiente conserva un unico scroll vertical por accesibilidad. La tarjeta central ocupa cerca del 64% del ancho en telefonos, con laterales visibles y sin avance automatico. El foco del carrusel no cambia el vehiculo activo sin accion explicita.
- Estado: "Puede circular" aparece solo en la franja superior del vehiculo. Si hay restriccion, la franja superior dice "Pico y placa hoy" y el detalle bajo tipo/placa muestra las ventanas aplicables. No duplicar "Estado hoy" ni afirmar restriccion de todo el dia si existen horarios.
- Tipo y placa comparten fila con texto normal; con texto ampliado se apilan sin recortar placa ni bajar el objetivo tactil. Estados desconocido/vencido no se pintan verde ni autorizan circular.
- Franja inferior: toda la tarjeta "Pico y placa / ciudad / horario" abre Pico del vehiculo enfocado. La ubicacion se cambia solo desde el pin superior para evitar gestos ambiguos. SOAT, Tecnomecanica y banner mantienen orden y destinos. Un solo scroll vertical se permite solo si los minimos legibles exceden el alto util; sin scroll interno ni reduccion artificial de fuentes.

## Viaje: correccion owner de lectura (2026-09-09)

- Peajes: nombre y precio visibles en cada fila; importes nominales excluidos se identifican como tarifa de referencia no sumada, nunca como una deuda del usuario. No repetir advertencias tecnicas antes del listado.
- Al abrir un peaje: ubicacion en Google Maps y valores de sus categorias generales. Condiciones, descripciones ausentes y fuentes permanecen accesibles en un desplegable secundario. Las autorizaciones excepcionales siguen visibles junto a la tarifa afectada.
- Salida y llegada comparten ciudad, fecha/hora, estado y chevron en toda la fila. No mezclar un enlace por ciudad con un boton distinto para destino. Sin hora de salida no se inventa llegada ni resultado de restriccion.
- Mantener nombres legibles, precios alineados, cierre explicito de hojas y reflujo vertical con texto ampliado. Las capturas fisicas se revisan aparte de los tests funcionales; no equivalen a aprobacion visual del owner.

## Conducir: mapa, proximidad y peajes (2026-09-09)

- El valor ANSV solo vive en detalles con fuente, fecha y advertencia: no confirma el limite vigente. No produce senal de limite, exceso numerico, rojo/pulso del velocimetro ni voz/vibracion de exceso. El velocimetro conserva velocidad propia centrada y un indicador compacto de camara durante el aviso.
- Mapa orientado al rumbo fiable, flecha arriba, vehiculo al 50% horizontal y 72% vertical en conos frontales; centrado en 360 grados. El objetivo conserva su posicion geografica, incluso lateral o posterior. Los angulos son aperturas totales, no semianchos.
- Una sola instancia de mapa: radar completo hasta cubrir el encuadre con todas sus teselas. Error o timeout de tres segundos fija radar durante el episodio; reintento explicito o nuevo episodio permite recuperar. No mostrar mosaicos parciales como listos.
- Peajes inicialmente OFF, con interruptor propio y distancias/angulo/voz/sonido/vibracion compartidos. Una tarjeta principal, con prioridad de camara. Precio de categoria I como referencia, nunca cobro acumulado o confirmado; desconocidos y restricciones de publicacion se explican.
- Las tarifas completas se abren solo por accion explicita, tambien en marcha para un acompanante; una camara prioritaria cierra esa ficha. HUD conserva informacion breve sin mapa ni fichas nuevas.
- Sin GPS continuo al servidor, historial de recorrido, nuevos permisos ni navegacion giro a giro. Simulaciones identificadas, separadas de conduccion real. Esta decision sustituye la relacion velocimetro/senal del feedback V01A para R15/R16.

## Conducir: composicion activa y alerta visual (owner consolidado)

- La pantalla activa no tiene scroll. Reserva SafeArea, cabecera y barra; mide primero la tarjeta y entrega al velocimetro el espacio restante. La tarjeta puede crecer hacia arriba y conserva direccion, autoridad y mapa/radar completos, sin mas botones ni informacion oculta.
- Con texto normal, el velocimetro conserva aproximadamente 300/324/344 dp en pantallas de 360/390/412 dp, numero blanco centrado y arco abierto teal 0-200. Sin aviso vuelve al centro (280 ms; inmediato con movimiento reducido). Con texto ampliado se adapta a la altura disponible; el numero y km/h mantienen medidas de instrumento, sin escalar sobre las graduaciones.
- La cabecera compacta alinea logo de 28 dp, marca de 22 sp y etiquetas GPS/Voz de 13 sp. Con texto ampliado pasan juntos los estados a otra fila. GPS verde hasta 25 m, naranja hasta 60 m y rojo si supera 60 m o no hay posicion. Voz verde representa la preferencia, no garantiza reproduccion. Iconos, semantics y tooltips conservan el significado completo.
- Configuracion, HUD y Espejo: iconos de 26 dp, controles de 48x56 dp. Finalizar domina con Stop y texto. Separacion 8 dp; si el texto ampliado no cabe, iconos arriba y Finalizar debajo. No reducir objetivos tactiles.
- Camara: disco blanco de 72 dp, borde rojo y silueta vial en perspectiva, con lente, visera y poste. Su centro queda 24 dp por encima del centro del numero; puede cubrir el arco lateral, no el numero. Area tactil real alineada con el dibujo.
- Tarjeta: fondo #061118, encabezado #59121C, borde rojo; fondo activo #03090D. Encabezado con silueta, Camara de fotomulta/Camara cercana, informacion y cerrar (48 dp cada uno, separados). La segunda fila contiene solo distancia. El estado operativo y la fuente permanecen en detalles; no mostrar '(reportado)' ni convertirlo en afirmacion de vigencia.
- Mapa/radar a la izquierda, direccion/autoridad a la derecha; apilar solo si el ancho realmente no permite columnas. Priorizar espacios y crecimiento de tarjeta. Si falta altura, limitar la escala de texto de tarjeta a 1.15 (menos de 340 dp) o 1.5 y ajustar solo el bloque de datos al espacio restante, sin recortar su contenido. Revisar capturas y legibilidad, no aceptar datos diminutos por tener cero overflow. Los controles no se escalan.
- Tocar disco, mapa, radar o informacion abre la misma ficha Fuente de camara. No abrir Google Maps directamente: solo desde Ver en Google Maps dentro de esa ficha. El callback del mapa real y el del radar deben verificarse por separado.
- Alerta visual OFF por defecto, persistencia local y previsualizacion explicita. Secuencia suave de 2400 ms: azul 22% y blanco atenuado 12%; cada pulso tiene entrada 400 ms, mantenimiento 200 ms, salida 400 ms y descanso 200 ms. Sin cambio del brillo fisico.
- Tras el primer umbral valido de camara, repetir esa secuencia mientras siga la aproximacion del mismo episodio, independiente del audio. No reiniciar por cada GPS ni encolar efectos. Cancelar al pasar/receder, descartar, finalizar, perder objetivo valido, apagar la opcion o salir de primer plano. Encender la opcion no reproduce umbrales anteriores.
- Peajes conservan una secuencia por aviso y prioridad inferior a camaras; no cambian tarifas ni deteccion. Misma capa visual en normal/HUD/espejo. Movimiento reducido conserva aviso estatico. Prohibidos strober rapido, blanco pleno y destellos rojo/azul tipo patrulla.
- Pruebas funcionales y CI no sustituyen QA visual fisica. El objetivo de fluidez pendiente se informa por separado.

## Tokens

- Color primario: navy `#17324D`.
- Acento funcional: teal `#0B7A75`.
- Accion/enlace: blue `#2F6FED`.
- Exito: green `#1B8A5A`.
- Alerta: orange `#D97706`.
- Riesgo: red `#C2413B`.
- Background/surface: off-white/white con bordes suaves.
- Radio de cards principales: 20-24 dp.
- Padding de cards principales: 20-24 dp.
- Botones/chips: radio tipo pill solo cuando el componente lo requiere.
- Spacing base: 4/8/12/16/24/32/48, aplicado con jerarquia consistente.
- Token 3XL: 48 dp.
- Tipografia: jerarquia sobria, no Material-default generico; textos compactos en cards y paneles.

## Componentes compartidos esperados

- `AppBottomNav` para la barra inferior exacta.
- Cards base de estado/vehiculo/modulo.
- Botones primarios/secundarios/terciarios coherentes.
- Chips de vehiculo, ciudad, estado y cobertura.
- Skeleton loaders para cargas de pantalla o tarjetas.
- Empty/error states con copy especifico y accion clara.

No duplicar widgets privados equivalentes entre Inicio, Garaje, Apps y Pico si pueden ser shared components.

## Contratos por raiz

Navigation:
- Tabs exactas: Inicio, Garaje, Apps, Viaje, Conducir.
- Apps siempre al centro.
- Apps centro es una accion de launcher overlay; la ruta `/apps` permanece para compatibilidad, pero el boton central no abre una pantalla completa.
- Estados activo/inactivo accesibles por texto, semantica e iconografia, no solo color.

Inicio/Pico:
- Debe hacer evidente si el usuario puede conducir hoy.
- Debe incluir CTA dominante "Iniciar conduccion" cuando el contexto lo permita.
- "Cambiar vehiculo" debe resolver el flujo H-005/selector rapido, no saltar al Garaje completo.
- Pico Detail debe ser util con ciudad/vehiculo configurados y tener estado claro cuando falten datos.

Garaje:
- Vehiculo activo visible y facil de cambiar.
- Obligaciones/estado integral deben usar componentes compartidos y jerarquia escaneable.
- R02B Garage V2 usa `docs/design/GARAGE_OWNER_V1.json` y `docs/design/reference/garage_owner_v1.png` como autoridad visual owner-selected.
- La raiz de Garaje no lleva titulo grande; usa header PicoRadar, filtros compactos, carrusel PageView, panel de informacion real, tarjeta punteada de agregar vehiculo y acciones rapidas.
- Favoritos son preferencia local no sensible; el foco de carrusel no cambia el vehiculo activo sin accion explicita.
- No mostrar kilometraje falso, `Sin comparendos` ni `0 comparendos` antes de sus lotes aprobados.

Apps:
- Launcher inferior overlay sobre la pantalla actual con scrim suave, nav inferior visible y rango compacto 55-70% de altura del cuerpo.
- Principales usa grid 3x3 sin overflow en dispositivos pequenos.
- Más concentra los modulos secundarios existentes.
- Los modulos premium/off deben diferenciar disponibilidad sin parecer errores.
- No usar texto que se corte dentro de tiles.

Viaje:
- Owner peajes/UX review: resumen compacto, mapa, alternativas/peajes de la ruta, dos extremos Pico con ciudad, navegacion externa e Informacion importante desplegable. La consulta nacional de tarifas no ocupa el flujo de una ruta.
- El costo visible procede del presupuesto local de la misma alternativa. Estimacion parcial y cobros pendientes permanecen visibles; cambiar categoria en una ficha solo consulta precios de ese peaje.
- El acceso de cada extremo abre Pico por ciudad de manera temporal y conserva el viaje al volver. No repetir la evaluacion diaria cuando ya se muestra la evaluacion por hora.
- Una sola pagina con scroll vertical; el mapa no crea un segundo scroll vertical competidor.
- Tras una consulta exitosa, revelar resultados una sola vez y compactar la preparacion sin perder valores; seleccionar otra alternativa no repite el auto-scroll ni la consulta.
- Resumen 2x3 en ancho estrecho, alternativas verticales de ancho completo y `Ver en mapa` antes del desglose/fuentes.
- El mapa previo conserva ruta, inicio/fin y capas separadas para peajes, historicos y camaras. Pan, zoom, capas y pantalla ampliada no recalculan ni vuelven a consultar la ruta.
- Distinguir ubicaciones fisicas de pasos candidatos. Tarifa, cobro, vigencia y sentido desconocidos se muestran como desconocidos; las camaras por distancia sola son proximas al recorrido, no confirmadas para la via/sentido.
- Si faltan geometria, datos locales o tiles, mantener el plan y mostrar un estado honesto con reintento. Nunca dibujar una linea recta inventada.

Loading:
- Usar skeletons para cargas visibles de pantalla/tarjeta.
- Reservar spinners para acciones cortas o estados inevitables de sistema.

Accesibilidad:
- Objetivos tactiles de al menos 44x44.
- Soporte `TextScaler`/textScale 1.0, 1.5 y 2.0 sin overflow.
- Contraste suficiente y estado no dependiente solo de color.
- Semantics labels en controles iconicos y estados importantes.
- Superficies raiz de telefono son portrait-only salvo autorizacion explicita por lote.

## Gate visual R01+

Cada cambio visual debe:
1. localizar mockup/ref baseline;
2. leer este contrato;
3. buscar componente compartido antes de crear uno nuevo;
4. implementar la pantalla/componente;
5. ejecutar widget tests;
6. renderizar viewports 360x800, 390x844 y 412x915;
7. probar textScale 1.0, 1.5 y 2.0;
8. ejecutar al menos un smoke visual de superficie raiz en Android fisico cuando haya Mi A3 o dispositivo equivalente disponible;
9. verificar portrait-only en telefono; landscape solo aplica si un lote futuro lo autoriza explicitamente;
10. registrar mismatch ledger;
11. iterar hasta `VISUAL_FIDELITY=PASS`.

No se requieren cientos de goldens. El set canonico debe cubrir raiz, densidad, estado semantico y overflow.

`VISUAL_FIDELITY=PASS` exige 0 Critical mismatches, 0 High mismatches, 0 overflow, 0 clipping y 0 labels ilegibles, truncados o cortados.

## Mismatch ledger R00

| Finding | Esperado | Actual | Severidad | Impacto | Fix phase |
|---|---|---|---|---|---|
| Card radius | 20-24 dp | `AppRadius.card = 8.0` en `mobile/lib/app/theme/app_tokens.dart` | High | La UI se siente Material/default y no baseline | R01 |
| Theme incompleto | Component families propios | `ThemeData` minimo en `mobile/lib/app/theme/app_theme.dart` | High | Inconsistencia visual entre pantallas | R01 |
| Bottom nav | `AppBottomNav` compartido | Stock `NavigationBar` en `mobile/lib/app/shell/app_shell.dart` | Medium | Navegacion funcional pero no fiel | R01/R02 |
| CTA Inicio | "Iniciar conduccion" dominante | Inicio prioriza detalle/cambiar ciudad | High | El trabajo primario queda oculto | R02 |
| Cambiar vehiculo | Selector rapido H-005 | `context.go(AppRoute.garage.path)` | Medium | Flujo mas lento y pierde contexto | R02 |
| Loading | Skeletons estables | `CircularProgressIndicator` repetido | Medium | Sensacion generica y saltos visuales | R01/R02 |
| Componentes | Shared cards/chips/tiles | Widgets privados `_StatusCard`, `_VehicleCard`, `_ModuleTile`, etc. | Medium | Duplica decisiones visuales | R01 |
| Apps grid | Sin overflow | Mi A3 fisico muestra `BOTTOM OVERFLOWED BY 14 PIXELS` | Critical | UI rota en dispositivo real | R02 |
