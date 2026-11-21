# PICORADAR — PREPARACIÓN TÉCNICA DE INTEGRACIÓN Y GATES GOOGLE PLAY PARA FREE 1.0

**DOCUMENTO DEL DIRECTOR, NO PROMPT PARA CODEX.** Fecha de corte: 21 de noviembre de 2026, Colombia.

**Estado:** Codex Luna ejecuta `PICORADAR-C7-V2-IMPLEMENTACION-NACIONAL-20261121`. **No interrumpir, reiniciar ni modificar el checkout, rama, índice Git o tests de C7.** No entregar todavía este documento a Codex como orden. Este análisis es un complemento nuevo y específico de los dos paquetes ya publicados: el plan director de aceleración y el paquete técnico de Medellín/Bogotá/Cali. **No rehace esos análisis.**

**Objetivo de este adelanto:** resolver de antemano la estrategia de convergencia de código con `main` y detectar requisitos Android/Play que una APK DEV satisfactoria **no** acredita. Evitar otra serie de prompts para «descubrir» cómo integrar el código cuando C7 termine.

**Ramas observadas (GitHub, lectura directa):**
- Canonical `sierraglobalcompany-rgb/PicoRadar`.
- `main` HEAD `e9ef37511df3110ffb0fc006ef06be781df432ac`; su **árbol** `3e3a6c05bf09c1b059262ba5cf311d3e6b348b6f`.
- Respaldo `backup/picoradar-c6-source-20261120` HEAD `bc1422c7198607850a49f4a294ed67316fed0805`; su árbol `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`.
- El commit C6 es **raíz, cero padres Git**; por tanto no tiene ancestro compartido con `main`. Ni `git merge` normal ni `git rebase` automático son una salida segura.
- PR #79 permanece Draft con base `recovery/20261019-modern`; no es la rama de convergencia. Prohibido tocarlo por esta preparación.
- `RELEASE=NO_GO`; se reportó APK DEV compilada en C6, **sin evidencia de ejecución física ni prueba de Play**. No solicitar ni adjuntar esa APK.

---

## 1. Reconstrucción del problema Git real: números comprobados, no estimaciones recicladas

Se consultaron ambos árboles completos por SHA a GitHub (ambos `truncated=false`), comparando **rutas de blobs y su SHA Git**, sin usar el ZIP como sustituto del remoto.

| Clasificación exacta | Rutas | Implicación |
|---|---:|---|
| Coinciden ruta + blob SHA | **806** | No copiar ni auditar por segunda vez; ya tienen contenido idéntico en ambos árboles |
| Misma ruta, blob SHA diferente | **408** | Reconciliación de implementación; tratar la instantánea C7 como candidata actual y `main` como historia que no debe pisarse a ciegas |
| Existen solo en respaldo C6 | **668** | Funciones y archivos candidatos para incorporación en nueva rama de integración |
| Existen solo en `main` | **2** | Analizar consumidores antes de preservar o eliminar; **NO copiarlos automáticamente** |
| Total blobs en `main` | **1.216** | Base de comparación, no total de requisitos funcionales |
| Total blobs en C6 | **1.882** | Respaldo versionado; incluye código, pruebas, recursos y documentos, **no** 1.882 archivos de código runtime |

**Por tipos del grupo «misma ruta, diferente SHA» (408):** 140 runtime Flutter/Android, 15 runtime Laravel/rutas/vistas, 70 pruebas Flutter, 4 pruebas Laravel, 8 recursos, 82 docs y 89 otros archivos. **Por tipos de los 668 solo C6:** 125 runtime Flutter/Android, 109 runtime Laravel/rutas/vistas, 145 tests Flutter, 58 tests Laravel, 20 assets, 85 docs y 126 otros. Las clasificaciones son **operativas**, no el número exacto de features.

Esta medición actual produce **1.076 archivos a agregar o actualizar** y **dos archivos históricos exclusivamente presentes en `main`**; **1.078 rutas difieren** si se cuentan también los dos del lado `main`. El histórico «838 diferencias» se refería a otro corte/metodología y **no puede reutilizarse** para afirmar la escala de esta convergencia.

### 1.1 Dos rutas exclusivas de `main`: hallazgo nuevo del análisis estático

