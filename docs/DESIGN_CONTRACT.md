# PicoRadar Design Contract

Este contrato traduce el baseline visual a reglas operables para Flutter. Autoridad: `docs/baseline/02_Wireframes_Design_System_v1.docx` y flujos 01-08, subordinados a seguridad, privacidad, store, Cierre Global y Arquitectura Tecnica.

## Preparar compra: encaje auditado (2026-09-15)

- Extension funcional: cada revision abre una hoja con titulo 20 sp, contenido
  minimo 14 sp y acciones de 48 dp. Un solo scroll en la hoja; se conserva la
  portada aprobada. SIMIT y los buscadores no requieren placa ni Garaje.
- Ciudad de matricula, entidad tributaria, organismo de traspaso y autoridad
  de comparendos son selecciones distintas. Las consultas no marcan Revisado.
- Las declaraciones antiguas de adjuntos no muestran Copia guardada. Los
  archivos reales solo se gestionan dentro de la carpeta privada de la
  preparacion, con proteccion y sin publicidad.

- Pantalla independiente dentro del shell. Texto normal: LayoutBuilder reserva
  encabezado y pie; seis revisiones 3x2 sin desplazamiento ni controles ocultos.
- Encabezado navy #143963 muestreado del mockup: titulo 18 sp semibold,
  Opcional con fondo #DDF8F2; regreso con target 48 dp, circulo visual 32 dp
  blanco .55 y flecha 24 dp. Acciones normales 64 dp, accesibles minimo 48 dp.
- Mis preparaciones 48 dp; Tus revisiones 18 sp, contador 16 sp, progreso 6 dp.
- Tarjetas: radio 8 dp, numero 16 sp sin circulo compartiendo zona superior con
  icono 32 dp, titulo 14 sp, estado 13 sp. Azul #1D62C6 solo tras revision
  explicita. Tinta #0A2252; accion principal #078B90.
- Notas/Copiar/informacion y Guardar conservan targets de 48 dp. Los textos de
  orientacion estan en Sobre esta guia. Sin cambios en persistencia o adjuntos.
- Letra ampliada: un scroll accesible; dos columnas, o una si la palabra mas
  larga no cabe completa. Sin elipsis ni reduccion de fuentes.
- QA normal fisica Mi A3: encabezado 164 dp, tarjetas aproximadamente 119 dp, Guardar termina
  en y=646 dp y navegacion comienza en y=650 dp. Gesto vertical no mueve portada.
- El encabezado de 108 dp fue rechazado por el owner; esta correccion recupera
  su presencia sin ocultar acciones. Aprobacion visual final pendiente.

## Seguro: ficha y editor de poliza (2026-09-14)

- Cambio limitado a hojas: la portada, banner, vehiculo y placa aprobados siguen
  intactos. No nuevas pestanas ni pantalla principal.
- Ficha protegida con identidad, numero completo y Copiar, fechas con iconos,
  valor opcional, copia documental, Editar y recordatorio secundario. Un scroll
  interior cuando haga falta; sin tabla ni tarjetas anidadas.
- Aseguradora se elige desde un unico buscador; nombre manual solo tras la
  excepcion explicita. Telefonos particulares contraidos, sin borrar los legados.
- Calendario Material en espanol, meses/anos/dias legibles, sin escritura manual
  obligatoria. Localizacion limitada al flujo; no limitar el TextScaler.
- Un valor COP original y periodo. Equivalente anual/mensual solo de referencia,
  nunca financiacion ni pago comprobado. Cambiar vista no redondea el origen.
- Servicios oficiales dependen de evidencia por canal; canales particulares
  separados. Ausencia de evidencia no demuestra exclusion de una poliza.
- Sesion/FLAG_SECURE se mantienen en rutas anidadas. Evidencias automatizadas
  ficticias se identifican como tales; no desbloquear capturas privadas para QA.
- Candidato instalado, aprobacion visual pendiente. Ver
  codex/C13_INSURANCE_POLICY_HANDOFF.md y C13_INSURANCE_DIRECTORY_AUDIT.md.

## Seguro y asistencia: vista previa del owner (2026-09-13)

