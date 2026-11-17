# CODEX LUNA — PICORADAR N3 · EDITOR NACIONAL ÚNICO → PUBLICACIÓN → OTA HTTPS · MACROBLOQUE VERTICAL

**TASK_ID:** `PICORADAR-N3-EDITOR-NACIONAL-OTA-HTTPS-ONEBATCH-20261117`  
**RESPONSABLE:** Codex Luna ejecuta en un único candidato aislado; ChatGPT Director decide y acepta.  
**ESTADO:** orden de implementación posterior a R2; NO es una reauditoría ni autorización de release.  
**REEMPLAZA:** prompts OTA R2 y V5-R1 como órdenes pendientes; **R2 YA FUE EJECUTADO**, no repetirlo.  
**META ÚNICA:** que Super Admin/editor cambie desde el panel **un dato oficial por autoridad/departamento/municipio/localidad y modalidad**, lo publique usando el sistema Laravel existente y la aplicación, con el motor `schemaVersion=2` existente, lo aplique por OTA sin otro motor ni nueva APK por ciudad. El cierre técnico requiere demostración desde edición hasta consumidor, no otro informe conceptual.

## A. Fuente fija y restricciones antes de actuar (preflight corto, una vez)

1. Repositorio privado `sierraglobalcompany-rgb/PicoRadar`; trabajar desde `D:\codex\PicoRadar` **solo si esa es la ubicación real**, sin suponer rutas. Leer `AGENTS.md`, reglas anidadas y referencia PingPongLaw L1–L6 que esté disponible. Priorizar seguridad, datos locales y especificación aprobada. No instalar/reinstalar skills/herramientas por protocolo.
2. **Último código de producto V5-R1:** `BASE_V5_TREE=10ab7af9d07ea6ea941ba54289c9c0455b6d1f70`. **Última evidencia R2:** `FINAL_TREE=07f93bac253f9d6abf5f6535720786f571d26414`, que añade **solo un test** en `mobile/test/core/sync/restriction_g2_same_bytes_test.dart`. ZIP R2 `PICORADAR_V5R1_OTA_QA_R2_UNICO.zip`, SHA256 `12e368cc58630131e879643eae9ffd4b0dd688170fe2c1d34adc8d81643584b2`; la evidencia se recibió en el chat. El HEAD local `182a8821...` e índice real `24408f...` fueron REPORTADOS por Codex y **NO** representan por sí solos el árbol R2. Confirmar `git rev-parse HEAD`, `git write-tree` en índice alterno y WIP; **no sobrescribir, stagear ni commitear WIP ajeno**. Si R2 ya está incorporado, no aplicar dos veces; si no, usar `PATCH_R2_tests.patch` **del ZIP R2 verificado**, solo sobre el árbol base correcto y en candidato aislado; no confundir el árbol de HEAD con el del índice alterno. Nunca `reset --hard`, `clean`, rebase destructivo ni segundo escritor concurrente.
3. **Acreditado, REUTILIZAR:** R2 manifiesto 19/19, Laravel sintético A+B tres revisiones → HTTP loopback → `DatasetSyncService` → Drift/selector/motor/last-good PASS; tres inputs históricos PASS; `flutter analyze` R2 PASS. V4-R1 suite global 3347 PASS/11 SKIP/0 FAIL **sobre su árbol**, V5-R1 175 focales PASS y APK DEV `1.0.1+2` con OTA **desactivada**. **No extrapolar estas pruebas a nuevo código, pero no correr suites globales como preflight.** N1 LAB 14 autoridades/33 DIVIPOLA/22 coberturas parciales/120 reglas; 1.104 códigos geográficos no equivalen a 1.104 normas certificadas.
4. Producto en GitHub sigue `HOLD_SECURITY`; PR #79 es documentación en DRAFT. **NO push ni merge de código, ni publicación productiva/CDN real, ni cambios de firma de distribución** sin saneamiento/autorización. Registrar árbol y parche recuperable para el ZIP. Sin cuentas reales, matrículas, cédulas, contratos, documentos ni credenciales en el ZIP o servidor de QA. Mi A3 NO se desinstala, borra ni actualiza en este bloque.
5. **Fuente oficial:** publicación institucional de alcaldía, departamento o secretaría basta para los **campos expresamente indicados**, sin exigir PDF del decreto; fuente incompleta = `partial/UNKNOWN/STALE` según contrato, no `ALLOWED`. No investigar de nuevo los 1.104 municipios, no ampliar normas de Cartagena diciembre por inferencia. **Pruebas de esta orden usan datos claramente sintéticos.**

