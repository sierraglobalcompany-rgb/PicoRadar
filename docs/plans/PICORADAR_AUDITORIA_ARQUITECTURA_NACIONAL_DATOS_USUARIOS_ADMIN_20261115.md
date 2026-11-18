# PicoRadar — Auditoría de cierre: motor nacional, actualización de contenidos, usuarios y administración

**Corte:** 15 de noviembre de 2026, hora Colombia. **Modo:** auditoría de arquitectura y decisión, SOLO lectura del producto. **Producto examinado:** árbol recuperado N1-R1 `3980778395ade9957e9ddf5097916ac814f2a1e5` (HEAD RC2 `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289` + delta staged). **Orden en curso:** Codex Luna ejecuta `PICORADAR-N1-V3-CIERRE-VERTICAL-SIN-PINGPONG-20261115`; **no interrumpir ni emitir otro prompt**, no confundir resultados futuros de V3 con este estado estático. **Release:** NO_GO.

## 1. Decisión ejecutiva

**Conservar la plataforma existente y completarla.** Un solo intérprete de pico y placa (`schemaVersion=2`) recibe un archivo de datos versionado; el servidor Laravel valida/publica; el teléfono consulta y evalúa localmente incluso sin red. Añadir municipio, cambiar día/dígito, invertir paridad, modificar franja, habilitar o deshabilitar consulta **no exige nueva APK** si ese caso ya es expresable en el esquema. No crear un switch de código por ciudad ni una colección de motores regionales.

**NO está probado aún que sea totalmente nacional**: existe catálogo de selector empaquetado en APK, formulario web parcial y falta certificar la publicación OTA integral y la selección geográfica real. La cobertura legal N1 es LAB **14 autoridades / 33 códigos DIVIPOLA / 22 coberturas parciales / 120 reglas**, no cobertura total de Colombia ni licencia para informar `ALLOWED` a falta de datos. Para localidades o modalidades sin evidencia, `UNKNOWN/STALE`; «sin medida» solo con evidencia positiva institucional.

**Los nuevos requisitos de cuentas/CRM/marketing** no forman parte de la orden V3 que Codex ya ejecuta. Quedan definidos aquí para el siguiente bloque integrado **después de su ZIP**, no como una orden paralela ni como supuesto de que ya existen.

## 2. Inventario contrastado de implementación