- Extension C13 solo de seguro voluntario. C25, leads, envio, monetizacion y
  banner comercial publico permanecen desactivados.
- Banda bitmap local de carretera/ciudad/escudo, texto nativo y CTA amarillo.
  Requiere simultaneamente flavor dev y APP_ENV=dev. Identificacion Vista previa;
  no empresa ficticia, ni formulario que acepte cedula/contacto reales.
- Correccion aprobada: portada unica sin AppBar, titulo superior, pestanas ni
  scroll vertical. Regreso dentro del banner (superficie 36 dp, objetivo 48 dp);
  sin promocion o durante carga/error/vacio, regreso en franja compacta.
- Imagen completa en carrusel estable; tocar abre registro o poliza protegida
  segun el estado del vehiculo tocado. Deslizar no abre hojas. Placa horizontal
  centrada de 80 dp en Seguro, numero adicional escalable y acceso documental independiente
  de los metadatos de poliza. Cambiar vehiculo queda fuera de la promocion.
- Ajuste posterior del owner: banner normal aproximadamente 50% mayor (Mi A3:
  186 a 279 dp), con titular, paisaje, escudo y CTA. Compactar primero acciones
  y textos secundarios; en el telefono corto se permite menor area de vehiculo
  sin recortar la imagen. En accesibilidad extrema, detalle promocional en hoja.
  Espacio restante favorece al vehiculo; nunca encoger fuentes ni agregar vistas.
  Con texto normal conservar titular y explicacion exactos del mockup en ambos
  estados, no sustituirlos por una frase corta ni ocultar el parrafo de cotizacion.
  Acciones inferiores con iconos, etiquetas, flechas y separacion visual del
  mockup; variante accesible conserva etiquetas breves completas y semantica.
- Revision 14/09: conservar banner y aumentar el vehiculo mediante espacio real
  contenido, no Transform.scale. Placa micro nativa 80 dp / proporcion 2.15:1;
  numero objetivo 20 dp y minimo medido 17 dp para formatos normales. Nunca
  encoger toda la placa para simular el nuevo tamano: solo la fila de numeros
  excepcionales y municipio pueden ajustarse internamente. La variante es opt-in
  de Seguro; los otros modulos conservan sus placas. Controles siguen en 48 dp.
- Segundo aumento solicitado: en Mi A3 normal el slot pasa de 112 a 144 dp.
  Franja de poliza y acciones compactas de 48 dp; icono y etiqueta en una fila.
  El espacio recuperado se asigna a imagen completa, no a mas promocion.
  Texto ampliado mantiene la distribucion medida previa, sin encoger fuentes.
- Poliza ausente no implica vehiculo sin asegurar. Estado documental accesible
  aunque no haya metadatos de poliza. Contactos solo por accion, mostrando alcance.
- Asistencia en ruta opaca sin banner visible. Billetera con autorizacion,
  FLAG_SECURE y visor interno compartidos; sin exportar/adjuntar documentos.
- Directorio offline con fuente por canal; las observaciones inactivas no generan
  acciones. La cotizacion demostrativa no transmite ni persiste solicitudes.
- Aprobacion visual pendiente; la importacion/autenticacion positiva fisicas
  anteriores siguen abiertas. Detalles: codex/C13_INSURANCE_SINGLE_HOME_HANDOFF.md.

## Impuestos: vista previa instalada, aprobacion visual pendiente (2026-09-13)

- Extension autorizada de C13: directorio tributario nacional parcial y calendarios
  versionados mediante el publisher B01 existente. No estimacion, deuda, estado de
  pago ni recordatorios tributarios nuevos. No nuevas tablas ni dependencias.
- Hero navy continuo con entidad, autoridad y placa compartida de 96 dp. Buscar
  entidad abre consulta temporal; Guardar para este vehiculo es accion separada.
  La matricula sugiere entidad; GPS, ciudad de Pico y favorito no se modifican.
- Portal oficial antes del historial; fuente en hoja. Fechas pasadas agrupadas,
  condiciones visibles, prorroga vigente sin duplicar el plazo sustituido.
  Conceptos adicionales publicados se consultan por separado en informacion.
