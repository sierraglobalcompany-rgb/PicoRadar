# C13: revisión de servicios del directorio, 2026-09-14

Fecha real de revisión editorial: **2026-09-14**. Asset **2026-09-14.1**,
schemaVersion **1**, compatible con canales anteriores sin servicios/condiciones.
Esta sección sustituye las conclusiones de servicios del registro histórico
conservado abajo. No certifica cobertura de una póliza ni respuesta operativa.

## Resultado e identidad

Se contrastaron las **16 referencias existentes** con la
[lista Fasecolda](https://www.fasecolda.com/ramos/automoviles/companias-autorizadas/)
y la [publicación SFC](https://www.superfinanciera.gov.co/publicaciones/61694/industrias-supervisadasentidades-vigiladas-por-la-superintendencia-financiera-de-colombialista-general-de-entidades-vigiladas-por-la-superintendencia-financiera-de-colombia-61694/),
modificada el **2026-09-01**. Se descargó y leyó nuevamente en memoria el
[XLSX oficial SFC](https://www.superfinanciera.gov.co/loader.php?idFile=1004011&lFuncion=descargar&lServicio=Tools2&lTipo=descargas),
con XML estructurado de sharedStrings/worksheets, sin incorporar archivos ni
dependencias al proyecto. Los 16 códigos de la tabla histórica permanecen
contrastados. Tipo 13 identifica seguros generales; tipo 15, cooperativas.
La SFC acredita identidad, no teléfonos de asistencia ni coberturas. Liberty
permanece separada como 13-45; no se agrega alias HDI. Bolívar se mantiene
vinculada a Seguros Comerciales Bolívar, 13-27, conservando los aliases legados.

Inventario: **60 contactos, 54 habilitados, 6 deshabilitados**. No se elimina
ninguna observación previa ni se habilita un canal disputado. **34 canales**
tienen al menos un servicio publicado; otros 20 habilitados son contactos sin
ruta de servicio acreditada. Se mantienen las categorías previas: esta revisión
no es un nuevo censo de productos para carros, motos o taxis.

Se auditaron las 64 combinaciones de 16 entidades por 4 servicios. Hay una ruta
verificada para **39/64**: asistencia general 11 entidades, grúa 9, conductor
elegido 10 y carro taller 9. **25/64 pendientes**. Una de las 39 combinaciones
también conserva una alternativa contradictoria deshabilitada (MAPFRE general).
Por estado principal de la matriz: **38 verified, 1 conflicting, 25 pending**.
No afirmar `allColombia`, exhaustividad nacional o disponibilidad para toda póliza.

### Límite nacional y entidades adicionales SFC

El inventario auditado procede de las **16 referencias Fasecolda**. El cruce
con SFC confirma sus identidades jurídicas y permite detectar entidades
adicionales o separadas; no equivale a auditar la oferta de automóviles de
todas las entidades vigiladas. La presencia en SFC, por sí sola, no demuestra
una oferta vehicular vigente ni acredita un canal o servicio de asistencia.

**Liberty Colombia, código SFC 13-45**, es la entidad adicional identificada
expresamente en este contraste. No se incorpora como una referencia número 17
ni como alias de HDI: en esta revisión no quedó verificada una oferta actual
propia de seguros de automóviles con evidencia primaria suficiente para su
incorporación. Esto significa **evidencia pendiente**, no que se haya probado
la inexistencia de esa oferta, su retiro del mercado o su falta de autorización.
Su identidad diferenciada sí quedó contrastada en el XLSX SFC citado arriba.

La consideración de posibles entidades adicionales queda documentada con ese
hallazgo y su motivo de no incorporación. No se afirma haber evaluado todas
las demás entidades SFC ni que las 16 referencias sean la totalidad nacional.
Una ampliación exige verificar identidad y oferta vehicular vigente en fuentes
primarias; cada canal y servicio requerirá además su propia evidencia de alcance.

## API para la hoja

```dart
enum InsuranceService {
  generalAssistance,
  towing,
  designatedDriver,
  roadsideRepair,
}

// Parámetros opcionales añadidos al constructor const existente:
// this.services = const [], this.conditions,
// final List<InsuranceService> services;
// final String? conditions;
```

JSON: `services` es una lista de los nombres exactos del enum; `conditions` es
texto opcional o null. Si faltan, el resultado es lista vacía/null. La lista
producida por el parser es inmutable. La fábrica rechaza listas nulas o mal
tipadas, servicios desconocidos/repetidos, condiciones vacías/no textuales y
servicios en canales deshabilitados o de `customerService`. Se conserva el
constructor const y su firma anterior; como los demás constructores de datos,
no sustituye la validación del parser para entradas externas.

La evidencia se vincula al canal por `sourceUrl` y `reviewedAt`. Las fuentes
complementarias de producto/clausulado se identifican expresamente en la matriz
y notas; no se atribuye a una portada un detalle que solo aparece en el anexo.
`reviewedAt` de entidad indica revisión editorial; en contactos con extracción
incompleta se conserva **2026-09-13**, la última revisión documentada. Todos los
canales que reciben servicios en esta entrega tienen revisión **2026-09-14**.

Usar `company.verifiedChannels` y después `channel.services.contains(service)`.
`generalAssistance` no implica grúa/conductor/taller; un servicio específico
tampoco implica asistencia general. Lista vacía significa **sin ruta acreditada**,
no servicio excluido por la póliza. `conditions` y el label deben mostrarse.
No duplicar un canal por servicio: un canal contiene varios servicios. El parser
rechaza destinos repetidos dentro de la entidad aunque cambien ID, propósito o
prefijo nacional (`601...`, `57601...`, `+57601...`). Teléfono y WhatsApp son
canales diferentes; esa distinción no autoriza inferir WhatsApp desde un teléfono.

## Matriz entidad por servicio

Revisión de todas las filas: **2026-09-14**. `V` = verified: al menos una ruta
publicada. `P` = pending: falta vínculo suficiente entre servicio y canal de
autos, incluso si existe el producto. `C(V)` = conflicting: alternativa
contradictoria bloqueada, con otra ruta verificada. Ningún estado significa
cobertura del usuario. Las notas delimitan exactamente los canales.

| Entidad / código SFC | General | Grúa | Conductor | Carro taller | Fuentes primarias de esta revisión y alcance |
|---|---|---|---|---|---|
| Allianz / 13-1 | V | V | V | V | [Llave en Mano](https://www.allianz.co/seguros/vehiculos/Autos/llave-en-mano.html): servicios y #265; [líneas](https://www.allianz.co/contacto/lineas-de-atencion.html): fijos siguen atención. |
| Solidaria / 15-2 | V | P | P | P | [Portada oficial](https://aseguradorasolidaria.com.co/): CAMI WhatsApp recibe solicitudes; no enumera los tres servicios por ese canal. |
| AXA / 13-6 | V | V | V | P | [Autos](https://www.axacolpatria.co/seguro-de-auto): planes y líneas de asistencia; carro taller no acreditado en esta revisión. |
| BBVA / 13-41 | P | P | P | P | [Autos](https://www.bbvaseguros.com.co/seguros-autos/): atención/siniestros; [asistencias](https://www.bbvaseguros.com.co/asistencias/): hogar y vida. No trasladar esos alcances a autos. |
| Equidad / 15-1 | P | P | P | P | [Siniestros](https://www.laequidadseguros.coop/contacto/que-hacer-en-caso-de-siniestros/): 403 en lectura directa; [Auto Protegido](https://www.laequidadseguros.coop/productos/seguros-generales/seguros-de-autos-y-rc/auto-protegido/): extracto indexado oficial enumera producto, sin resolver canal. |
| HDI / 13-33 | V | P | V | V | [Asistencias](https://www.hdiseguros.com.co/asistencias): teléfonos generales separados de WhatsApp conductor/carro taller. |
| MAPFRE / 13-26 | C(V) | V | V | V | [Contacto](https://www.mapfre.com.co/contacto/): WhatsApp enumera los tres servicios; [SI24](https://www.mapfre.com.co/contacto/mapfre-si-24/): nacional habilitado. |
| Quálitas / 13-52 | V | V | V | V | [Portada](https://www.qualitascolombia.com.co/web/qco/inicio) y [solicitud](https://www.qualitascolombia.com.co/como-puedo-pedir-una-asistencia): líneas de asistencia; clausulado Q1 debajo acredita servicios. |
| Previsora / 13-24 | V | V | V | V | [Siniestros/asistencia](https://previsora.gov.co/web/personas/automoviles-siniestros) y [Autos Livianos](https://www.previsora.gov.co/web/personas/autos-livianos): las tres prestaciones del producto. |
| SBS / 13-22 | P | P | P | P | [Portada](https://www.sbseguros.co/): atención; [Autos](https://clientes.sbseguros.co/autos): producto/conductor. No se logró acreditar despacho vehicular de los contactos existentes. |
| Alfa / 13-25 | P | P | P | P | [Líneas](https://www.segurosalfa.com.co/lineas-de-atencion) y [asistencias](https://www.segurosalfa.com.co/asistencias): extracción incompleta; documentos recuperados de vida/AP no acreditan autos. |
| Mundial / 13-17 | V | V | V | V | [Rodando Contigo](https://www.segurosmundial.com.co/personas/seguros-personales/movilidad/rodando-contigo): asistencias del producto y líneas; WhatsApp permanece orientación. |
| Bolívar / 13-27 | V | V | V | V | [Autos Básico](https://digital.experienciasbolivar.segurosbolivar.com/recorrido-seguro-autos-basico): teléfono/numeral/WhatsApp, Básica y Full separados. |
| Estado / 13-29 | V | V | V | V | [FamiEstado](https://www.segurosdelestado.com/productos/productos/1114): grúa, conductor, auxilio vial básico y líneas de asistencia. |
| SURA / 13-18 | V | V | V | V | [Clausulado 16/03/2026](https://www.sura.co/documents/d/seguros/condicionado-seguro-de-autos), sección 6, pág. 37: teléfonos y WhatsApp para solicitar asistencias; [FAQ](https://www.sura.co/seguros/centro-de-ayuda/preguntas-frecuentes): anticipación. |
| Zurich / 13-9 | P | P | P | P | [Movilidad](https://www.zurichseguros.com.co/lineas-personales/movilidad), [carro taller](https://www.zurichseguros.com.co/blog/articulos/2025/01/carro-taller-tu-asistente-vial-en-carretera): producto sin teléfono de despacho acreditado. |

Q1: [Póliza oficial Quálitas, autos y pickups de uso personal 01082025](https://www.qualitascolombia.com.co/documents/20125/1324554/POLIZA%2BDE%2BSEGURO%2BPARA%2BAUTOS%2BY%2BPICKUPS%2BDE%2BUSO%2BPERSONAL%2B01082025%2B2.pdf/d5934887-f41e-e48a-1d0c-e9b50f7b5b2f?t=1779123635167).
Servicios sujetos a las ciudades habilitadas, al plan y a sus límites; no aplicar
automáticamente a otros productos/vehículos. Fuente de contactos conservada en
los tres canales: portada oficial que publica asistencia 24 horas.

## Restricciones y contradicciones

- **HDI:** WhatsApp `573164821802` solo recibe `designatedDriver` y
  `roadsideRepair`, sin general ni grúa. Conductor exige al menos 2 horas de
  anticipación, espera máxima de 15 minutos y ciudades/radio publicados. Carro
  taller tiene otra lista de ciudades y extensión de 40 km por carretera
  pavimentada. `conditions` remite a ambas listas y a la póliza. Teléfonos #224,
  6013077050 y 018000113390 reciben exclusivamente `generalAssistance` en el
  catálogo: confirmar el servicio particular. [Fuente](https://www.hdiseguros.com.co/asistencias).
- **AXA:** las tres líneas conservan general, grúa y conductor según el plan.
  Fuente de canales corregida al HTML de autos, donde son visibles; el PDF
  anterior no permitió corroborar números mediante extracción. WhatsApp
  `573124457921` sigue inactivo: publicación expresamente informativa de
  renovación, no chat de asistencia. [Aviso oficial](https://www.axacolpatria.co/es/-/actualidad-axa-colpatria-evita-caer-en-estafas-al-renovar-tu-seguro-de-autos).
- **MAPFRE:** `573188030276` acredita los cuatro servicios. #624 y
  018000519991 conservan solo general; Bogotá sigue atención. 018000516991 sigue
  bloqueado por discrepancia entre el bloque SI24 y los otros bloques oficiales.
  No copiar los servicios WhatsApp a cualquier teléfono por compartir entidad.
- **SURA:** los seis canales reciben los cuatro servicios desde el clausulado
  actual. Esto reclasifica Bogotá/Medellín/Cali de atención a asistencia con
  evidencia explícita. La FAQ vincula conductor por teléfono a anticipación de
  4 horas; número de eventos, límites y clase de vehículo dependen del plan.
- **Bolívar:** #322, 018000123322 y WhatsApp 573223322322 tienen los cuatro
  servicios. Conductor elegido pertenece a Full en la publicación; grúa y carro
  taller a Básica. Bogotá 6013122122 conserva el contacto y fecha anterior,
  con servicios vacíos: su fuente específica devolvió timeout en esta revisión.
- **Previsora:** la página de siniestros acredita #345 (Tigo/Claro), 018000910554
  y 6013487555. Un [documento institucional de abril 2026](https://www.previsora.gov.co/documents/20121/4902000/Documento%2Bde%2BCondiciones%2BDefinitivas.pdf/f7123cae-7f71-f761-a7e0-885be12e0f8e?t=1777058643622)
  contiene otra cifra Bogotá y un WhatsApp; no se agregan desde un pie de
  contratación. Se prioriza la página funcional y se deja pendiente aclarar la
  inconsistencia institucional. El alcance de los servicios procede de Autos
  Livianos, sin extenderlo automáticamente a motos.
- **Equidad/SBS:** oferta de un servicio y presencia de un número en la portada
  no bastan para clasificar ese contacto como ruta vehicular. La lectura directa
  Equidad falló; se conservan sus cuatro contactos de siniestros y fechas previas.
  SBS publica atención y productos; no se reutiliza la asistencia de su producto
  de viajes para autos. No se usaron directorios comerciales para activar canales.
- **BBVA/Alfa/Zurich:** atención permanece disponible; no se crea asistencia
  desde productos de hogar, vida, banco o accidentes personales. Alfa mantiene
  categorías vacías y contactos con revisión previa. Zurich #723 está publicado
  para [ecomovilidad](https://www.zurichseguros.com.co/beneficio-rutasegura-ecomovilidad),
  no demuestra grúa de autos; no se agrega. La lectura de páginas de Zurich fue
  intermitente y no resuelve despacho de sus teléfonos generales.

Seis observaciones originales permanecen deshabilitadas, con `services: []`:

| Canal | Estado / motivo | Fuente |
|---|---|---|
| solidaria-legacy-national, solidaria-legacy-mobile | conflicting: convivencia de antiguos teléfonos con nueva portada sin aclarar | [Portal previo](https://www.solidaria.com.co/WAPQRRadicacion/ConsultarEstadoPQRS), [portada](https://aseguradorasolidaria.com.co/) |
| axa-informational-only | conflicting con uso de asistencia: solo información saliente | [Aviso renovación](https://www.axacolpatria.co/es/-/actualidad-axa-colpatria-evita-caer-en-estafas-al-renovar-tu-seguro-de-autos) |
| hdi-disability-legacy | conflicting: cifra distinta en accesibilidad | [Contacto](https://www.hdiseguros.com.co/centro-de-informacion-y-contacto) |
| mapfre-disputed-national | conflicting: 516991 frente a 519991 | [Contacto](https://www.mapfre.com.co/contacto/), [SI24](https://www.mapfre.com.co/contacto/mapfre-si-24/) |
| zurich-unresolved-whatsapp | pending: accidentes personales Carnaval, no autos | [Producto Carnaval](https://www.zurichseguros.com.co/zurich-carnaval/accidentes-personales) |

## Handoff del sidecar

Estado **PARTIAL** por validación de ejecución pendiente del padre; implementación
y revisión editorial entregadas dentro del scope C13. No cierra el lote completo.

- Branch: `codex/insurance-owner-mockup`.
- HEAD leído: `ddf60407174e3ee8d447b7eff3ca45e0fd983789`; sin commits propios.
- Base: worktree compartido existente; no se modifica rama ni base.
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
- Archivos: `mobile/lib/features/vehicle_status/data/insurance_directory.dart`,
  `mobile/assets/catalogs/insurance_directory_v1.json`,
  `mobile/test/features/vehicle_status/data/insurance_directory_test.dart`,
  `codex/C13_INSURANCE_DIRECTORY_AUDIT.md`.
- Cambios: API opcional de servicios/condiciones, asignación editorial por canal,
  deduplicación de destinos, pruebas de compatibilidad y semántica de servicios.
- Pruebas escritas: campos inválidos, defaults legados/const, lista inmutable,
  independencia entre general/específicos, HDI/AXA, pendientes, cifras del asset,
  destinos duplicados con distintos prefijos y teléfono/WhatsApp separados.
- **Tests ejecutados en esta revisión: ninguno.** No se ejecutaron Dart format,
  Flutter analyze, Flutter test, builds o instalación; el padre serializa gates.
  Comando preparado para el padre desde `mobile`:
  `flutter test test/features/vehicle_status/data/insurance_directory_test.dart`.
- QA manual: lectura web oficial y XML SFC; sin llamadas, mensajes ni consultas
  sobre pólizas personales. QA física del sidecar: no requerida; UI a cargo del padre.
- Datos/migración: solo asset local; sin Drift/schema de DB, dependencias,
  permisos, red runtime, PII o envío de información del usuario.
- Riesgos/deuda: fuentes dinámicas, extracciones fallidas documentadas, 25
  combinaciones pendientes; revisar condiciones con cada versión y póliza.
- Siguiente trabajo desbloqueado: integración de la hoja de servicios C13 y
  validación coordinada por el padre. No se inicia otro lote.
- `git status`: worktree con WIP previo de múltiples workers, conservado; los
  cuatro archivos propios ya eran no rastreados. No commit, push, merge ni limpieza.

---

# Registro histórico 2026-09-13 (conservado, no es validación de esta entrega)

Fecha real de revisión: **2026-09-13**. Versión del asset: **2026-09-13.1**.
Alcance de este sidecar: datos, cargador tipado y pruebas. No implementa pantalla,
cotización, comunicaciones automáticas, patrocinio ni selección de aseguradora.

## 1. Inventario y metodología

Se revisaron las **16/16 etiquetas de la referencia Fasecolda**, se contrastaron
sus personas jurídicas con la lista general SFC y se inspeccionaron publicaciones
de cada entidad para los canales. Resultado: **60 observaciones de contacto:
54 habilitadas y 6 inactivas**. No se efectuaron llamadas ni mensajes.

- [Referencia Fasecolda](https://www.fasecolda.com/ramos/automoviles/companias-autorizadas/).
- [Lista general SFC](https://www.superfinanciera.gov.co/publicaciones/61694/industrias-supervisadasentidades-vigiladas-por-la-superintendencia-financiera-de-colombialista-general-de-entidades-vigiladas-por-la-superintendencia-financiera-de-colombia-61694/).
- [XLSX oficial SFC realmente leído](https://www.superfinanciera.gov.co/loader.php?idFile=1004011&lFuncion=descargar&lServicio=Tools2&lTipo=descargas).
  Modificación publicada por SFC: **2026-09-01**, distinta de la revisión del
  catálogo. Se descargó a memoria y se leyeron los XML de la hoja y cadenas
  compartidas; no se agregó el libro ni una dependencia a la aplicación.
- SFC tipo 13 corresponde a compañías generales; tipo 15 a cooperativas.
  La correspondencia identifica la entidad vigilada, no demuestra por sí sola
  una oferta actual para motos/taxis ni certifica cada teléfono.
- Los canales se respaldan en el sitio de la entidad, no en directorios
  comerciales ni números de otros países. WhatsApp exige publicación explícita;
  nunca se deriva de un teléfono. Los enlaces oficiales hacia wa.me/API WhatsApp
  se usaron como corroboración del número, sin abrir conversaciones.
- `verified=true` significa publicación oficial compatible con el propósito
  documentado en la revisión. No significa prueba de respuesta, cobertura
  contratada, vigencia perpetua ni disponibilidad para toda póliza.
- Car/motorcycle/taxi son evidencia de oferta, no certificación de elegibilidad
  del vehículo. No se infieren motos desde SOAT ni taxis desde transporte público.
- **No se afirma exhaustividad nacional**: se completó la revisión de este
  inventario de 16 referencias; siguen pendientes los alcances/canales indicados.
  Alfa permanece en el directorio general, sin categoría de producto comprobada.
  No debe desaparecer por completo porque un filtro por categoría no la devuelva.

## 2. Cruce de entidades

Activos/total cuenta contactos, no sedes ni productos. Los nombres heredados de
`insuranceProviderOptions` se preservan literalmente en `aliases`.

| Nombre e ID | Persona jurídica contrastada SFC | Código SFC | Categorías probadas | Activos/total | Evidencia de canales |
|---|---|---|---|---|---|
| Allianz (`allianz`) | Allianz Seguros S.A. | 13-1 | car | 3/3 | [Sitio propio](https://www.allianz.co/contacto/lineas-de-atencion.html) |
| Aseguradora Solidaria (`solidaria`) | Aseguradora Solidaria de Colombia Entidad Cooperativa | 15-2 | car | 2/4 | [Sitio propio](https://aseguradorasolidaria.com.co/) |
| AXA Colpatria (`axa`) | AXA Colpatria Seguros S.A. | 13-6 | car, motorcycle, taxi | 3/4 | [Sitio propio](https://www.axacolpatria.co/seguro-de-auto) |
| BBVA Seguros (`bbva`) | BBVA Seguros Colombia S.A. | 13-41 | car | 3/3 | [Sitio propio](https://www.bbvaseguros.com.co/seguros-autos/) |
| La Equidad (`equidad`) | La Equidad Seguros Generales Organismo Cooperativo | 15-1 | car, motorcycle | 4/4 | [Sitio propio](https://www.laequidadseguros.coop/contacto/que-hacer-en-caso-de-siniestros/) |
| HDI Seguros (`hdi`) | HDI Seguros Colombia S.A. | 13-33 | car, motorcycle | 4/5 | [Sitio propio](https://www.hdiseguros.com.co/asistencias) |
| MAPFRE (`mapfre`) | Mapfre Seguros Generales de Colombia S.A. | 13-26 | car | 4/5 | [Sitio propio](https://www.mapfre.com.co/contacto/) |
| Quálitas (`qualitas`) | Quálitas Compañía de Seguros Colombia S.A. | 13-52 | car | 3/3 | [Sitio propio](https://www.qualitascolombia.com.co/web/qco/inicio) |
| La Previsora (`previsora`) | La Previsora S.A. Compañía de Seguros | 13-24 | car, motorcycle | 3/3 | [Sitio propio](https://previsora.gov.co/web/personas/automoviles-siniestros) |
| SBS Seguros (`sbs`) | SBS Seguros Colombia S.A. | 13-22 | car, motorcycle | 3/3 | [Sitio propio](https://www.sbseguros.co/) |
| Seguros Alfa (`alfa`) | Seguros Alfa S.A. | 13-25 | Pendiente | 2/2 | [Sitio propio](https://www.segurosalfa.com.co/lineas-de-atencion) |
| Seguros Mundial (`mundial`) | Compañía Mundial de Seguros S.A. | 13-17 | car | 5/5 | [Sitio propio](https://www.segurosmundial.com.co/seguros-mundial-v2/atencion-al-cliente/) |
| Seguros Bolívar (`bolivar`) | Seguros Comerciales Bolívar S.A. | 13-27 | car | 4/4 | [Sitio propio](https://digital.experienciasbolivar.segurosbolivar.com/recorrido-seguro-autos-basico) |
| Seguros del Estado (`estado`) | Seguros del Estado S.A. | 13-29 | car | 3/3 | [Sitio propio](https://www.segurosdelestado.com/) |
| SURA (`sura`) | Seguros Generales Suramericana S.A. | 13-18 | car, motorcycle | 6/6 | [Sitio propio](https://www.sura.co/seguros/centro-de-ayuda/asistencias/choque-simple) |
| Zurich (`zurich`) | Zurich Colombia Seguros S.A. | 13-9 | car | 2/3 | [Sitio propio](https://www.zurichseguros.com.co/lineas-personales/movilidad) |

La etiqueta histórica “Seguros Bolívar S.A.” se conserva por compatibilidad con
Fasecolda y los datos guardados. El ramo general se enlaza a **Seguros Comerciales
Bolívar S.A.**, no a la compañía de vida. Resolver el alias no modifica la póliza
ni acredita que esa sea su emisora real: debe poder corregirse expresamente.

No se incorpora `Liberty` como alias de HDI: la lista SFC consultada todavía
contiene una entidad diferenciada, código **13-45**. No se confunde BBVA con
Zurich por un producto comercializado en alianza.

## 3. Evidencia y pendientes por entidad

Los valores se conservan como cadenas: los ceros iniciales y los numerales son
parte del número. Las restricciones de uso se mantienen en los labels; la UI
debe mostrarlos al elegir un canal, especialmente HDI, Equidad y líneas nacionales.

### Allianz

- Habilitado: `#265`, phone, assistance. Asistencia de autos desde celular. [Evidencia](https://www.allianz.co/clientes/autos/usa-tu-seguro.html); revisión 2026-09-13.
- Habilitado: `6015941133`, phone, customerService. Atención clientes autos · Bogotá. [Evidencia](https://www.allianz.co/contacto/lineas-de-atencion.html); revisión 2026-09-13.
- Habilitado: `018000513500`, phone, customerService. Atención clientes autos · nacional. [Evidencia](https://www.allianz.co/contacto/lineas-de-atencion.html); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.allianz.co/seguros/vehiculos/Autos.html).
- Pendiente/límite: No se verificó WhatsApp de atención/asistencia vehicular en el sitio colombiano. No usar números de otros países.
- Pendiente/límite: Moto y taxi no confirmados en esta revisión.

### Aseguradora Solidaria

- Habilitado: `3232641770`, phone, customerService. Línea de voz Solidaria. [Evidencia](https://aseguradorasolidaria.com.co/); revisión 2026-09-13.
- Habilitado: `573142034106`, whatsapp, assistance. CAMI · solicitudes y asistencias. [Evidencia](https://aseguradorasolidaria.com.co/); revisión 2026-09-13.
- INACTIVO: `018000512021`, phone, customerService. Número anterior · vigencia por confirmar. [Evidencia](https://www.solidaria.com.co/WAPQRRadicacion/ConsultarEstadoPQRS); revisión 2026-09-13.
- INACTIVO: `#789`, phone, customerService. Numeral anterior · vigencia por confirmar. [Evidencia](https://www.solidaria.com.co/WAPQRRadicacion/ConsultarEstadoPQRS); revisión 2026-09-13.
- Producto car: [publicación propia](https://aseguradorasolidaria.com.co/).
- Pendiente/límite: La portada redirigida publica nuevos contactos; los antiguos siguen en portales secundarios. Se preservan inactivos hasta aclarar su convivencia.
- Pendiente/límite: Moto/taxi no confirmados; CAMI no implica cobertura contratada.

### AXA Colpatria

- Habilitado: `#247`, phone, assistance. Asistencia · opción 1-1. [Evidencia](https://www.axacolpatria.co/seguro-de-auto); revisión 2026-09-13.
- Habilitado: `018000512620`, phone, assistance. Asistencia · línea nacional. [Evidencia](https://www.axacolpatria.co/documents/42201273/87551131/clausulado-autos-livianos-feb-2026.pdf); revisión 2026-09-13.
- Habilitado: `6014235757`, phone, assistance. Asistencia · Bogotá. [Evidencia](https://www.axacolpatria.co/documents/42201273/87551131/clausulado-autos-livianos-feb-2026.pdf); revisión 2026-09-13.
- INACTIVO: `573124457921`, whatsapp, customerService. Solo mensajes informativos de renovación · no habilitado para consulta. [Evidencia](https://www.axacolpatria.co/es/-/actualidad-axa-colpatria-evita-caer-en-estafas-al-renovar-tu-seguro-de-autos); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.axacolpatria.co/seguro-de-auto).
- Producto motorcycle: [publicación propia](https://www.axacolpatria.co/es/seguro-de-moto).
- Producto taxi: [publicación propia](https://www.axacolpatria.co/seguro-de-taxi).
- Pendiente/límite: El WhatsApp publicado para autos es únicamente informativo saliente, no atención ni asistencia. Se conserva inactivo; no sustituir por la línea SOAT.

### BBVA Seguros

- Habilitado: `6013078080`, phone, customerService. Atención al cliente · Bogotá. [Evidencia](https://www.bbvaseguros.com.co/seguros-autos/); revisión 2026-09-13.
- Habilitado: `018000934020`, phone, customerService. Atención al cliente · nacional. [Evidencia](https://www.bbvaseguros.com.co/seguros-autos/); revisión 2026-09-13.
- Habilitado: `6013077121`, phone, customerService. Reporte de siniestros · no asistencia vial. [Evidencia](https://www.bbvaseguros.com.co/seguros-autos/); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.bbvaseguros.com.co/seguros-autos/).
- Pendiente/límite: No se verificó un WhatsApp ni canal de asistencia vial general propio aplicable a todos los autos BBVA. Confirmar emisor y canal en la póliza; Zurich publica también productos en alianza con BBVA.
- Pendiente/límite: No reutilizar #370 de productos de salud/vida ni deducir el asegurador por el banco.

### La Equidad

- Habilitado: `#324`, phone, customerService. Reporte de siniestros · Claro, Movistar y Tigo. [Evidencia](https://www.laequidadseguros.coop/contacto/que-hacer-en-caso-de-siniestros/); revisión 2026-09-13.
- Habilitado: `018000919538`, phone, customerService. Reporte de siniestros · nacional. [Evidencia](https://www.laequidadseguros.coop/contacto/que-hacer-en-caso-de-siniestros/); revisión 2026-09-13.
- Habilitado: `6017460392`, phone, customerService. Reporte de siniestros · Bogotá. [Evidencia](https://www.laequidadseguros.coop/contacto/que-hacer-en-caso-de-siniestros/); revisión 2026-09-13.
- Habilitado: `573185884515`, whatsapp, customerService. Siniestros autos livianos · daños y hurto. [Evidencia](https://www.laequidadseguros.coop/contacto/que-hacer-en-caso-de-siniestros/); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.laequidadseguros.coop/productos/seguros-generales/seguros-de-autos-y-rc/).
- Producto motorcycle: [publicación propia](https://www.laequidadseguros.coop/productos/seguros-generales/seguros-de-autos-y-rc/motos/).
- Pendiente/límite: La página mezcla el título de asistencia con descripción limitada a radicar/seguir daños y hurto. Se clasifica como atención de siniestros, no grúa inmediata.
- Pendiente/límite: Taxi no inferido a partir de transporte público genérico.

### HDI Seguros

- Habilitado: `#224`, phone, assistance. Asistencia · desde cualquier operador. [Evidencia](https://www.hdiseguros.com.co/asistencias); revisión 2026-09-13.
- Habilitado: `6013077050`, phone, assistance. Asistencia · Bogotá. [Evidencia](https://www.hdiseguros.com.co/asistencias); revisión 2026-09-13.
- Habilitado: `018000113390`, phone, assistance. Asistencia · resto del país. [Evidencia](https://www.hdiseguros.com.co/asistencias); revisión 2026-09-13.
- Habilitado: `573164821802`, whatsapp, assistance. Conductor elegido y carro taller · según póliza. [Evidencia](https://www.hdiseguros.com.co/asistencias); revisión 2026-09-13.
- INACTIVO: `018000115569`, phone, customerService. Número en sección accesibilidad · discrepancia pendiente. [Evidencia](https://www.hdiseguros.com.co/centro-de-informacion-y-contacto); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.hdiseguros.com.co/personas/mi-carro).
- Producto motorcycle: [publicación propia](https://www.hdiseguros.com.co/noticias/autos).
- Pendiente/límite: La sección de discapacidad conserva 115569 y la sección principal/footer 113390. El primero permanece inactivo.
- Pendiente/límite: No asignar automáticamente Liberty Colombia: SFC aún lista una entidad separada 13-45. No se añade alias Liberty.

### MAPFRE

- Habilitado: `#624`, phone, assistance. Emergencias y asistencia · disponibilidad según operador. [Evidencia](https://www.mapfre.com.co/contacto/red-oficinas/); revisión 2026-09-13.
- Habilitado: `018000519991`, phone, assistance. SI 24 · asistencia nacional. [Evidencia](https://www.mapfre.com.co/contacto/mapfre-si-24/); revisión 2026-09-13.
- Habilitado: `6013077024`, phone, customerService. SI 24 · Bogotá. [Evidencia](https://www.mapfre.com.co/contacto/); revisión 2026-09-13.
- Habilitado: `573188030276`, whatsapp, assistance. Asistencias y consultas. [Evidencia](https://www.mapfre.com.co/contacto/); revisión 2026-09-13.
- INACTIVO: `018000516991`, phone, assistance. Número discrepante en bloque SI24 · por confirmar. [Evidencia](https://www.mapfre.com.co/contacto/); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.mapfre.com.co/).
- Pendiente/límite: La página de contacto contiene 516991, mientras SI24, portada y oficinas publican 519991. 516991 queda inactivo.
- Pendiente/límite: #624 no está disponible para Uff, Virgin y Avantel según la página SI24. Preferir fijo/nacional si no funciona.
- Pendiente/límite: Moto/taxi no confirmados.

### Quálitas

- Habilitado: `#963`, phone, assistance. Asistencia · numeral celular. [Evidencia](https://www.qualitascolombia.com.co/web/qco/inicio); revisión 2026-09-13.
- Habilitado: `6016579650`, phone, assistance. Asistencia · Bogotá. [Evidencia](https://www.qualitascolombia.com.co/web/qco/inicio); revisión 2026-09-13.
- Habilitado: `018000189873`, phone, assistance. Asistencia · nacional. [Evidencia](https://www.qualitascolombia.com.co/web/qco/inicio); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.qualitascolombia.com.co/web/qco/livianos).
- Pendiente/límite: Página específica de atención devuelve 403 al revisor; los teléfonos están visibles en la portada oficial.
- Pendiente/límite: No se verificó WhatsApp colombiano. No usar números de México.
- Pendiente/límite: Moto/taxi no confirmados.

### La Previsora

- Habilitado: `#345`, phone, assistance. Asistencia · opción 1. [Evidencia](https://www.previsora.gov.co/web/guest/automoviles-servicio-de-asistencia); revisión 2026-09-13.
- Habilitado: `6013487555`, phone, assistance. Asistencia · Bogotá. [Evidencia](https://previsora.gov.co/web/personas/automoviles-siniestros); revisión 2026-09-13.
- Habilitado: `018000910554`, phone, assistance. Asistencia · nacional. [Evidencia](https://previsora.gov.co/web/personas/automoviles-siniestros); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.previsora.gov.co/web/personas/automoviles).
- Producto motorcycle: [publicación propia](https://previsora.gov.co/web/entidades-estatales/seguro-de-automovil).
- Pendiente/límite: No se verificó WhatsApp para asistencia vehicular. Un proyecto de WhatsApp en informe de gestión no es un canal operativo.
- Pendiente/límite: Moto existe en portafolio oficial; confirmar contratación particular con entidad. Taxi no confirmado.

### SBS Seguros

- Habilitado: `#360`, phone, customerService. Atención · celular. [Evidencia](https://www.sbseguros.co/); revisión 2026-09-13.
- Habilitado: `018000911360`, phone, customerService. Atención · nacional. [Evidencia](https://www.sbseguros.co/); revisión 2026-09-13.
- Habilitado: `573228861010`, whatsapp, customerService. ESE · atención al cliente. [Evidencia](https://www.sbseguros.co/); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.sbseguros.co/).
- Producto motorcycle: [publicación propia](https://www.sbseguros.co/).
- Pendiente/límite: La ruta /indemnizaciones/asistencias muestra solo la navegación al extractor. Los canales de portada sí están publicados, pero su alcance vial específico no se verificó; se clasifican como atención.
- Pendiente/límite: Taxi no confirmado.

### Seguros Alfa

- Habilitado: `6013077032`, phone, customerService. Atención general · Bogotá. [Evidencia](https://www.segurosalfa.com.co/lineas-de-atencion); revisión 2026-09-13.
- Habilitado: `018000122532`, phone, customerService. Atención general · resto del país. [Evidencia](https://www.segurosalfa.com.co/lineas-de-atencion); revisión 2026-09-13.

- Pendiente/límite: Incluida por referencia Fasecolda y cruce SFC, pero sin oferta voluntaria car/motorcycle/taxi comprobada en las páginas revisadas: categories vacío, no exclusión del directorio general.
- Pendiente/límite: Los WhatsApp publicados son por banco adquirente; no existe evidencia de uno universal de autos. No se promueven a asistencia ni se elige banco por defecto.

### Seguros Mundial

- Habilitado: `#935`, phone, assistance. Asistencia · Tigo, Claro y Movistar. [Evidencia](https://www.segurosmundial.com.co/); revisión 2026-09-13.
- Habilitado: `6013274712`, phone, assistance. Asistencia · Bogotá. [Evidencia](https://www.segurosmundial.com.co/); revisión 2026-09-13.
- Habilitado: `6013274713`, phone, assistance. Asistencia · Bogotá, alternativa. [Evidencia](https://www.segurosmundial.com.co/); revisión 2026-09-13.
- Habilitado: `018000111935`, phone, assistance. Asistencia · fijo fuera de Bogotá, no celular. [Evidencia](https://www.segurosmundial.com.co/seguros-mundial-v2/atencion-al-cliente/); revisión 2026-09-13.
- Habilitado: `573228484007`, whatsapp, customerService. Orientación y consultas · incluye movilidad. [Evidencia](https://www.segurosmundial.com.co/seguros-mundial-v2/atencion-al-cliente/); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.segurosmundial.com.co/).
- Pendiente/límite: El sitio ofrece Seguro Amarillo, pero su texto extraído no permitió confirmar taxi explícitamente. No asignar taxi por el nombre/color del producto.
- Pendiente/límite: WhatsApp es orientación/consultas de movilidad, no se presenta como despacho inmediato de grúa.

### Seguros Bolívar

- Habilitado: `#322`, phone, assistance. Asistencia · celular. [Evidencia](https://digital.experienciasbolivar.segurosbolivar.com/recorrido-seguro-autos-basico); revisión 2026-09-13.
- Habilitado: `018000123322`, phone, assistance. Asistencia · desde teléfono fijo. [Evidencia](https://digital.experienciasbolivar.segurosbolivar.com/recorrido-seguro-autos-basico); revisión 2026-09-13.
- Habilitado: `6013122122`, phone, assistance. Emergencias y atención · Bogotá. [Evidencia](https://wpclientes.segurosbolivar.com/canales-de-atencion); revisión 2026-09-13.
- Habilitado: `573223322322`, whatsapp, assistance. Asistencia de autos. [Evidencia](https://digital.experienciasbolivar.segurosbolivar.com/recorrido-seguro-autos-basico); revisión 2026-09-13.
- Producto car: [publicación propia](https://digital.experienciasbolivar.segurosbolivar.com/recorrido-seguro-autos-basico).
- Pendiente/límite: La etiqueta heredada/Fasecolda Seguros Bolívar S.A. se conserva como alias comercial. La entidad para seguros generales es Seguros Comerciales Bolívar S.A. (13-27), distinta a Compañía de Seguros Bolívar S.A. (vida). No modificar pólizas del usuario.
- Pendiente/límite: Moto/taxi no confirmados en esta revisión.

### Seguros del Estado

- Habilitado: `#388`, phone, assistance. Asistencia · celular. [Evidencia](https://www.segurosdelestado.com/); revisión 2026-09-13.
- Habilitado: `6017443900`, phone, assistance. Asistencia · Bogotá. [Evidencia](https://www.segurosdelestado.com/); revisión 2026-09-13.
- Habilitado: `018000123010`, phone, assistance. Asistencia · nacional. [Evidencia](https://www.segurosdelestado.com/); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.segurosdelestado.com/).
- Pendiente/límite: No se verificó WhatsApp oficial de asistencia de autos; no generar uno a partir del fijo.
- Pendiente/límite: Transporte público no se convierte automáticamente en categoría taxi; moto/taxi pendientes.

### SURA

- Habilitado: `#888`, phone, assistance. Asistencia y siniestros · opción 1. [Evidencia](https://www.sura.co/seguros/centro-de-ayuda/asistencias/choque-simple); revisión 2026-09-13.
- Habilitado: `018000518888`, phone, assistance. Asistencia y siniestros · nacional. [Evidencia](https://www.sura.co/seguros/centro-de-ayuda/asistencias/choque-simple); revisión 2026-09-13.
- Habilitado: `6014378888`, phone, customerService. Atención seguros · Bogotá. [Evidencia](https://www.sura.co/centro-de-ayuda/contacto); revisión 2026-09-13.
- Habilitado: `6044378888`, phone, customerService. Atención seguros · Medellín. [Evidencia](https://www.sura.co/centro-de-ayuda/contacto); revisión 2026-09-13.
- Habilitado: `6024378888`, phone, customerService. Atención seguros · Cali. [Evidencia](https://www.sura.co/centro-de-ayuda/contacto); revisión 2026-09-13.
- Habilitado: `573152757888`, whatsapp, assistance. Asistencia y siniestros de autos. [Evidencia](https://www.sura.co/seguros/centro-de-ayuda/asistencias/choque-simple); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.sura.co/seguros).
- Producto motorcycle: [publicación propia](https://www.sura.co/seguros).
- Pendiente/límite: Canales de Seguros SURA, no EPS ni ARL. No se asigna taxi sin evidencia de producto específica.

### Zurich

- Habilitado: `6013190730`, phone, customerService. Atención general · PBX. [Evidencia](https://www.zurichseguros.com.co/lineas-personales/movilidad); revisión 2026-09-13.
- Habilitado: `018000112723`, phone, customerService. Atención general · nacional. [Evidencia](https://www.zurichseguros.com.co/lineas-personales/movilidad); revisión 2026-09-13.
- INACTIVO: `573173643185`, whatsapp, customerService. Publicado en producto Carnaval · alcance autos por confirmar. [Evidencia](https://www.zurichseguros.com.co/zurich-carnaval/accidentes-personales); revisión 2026-09-13.
- Producto car: [publicación propia](https://www.zurichseguros.com.co/lineas-personales/movilidad).
- Pendiente/límite: WhatsApp hallado en producto de accidentes personales; no habilitado para consulta de autos sin confirmar alcance. La página de contacto no pudo extraerse.
- Pendiente/límite: La oferta de movilidad no prueba un teléfono de despacho de asistencia universal. Mantener canales generales; producto BBVA no transforma BBVA en alias Zurich.
- Pendiente/límite: Moto/taxi no confirmados.

## 4. Tratamiento conservador de discrepancias

Las seis observaciones inactivas permanecen auditables en el JSON y en
`channels`, pero **nunca** dentro de `verifiedChannels`:

1. Solidaria: nacional 018000512021 y #789 conservados en un portal secundario,
   frente a los nuevos canales publicados en la portada redirigida.
2. AXA: 573124457921 se publica para mensajes informativos de renovación,
   no para recibir solicitudes de servicio. Su `purpose` es únicamente una
   clasificación editorial candidata; `verified=false` impide activarlo.
3. HDI: 018000115569 en el bloque de discapacidad difiere del 018000113390
   publicado en el bloque principal y asistencia.
4. MAPFRE: 018000516991 difiere del 018000519991 que corroboran SI24 y oficinas.
5. Zurich: 573173643185 está acreditado para un producto de accidentes personales
   Carnaval, sin alcance automóviles comprobado. No reutilizarlo para autos.

Un número no encontrado no se inventa ni se declara inexistente. Los WhatsApp
segmentados por banco de Alfa no se convierten en un canal universal de autos.
Los contactos generales BBVA, SBS, Equidad y Zurich no se rotulan como grúa
inmediata. No se expone el envío de placa, GPS o información documental.

## 5. API de integración

Archivo: `mobile/lib/features/vehicle_status/data/insurance_directory.dart`.

```dart
const insuranceDirectoryAsset =
    'assets/catalogs/insurance_directory_v1.json';

final insuranceDirectoryProvider = FutureProvider<InsuranceDirectory>(...);

class InsuranceDirectory {
  InsuranceDirectory({required List<InsuranceCompany> entries});
  factory InsuranceDirectory.fromJsonString(String source);
  factory InsuranceDirectory.fromJson(Map<String, dynamic> json);
  final List<InsuranceCompany> entries;
  InsuranceCompany? resolve(String? id, String? legacyName);
  List<InsuranceCompany> search(String query, {String? category});
}

class InsuranceCompany {
  // Constructor: todos los campos required.
  final String id, name, legalName, website, sourceUrl, reviewedAt;
  final List<String> aliases, categories;
  final List<InsuranceChannel> channels;
  List<InsuranceChannel> get verifiedChannels;
}

class InsuranceChannel {
  // Constructor const; todos los campos required.
  final String id, label, kind, value, purpose, sourceUrl, reviewedAt;
  final bool verified;
}
```

Ambos modelos ofrecen también `fromJson(Map<String, dynamic>)`.
`reviewedAt` y `value` son **String**, no DateTime/int.
`kind`: phone/whatsapp. `purpose`: assistance/customerService.
Listas de entrada y salida inmutables; no modificar el catálogo cacheado.

El provider no es autoDispose: una carga por vida del ProviderContainer, salvo
invalidación/reintento explícito. Una lectura fallida se propaga como error de
Riverpod, no como directorio vacío. No hay red en el loader.

`resolve`: ID conocido tiene prioridad; de lo contrario usa nombre legado
exacto, normalizando tildes, mayúsculas y espacios. No hay similitud aproximada.
Nulos, vacío, “Otra / no aparece” y desconocidos retornan null.
`search`: todos los términos buscados, sin tildes, sobre nombre/legal/alias;
orden alfabético estable. Categoría desconocida retorna lista vacía.
No cambiar preferencias ni documentos al resolver un nombre.

**Contrato crítico para UI:** abrir acciones solo desde `verifiedChannels`.
El fallback `const <InsuranceChannel>[]` es compatible. Separar asistencia
de atención al cliente y conservar el label específico. Construir `tel:`
mediante componentes URI para no perder `#` como fragmento; no agregar
identificadores ni mensajes a WhatsApp. No marcar contactos particulares como
verificados por este directorio.

El JSON agrega metadatos editoriales `reference`, `categoryEvidence` y
`pending`. El modelo no los expone porque no forman parte de la API solicitada.
El decoder valida schema, campos obligatorios, códigos duplicados, colisiones de
alias, fechas reales, HTTPS y formato de números. **La oficialidad se acredita
por esta investigación**, no simplemente por pasar esas validaciones sintácticas.

## 6. Pruebas preparadas y coordinación

Archivo: `mobile/test/features/vehicle_status/data/insurance_directory_test.dart`.

Cobertura escrita:
- Referencia 16/16 y cada alias heredado literal; 16 códigos SFC independientes.
- Evidencia por canal/producto y las seis observaciones excluidas de acciones.
- ID prioritario, fallback exacto, nulos, errores de identidad, búsqueda por
  acentos/Unicode y filtro por producto realmente probado.
- Listas inmutables, schema, duplicados, fechas inexistentes, URLs inseguras,
  inyección de destinos, conservación de numerales y ceros.
- Provider sin recargas al cerrar un listener y leer de nuevo en el mismo
  container; asset simulado sin red.

**No se ejecutaron tests, analyze ni builds en este sidecar**, por instrucción
expresa de coordinación para evitar bloqueos nativos de Windows. El archivo de
pruebas queda listo para el proceso principal:

```powershell
flutter test test/features/vehicle_status/data/insurance_directory_test.dart
```

El resultado de ese comando sigue pendiente; no presentar estas pruebas como
verdes. Se ejecutó `dart.bat format` sobre los dos Dart propios: salida correcta,
2 archivos formateados, código de salida 0. Las pruebas de geometría del principal pueden sustituir el provider;
no necesitan esperar la revisión editorial del JSON.

## 7. Límites de propiedad y entrega

Solo los cuatro archivos autorizados. Se confirmó que pubspec ya incluye
`assets/catalogs/`; no se editó pubspec ni el catálogo legado. Sin nuevas
dependencias, migración, cambios de rama, commits, build o instalación.
No se revirtieron cambios de otros agentes. No hay datos personales.

Quedan fuera: UI/sheets, selección/guardado de pólizas, errores del launcher y
QA telefónica, PDF/autenticación y captura visual, publicidad/cotización y
revisión jurídica de una futura captación. La lista requiere revisión editorial
en futuras versiones; no prometer que los teléfonos nunca cambian.