## B. Trabajo operativo concreto (una sola entrega vertical; no cuatro prompts)

### B1 — Completar el editor/manual existente según el contrato real

**Leer/usar primero** el validador y publicador existentes, `RestrictionContractValidator.php`, `RestrictionPublicationService.php`, `RestrictionFormPayloadBuilder.php`, la vista `server/resources/views/admin/restrictions/partials/rule-fields.blade.php`, controladores/rutas `/admin/restrictions/*`, y modelos de autoridad/municipios. Resolver rutas reales con búsqueda focal de nombre una vez; **no inventar clases ni rutas**.

- Comprobar qué expresiones acepta realmente el `schemaVersion=2`: categoría de vehículo + clase de servicio, autoridad y códigos geográficos, lista de dígitos/posición, días, paridad de **fecha**, intervalos/fullDay, festivos, vigencia, condiciones tipadas, zona/ámbito, `consultationEnabled`, `coverageCompleteness` y fuentes. **No añadir tipos/condiciones no comprendidos por ambos motores PHP y Dart**. Si el formulario limita hoy car/motorcycle y private/taxi, ampliar **el formulario existente** a todas las combinaciones que soporte el contrato; no crear motor, migración o editor paralelo. Reutilizar la importación JSON tipada para capacidades no representables de forma segura en un control simple, dejando opción visible y validación, sin inventar campos.
- Debe poderse **crear/editar/deshabilitar** una regla y activar/desactivar la **consulta** de una jurisdicción o modalidad; asegurar que `Jurisdiction.enabled` (estado de administración), `consultationEnabled` (dataset público) y `coverageCompleteness` (confianza legal) no se confundan. Deshabilitar consulta ≠ declarar circulación permitida. Si falta ámbito/exención certificada, marcar `partial` y respuesta cautelosa; no desactivar guardas de publicación para obtener PASS.
- El formulario debe poder editar las combinaciones existentes de: lunes→martes, conjunto de números 1/2→3/4, rango horario, paridad de fecha, festivo y periodo de vigencia; fullDay solo cuando el contrato existente permite inicio=fin desde el ancla. **No incorporar reglas legales nuevas al LAB sin evidencia oficial**. Mostrar estado de validación y fuente, y usar la revisión/roles existentes (edición ≠ aprobación).
- Super Admin/editor: verificar permisos reales para **editar / revisar / aprobar / publicar / revertir**; impedir que el editor se autoapruebe cuando la política vigente lo prohíba. No tocar el futuro módulo de clientes finales en este macrobloque.

**Gate B1:** dos territorios sintéticos (A y B) desde el panel/API administrativa de QA: editar A dígitos/día/hora y luego `consultationEnabled` sí→no→sí, B intacta; validación y aprobaciones correctas, reversiones trazables. Usar pruebas administrativas existentes; crear **solo una prueba causal** si el contrato/hueco no está cubierto. Si hay ausencia demostrable de UI para una modalidad, corregir en builder + Blade + validación y test afectado, no una pantalla adicional.

### B2 — Publicación canónica de todo el país soportado, sin borrar otras jurisdicciones

- Reusar `RestrictionRuleVersionService`, `DatasetReleaseValidator`, `RestrictionPublicationService`, `DatasetPublisher` y `ManifestPublisher`; no reescribirlos. Publicar **snapshot íntegro** de todas las autoridades aprobadas en la base QA, no solo el registro editado, junto al asset y manifiesto vigente (manifest `schemaVersion=1` envoltorio vs restricciones `schemaVersion=2`). A y B siguen en cada revisión; no crear un endpoint por ciudad.
- Registrar quién editó, aprobó, fuente oficial/fecha de revisión, hash/revision y si se activa/desactiva **consulta**. Cambiar horarios o números sin alterar APK; impedir que un `partial` produzca `ALLOWED` sin evidencia suficiente. Una localidad nueva fuera de las 73 editoriales, pero existente en el inventario geográfico, debe conservar su identificador canónico; localidad/pueblo con identidad no resuelta se mantiene `UNKNOWN` y no se inventan geocercas.
- No extender `staleAfter` artificialmente para pasar pruebas; evitar exponer datos privados en la publicación.