- Escala de letra real, filas adaptables y un scroll vertical. Sin compresion de
  fuentes ni reserva inferior adicional a la navegacion del shell.
- Respaldo local validado; recuperacion degradada se advierte. La actualizacion
  remota necesita endpoint real y evidencia en la misma APK: permanece pendiente.
- La implementacion no tiene aun aprobacion visual ni cierre tecnico global.

## Fotomultas departamental: mapa protagonista (2026-09-12)

- Cabecera navy 72 dp normal; titulo 20 sp, departamento 14 sp completo. Lista/Mapa
  pasa a icono tactil de 48 dp cuando la etiqueta compite con el titulo ampliado.
- Mapa ocupa el espacio entre cabecera y navegacion, sin scroll exterior. Busqueda
  y conteo/filtros superpuestos arriba; fuente/Conducir y atribucion abajo.
- Zoom y encuadrar ARRIBA a la derecha: 12 dp bajo la banda superior, 12 dp del
  borde derecho. Superficie 36 dp, blanco .78, icono 22 dp, objetivo 48 dp.
- La variante compacta usa iconos realmente de 48 dp, con tooltip, nombre completo
  y accion accesible. Conteos filtrados no provocan cambios de variante.
- Aviso unico de teselas/resultados, a la izquierda de zoom; atribucion separada.
- Busqueda y filtros se confirman desde borradores; cancelar no cambia la consulta.
  Lista/Mapa conserva controlador y encuadre. No cambios en inventario ni GPS.
- Preview instalada; ultima correccion de posicion pendiente de aceptacion visual.

## Fotomultas: seleccion compacta y mapa flexible (2026-09-12)

- Cabecera nacional: Fotomultas 20 sp, inicio tras flecha de 48 dp con separacion
  4 dp. A la derecha, camara/conteo 14 sp y ANSV + fecha real dd/MM/yy 12 sp.
  Sin otra franja de inventario bajo el buscador. Si las metricas de texto no
  permiten una fila, cabecera accesible en dos niveles, sin FittedBox ni recortes.

- Excepcion autorizada: exploracion manual en Apps del inventario parcial local;
  no seguimiento GPS ni cambios de Conducir. No recuadro insular dedicado.
- Sin seleccion no existe tarjeta ni reserva. Con seleccion, tarjeta debajo del
  mapa: nombre 16 sp, conteo 14 sp y Ver camaras lateral, sin avatar de abreviatura.
- Altura normal aproximada 74 dp; nombres largos pueden crecer. Cuando quitarian
  al mapa su minimo de 220 dp, fila hacia hoja con toda la informacion. Nombre
  extremo con accesibilidad: Ver departamento con nombre completo en tooltip/hoja.
- Mas altura de pantalla corresponde al mapa, no al resto de los controles.
  Seleccionar no cambia centro/zoom; buscar y Ver Colombia reencuadran expresamente.
- Ver Colombia y zoom nacionales: superficie 36 dp, blanco alpha .78, area tactil
  48 dp; letra normal 13 sp, icono accesible al ampliar. Sin sombra opaca grande.
- Preview tecnico no equivale a aceptacion visual; se compara fisicamente.

## Detalle del vehiculo: mockup sin scroll (2026-09-11)

- Vista previa pendiente de aprobacion visual. El nuevo mockup del owner define
  fondo navy, vehiculo completo y cambio visual desde imagen o camara teal.
- Placa aprobada de 96 dp con texto normal. Solo en este detalle, el ancho puede
  crecer con accesibilidad hasta 192 dp para evitar una columna ilegible; no se
  reducen fuentes ni se altera Inicio/Garaje/Pico. Emblema y pie se conservan.
- Identidad: apodo, marca/modelo o Mi vehiculo; matricula y Editar. Letra ampliada
  puede convertir Editar en icono con ayuda accesible para dar ancho a la ciudad.
- Orden normal: Pico, SOAT, RTM, Seguro/Impuestos, Eliminar. Sin scroll. Medicion
  de textos/controles y espacio real antes de asignar altura a la imagen.
- Si no cabe: primera vista con identidad, Pico, SOAT y Mas gestiones; segunda
  con RTM, Seguro, Impuestos y Eliminar. Regreso interno antes de salir de ruta.