| Ruta de `main` | Análisis estático en TAR C6 | Instrucción futura |
|---|---|---|
| `mobile/lib/app/router/root_placeholder_screen.dart` | `RootPlaceholderScreen` y su import no tienen referencias en los fuentes Dart del respaldo C6 | **Candidato a exclusión** si C7 no incorpora consumidores nuevos; no resucitar placeholder de navegación |
| `mobile/lib/features/home/presentation/home_banner_slot.dart` | En C6 no existe ningún uso Dart de `home_banner_slot` ni `HomeBannerSlot`; solo dos menciones en documentos históricos | **Candidato a exclusión**. Es un archivo `part of 'home_screen.dart'` de la versión antigua: reintroducirlo sin un `part` real puede causar análisis Dart fallido y duplicar la UI de patrocinio |

No se ha probado un análisis Flutter del árbol fusionado; **ninguno de estos dos archivos se puede etiquetar todavía como seguro para eliminar**. Codex deberá hacer la comprobación focal de referencias en el candidato C7, no otra auditoría de todo el repositorio.

### 1.2 Por qué es mejor esta estrategia

En lugar de pedirle a Codex una nueva auditoría de GitHub y luego otro prompt, el director ya fija el algoritmo de convergencia. Se reutilizan 806 blobs idénticos, se acotan los 408 conflictos de contenido a revisión por área y no se crea un merge ficticio entre commits sin parent común. No se pierde la historia de `main`; el respaldo C6/C7 permanece como copia independiente y rastreable.

---

## 2. Receta de integración NO DESTRUCTIVA para después de C7