**Gate B2:** del resultado administrativo B1 se producen tres revisiones A+B, manifest/version/asset SHA exactos, rollback/last-good y cero borrados de autoridades no editadas. Reutilizar y extender el test R2 **solo por el nuevo límite admin→publicación**, no repetir los tres tests históricos ni fabricar una segunda suite de sincronización.

### B3 — OTA HTTPS de producto en QA aislado, o bloqueo MATERIAL acotado

- **NO confundir** HTTP loopback de R2 con OTA productiva. El provider móvil existente exige HTTPS y origen coherente entre manifest y CDN; no reducir requisitos, no aceptar certificados inválidos en build público, no modificar configuraciones globales de Windows. Usar **un endpoint QA HTTPS autorizado y accesible** si ya existe; comprobar origen/certificado/rutas y valores reales de configuración, sin secretos en logs ni ZIP.
- Si NO existe endpoint QA válido, una sola comprobación de disponibilidad y registrar exactamente `HTTPS_QA_NOT_AVAILABLE`, con la mínima dependencia concreta para habilitarlo. **Continuar B1, B2 y tests independientes** y NO hacer 4 rondas de preflight/CDN/túneles/infra nueva. No usar un HTTP local y declarar `OTA_PRODUCT_HTTPS=PASS`.
- Con HTTPS QA real: publicar manifest/asset íntegros, ejecutar consumidor de configuración productiva (no `AppConfig` inyectada que salte el contrato), importar a Drift y reiniciar en offline; comprobar habilitar/deshabilitar, rotación, otro municipio no afectado, SHA corrupto, rollback/last-good, ETag/304 según soporte. Reusar pruebas existentes. Si se modifica Flutter, una suite global **una sola vez sobre el árbol final** conforme a `AGENTS.md`; no reciclar los 3347 PASS como si fueran QA del nuevo árbol.
- Android: si no hay autorización/condiciones para instalar, **no tocar el Mi A3**. Build DEV conectado a QA HTTPS solo si hay endpoint real, cambio/configuración que justifique reconstruir y precondiciones seguras. Un APK DEV sin `CDN_BASE_URL` es **offline**, no venderlo como OTA probada. Si se compila, incluir bytes y hash en ZIP; si no hay build nuevo, referenciar APK V5 sin duplicar 245 MB.

**Gate B3:** `OTA_HTTPS_QA=PASS|NOT_RUN_ENV|FAIL` atribuido a endpoint y árbol/build. R2 HTTP local se conserva como PASS_SCOPE, no sustituye esta aceptación.

### B4 — Identidad, pruebas relevantes y cierre, sin ping-pong