- No activo/favorito adicional; ninguna accion del detalle cambia favorito.
  Volver respeta el origen; guardar una edicion conserva la pila existente.
- Eliminar mantiene confirmacion y cinco segundos de Deshacer antes de limpiar
  datos privados. Volver de Mas gestiones cancela una eliminacion pendiente.
- Estados de obligaciones proceden de datos guardados. Carga/error no se
  representan como Sin configurar; impuestos conserva calendarios/portales.
- Matriz portrait 360x780/800, 390x844, 412x915 y 430x932 con texto 1/1.5/2.
  Pantallas landscape extremadamente bajas no forman parte de la aceptacion.

## Garaje: favorito unico y prioridad de Inicio (2026-09-11)

- Decision explicita del owner: el antiguo activo se presenta como Favorito.
  La seleccion interna existente permanece; no son dos preferencias sincronizadas.
- Garaje: Todos / Favorito. Un unico control de favorito por vehiculo, objetivo
  tactil de 48 dp; quitar estado Activo/No activo y Hacer activo tambien del detalle.
- La tarjeta informativa reduce altura naturalmente; no compensar con espacios,
  tipografia mayor ni crecimiento artificial del carrusel. Placas aprobadas intactas.
- Inicio destaca restriccion activa, pendiente o finalizada hoy; luego proxima
  restriccion verificada hasta siete dias, datos inciertos y orden alfabetico.
  Esta eleccion no cambia favorito. El resumen continua describiendo hoy.
- Aplicar prioridad al abrir o volver desde otra pestana, no por ticks, swipes,
  recarga de datos ni regreso del detalle. Consultas abiertas conservan su vehiculo.
- Estado de este lote: vista previa pendiente de aprobacion. No certifica el cierre
  tecnico previo, rendimiento, ni autoriza merge.

## Mi pico y placa: vehiculo protagonista y mes directo (2026-09-11)

- Plan del owner: esta pantalla personal usa cabecera navy con regreso y un solo
  titulo "Mi pico y placa". No muestra marca, avatar ni notificaciones duplicadas.
  Inicio permanece aprobado visualmente y conserva su accion.
- Hero personal: fondo local ilustrativo de ciudad/carretera, no GPS ni mapa.
  Nombre centrado arriba (apodo, marca/modelo o "Mi vehiculo"), vehiculo completo
  dominante y placa aprobada centrada sobre el borde inferior del hero, mitad
  dentro y mitad fuera del fondo. La placa es secundaria frente al vehiculo:
  78 dp con texto normal y 88 dp con texto ampliado. El hero normal debe ser
  bajo, no una tarjeta alta que empuje el calendario.
- La ciudad consultada vive en una fila compacta con pin bajo el hero y muestra
  el nombre real ("Medellin", "Bogota", etc.), no el texto generico "Cambiar
  ciudad". Al tocarla abre el selector temporal. No cambia GPS, ciudad global,
  favorito ni foco de Inicio.
- Resumen navy compartido con Inicio, sin accion recursiva en Pico. Mismos estados,
  horario unico, contador de minuto y aguja decorativa con pausas ya aprobadas.
- Sin bloques independientes "Hoy...", "Estado inmediato", motivo exterior ni
  tarjetas anidadas. El motivo comprobable se muestra al tocar un dia del mes.
- Mes directo: sin selector "Proximos dias / Mes" ni tarjetas horizontales en la
  vista personal. Encabezado de mes con flechas, dias Lun/Mar/Mie/Jue/Vie/Sab/Dom,
  cuadricula compacta de siete columnas con margen horizontal interno y casillas
  fuera del mes neutras/no interactivas. Las celdas son casi cuadradas y bajas,
  no tarjetas verticales grandes ni un bloque de borde a borde; el mes debe
  liberar espacio para el resto de la pantalla.
- Estados del mes: check verde, prohibicion roja con menos e interrogante ambar.
  El numero del dia y el simbolo se separan; hoy conserva borde navy. Leyenda
  centrada: Libre, Restriccion y Por verificar.
