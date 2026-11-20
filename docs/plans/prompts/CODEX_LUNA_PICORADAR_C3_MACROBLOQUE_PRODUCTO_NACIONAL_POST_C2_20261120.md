# CODEX LUNA — PICORADAR C3 · MACROBLOQUE DE PRODUCTO NACIONAL, ADMIN, EDITOR, OFFLINE Y ENTREGA CONTROLADA

**ORDEN EJECUTABLE PARA CODEX LUNA. Director: ChatGPT. Fecha: 20/11/2026, America/Bogota.**  
**TASK_ID:** `PICORADAR-C3-PRODUCTO-NACIONAL-POST-C2-20261120`  
**OBJETIVO:** avanzar en **código funcional** de PicoRadar, no crear otra auditoría, otra preflight o un nuevo prompt. Trabajar de forma KISS y evitar ping-pong. **Entregar un único ZIP** de retorno, listo para adjuntar a ChatGPT, con el código nuevo y evidencia proporcional.

## 0. Contrato del lote — léelo antes de ejecutar

1. **No repetir gates ya aprobados**. El ZIP C2 V2 `CF8964C82A7203BCCAA39B97EC12EA8CC111EE5B054623BB011D7CCD962C3987` acreditó `VERTICAL_SAME_BYTES=PASS_LOCAL`, `ROLLBACK_LAST_GOOD=PASS_LOCAL`, `SDK_SQLITE3=PASS_LOCAL`. C1 acreditó 53 PHP/592 aserciones/0 warnings y R2 acreditó 3.365 Flutter PASS/11 SKIP. Estas evidencias **no certifican** otros escenarios, pero no deben reejecutarse por rutina si no tocaste código relacionado.
2. **Candidato local**: conservar árbol inicial `859bb8bbdff769ec3504af407f4df27593b2efea`, HEAD candidato `37ca71e1a1ebfbb14d908f3ab128c109ff401bc2`, `pubspec.lock` SHA-256 `e86ada9d658800b3c47bcfb1f8743d3ff14ce75fac1b81bc040b16ccfb03a41b`, 61 rutas previamente staged. **No confundas el árbol inicial con el nuevo final.** El lote C3 DEBE hacer cambios funcionales si el entorno lo permite. Si algún hash ya cambió por una ejecución real posterior, registrar evidencia y adoptar la nueva base solamente si se puede demostrar, nunca sobreescribir el trabajo de otro agente.
3. **Fuente protegida**: `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`, HEAD `182a8821bba688b28a6e223a1e956df748f7948b`, índice `24408f305f7a977cf30e426ce3925cca19f981ad`, 43 rutas WIP observadas (18 tracked, 25 untracked). **SOLO LECTURA, no git clean/reset/checkout/stash/commit**, y no escribir allí. Calcular huella de contenido **una vez al principio y una vez al final** con recorrido determinista sobre las rutas existentes (contenido y modo/metadatos relevantes); distinguir explícitamente lo que no pudo verificarse. No tomar un fingerprint de otro informe como medición nueva.
4. El candidato usa `alternates` hacia objetos Git del checkout protegido. No eliminar esa fuente, no hacer operaciones que rompan el almacén de objetos. Antes de cualquier rama/commit, verificar integridad de los objetos requeridos y conservar procedimiento de recuperación. No utilizar la existencia de un `git tree` como prueba de que se transfirió al GitHub remoto.
5. **El Markdown C2 y el reporte/ZIP C2 son contexto, no pasos para repetir**. Si hay funciones ya implementadas, inspeccionar sus tests y rutas **una vez** y completar solo el contrato faltante; no clonar clases, no crear doble motor ni una segunda base de datos. Primero leer `AGENTS.md` y el documento de mayor precedencia que aplique al flujo modificado; no reinterpretar las leyes aprobadas.
6. **Reglas de producto**: Free 1.0 antes de monetización; funciona sin cuenta; barra `Inicio · Garaje · Apps · Viaje · Conducir` con Apps al centro; restricciones evaluadas localmente; GPS continuo no se transmite ni almacena por defecto; publicidad, pagos, email marketing, SDK comercial y cuentas obligatorias OFF. NO desplegar al servidor, NO FTP, NO ADB, NO teléfono ni release sin gates y autorización.
7. **Leyes 1–6**: L1 KISS/ponytail, L2 antirruido, L3 antiparches, L4 diseño humano, L5 verificación independiente proporcional, L6 antipíng-pong. Un error se investiga por causa, no con secuencias de cambios aleatorios ni diez tandas de pruebas. No inventar PASS para bloqueos ambientales.
8. Trabaja en `D:\codex\PicoRadar` **solo si es el directorio del candidato previamente validado**. De lo contrario identifica y usa el candidato aislado real ya existente, **no** la fuente protegida. Todos los outputs en `D:\codex\_REPORTES\PicoRadar\C3-20261120\`, o ruta de reportes equivalente existente. No crear carpetas en la fuente protegida.

## 1. Prioridades — de mayor retorno a menor retorno

**P0: cerrar experiencia manual de restricción nacional** en Laravel/Super Admin/editor sin prometer cobertura que no existe. **P1: terminar la experiencia Flutter offline/rollback y migración desde datos existentes.** **P2: publicidad y aliados integrados pero desactivados y controlables.** **P3: build APK DEV únicamente cuando el entorno permita compilar; HTTPS real y dispositivo solo cuando haya configuración externa aprobada.**

No bloquear P0/P1 por P3. La RAM al cierre C2 era 4,64 GiB, inferior al umbral operativo de 6 GiB, por tanto no gastar el lote en esperar memoria o lanzar Gradle repetidamente. Solo medir una vez antes del intento final.

## 2. Coordinación para avanzar en paralelo SIN colisiones

Codex principal es **INTEGRADOR ÚNICO**. Puede usar **máximo 2 subagentes ejecutores** si dispone de worktrees/copies aislados con el árbol integrado completo y recursos suficientes; nunca dos agentes con escritura en el mismo índice Git, `mobile/.dart_tool`, directorios Gradle ni `.env`.

- **Agente A — Laravel, editor nacional, Super Admin, seguridad de ejemplos**: escribir SOLO `server/` en su espacio aislado. Entregar diff/patch y tests causales. No alterar móvil.
- **Agente B — Flutter, offline, persistencia, migraciones y superficies publicitarias OFF**: escribir SOLO `mobile/` en su espacio aislado. Entregar diff/patch y tests causales. No alterar servidor ni correr Gradle mientras otro proceso Dart importante esté activo.
- **Integrador**: reúne patches en el candidato controlado, resuelve solo conflictos reales, corre una vez el gate cruzado cuando exista dependencia causal, firma el ZIP de salida. Si subagentes/worktrees no existen, RAM insuficiente o el candidato staged no puede reproducirse idéntico, ejecutar **A y B secuencialmente** en el mismo candidato. Paralelismo es una oportunidad, **no un nuevo bloqueador**.
- Si hay tareas no relacionadas, pueden investigarse en paralelo de solo lectura; ninguna necesita esperar a `sqlite3` para adelantar código servidor. No afirmar agentes creados si no se crearon.

## 3. Agente A — implementar, no describir (P0)

Usar **las estructuras existentes**: `server/resources/views/admin/restrictions/form.blade.php`, `partials/coverage-fields.blade.php`, `server/app/Services/RestrictionFormPayloadBuilder.php`, `server/app/Services/DatasetReleaseValidator.php`, rutas/admin Laravel y publicador existente; revisar previamente tests `RestrictionSchemaV2LabRoundTripTest.php`, `RestrictionFormPayloadBuilderTest.php`, `MobileCatalogPublicationTest.php`. No duplicar servicios existentes.

**Entrega obligatoria del agente A**:

A1. Dejar el editor nacional realmente utilizable para **crear/editar/previsualizar/validar** una jurisdicción, vehículo y modalidad de regla presentes en el contrato tipado actual: particulares, motos, taxis y servicio público donde haya cobertura acreditada. Reutilizar schemaVersion=2 y motor generalizable para excepciones/horarios/días/placa, y zona horaria explícita en vencimientos. Si un tipo todavía no está soportado, mostrar `UNKNOWN/NO_COVERAGE` y consignar necesidad, **no agregar reglas legales inventadas ni reinterpretar excepciones**.

A2. Estados por jurisdicción/categoría claramente separados: `VERIFIED_OFFICIAL` (con referencia oficial comprobable, fecha/ventana de vigencia, categoría y alcance), `PARTIAL`, `UNKNOWN`, `STALE`, y **SIN_RESTRICCION_SOLO_CON_FUENTE_OFICIAL_VERIFICADA**. Los nombres internos pueden diferir si el modelo existente ya los define, pero la semántica no puede confundirse. Municipio presente en selector ≠ cobertura legal, `UNKNOWN` ≠ libre circulación, ciudad sin restricción por falta de datos ≠ certificación de ausencia de norma.

A3. Ruta manual completa: **borrador → validación causal → revisión por rol autorizado → publicación versionada → puntero/manifiesto SHA-256 → rollback al último bueno**. Si ya existe, demostrarlo con una prueba focal nueva del caso faltante en lugar de reconstruirlo. Debe rechazar/publicar nada ante reglas inválidas, fuente caducada no autorizada o rol insuficiente; en rollback conservar último artefacto inmutable válido.

A4. Super Admin: distinguir explícitamente permisos de editor y aprobador/publicador, evitar que un operador común habilite un país/ciudad o reemplace la fuente sin control. Usar guards/policies/middleware existentes; **no añadir otro sistema de autenticación**. Una prueba causal de denegación y otra de acción permitida donde faltaban, no repetir todos los tests anteriores.

A5. Cobertura nacional: usar la matriz C2 como inventario de trabajo, NO como fuente legal. Priorizar Medellín, Bogotá, Cartagena, Manizales u otras jurisdicciones cuyo dato local tenga fuente y vigencia demostrable. **No fabricar decreto ni cambiar `UNKNOWN` a PASS legal solo por hash LAB o por archivo bajo `official/`**. Adjuntar para cada nueva cobertura verificada URL oficial real, fecha de consulta, normas y categorías efectivamente cubiertas. Si no hay fuente confiable, permanecer `UNKNOWN` y **adelantar el editor y publicación funcionales de todos modos**. Registrar cobertura por jurisdicción × clase × período, nunca dar un porcentaje nacional por conteo de municipios en catálogo.

A6. Revisar **diferencialmente** el hallazgo de `server/.env.example` y `server/.env.staging.example` sin mostrar valores: los ficheros son ejemplos y en el parche integrado agregaron principalmente flags de campañas/cuentas OFF. Comparar añadidos del delta con el baseline, ejecutar escaneo apropiado de secretos solo en archivos cambiados y clasificar: `PLACEHOLDER/EMPTY`, `SUSPICIOUS_UNCONFIRMED` o `CONFIRMED_EXPOSED`. Si se confirma un secreto activo, no exportarlo, no subirlo y marcar rotación humana. **No afirmar compromiso ni desbloqueo seguro a partir del nombre `APP_KEY` por sí solo**. No reescribir los valores de ejemplo que no correspondan a este lote salvo riesgo confirmado.

**Resultados A**: fuente y tests cambiados, listado de endpoints/roles/estado, una demostración reproducible del flujo manual y matriz legal honesta. Si el flujo ya está completo, no tocar código sin necesidad: documentar qué falta realmente y usar el tiempo para cerrar otra ruta admin pendiente de producto.

## 4. Agente B — offline real y móvil (P1)

Usar arquitectura existente `mobile/lib/core/sync/dataset_sync_service.dart`, `published_catalog_store.dart`, `mobile/lib/app/app_providers.dart`, Drift `AppDatabase`, tests previos `mobile_catalog_ota_test.dart` y el test puente G2. **Una sola fuente de verdad** para datasets locales; no un segundo motor de restricciones, no duplicar persistencia.

B1. Diseñar y ejecutar **una prueba causal offline**: sincronizar una vez un snapshot íntegro de schemaVersion=2, cortar/redirigir el transporte, reiniciar el servicio/proveedores y comprobar que un usuario SIN CUENTA puede consultar el último dataset válido y evaluar una categoría cubierta. Durante interrupción la app no debe inventar `ALLOWED`; ante `UNKNOWN/STALE`, indicar incertidumbre. Si ya pasa, no introducir cambios artificiales.

B2. **Una prueba causal de migración/upgrade Drift** utilizando fixture de versión histórica realmente soportada y ruta actual; comprobar que conserva vehículos y datos de usuario, y la versión/filas de cobertura pertinentes. No resetear BD del usuario para superar fallo; si el fixture original no está disponible, dejar `NOT_RUN_FIXTURE` con la identidad precisa que falta y avanzar B3. Si requiere ajustar una migración, corregir solo la causa reproducida.

B3. Garantizar que el catálogo de campañas/aliados, si el código ya lo consume, sea **fail-closed por defecto** (OFF/ausencia/manifest inválido/no HTTPS) y no convierta contenido patrocinado en oficial. Implementar solo el punto faltante de presentación o validación usando componentes existentes; NO agregar SDK de anuncios, pagos, telemetría, suscripciones ni nueva infraestructura comercial. Validar navegación principal `Inicio · Garaje · Apps · Viaje · Conducir`; no mover Apps del centro.

B4. Si hay dos defectos de producto directamente reproducibles en estas rutas, corregirlos con una prueba primero. No gastar recursos en `flutter test` global, `pub get` o `flutter clean` sin causalidad. Si la suite afectada es pequeña, correrla una vez; guardar salida y tiempo de ejecución. Mantener Flutter 3.47.1/Dart 3.13.1 si es el SDK activo validado; no borrar `hooks_runner` regenerado salvo que surja un fallo NUEVO acreditado.

**Resultados B**: por lo menos un gate offline o migración realmente ejecutado (PASS/FAIL_BUG/NOT_RUN_ENV honesto), cambios causales si fueron necesarios, y visualización de incertidumbre sin convertir sin cobertura en libre circulación.

## 5. Integración funcional y salida (P2/P3)

I1. Integrador aplica SOLO los diffs causales de A/B al candidato integrado, comprueba rutas y ausencia de conflictos de índice. Conservar los 61 staged preexistentes en historial de lote, y reportar por separado **archivos nuevos C3** de los heredados N4/N5. No imponer `git add .` a ciegas. Crear commit(s) **locales en una rama aislada** si el árbol y auditoría de secretos lo permiten, con hashes HEAD/TREE; **nunca** commit en la fuente protegida. Si por condiciones del candidato no es seguro, entregar patch portable y estado exacto sin commit; no declararlo integrado si no lo está.

I2. Ejecutar **una sola integración cruzada adicional** si A cambia validación/publicación o B cambia contrato de sincronización: publicar localmente schema2 con el editor actualizado y probar importación Flutter; no repetir el puente C2 si ninguna pieza del contrato cambió. No publicar LAB como dato legal productivo. Si B solo agrega offline, ejecutar exclusivamente su test offline y no el puente anterior.

I3. Seguridad y GitHub: `GITHUB_PRODUCT=HOLD_SECURITY` se conserva hasta que el directorio/código exacto a publicar tenga escaneo de secretos y controles autorizados verificables. **No push ni merge si hay secreto confirmado, permisos 403, o gate de seguridad sin cerrar**. No usar GitHub Actions pagos. Si todo está realmente limpio, GitHub permite escritura y la rama de integración aislada está autorizada, push de **rama de candidato no productiva**, sin merge automático a `main`; publicar un único informe de qué commit/archivos quedaron remotos. Si no hay permiso, entregar la nueva rama/patch dentro del ZIP, con SHA-256, para recuperación posterior. Nunca convertir documentación subida a GitHub en afirmación de código publicado.

I4. Android DEV: **SOLO al final** medir RAM libre; si >=6 GiB, comprobar de forma no destructiva Android SDK, Java y Gradle desde candidato aislado e intentar **una build DEV**; si falta RAM/SDK, `APK=BLOCKED_RESOURCE/ENV` y continuar cerrando el ZIP. No modificar `key.properties`, certificados ni firma productiva. No ADB ni Mi A3 sin autorización/compatibilidad de firma. No Gradle reintentos ciegos. Flutter multiplataforma permanece, enfoque Android primero.

I5. HTTPS/OTA vivo solo si existe entorno autorizado con URL/configuración explícita y secretos no compartidos; de lo contrario `NOT_RUN_EXTERNAL`, sin exponer ni tocar FTP/Hostinger o CDNs productivos. En ausencia de entorno real, la validación local **no** se renombra `E2E_HTTPS_PASS`.

## 6. Gatillos antiestancamiento — obligatorio

- **Falla SDK/SQLite otra vez**: reporta SDK activo/ruta/error nuevo, **máximo una reparación causal**; servidor sigue trabajando. No repetir reseteos globales.
- **PHP falla por `sqlite`/migración**: reproducir con un test específico, corregir causa si posible; móvil sigue trabajando. No reiniciar suites completas.
- **Fuente legal insuficiente**: conservar `UNKNOWN`, completar herramientas de editor/validación/rol y registrar únicamente la evidencia faltante.
- **Seguridad incierta**: no publicar, pero **desarrollo local continúa** con patches sanitizados.
- **No hay subagentes**: ejecutar secuencialmente; no declarar `PARTIAL` solo porque la orquestación no estuvo disponible.
- **RAM < 6 GiB**: no iniciar Gradle ni repetir mediciones; avanzar P0/P1 y salir con artefactos de código verificables.
- **No se puede escribir GitHub**: no gastar ciclos de intentos; registrar error 403 real, branch/commit local, patch SHA y recuperación, ZIP único. No cambiar a repositorios pagos ni ejecutar Actions.
- **Ningún código cambió** porque todo P0/P1 ya funciona: entregar evidencia de tests focales **nuevos y relevantes** más lista verificable de gaps reales restantes; no simular funcionalidad no construida.

## 7. Gates y evidencias requeridas — SIN falsos positivos

| Gate | Criterio de PASS | Si falta |
|---|---|---|
| `C3_EDITOR_NATIONAL` | Editor crea/valida/previsualiza y publica/rollback con rol correcto y prueba focal | `PARTIAL_CODE` o `NOT_RUN_ENV` + causa precisa |
| `C3_ADMIN_AUTHZ` | Permisos editor/aprobador contrastados en prueba focal | `FAIL` o `NOT_RUN` |
| `C3_NATIONAL_LEGAL` | Solo jurisdicciones/clases/fuentes vigentes verificadas; resto UNKNOWN | `PARTIAL_LEGAL` nunca VERIFIED inventado |
| `C3_OFFLINE` | Prueba sin red sobre last-good, reinicio y evaluación sin cuenta | `NOT_RUN_ENV` o `FAIL` |
| `C3_DRIFT_MIGRATION` | Migración con fixture real preserva datos | `NOT_RUN_FIXTURE` o `FAIL` |
| `C3_ADS_OFF` | Contenido patrocinado OFF/fail-closed y distinguible | `PARTIAL_CODE` o `FAIL` |
| `C3_PUBLICATION_BRIDGE` | Solo si contratos cambiaron, nueva aserción local pasa | `REUSED_C2` si sin cambios relevantes |
| `C3_GITHUB_SECURITY` | Revisión sobre bytes/rutas a subir, sin confirmados secretos y con permiso | `HOLD_SECURITY` |
| `C3_APK_DEV` | APK DEV construida, hash, firma y método de build disponibles | `BLOCKED_RESOURCE/ENV` |
| `C3_SOURCE_WIP_BYTES` | Fingerprint de bytes de las 43 rutas fuente inicial/final igual | `NOT_VERIFIED`, sin falso PASS |
| `C3_RELEASE` | NO_GO hasta HTTPS real, firma, QA física, validación legal y autorización | `NO_GO` |

Ningún PASS se obtiene de un archivo llamado `official`, de 14 hashes LAB correctos, de `exit 0` sin aserciones pertinentes, de un snapshot sintético, de un `git tree` local ni de un placeholder de APK.

## 8. Entrega final ÚNICA

Guardar **exactamente un ZIP** `PICORADAR_C3_RETORNO_UNICO.zip` en la carpeta de reportes; sin directorios dispersos, ZIPs anidados ni secretos. Incluir:

1. `FINAL_REPORT.md`: tabla inicial/final de gates; qué **se implementó en código**, archivos cambiados, flujos demostrados, pendientes, causas ambientales, decisión `RELEASE`, `NEXT=CHATGPT_DIRECTOR`.
2. `GATES.csv`: PASS/PARTIAL/FAIL/NOT_RUN con rutas de evidencia (nunca PASS sin ejecución).
3. `CHANGES.patch` (o `CHANGES_C3.patch`): cambios nuevos C3 portables, con base commit/tree, sin incluir credenciales; si cero cambios, explicación causal.
4. `QA_LOGS/` con logs focales relevantes completos y sanitizados, conteos, SHA-256 y comandos exactos; no copiar suite vieja por volumen.
5. `NATIONAL_COVERAGE_DELTA.csv`: cobertura por jurisdicción/clase/fecha/fuente URL comprobable, `UNKNOWN` donde falte; NO añadir filas sintéticas como vigencia legal.
6. `GITHUB_STATUS.md`: local HEAD/TREE, ramas, commits reales y estado remoto verificado si se hizo push; consignar 403 si ocurre, sin inventar sincronización.
7. `SOURCE_WIP_FINGERPRINTS.csv`: 43 rutas protegidas si siguen presentes, digest inicial/final o estado de verificación no posible; sin contenido sensible.
8. `APK/` solo si se construyó, con SHA-256 y firma DEV verificada. No empaquetar datos privados de teléfonos.
9. `MANIFEST.csv` con path/size/SHA-256/CRC32 de todos los miembros salvo el propio manifest. **Comprobar CRC y cada hash después de cerrar el ZIP**, incluir su SHA-256 y ruta para adjuntar. Un solo ZIP.

**Formato del mensaje final de Codex**: `TASK_ID | CODE_STATUS | SOURCE_TREE | FINAL_TREE | CHANGED_C3 | GATES | ZIP_SHA256 | GITHUB_PRODUCT | RELEASE | NEXT=CHATGPT_DIRECTOR` y enlace local al ZIP. Los porcentajes no suben solo por pasar pruebas antiguas; registrar progreso cuantificable de funcionalidades C3 cerradas.

## 9. Directrices de cierre y siguiente actor

**No volver a generar un C2, no pedir otro prompt, no reabrir una auditoría 10×10, no perseguir defectos de SDK que ya pasaron.** El destino es una app Free 1.0 completa en motor nacional tipado, editor nacional, Super Admin, OTA offline, catálogo de aliados con publicidad OFF, servidor y Android. Este C3 debe dejar cambios de producto verificables y un único paquete transferible aun si no existe APK por RAM.

# 🔴🔴🔴 SIGUE: CODEX LUNA — IMPLEMENTAR C3 Y DEVOLVER UN ZIP ÚNICO 🔴🔴🔴

**DESPUÉS DEL ZIP SIGUE: CHATGPT DIRECTOR.**