**Especificación; NO ejecutar mientras C7 esté en curso.** Solo el integrador tendrá autoridad para la rama de integración. Utilizar una carpeta nueva bajo `D:\codex\_isolated\`; no alterar `D:\Dev\PicoRadar` ni el checkout con las 43 rutas WIP. El `HEAD`, estado, tamaño y SHA de esas 43 rutas deben permanecer iguales al inicio y final.

### Paso I0 — Recibir C7, no rehacer C6

1. Verificar **solo** el ZIP ligero C7 (manifiesto, CRC, SHA) y extraer: `C7_COMMIT`, `C7_TREE`, `C7_BRANCH`, lista de archivos modificados, gates y bloqueos.
2. Confirmar que C7 deriva del respaldo C6 o documentar con evidencia la forma real de recuperación; **no suponer ascendencia**.
3. Excluir del siguiente macrobloque la pantalla municipal, las reglas/pilotos y el QA que C7 ya haya terminado. Conservar inmutables los hashes de pruebas ya aceptadas C2–C6.
4. Si C7 no publicó código remoto, usar exclusivamente su pequeño parche/commit y la fuente C6, sin reconstruir el proyecto completo ni volver a transportar 77 MB al usuario.

### Paso I1 — Crear dos copias aisladas de fuentes de verdad

- **Fuente funcional:** checkout de rama C7 ya publicada (o C6 + delta C7 probado en aislado). Nunca la rama de `main` por sí sola como implementación actual.
- **Destino con historia canónica:** nueva rama local de integración basada en `origin/main` observado, en otro checkout aislado. No tocar `main` remoto, no force-push, no cambiar base de PR #79.
- Congelar `origin/main` y `C7_HEAD` con SHA, sin asumir que `main` sigue en el mismo commit una vez inicie la integración.
- Fuente y destino tienen worktrees e índices distintos; director e integrador no editan simultáneamente las mismas rutas.

### Paso I2 — Calcular, clasificar e integrar UNA VEZ

1. Regenerar matriz exacta `same | source_changed | source_only | main_only` usando `git ls-tree -r` de ambos árboles; la tabla anterior es **baseline C6 vs main**, no un diff C7 anticipado.
2. **No tocar los `same`.** En `source_only`, incorporar solo contenido de producto aprobado/relacionado; excluir salidas de build, `.env` con valores, backups privados, WIP, `.gradle`, `vendor`, llaves, ZIP/APK/AAB, capturas con datos personales y carpetas de QA pesadas.
3. En `source_changed`, la fuente C7 es candidata preferida **pero no una sustitución ciega**: resolver por dominio/bloque, conservar requisitos de `AGENTS.md`, baseline, seguridad y rutas del producto. `main` sirve como historia Git y posible proveedor de cambios exclusivos, no como versión funcional más reciente por defecto.
4. Para los dos archivos `main_only`, ejecutar búsqueda de consumidores Dart y análisis focal: conservar solo si son necesarios y compatibles; de lo contrario proponer exclusión explícita, con justificación y diff.
5. En archivos de código, prohibido añadir reglas de pico y placa hardcodeadas por ciudad, duplicar admin/publisher/partners existentes, cambiar API 2 a 3, añadir framework o borrar datos de Drift.
6. **Un commit de integración revisable** con inventario `added/modified/deleted`, pruebas causales y hashes; si hay conflictos de arquitectura, dividir por dominios (móvil, servidor, integración) dentro de **la misma rama descendiente de `main`**, no otro proyecto raíz.

### Paso I3 — Gates antes de subir una rama de integración

| Gate | Criterio | Resultado permitido |
|---|---|---|
| Precedencia baseline + `AGENTS.md` | Comprobar diferencias de contrato, navegación y privacidad | `PASS` o `BLOCK_CONTRACT` |
| Secretos | Scanner estándar y revisión manual de falsos positivos, incluida historia nueva que se proponga publicar | `PASS` o `HOLD_SECURITY`; **jamás** imprimir valores |
| Git | Un único ancestro real con `main`, sin force-push ni cambios protegidos; diff y rollback disponibles | `PASS` o `HOLD_INTEGRATION` |
| PHP + Flutter | Gates focales de los módulos reconciliados; una regresión integral acotada **solo** cuando el diff transversal la justifique | `PASS`, `PARTIAL_ENV` o `FAIL` con causa |
| Producto | No activar anuncios/pagos; no convertir `UNKNOWN` en circulación permitida; no publicar reglas sin revisión | `PASS` o `HOLD_PRODUCT` |
| QA Android | APK compilada ya registrada; solo nuevo build si cambió plataforma/ensamblado; no pedirla/adjuntarla | `PASS_BUILD` independiente de `PASS_DEVICE` |

Si un gate es `HOLD`, seguir con otros frentes independientes y guardar la rama local/backup seguro. No usar «escáner no instalado» como autorización para push público. **Nunca realizar merge a `main` automáticamente.**

### Paso I4 — Publicación documental y código real

- Subir una **rama propia de integración** solo tras gates de publicación seguros; crear PR **Draft** contra `main` cuando sea comparable, dejando explícito `NO_MERGE`.
- Incluir un mapa de archivos conflictivos, evidencia de los cambios que aportan las 3 capacidades nuevas y un enlace a la fuente C7/C6. Revisión de los 408 conflictos **por riesgos/rutas críticas**, no revisión manual repetitiva de 1.076 archivos idénticos o triviales.
- GitHub Actions puede permanecer bloqueado por cuota; no afirmar CI verde ni cambiar workflows para evadir billing.
- `docs/CURRENT.md` se actualizará **una vez al integrar una entrega acreditada**, no con cada edición del prompt. En el respaldo C6 todavía señala un estado de octubre: evitar confundirlo con estado C7.
- Retorno único **ligero** de Codex: hasta 5 MiB; `FINAL_REPORT.md`, `GATES.csv`, `MIGRATION_DIFF.csv`, hashes y logs pertinentes; **sin APK, TAR completo ni bundle**.

---

## 3. Gates nuevos Android / Google Play que NO estaban cerrados con la APK DEV

Análisis estático directo del TAR íntegro C6 recibido, sin instalar la APK ni acceder al teléfono. Fuente externa contrastada: documentación vigente de Google Play/Android Developers al 21/11/2026. **Son riesgos/gates potenciales; no afirmaciones de incumplimiento verificado.**

| Evidencia C6 | Situación objetiva | Decisión de QA previa a release |
|---|---|---|
| `mobile/android/app/build.gradle.kts`: `targetSdk = 36`, `compileSdk = 37`, `minSdk = 24` | El objetivo API 36 satisface el mínimo Google Play vigente para apps móviles nuevas (excepto categorías especiales) | **No** dedicar otro lote a subir la API objetivo; validar comportamiento/API real |
| `mobile/android/settings.gradle.kts`: AGP **9.1.0**, Kotlin plugin **2.4.0** | La versión AGP supera el mínimo 8.5.1 recomendado para empaquetado de bibliotecas nativas alineadas | **No** actualizar Gradle/Kotlin por reflejo. Confirmar la alineación **real** del artefacto de publicación |
| `AndroidManifest.xml`: `SCHEDULE_EXACT_ALARM` | La aplicación solicita exact alarm; `AlertPlatform.kt` comprueba acceso y usa `AlarmManager.setAlarmClock` | Probar concesión/denegación y fallback con Android reciente; documentar caso de uso y Play policy |
| `AndroidManifest.xml`: `USE_FULL_SCREEN_INTENT` | `AlertPlatform.kt:105` utiliza `setFullScreenIntent` si hay permiso; `AlertsBridge.kt` abre ajustes | Revisar si las **alarmas opcionales** constituyen funcionalidad principal autorizada por Play; validar fallback cuando no se concede, sin obligar al usuario |
| `AndroidManifest.xml`: `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | `AlertRingingService.kt:64` ejecuta `startForeground(...MEDIA_PLAYBACK)` mientras reproduce tono de **alarma** | Confirmar que `mediaPlayback` cumple política para ese uso específico; evitar declarar «aprobado» porque Gradle compila; revisar declaración FGS en Play Console |
| Flutter + plugins nativos/SQLite | Binarios nativos pueden requerir compatibilidad con memoria de página **16 KB** | Comprobar empaquetado/ELF en **AAB de release cuando esté autorizado**; no inferirlo de debug APK ni pedir subir un APK al chat |
| `AndroidManifest.xml`: `android:allowBackup="false"` y reglas de extracción privadas | Hay controles declarativos para evitar exportación predeterminada de datos sensibles | Mantenerlos; comprobar comportamiento en versión de distribución, no eliminar por «simplificar» |