- Tocar un dia abre hoja con fecha, estado, horarios, motivo si existe y fuente.
  Cerrar no sustituye el resumen de hoy ni cambia el mes consultado.
- Proxima restriccion se calcula localmente desde manana hasta 30 dias. No convierte
  datos vencidos/desconocidos en dias libres ni inventa vigencias.
- Fuente y vigencia abre una hoja adicional, no un desplegable dentro del contenido.
  Muestra fuente, ultima verificacion, vigencia publicada y revision de datos por
  separado; abrir sitio oficial requiere accion expresa.
- Un solo scroll vertical en pantalla principal; el calendario no tiene scroll
  interno. Hojas auxiliares pueden desplazarse con texto ampliado. Sin FittedBox,
  recortes ni scroll horizontal. Celdas del mes conservan tamano tactil util.
- Pruebas tecnicas no constituyen aprobacion visual; la vista previa fisica y la
  aprobacion del owner siguen pendientes antes del cierre/publicacion.

## Inicio: horario y cuenta regresiva (2026-09-11)

- Peticion posterior del owner: el icono de reloj tendra una aguja que avanza
  6 grados cada segundo, una vuelta por minuto. Excepcion al icono estatico del
  plan anterior: solo repinta el reloj de 16 dp, no el texto ni toda la tarjeta.
  Pulso visual local de 1 Hz, sin animacion a 60 fps; detener al ocultar la ruta,
  TickerMode desactivado, background, movimiento reducido o retirar el contador.
  No usa segundos para calcular ni mostrar la restriccion.
- Solo en la tarjeta de restriccion de Inicio: etiqueta "Tiene pico y placa hoy",
  horario(s) una sola vez en 18 sp, contador con reloj y ciudad en al menos 14 sp.
- Antes: "Empieza en 4 h". Durante: "Termina en 2 h 15 min". Varios tramos:
  "Este tramo termina en..." hasta el final del tramo activo; en pausa, mostrar
  "Sin restriccion ahora" y "Proximo tramo en..." conservando todos los horarios.
- Tras el ultimo tramo: "Restriccion finalizada", sin horario ni contador;
  conservar la etiqueta del dia restringido. Dias libres mantienen la tarjeta
  verde aprobada. Datos desconocidos/vencidos o sin ventanas fiables no generan
  cuenta regresiva ni una afirmacion de restriccion horaria confirmada.
- Calculo desde hora real de Bogota, redondeado hacia arriba a minutos completos.
  Calculo compartido existente: sin nuevo timer de cuenta, segundos ni liveRegion.
  Mantener descripcion accesible de fase, horario, contador y ciudad.
- Un tramo y texto normal: 100-108 dp de altura. Varios tramos o letra ampliada
  pueden aumentar altura; nunca recortar horarios, encoger fuentes o ocultar datos.
- Toda la tarjeta conserva la apertura de Pico del vehiculo enfocado. Sin cambios
  a la tarjeta personal de Pico, GPS, reglas, vehiculos ni notificaciones.

## Ajuste vigente aprobado: placa secundaria (2026-09-11)

- Correccion adicional de centrado: apodo, marca o "Mi vehiculo" centrados
  respecto a toda la tarjeta del carrusel, no al espacio restante tras el icono.
  Reservar 32 dp a cada lado del titulo (icono 24 + separacion 8 a la izquierda).
  La medicion de titulos largos considera ambas reservas; no encoger fuentes.
- Reemplaza las medidas de 128 dp documentadas en el historial inferior.
  El owner aprobo visualmente la placa de 96 dp, aproximadamente 46 dp de alto,
  numero 20 sp, emblema 7 dp y municipio 10 sp. Sin deformar ni escalar la placa.
- Tres filas: ranuras superiores, numero/emblema y municipio entre ranuras
  inferiores. Municipio y ranuras inferiores alineados a 1 dp; centro del numero
  aproximadamente al 40% de altura. Mantener borde negro exclusivamente interior.
- Con texto normal la placa no superara 2/3 del ancho visible del vehiculo en
  Inicio. Medir pixeles del asset dibujado, no el contenedor transparente.
  Texto ampliado o municipio largo puede aumentar altura sin ocultar caracteres.