- Asegurar comparabilidad de HEAD/índice real/índice alterno/árbol final; WIP intocado. Código modificado ⇒ prueba focal RED→GREEN cuando hay defecto reproducido, regresión de panel/publicación/cliente afectado, `flutter analyze` si cambia Dart, PHP focal si cambia PHP, formato solo rutas alteradas; **una única suite global móvil final SOLO si cambió código Dart** y el repositorio lo exige; explicar skips sin desactivar tests. Sin cambio de código, reutilizar su prueba atribuible y no reconstruir APK.
- Resolver errores mecánicos en el mismo macrobloque, sin pedir orientación por detalles menores. No aceptar PASS si falla input, ambiente o prueba; registrar estado preciso y seguir frentes independientes. No gastar tiempo en 10 auditorías documentales, nuevos documentos Plan Maestro, pruebas históricas 3347, revisión nacional completa o cleanup ajeno.
- Entregar un **ÚNICO ZIP** pequeño, dentro de `D:\codex\_REPORTES\PicoRadar\<TASK_ID>\delivery\`, con: `FINAL_REPORT.md` breve, `GATES.csv`, `EVIDENCE_MATRIX.csv`, logs focales y comando/exit, pruebas/fixtures sintéticos mínimos, fuente/archivo de editor y evidencia captura sin secretos si pertinente, `RECOVERY.patch` aplicable a base identificada si hubo cambios, manifest con SHA-256/tamaño/CRC32, identidad commit/tree, instrucción de restauración y WIP. **No agregar bundle RC2 ni APK V5 repetida**. Si se crea APK nueva, incluirla en ZIP (una copia) más bytes, certificado y SHA-256; excluir PII, placas y credenciales. Antes de entregar verificar CRC/manifest, reproducibilidad patch/tree y ausencia de secretos.

## C. Salidas obligatorias y decisión de cierre

Entregar estados exactamente como hechos, no como expectativas:

```text
TASK_ID=PICORADAR-N3-EDITOR-NACIONAL-OTA-HTTPS-ONEBATCH-20261117
BASE_TREE=<TREE_V5_O_R2_VERIFICADO>
FINAL_TREE=<TREE_REAL>
ADMIN_EDITOR_SCHEMA2=PASS|PARTIAL|FAIL
ADMIN_ROLES_REVIEW_PUBLISH=PASS|PARTIAL|FAIL
NATIONAL_DATA_ONLY_MANUAL_EDIT=PASS_SCOPED|PARTIAL|FAIL
PUBLISH_FULL_SNAPSHOT_SHA=PASS|FAIL|NOT_RUN_ENV
OTA_HTTP_R2=CARRIED_PASS_SCOPED
OTA_HTTPS_QA=PASS|FAIL|NOT_RUN_ENV
OTA_ANDROID=PASS|FAIL|NOT_RUN_ENV
MOBILE_FULL_QA=PASS|REUSED_PRIOR|FAIL|NOT_RUN_ENV
APK_NEW=YES|NO
USER_DOCUMENTS_LOCAL_ONLY=RESPECTED|ISSUE
GITHUB_PRODUCT=HOLD_SECURITY|SECURITY_CLEARED_VERIFIED
PRODUCT_RELEASE=NO_GO
ZIP=<RUTA_UNICA>
ZIP_SHA256=<SHA256>
NEXT_ACTOR=CHATGPT_DIRECTOR
```

**Condición de salida parcial permitida:** si falta HTTPS QA autorizado, entregar editor nacional realmente probado y publicación sintética completa con el blocker exacto; no convertirlo en otra auditoría de ambiente. Si faltan capacidades del motor tipado, identificarlas como incompatibilidad precisa y arreglar solo lo necesario en los consumidores realmente afectados, no crear una versión schema3 ni un motor por municipio.

## D. Lo que NO pertenece a N3 y sigue en el roadmap para el 100%

**Bloque siguiente, no paralelo:** registro opcional de usuarios finales, verificación email, consentimiento, perfil mínimo, control/supresión; **Super Admin** listado/búsqueda/filtros/exportación CSV de datos compartidos voluntariamente, baja de marketing, correo a opt-in. Las **placas, fotos de matrículas, cédulas, contratos, VIN y documentos** siguen locales y no deben enviarse por API/exportación. No confundir operadores admin actuales con usuarios finales.

**Después:** administración OTA/manual de CDA/SOAT/aseguradoras, catálogos y aliados ya existentes; campañas/publicidad en ubicaciones permitidas cuando el alcance Free 1.0 lo autorice. No activar anuncios por defecto. Finalmente controles de seguridad del historial GitHub, sincronización de producto/PR/merge autorizados, firma release y QA física Android/OTA; **sin publicar producto mientras exista HOLD_SECURITY**.

**Cierre real de la plataforma nacional ≠ cobertura legal total de 1.104 municipios.** Los datos normativos se amplían después con fuentes oficiales municipio por municipio sin recompilar app. La disponibilidad de geografía no significa que se haya verificado que no existe restricción.

**SIGUIENTE EJECUTOR: CODEX LUNA. DESPUÉS DEL ZIP: CHATGPT DIRECTOR.**