**Rutas a inspeccionar en futuro gate focal:**
- `mobile/android/app/src/main/AndroidManifest.xml` (permisos y componentes).
- `mobile/android/app/src/main/kotlin/co/picoradar/app/alerts/AlertPlatform.kt` (acceso, exact alarm, full-screen y fallback).
- `mobile/android/app/src/main/kotlin/co/picoradar/app/alerts/AlertRingingService.kt` (FGS audio y duración).
- `mobile/android/app/src/main/kotlin/co/picoradar/app/alerts/AlertsBridge.kt` (solicitud de permisos).
- `mobile/android/settings.gradle.kts` y `mobile/android/app/build.gradle.kts` (AGP, Kotlin, NDK, SDK).

**Fuentes oficiales verificadas:**
- Google Play, requisito actual de API 36: https://support.google.com/googleplay/android-developer/answer/11926878
- Google Play, declaración de FGS e intents de pantalla completa: https://support.google.com/googleplay/android-developer/answer/13392821
- Google Play, política de permisos de alarmas: https://support.google.com/googleplay/android-developer/answer/16558241
- Android Developers, tipos FGS obligatorios y condiciones: https://developer.android.com/develop/background-work/services/fgs/service-types
- Android Developers, páginas de 16 KB, bibliotecas nativas y alineación: https://developer.android.com/guide/practices/page-sizes

**Precaución:** `USE_FULL_SCREEN_INTENT` restringido no significa que PicoRadar esté automáticamente prohibida; `MEDIA_PLAYBACK` para alarma no es automáticamente conforme. Se necesita el caso de uso demostrado y la decisión de Play/propietario. No cambiar permisos sin pruebas y diseño de fallback.

---

## 4. Reparto listo para la primera ola POST-C7, sin pisar a Codex

Este documento no crea C8. En cuanto llegue el SHA real y el ZIP ligero C7, **descontar los archivos y capacidades que C7 ya cerró**. Las tareas siguientes se asignan solo después de esa comprobación.