- Separacion de la placa en Inicio: arriba 2 dp y abajo 4 dp. Espacio recuperado
  para el vehiculo, manteniendo imagen completa y proporcion original.
- Nueva peticion posterior a aprobar la placa: SOAT/Tecnomecanica de 72 a 64 dp
  con texto normal. Solo reducir padding vertical de 8 a 4 dp; conservar fuentes,
  iconos, contenido y acciones. Con texto ampliado adaptar altura. La medicion
  existente asigna el espacio liberado al carrusel. Sin cambiar tarjeta verde.

## Historial de vista previa rechazada: placas e Inicio (2026-09-11)

- La vista anterior de placas fue rechazada por tamano y emblema ausente. No es
  referencia aprobada. El cierre queda condicionado a aprobacion visual del owner.
- Ajuste posterior del owner: conservar diseno, reducir superficie y aumentar
  letras. Placa detallada compacta: ancho 128 dp, altura normal 57-60 dp con
  municipio corto, numero 26 sp, pie 10 sp, emblema 9 dp. Margenes internos
  reducidos; no escalar caracteres. Escala del sistema respetada. El ensayo de
  124 dp no admitio todos los grupos anchos con numero de 26 sp en una fila.
- Agrupacion visual de seis caracteres alfanumericos en 3 + 3, sin alterar ni
  validar la matricula. Otros formatos se conservan completos. Accesos de Pico
  ciudad de 154 dp permiten mostrar la placa sin comprimirla.
- Inicio sin restriccion del dia: check circular verde grande sobre disco claro,
  etiqueta verde clara "Sin pico y placa hoy", "Puede circular" blanco sin
  subrayado y pin/ciudad debajo. Referencia:
  [tarjeta permitida owner](design/reference/home_allowed_owner_20260911.png).
- Tarjeta de 100-108 dp con texto normal; sin altura maxima rigida para letra
  ampliada o ciudad larga. Los demas estados del motor no cambian.
- Primero instalar y comparar la vista previa en Mi A3; esperar aprobacion
  antes de suite completa de cierre, commit, push y PR. Sin merge.

## Placas compartidas: correccion owner (2026-09-10)

Referencia: [placa owner](design/reference/plate_owner_20260910.png).

- Esta revision amplifica el opt-in anterior de Inicio a Garaje, Mi Pico y los
  accesos de vehiculos en Pico por ciudad; otras superficies conservan su placa.
- Fondo amarillo para particular/moto, blanco para taxi; sin trazo negro exterior.
  Un unico borde negro interior deja margen de color visible. Cuatro ranuras
  horizontales interiores, sin invadir el numero ni el pie.
- Dos grupos de caracteres con espacio real para un emblema circular dibujado
  en Flutter. Monograma propio inspirado en la referencia, no sello oficial de
  autenticidad ni marca de agua. Formatos excepcionales conservan todos sus caracteres.
- El pie muestra solo el municipio registrado en mayusculas, resuelto con el
  catalogo local existente; moto o registro vacio muestran COLOMBIA. Texto antiguo
  sin correspondencia se conserva, nunca se corta por guiones arbitrariamente.
- La placa no modifica datos guardados ni selecciona la jurisdiccion de Pico.
  No consulta red. Carga compartida local fuera de la barrera critica de Inicio.
- Proporcion orientativa 2.15:1 con texto normal. Sin reducir toda la placa con
  FittedBox; texto ampliado puede reorganizar grupos y aumentar la altura. Los
  carruseles reservan espacio al vehiculo y al pie en lugar de recortar contenido.
- Evidencia antes/despues y variantes automatizadas deben distinguirse. El
  emblema es una adaptacion, no una reproduccion certificada de placa fisica.

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
- Con texto ampliado, la marca de Conducir respeta el ancho del encabezado
  mediante reflujo; no se reduce la fuente ni se recorta el nombre.
- La comparacion fisica conserva el contenido de Inicio. El indicador GPS
  puede cambiar por su estado real. El crossfade nativo/Flutter aun muestra
  un breve desplazamiento de la marca; no se declara continuidad perfecta.

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