| Capacidad | Fuente concreta del árbol | Estado y alcance |
|---|---|---|
| Reglas generales: `weekdays`, `dateParity` odd/even, primeros/últimos dígitos, valores 0–9, horarios, festivos, vigencia, condiciones | `mobile/lib/features/pico_placa/domain/restriction_engine.dart`; `.../data/restriction_dataset.dart`; `server/app/Services/RestrictionContractValidator.php` | **IMPLEMENTADO EN CÓDIGO**. `fullDay` N1 pendiente ejecución Flutter. Distinguir paridad de fecha de paridad de placa (esta última se expresa como dígitos, sin nueva lógica). |
| Grano autoridad/municipio y modalidad/servicio | JSON N1 `jurisdictions[].municipalityCodes`, `consultationEnabled`, `coverages[].vehicleKind`, `serviceType`, `coverageCompleteness` | **DATOS/CONTRATO DISPONIBLES**, no implica cobertura verificada nacional. Ámbito por pueblo/corregimiento necesita identidad geográfica inequívoca y prueba focal de selección. |
| Gestión manual de pico y placa | `server/routes/web.php` `/admin/restrictions/*`, `RestrictionRuleController.php`, `RestrictionPublicationService.php`, importación y rollback | **PANEL EXISTENTE**. Importar, revisar, validar, publicar, versionar y revertir. No crear otro panel equivalente. |
| Habilitación administrativa | `Jurisdiction.enabled` y en datos `consultationEnabled` | **DOS BANDERAS DE DISTINTO PROPÓSITO**; falta probar que la operación desde panel termina en el dataset instalado. `enabled=false` en BD no debe asumirse automáticamente equivalente a `consultationEnabled=false` ya publicado. |
| Descarga/comprobación de datos | `mobile/lib/core/sync/dataset_sync_service.dart`, `dataset_manifest.dart`, `server/app/Services/ManifestPublisher.php` | **CÓDIGO EXISTENTE**: manifest v1, ETag/304, SHA256, versionado, límites de descarga, importer/Drift; publicación y E2E real aún no certificados para N1. `manifest schemaVersion=1` es el **envoltorio** y NO contradice `restrictions schemaVersion=2`. |
| Datos activos nuevos en catálogo de municipios | `mobile/lib/features/pico_placa/data/pico_jurisdiction_catalog.dart` | **BRECHA FUNCIONAL NACIONAL**: asset fijo de 73 registros/5 inicialmente habilitados; superposición dinámica parcial desde runtime. Nuevos registros pueden añadirse, pero el fallback crea `department='Colombia'` y carece de metadatos geográficos completos; `RestrictionStore.listJurisdictions()` arranca de filas de coberturas. Completar el consumo de geografía y habilitación del dataset, sin reescribir el motor. |
| Editor de reglas para todas las categorías/24h | `server/app/Services/RestrictionFormPayloadBuilder.php`; `server/resources/views/admin/restrictions/partials/rule-fields.blade.php` | **BRECHA CONCRETA**: formulario restringe `vehicle_kind` a `car/motorcycle`, `service_type` a `private/taxi` y rechaza ventanas inicio=fin; no expone condiciones tipadas. Motor y validador admiten más. Reutilizar importación JSON y ampliar **el formulario actual** según contrato, no duplicar motor. |
| CDA / datos de aseguradoras y SOAT | `mobile/lib/features/cda/data/cda_catalog.dart`, `cda_geography.dart`, `mobile/lib/features/vehicle_status/data/insurance_directory.dart`, `vehicle_status_catalog.dart` | **EN GRAN PARTE ASSETS EMBEBIDOS**; la actualización manual en servidor no está conectada de punta a punta con estos consumidores. No trasladar al servidor fechas particulares/documentos/alertas privados del usuario. |
| Campañas, aliados publicitarios | `server/routes/web.php` `/admin/sponsors`, `/admin/campaigns`, `/admin/partner-inquiries`; `CampaignCatalogPublisher.php`; API `GET /api/v1/campaign-catalog`; cliente home partner | **YA EXISTE** un circuito para patrocinadores/campañas y solicitudes de aliados. Comprobar activación, vigencia y consumo reales; **no construir otro módulo de publicidad**. Feature `ads=false` en configuración base; no activar silenciosamente. |
| Administración de usuarios registrados de la app | `server/app/Models/User.php` (operadores), migraciones `users` con `role`/`is_active`, rutas `api.php` | **NO IMPLEMENTADO COMO CUENTAS DE USUARIO FINAL**. `users` protege operadores/admin; API pública solo health, viajes, solicitudes de aliados y catálogo de campañas. No existen en la evidencia examinada endpoints de alta/perfil consentido, listado/exportación de clientes o campañas email. |
| Documentos personales del vehículo | `mobile/lib/features/vehicle_status/data/private_vehicle_document_store.dart`; `core/storage/file_crypto.dart` | **LOCAL CON CIFRADO EN CÓDIGO**. No se auditó criptografía extremo a extremo ni backup del dispositivo. Mantener matrícula, cédula, contratos, fotos, placa/VIN, documentos, GPS y trayectos **fuera de API/exportaciones/telemetría**. |

> **Precisión sobre GitHub:** PR #79 es documentación (Draft), no publicación de la implementación. El commit local N1-R1 no está confirmado remotamente. `HOLD_SECURITY` impide presumir autorización para subir historial/código de producto. Esta auditoría no modifica producción ni el checkout de Codex.

## 3. Arquitectura mínima definitiva: un solo mecanismo, archivos especializados

```text
ADMIN LARAVEL (autorizado)
  editar/importar + fuente oficial + validar + aprobar + versionar
                    ↓
PUBLICADOR existente
  snapshot completo aprobado + manifest (versión/URL/SHA/TTL)
                    ↓ HTTPS GET / ETag
APP FLUTTER
  comprobar versión/hash/esquema → instalar en transacción Drift
  conservar última versión íntegra → motor único local
                    ↓
selector geográfico → carro/moto/taxi/carga/servicio → fecha/hora/dígito
                    ↓
RESTRICTED | ALLOWED acreditado | UNKNOWN | STALE
```