| Responsable | Entregable acotado | Exclusión para evitar conflicto | Criterio de aceptación |
|---|---|---|---|
| Agente A — Flutter | Unificar el aviso temporal de alcance Bogotá que ya se identificó en Pico/Viaje hacia fuente de datos/fallback general, sin hardcode legal por ciudad; además cerrar un recorrido de usuario que C7 no haya tocado | No editar controlador/CSV/bandeja municipal ni cambiar esquema OTA | Dos consumidores con estado seguro, prueba causal de vigencia/UNKNOWN; diff runtime real |
| Agente B — Laravel | Puerta editorial de fuente vencida/incompleta **solo si falta**, revisión de permiso y vínculo fuente–versión, con borrador nunca publicado por defecto | No repetir export CSV ni pantalla municipal de C7 | Admin *fuente → revisión → aprobación → publicación manual* y rechazo de `STALE` crítico sin evidencia |
| Agente C — Comercial Free OFF | Semántica y rotulación de fallback editorial vs patrocinio de campañas, sin SDK ads, cuentas obligatorias ni activación remota | No tocar motor/OTA ni layout común trabajado por C7 | UI y API fail-closed, `Ads/Pagos/Premium=OFF`, test único causal de la brecha real |
| Integrador I — Git + release | Rama descendiente de `main` reconciliada con C7; preflight focal de permisos Android y 16 KB, sin recompilar de rutina | Único dueño del Git index y archivos transversales; no entrar al worktree protegido | PR Draft de código solo si seguridad/contrato pasan; QA diferenciada de build, política y físico |

**Política de paralelismo:** 3 agentes solo si el host lo permite; distintos worktrees/paths y máximo una compilación pesada. Si no hay agentes, ejecutar la misma planificación secuencialmente sin cambiar criterios. Cada agente entrega SHA + archivos + test causal o bloqueo preciso al integrador. **No generar un prompt por cada subagente**; el director enviará UNA orden macrobloque cuando C7 haya terminado.

---

## 5. Checklist de no repetición y decisiones reservadas al director

- `NO_REDO`: C2 puente local PHP→Flutter; C3 tests de permisos/Drift/offline; C4 bandeja editorial; C5 filtros activos/inactivos y ciudades UNKNOWN; C6 export CSV y build APK DEV + backup remoto; C7 prueba/bandeja/pilotos **solo tras conocer resultado real**.
- `NO_FALSE_GREEN`: APK debug ≠ QA físico ≠ AAB firmado de producción ≠ aceptación Play; loopback HTTP ≠ HTTPS staging; municipio presente ≠ acto legal vigente; respaldo GitHub ≠ merge `main`; pantalla sin red simulada ≠ QA offline en dispositivo.
- `NO_NOISE`: no nuevos esquemas, motores por ciudad, microservicios, frameworks Flutter, interfaces duplicadas, tests completos repetidos sin cambio causal, corrección de cachés sin falla nueva.
- `NO_SECRETS`: solo scanner aprobado, variables y hashes, cero valores sensibles en ZIP/commit/log. Revisar también historia incorporada; C6 root no debe utilizarse como parent inventado de `main`.
- `NO_REGEN_APK`: conservar APK C6 únicamente local Codex; no solicitarla, adjuntarla, reconstruirla ni transmitirla por defecto.
- `NO_58%`: la cifra 58 % es estimación histórica sin denominador. Indicador de evidencia 61/100 **separado**. El progreso de Free 1.0 se medirá por recorridos críticos aceptados / recorridos críticos congelados; porcentaje real solo si el contrato y pesos quedan fijados.
- `NO_TOUCH_C7`: no nuevas órdenes, reinicios ni cambios de rama a Codex hasta retorno C7.

### Estado/actor al corte

`C7_V2=IN_PROGRESS_REPORTED_BY_OWNER` · `RELEASE=NO_GO` · `CODE_BACKUP_C6=PASS_REMOTE` · `MAIN_INTEGRATION=NOT_DONE` · `APK_C6=BUILD_PASS_ONLY` · `C7_RESULT=UNKNOWN`.

# 🔴🔴🔴 CONTINÚA CODEX LUNA CON C7-V2. EL DIRECTOR NO DEBE PISAR SU EJECUCIÓN. 🔴🔴🔴

**DESPUÉS DE RECIBIR EL ZIP C7, CHATGPT DIRECTOR DEBE ACTUALIZAR ESTE PLAN DIFERENCIALMENTE Y EMITIR UNA SOLA ORDEN DE DESARROLLO.**
