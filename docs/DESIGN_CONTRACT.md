# PicoRadar Design Contract

Este contrato traduce el baseline visual a reglas operables para Flutter. Autoridad: `docs/baseline/02_Wireframes_Design_System_v1.docx` y flujos 01-08, subordinados a seguridad, privacidad, store, Cierre Global y Arquitectura Tecnica.

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

## Conducir: composicion activa y alerta visual (2026-09-09)

- La pantalla activa reserva primero SafeArea, cabecera y controles inferiores. El velocimetro permanece centrado sin objetivo y se desplaza arriba al aparecer una alerta. En texto normal, velocimetro y tarjeta caben completos; con texto ampliado, el contenido usa un unico scroll y la barra queda fija.
- La cabecera compacta alinea logo de 28 dp, marca de 22 sp y etiquetas `GPS`/`Voz` de 13 sp en una fila; con texto ampliado, estados juntos en una segunda fila. GPS verde hasta 25 m, naranja hasta 60 m y rojo si supera 60 m o no hay posicion. Voz verde indica preferencia habilitada, rojo deshabilitada, sin garantizar reproduccion. Iconos diferenciados, semantics y tooltips conservan el significado completo. La simulacion tiene una linea independiente.
- La camara se reconoce mediante un disco blanco de 72 dp, borde rojo y silueta vial en perspectiva con visera, lente y poste sin pedestal ancho. Reutilizarla en el encabezado. Es estatica. Por correccion owner, su centro se alinea verticalmente con el centro del numero de velocidad; puede superponerse al arco lateral, pero nunca al numero.
- La tarjeta de camara usa encabezado rojo oscuro, `Camara de fotomulta`, `Camara cercana`, cierre de 48 dp, distancia y acciones independientes. El mapa/radar y los datos se presentan lado a lado cuando caben y en secuencia vertical con texto ampliado.
- Configuracion, HUD y Espejo usan solo iconos de 26 dp en controles de 48x56 dp, con semantics y tooltips. Finalizar ocupa el ancho restante con Stop y texto horizontales. Separacion de 8 dp. Si el texto ampliado no cabe, los tres iconos quedan arriba y Finalizar a ancho completo debajo.
- El conjunto del velocimetro mide aproximadamente 300/324/344 dp en anchos 360/390/412 dp; arco visible cercano al 75-80% del ancho, numero blanco centrado y dominante. No reducirlo para hacer caber texto ampliado: usar el unico scroll del contenido. Sin aviso vuelve al centro conservando tamano; transicion 280 ms, inmediata con movimiento reducido. Tarjeta completa y separada de la barra inferior, incluyendo insets Android.
- Revision owner de tarjeta: fondo activo casi negro `#03090D`, tarjeta `#061118`, encabezado rojo oscuro `#59121C` y borde rojo. Titulo 18 sp/700, subtitulo regular; distancia y acciones en la segunda fila, mapa a la izquierda y direccion/autoridad a la derecha hasta escala 1.5. A escala 2 los datos se apilan por accesibilidad. El estado se identifica como reportado junto al valor, sin pie redundante; no afirma vigencia ni `EN TU RUTA`. Direccion 14 sp/600, etiquetas 13 sp regulares. Texto ampliado tiene indicador de scroll y margen inferior; el gesto ascendente sobre la tarjeta desplaza el contenido. Las evidencias deben mostrar tambien los datos completos tras desplazar, no solo el encuadre inicial. Validar tambien 360x780 con insets Mi A3.
- `Alerta visual` inicia apagada y se guarda localmente. Un umbral valido produce dos pulsos suaves de fondo completo: azul al 22 % y blanco al 12 %, cada uno con entrada 400 ms, meseta 200 ms, salida 400 ms y descanso 200 ms. No cambia el brillo del dispositivo.
- El pulso es independiente de voz, sonido y vibracion; se consume una vez por sesion, objetivo y umbral. No se repite por rebuild, mapa o GPS. Camara interrumpe peaje y no se encolan efectos. Se cancela al descartar, perder objetivo, finalizar, apagar la preferencia o salir de primer plano.
- Movimiento reducido elimina el pulso y conserva el aviso estatico. La misma capa visual se aplica a normal, HUD y espejo. Se prohiben strober rapido, blanco pleno y destellos rojo/azul tipo patrulla.

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