**Un manifest, varios archivos tipados independientes** (ej.: `restrictions`, `cda_catalog`, `cda_geography`, `insurers`, `tax_calendars`, `tolls`). No es recomendable un único JSON gigante de todas las funciones; actualizar CDA no debería forzar descarga de normas de tránsito. Reutilizar `DatasetSyncService`, `DatasetPublisher`, `ManifestPublisher` y los importers existentes. **Campañas** ya tienen un publicador/catálogo independiente: mantenerlo si el contrato actual resuelve actualización y caché; solo unificar si hay causa concreta. No nuevos microservicios ni app recompilada por datos.

**Contrato mínimo por territorio y modalidad:** identificador estable y ámbito (departamento/municipio/pueblo con jerarquía y clave verificable); servicio y categoría; `consultationEnabled`; `coverageCompleteness`; calendario de reglas (día de semana, paridad de FECHA, posición y lista de dígitos de placa, ventanas, `fullDay`, festivos, inicio/fin de vigencia, prioridades y condiciones); URL oficial y fechas de revisión. Una regla `allow` sin ámbito/exenciones comprobados **no autoriza declarar circulación libre**. El estado «inhabilitado» debe explicarse como «sin consulta habilitada», no «sin restricción».

**Ruta rápida para cambios manuales:** administrador selecciona territorio y modalidad → modifica calendario/dígitos/horarios → añade URL de alcaldía/gobernación/secretaría y vigencia verificable → revisa impacto y aprueba si cambio material → publica la revisión canónica → la APK detecta manifest nuevo → valida SHA, instala o conserva last-good → interfaz refleja cambio sin nueva APK. Una publicación institucional **basta para lo que afirma de forma expresa**; no exigir PDF de decreto por rutina ni inferir ámbitos/excepciones no publicados.

## 4. Riesgos reales que hay que cerrar, no nuevas auditorías generales

| Prioridad | Defecto o brecha | Acción mínima concreta | Prueba que cambia la decisión |
|---|---|---|---|
| **P0** | Selector nacional depende aún de catálogo APK de 73 entradas y relleno runtime incompleto | Usar la geografía del dataset validado como fuente actualizable de disponibilidad/identidad; asset empaquetado solo fallback seguro; no duplicar catálogo de negocio | Publicar **municipio que no estaba en la APK**, aparece con código/departamento correctos y se evalúa sin rebuild |
| **P0** | Diferencia entre habilitar autoridad BD, consulta en snapshot, cobertura por modalidad y archivo descargado | Conectar la acción del panel existente con publicación versionada y resultado en el cliente; `consultationEnabled` no es permiso para circular | Activar/desactivar una localidad/servicio, otra conserva reglas, sin falsos `ALLOWED` |
| **P0** | Editor web no expone todas las expresiones del motor | Completar builder/form actual por contrato schema2, o usar import JSON tipado existente hasta tener formulario completo | Editar dígitos impares→pares, días, taxi/carga, 24h, condiciones; publish+OTA refleja exactamente el cambio |
| **P0** | `fullDay`/Viaje/Drift/OTA no certificados en N1 | **YA ESTÁ EN EJECUCIÓN POR CODEX V3. No duplicar orden.** | ZIP V3 con logs/árbol final, pruebas específicas, OTA y APK del mismo SHA si posible |
| **P1** | CDA/aseguradoras parcialmente empaquetados | Publicación/lector OTA tipado en el sistema YA EXISTENTE; no mover documentos personales | Actualización manual de un CDA o aseguradora aparece en la app sin APK; last-good y rollback |
| **P1** | Registro y CRM de usuario final ausentes | Nuevo módulo mínimo de cuenta opcional, separado de operadores, consentimiento y exportación autorizada | Alta/verificación/baja, anonimato preservado, panel filtro y CSV de datos **efectivamente consentidos** |
| **P1** | Envíos masivos de correo a registrados no existen | Reutilizar Laravel Mail + queue/SMTP configurado; selección solo consentidos, baja y logs sin datos ocultos | Prueba de destinatario válido/opt-out/errores/reintentos y cero envíos a no consentidos |
| **P2** | Publicidad, aliados y promociones | **Reutilizar** Sponsor/Campaign/PartnerInquiry y catálogo; no activar `ads` sin decisión y permisos | Campaña cambia en servidor y aparece solo en placements permitidos, nunca en Conducir/HUD o documentos |

**No confundir esta tabla con una autorización de programar simultáneamente todos los puntos.** No abrir otro Codex ni otro checkout escritor mientras corre V3.

## 5. Usuarios, vehículos y privacidad: diseño simple y seguro

**Principio:** la app **siempre funciona sin registro**. Registro opcional para quien desee comunicaciones/servicios ligados a su cuenta. No usar `users` de operadores como tabla abierta a clientes; crear identidad de cliente final separada (p. ej. `app_users`) o aislamiento equivalente estrictamente demostrable de permisos. `name`/`email` y `phone` opcional requieren política y consentimiento; email verificable y eliminación/corrección accesibles. **Ningún vehículo específico, placas, VIN, fotos de matrículas/cédulas/contratos, SOAT personal, vencimientos individualizados ni GPS va al servidor por defecto**.

**Segmentación voluntaria sin identificar vehículos:** atributos declarados/compartidos por el usuario: `has_car`, `has_motorcycle`, `has_public_service` o categorías tipadas y, si necesario, un contador por tipo; se usan para filtrado de producto/marketing **solo con finalidad informada y consentimiento separado**. **Estos atributos vinculados a una cuenta también son datos personales**. Un usuario anónimo no figura en listados nominales del CRM; jamás afirmar que se conoce la identidad de cada instalación.

**Campos mínimos posibles** (propuesta condicionada a autorización de la función y política de privacidad): ID opaco, nombre, correo verificado, teléfono opcional, ciudad declarada opcional, preferencias de contacto, categorías vehiculares opcionales, versión/fecha/finalidad del consentimiento, estado de baja/supresión y marcas temporales. Credenciales/tokens en almacén seguro; servidor con autorización y controles por rol. No pedir cédula, fotos, placa, contratos para registrarse.

**Panel de clientes:** listado con búsqueda/paginación, conteos, filtros (carro, moto, servicio público, municipio declarado si existe, consentimiento, fecha de alta), exportación CSV seleccionada por finalidad. Autorización exclusiva de administrador designado, evento auditado de quién/cuándo/criterios, cabeceras CSV sanitizadas contra inyección de fórmulas y control de descarga; NO exponer dump SQL ni incluir operadores, credenciales, documentos o instalaciones anónimas. Exportar solo columnas existentes/pertinentes y respetar supresiones. Ver/editar/suprimir consentimiento y estado de marketing.

**Correos:** distinguir avisos transaccionales de marketing; checkbox de **marketing voluntario desmarcado por defecto** y prueba de autorización; lista de exclusión, enlace sencillo para darse de baja, límites de frecuencia/horario/canal según la ley, historial de envío con metadatos mínimos, colas y límite de tasa. Sin opt-in: **NO correos publicitarios**. No usar la base de registro para alimentar terceros o aliados sin base legal/consentimiento específico. Evitar construir CRM comercial complejo o automatizaciones de campaña premium antes de cerrar lo esencial.

**Referencia normativa:** Ley 1581/2012; SIC, protección de datos (autorización previa, información de finalidad, derechos de acceso/corrección/supresión); Ley 2300/2023 arts. 3 y 5 (canales, horarios y baja de mensajes comerciales). Fuentes oficiales:
- https://sedeelectronica.sic.gov.co/politica-de-tratamiento-de-datos-personales
- https://sedeelectronica.sic.gov.co/publicaciones/boletin-juridico/concepto/derecho-la-tranquilidad-y-supresion-de-datos-personales
- https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=213990

## 6. Prioridades y ruta corta para terminar (sin competir con Codex actual)

**Bloque A — EN CURSO, no reordenar:** recibir el **único ZIP V3** de Codex y comprobar delta sobre TREE final: Flutter fullDay/Viaje, compatibilidad Drift, backend OTA, snapshot completo, rollback, APK DEV nueva y QA atribuible al mismo árbol. Reutilizar tests anteriores si sus contratos/bytes no cambiaron. `PASS_SCOPED` no equivale a release.

**Bloque B — UNA integración pendiente diseñada después de V3:** conectar administración territorial y catálogo runtime para cualquier municipio/departamento/pueblo sin APK; hacer que el formulario/importación soporte por completo el esquema general existente; extender datos OTA existentes a CDA/SOAT/aseguradoras, y terminar las rutas admin faltantes. En paralelo **solo después de elegir no competir por el mismo checkout**, se puede abordar cuenta opcional + listado/exportación y correos con consentimiento. El Director debe ajustar el alcance del siguiente lote desde el ZIP V3; no preparar nuevos prompts anticipadamente ni repetir auditoría nacional.

**Bloque C — aceptación final:** pruebas end-to-end del mismo árbol/build: ciudad nueva, cambio par/impar, habilitar/deshabilitar modalidad, snapshot completo/304/SHA corrupto/last-good/offline; actualización CDA/SOAT/campañas; alta opcional y exportación/opt-out, Android sin pérdida de vehículos ni documentos; saneamiento `HOLD_SECURITY`, firma release, PR/merge y despliegue **solo con autorización y evidencia**. El carril **editorial** de cobertura nacional se amplía continuamente por datos/fuentes aprobados y no bloquea cerrar la tecnología.

### Pruebas de aceptación mínimas NO duplicadas (reusar las existentes)

1. **Alta territorial sin APK:** un municipio/pueblo previamente no visible en el catálogo empaquetado pasa a la UI con nombre/departamento/código adecuados por manifest+snapshot; modalidad no publicada resulta UNKNOWN.
2. **Rotación:** admin cambia lunes 1/2 a 3/4, invierte paridad de fecha, actualiza día y horario; la app se comporta exactamente según dato, tanto online como después de reinicio offline.
3. **Switch:** `consultationEnabled=false` para territorio o modalidad no equivale a `ALLOWED`; otra autoridad activa sigue intacta después de publicación.
4. **Integridad:** 304 válido no descarga; versión nueva con SHA incorrecto/manifest incompatible no reemplaza última copia buena; snapshot incompleto no borra autoridades previas; app no revela datos personales en logs.
5. **Contenidos:** cambiar CDA/aseguradora por panel/dataset → se ve sin reinstalar; campaña contextual se publica/desactiva desde panel y no aparece en Conducir/HUD/documentos.
6. **Clientes:** usuario anónimo mantiene el servicio; registrado puede rectificar/borrar; admin autorizado filtra/exporta categorías declaradas; los no consentidos nunca entran en envío publicitario.

## 7. Invariantes y límites

- No motor por ciudad; no nueva arquitectura de servidor; no descargar un JSON completo gigante para cada edición de un CDA (manifest común + datasets independientes).
- No confundir `enabled` de la fila administrativa, `consultationEnabled` de la fotografía pública y `coverageCompleteness` de la regla jurídica.
- No publicar «puede circular» de `partial`, `unknown` o `stale`; no activar fuentes sin soporte.
- Mantener privacidad local de vehículo/documentos y anuncios fuera de navegación/documentos/emergencias.
- No confundir cuentas administradoras con registro de usuarios finales; no exponer SQL sin restricciones; no vender/enviar base de usuarios a aliados.
- No crear otro prompt para Codex mientras V3 esté activo, ni editar su worktree remoto o local en paralelo.
- No push de producto mientras persiste `HOLD_SECURITY`; documentación independiente y explícitamente Draft no equivale a release.

## 8. Estado de evidencia y relevo

- **VERIFICADO AQUÍ (inspección estática):** archivos/contratos/servicios/rutas listados, base RC2 + staged TREE N1, formulario con car/moto + private/taxi + rechazo start=end, catálogo fijo y overlay dinámico, API pública sin alta de clientes, assets CDA/aseguradora.
- **REPORTADO CON LOGS PREVIOS:** PHP 13/37, Python 16, V3 bajo ejecución según usuario.
- **NO VERIFICADO NI FINGIDO:** pruebas Flutter/OTA/Android sobre V3, implementación futura de cuentas/correos, funcionamiento productivo de las campañas y condición actual del host Windows de Codex.

**Dictamen:** `ARQUITECTURA=CONSERVAR_Y_COMPLETAR`, `RUMBO=ALINEADO_CON_BRECHAS_FUNCIONALES`, `RELEASE=NO_GO`, `NEXT_ACTOR=CODEX_LUNA_HASTA_ZIP_V3`; a su entrega, `NEXT_ACTOR=CHATGPT_DIRECTOR` para comprobar solo el delta y planificar un macrobloque final basado en resultados, no en estimaciones.

**Este documento NO es prompt para Codex y NO debe entregarse como una nueva orden mientras V3 está activo.**