# CODEX LUNA — PICORADAR C8 · MACROBLOQUE PARALELO DE CORRECCIÓN REAL + INTEGRACIÓN SEGURA

**ORDEN EJECUTABLE PARA CODEX LUNA — DIRECTOR: CHATGPT.** Corte: 21/11/2026, Colombia. `TASK_ID=PICORADAR-C8-MACROBLOQUE-PARALELO-POST-C7-20261121`. **Este archivo sustituye cualquier instrucción de «volver a auditar C7».** El objetivo es ENTREGAR CÓDIGO implementado, no un informe voluminoso.

## 0. Estado probado que NO se vuelve a investigar

- Repo `sierraglobalcompany-rgb/PicoRadar`. C6 source-only comprobado: rama `backup/picoradar-c6-source-20261120`, commit `bc1422c7198607850a49f4a294ed67316fed0805`, tree `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`, 1.882 blobs.
- **C7 aceptado en su alcance:** `feat/C7-national-review-20261121`, HEAD `9304aa8d03cfd852a3f8943405cf8250dfe1d3c0`, PR #86 `Draft`, basado en C6. Matriz municipal GET `/admin/restrictions/municipalities`, 3 PHP focales/41 aserciones, navegación visual local, Pint y Vite PASS. No repetir el paquete C7; **no fusionar PR #86**.
- **Rama C8 de trabajo YA PREPARADA por el director:** `feat/C8-national-release-hardening-20261121`, HEAD inicial `dfa8ee13d861f24c3213d424d768305a0ea08d60`, **descendiente de C7**. Incluye ya tres archivos del cambio de consentimiento del módulo de aliados, con hashes Git comprobados. No volver a introducir ni copiar ese parche; **ejecutar su prueba real**.
- APK DEV C6 (`co.picoradar.app.dev`, `1.0.1+2`, SHA-256 `245e285d86fa2057dd53870fc38141746b61342821012abd1f761857395fb639`) se conserva en equipo de Codex. **NO PEDIR, NO ADJUNTAR, NO VOLVER A COMPILAR POR RUTINA LA APK; NO EMPAQUETAR TAR NI BUNDLE DE FUENTE**. Android físico C7: cero dispositivos ADB, emulador no disponible; HTTPS: sin staging autorizado. **No bloquear desarrollo por esos dos gates**; solo volver a inspeccionarlos si cambió realmente el entorno y hay permiso.
- Rúbrica de evidencia: 61/100, no porcentaje real de aplicación. 58% de «producto integral» y 83% de «motor» son estimaciones históricas no comprobadas. Nunca declarar mejoras porcentuales a partir de cantidad de archivos, commits o tests repetidos.
- 43 rutas WIP protegidas del checkout original `D:\codex\PicoRadar` intocables. Trabajar exclusivamente en **nuevas copias/worktrees aislados**. `main` `e9ef37511df3110ffb0fc006ef06be781df432ac` y PR #79 intactos hasta orden posterior; sin merge ni force push.
- Diferencial Git real `main` vs C6: 806 blobs iguales, 408 rutas con mismo path y blob diferente, 668 solo C6, 2 solo `main`: `mobile/lib/app/router/root_placeholder_screen.dart` y `mobile/lib/features/home/presentation/home_banner_slot.dart`. **No son automáticamente necesarios, ni automáticamente eliminables**. `main` no tiene ancestro común con el snapshot raíz C6. No usar merge/cherry-pick ciegos.
- `AGENTS.md`, baseline, `docs/SOP.md` y contrato de diseño tienen precedencia. Arquitectura KISS: Flutter/Riverpod/Drift + Laravel; app Android-first, offline, sin registro obligatorio. Navegación `Inicio · Garaje · Apps · Viaje · Conducir`, Apps centro. Free 1.0: ads/pagos/premium **OFF** y no anuncios en Conducir. Sin GPS continuo/placas/documentos privados hacia servidor. Motor nacional OTA; ciudad sin regla = `UNKNOWN`, nunca automáticamente `ALLOWED`.

## 1. Resultado obligatorio y forma de paralelizar

**OBJETIVO DE C8:** cerrar tres deficiencias funcionales verificadas (móvil, panel nacional y consentimiento de aliados) y dejar un candidato integrable con la historia real de GitHub. No declarar `PASS` por ejecutar scripts o por producir un plan.

### Asignación de agentes (si Codex admite subagentes)

- **Agente A — Flutter / cobertura de alcance y trayecto.** Trabajo sobre `mobile/lib/features/pico_placa/presentation/restriction_scope_notice.dart`, sus consumidores y **solo los tests relacionados**. No editar `home_partner_carousel.dart` ni `partner_inquiry_client.dart`.
- **Agente B — Laravel / matriz municipal y publicación real.** Trabajo en `server/app/Http/Controllers/Admin/RestrictionRuleController.php`, `server/resources/views/admin/restrictions/municipalities.blade.php`, CSV de cobertura si resulta afectado, y **tests focales nuevos**. No editar archivos móviles.
- **Agente C — Aliados / consentimiento.** Parte del parche ya incluido en C8 (`partner_inquiry_client.dart`, `home_partner_carousel.dart` y `partner_inquiry_client_test.dart`). **Primero correr la prueba**. Si pasa, no tocar esos archivos. Si falla, reparar la causa mínima y agregar solo el test que documente el defecto real. No habilitar tráfico comercial ni modificar flags.
- **Agente D — Legal, investigación de solo lectura** (opcional en paralelo, sin retener integrador). Preparar matriz de fuentes oficiales con actos y artículos exactos; no tocar motor ni generar reglas hipotéticas. Texto íntegro del Decreto 652/2025 de Bogotá accesible en `https://www.bogotajuridica.gov.co/sisjur/normas/Norma1.jsp?dt=S&i=191872`, revisar también compilatorio/modificaciones `https://www.alcaldiabogota.gov.co/sisjur/normas/Norma1.jsp?dt=S&i=192118`. Medellín Decreto 1490/2026: ficha GIS `https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043`; aún no se verificó texto íntegro oficial. Cali Decreto 4112.010.20.0814 (26-06-2026), boletín `https://web1.cali.gov.co/aplicaciones/boletin_publico/detalle_boletin.php?id=3434&num=103` indexa el decreto pero lectura/PDF puede dar 403; si bloquea registrar sin evasión. **No publicar, activar ni ampliar cobertura sin fuente completa vigente, categoría, excepciones, fecha y alcance territorial comprobables**.
- **Integrador único (Codex principal):** consolida cambios A/B/C sobre una sola rama C8, resuelve conflictos solo tras comparar deltas, ejecuta gates focales, verifica GitHub remoto, prepara integración a `main` en rama separada **solo si es segura**. No lanzar compiles pesados en paralelo.

**Regla de aislamiento:** cada agente escribe en una copia/worktree distinto o tiene archivos disjuntos; entrega commit/diff concreto; integrador único aplica cambios. Un bloqueo externo de un agente no detiene a otros. Si no hay subagentes disponibles, ejecutar los tres frentes en serie en **este mismo lote**, sin regresar al director tras cada subetapa.

## 2. A — Flutter: retirar acoplamiento temporal de Bogotá SIN perder aviso de seguridad

**Defecto real identificado:** `bogotaUrbanRestrictionScopeNotice` en `mobile/lib/features/pico_placa/presentation/restriction_scope_notice.dart` está condicionado a `localDate.year == 2026 && localDate.month == 11`, y diferencia 2/16 de noviembre de forma codificada. Lo consumen `today_restriction_summary.dart` (Pico/Inicio) y `trip_plan_result.dart` (Viaje), y `mobile/test/features/pico_placa/presentation/bogota_scope_notice_test.dart` conserva el comportamiento. Una nueva rotación o festivo no debe depender de alterar la app, pero tampoco se puede borrar el aviso de retorno regional mientras el motor no lo evalúa.

**Implementación obligatoria, ordenada:**

1. Inspeccionar una vez el contrato de datos/OTA realmente soportado (schemaVersion 2, `InsideScopeRefCondition`, cobertura parcial/completa, vigencia, source, `RestrictionDayEvaluation`). No inventar otro parser ni cambiar el contrato nacional sin demostrar necesidad.
2. Hacer que el mensaje de **«pico y placa urbano general / ámbito regional no evaluado»** derive del alcance observable de la cobertura o de una configuración versionada ya existente y validada. Conservar representación de `UNKNOWN/STALE`; no inferir «puede circular» para ámbitos no evaluados, ni cambiar restricciones urbanas correctas. No declarar cobertura regional solo por tener una ciudad «verified».
3. Si el schema existente no expresa la condición, usar una **salvaguarda KISS mínimamente invasiva** que haga explícito «ámbito regional no evaluado» sin acotar indebidamente el aviso a noviembre de 2026, y registrar exactamente qué metadata OTA falta. No añadir un campo ad hoc que acepte contenido imposible de validar ni extender fechas legales inventadas. No mostrar aviso de Bogotá sobre ciudades o categorías no pertinentes.
4. Mantener consistencia Inicio/Pico/Viaje y accesibilidad; los consumidores no deben divergir. Probar casos vigentes noviembre, fecha posterior al mes codificado, vacaciones/festivos conocidos, ciudad distinta, moto, desconocido/vencido. **Solo tests focales nuevos o afectados**. Conservar textos aprobados y demás componentes.

**Entregable A:** diff productivo Flutter + evidencia de un comportamiento antes erróneo y después corregido; si hay ausencia contractual insalvable, **NO declarar PASS** por un aviso cosmético: entregar avance seguro comprobable, detallar bloqueo exacto y proponer un único cambio contractual integral para el siguiente lote. Mantener reglas jurídicas desconocidas como desconocidas.

## 3. B — Laravel: separar versión editorial más nueva del release realmente activo

**Defecto real identificado:** el C7 `municipalityCoverageEntries()` extrae `$jurisdiction->restrictionRuleVersions->first()` (última versión), y `publishedReleaseForVersion($version)` solo consulta las publicaciones de **esa misma versión**. Si hay v1 publicada vigente y v2 en borrador, la fila puede informar «Sin release publicado» cuando **sí existe publicación anterior**. Lo mismo debe revisarse en CSV C6 (`writeCoverageRow()`) y cualquier pantalla que proyecte `publication_state` desde la última versión; no afirmar que v2 es la regla pública.

**Implementación obligatoria:**

1. Investigar una vez relaciones/modelos existentes `RestrictionPublication`, `RestrictionPublicationItem`, `Dataset`, `DatasetRelease`, `RestrictionRuleVersion`, los estados `published/retired`, revisión vigente y rollback. **NO crear nuevas tablas ni migraciones para una consulta resoluble con relaciones actuales**.
2. Proyectar dos dimensiones independientes por municipio/jurisdicción/categoría: `última versión editorial` (borrador/validada/...) y `release efectivamente activo / última versión realmente incluida y publicada`, verificando pertenencia a publicación vigente y que no haya sido sustituida por rollback o eliminación. Si la historia es ambigua, exponer `NO_CONFIRMADO` en vez de presentar un release antiguo como activo. Una publicación histórica retirada no significa «publicado hoy».
3. Corregir vista C7 y CSV administrativo C6, preservando columnas existentes cuando sea posible; si se requieren 1–2 columnas nuevas, versionar encabezados consistentemente con los consumidores. Mantener roles (`datasets.view`, acciones de edit/review), filtros/paginación y `UNKNOWN` de municipios sin cobertura.
4. Hardening de filtros `GET`: `q[]` / `department[]` no deben producir errores por casts de arrays a string; validar tipo escalar, límite de longitud y código DIVIPOLA sin crear dependencia. No truncar silenciosamente identificadores válidos ni abrir consultas sin límite.
5. Nuevos tests focales: **(i)** v1 realmente activa + v2 draft muestra ambas dimensiones; **(ii)** rollback o release retirado no se etiqueta activo por error; **(iii)** municipio sin jurisdicción sigue `NO_JURISDICTION/UNKNOWN`; **(iv)** GET malformado devuelve fallback/422 coherente sin 500; **(v)** rol sin `datasets.view` recibe 403. Reusar fixtures existentes donde sea posible; no repetir las 3/41 C7 ni los 3/41 C6.

**Entregable B:** Laravel/UI/CSV corregidos, aserciones nuevas ligadas a defectos, sin autopublicar datos. Evitar un refactor genérico del controlador de ~700 líneas si los cambios quedan acotados.

## 4. C — consentimiento de aliados: cerrar la mejora YA ESCRITA, no repetirla

En la rama C8 existen **exactamente** estos deltas frente a C7:

- `mobile/lib/features/home/data/partner_inquiry_client.dart`: `PartnerInquiryDraft` exige `consentAccepted`, lo serializa en vez de escribir constante `true` y `HttpPartnerInquiryClient.submit()` impide el request HTTP cuando es `false`.
- `mobile/lib/features/home/presentation/home_partner_carousel.dart`: transmite `_consent`, presenta mensaje `consent_required`.
- `mobile/test/features/home/data/partner_inquiry_client_test.dart`: caso `false` comprueba error y `adapter.calls == 0`, y conserva prueba de payload consentido.

**No portear el parche otra vez, ni invocar pruebas de todo el proyecto.** Ejecutar `flutter test test/features/home/data/partner_inquiry_client_test.dart` desde `mobile/` y `dart format --output=none --set-exit-if-changed` de los archivos tocados; análisis focal si disponible. Si Flutter SDK falta, reportar `WRITTEN_NOT_EXECUTED` sin falso positivo. Si emerge un fallo compilatorio o de otra llamada a `PartnerInquiryDraft`, corregirlo con test mínimo. Mantener `PICORADAR_PARTNER_INQUIRIES_ENABLED=false` y bandera comercial OFF; no contactar servidor real, guardar datos personales ni publicar publicidad por esta corrección.

## 5. Integración GitHub y release: avance estructural sin merge ni pérdida de historia

1. **C8 fuente:** trabajar desde HEAD `dfa8ee13d861f24c3213d424d768305a0ea08d60` de la rama creada por director. Verificar SHA remota inicialmente y evitar modificar HEAD en paralelo a otro agente. Integrador publica al terminar nuevos commits en esa misma rama por push NO forzado; esperar HEAD final verificable y árbol limpio. Es rama de código recuperable, no documento ni snapshot nuevo. No tocar PR #86 ni PR #79.
2. **main:** cuando A/B/C estén integrados y gates focales pasen, preparar **otra rama de integración desde HEAD actual de `main`**, conservando su historia como primer ancestro. Trasplantar **el árbol de C8** a esa rama solo en una copia aislada, sin mezclar historias sintéticas mediante merge ciego. Comparar hash/estado de 1.882+ paths; mantener registro de los 806 idénticos, 408 divergentes, 668 nuevos y dos exclusivos de `main` del corte C6; recalcular diferencial exacto para C8. Los dos archivos exclusivos deben decidirse por consumidores/compilación, no copiar ni eliminar a ciegas. Revisar específicamente assets, manifests, workflows, `AGENTS.md`, archivos personales/excluidos y .gitignore. **NO force-push, NO reescribir `main`, NO merge a `main`**. PR Draft a `main` **solo si el árbol de integración es completo, escaneado y las suites relevantes pasan**; si no, mantener candidato branch y `HOLD` causal con lista corta de pasos que faltan. No tratar un PR Draft como deploy.
3. Ejecutar Gitleaks/secret scanner estándar sobre delta **e historia nueva** cuando esté disponible; salida cero hallazgos es necesaria pero no reemplaza comprobar rutas `.env`, claves, datos, media privados, APK o TAR. Mantener lista de archivos excluidos C6. **Jamás adjuntar source snapshot ni APK al ZIP**.
4. Android físico, HTTPS real, soporte 16KB/Play: documentar lo existente; **no repetir** `adb devices`, no build/gradle, no probar entornos ni instalar sin permiso/dispositivo/nueva evidencia. Si hay recursos reales nuevos, ejecutar solo el gate correspondiente. `RELEASE=NO_GO` mientras falten aceptación física/TLS/legales; esto **no bloquea código o PR Draft**.

## 6. Aceptación, eficiencia y controles anti-ping-pong

**Orden de ejecución:** preflight mínimo 1 vez → A/B/C paralelos → integración única → pruebas focales → seguridad y push → ZIP de salida. Reservar 15–20% del bloque para integración, no 90% para reportes. NO repetir QA aprobada de C2–C7 ni 20 pasadas textuales; auditar solo los archivos modificados y sus consumidores. NO crear nuevos prompts C8.1/C8.2 por fallos reparables; arreglar causalmente en este mismo lote. No cambiar paquetes, esquema o arquitectura sin necesidad demostrada. No limpiar cachés Gradle ni provocar escasez de RAM. No ejecutar GitHub Actions si está bloqueado por cuota.

**Gates por frente** (todos distintos de aprobación final del release):

| Gate | PASS exige | HOLD/FAIL apropiado |
| --- | --- | --- |
| A_SCOPE | Aviso/alcance seguro en Inicio/Pico/Viaje basado en datos y prueba focal nueva | Si metadata OTA insuficiente, no fingir seguridad; documentar contrato faltante |
| B_PUBLICATION | Nueva prueba v1 publicada + v2 borrador, rollback, CSV/UX, filtros malformados, permisos; PHP/Pint PASS | Explicar causa exacta; no crear migración especulativa |
| C_CONSENT | Flutter focal PASS: consentimiento falso, `0 HTTP`; verdadero conserva contrato | SDK ausente = WRITTEN_NOT_EXECUTED |
| INTEGRATION | Código nuevo verificable en C8 branch, diff y manifiesto de cambios + scanner | PR a `main` solo si independiente, completo y seguro; caso contrario HOLD causal |
| LEGAL | Registro normativo con enlaces oficiales, validez y excepciones sin inventar | Bloqueo 403 o fuente parcial = NO_CONFIRMADO, sin auto-publicación |
| RELEASE | Android físico/HTTPS/16KB + aprobaciones jurídicas/UX de alcance, licencias/privacidad | Hasta entonces NO_GO, **sin detener A/B/C** |

No degradar C7 ni modificar dependencias del motor solo por avanzar porcentajes. No dar `PASS` a pruebas escritas no ejecutadas. Un CSV o informe no es avance funcional. Registrar **tareas de producto realmente cerradas** con denominadores nuevos; conservar evidencia score base 61/100 salvo criterio explícito con pruebas. El usuario quiere Free 1.0 completa, no una clasificación artificial.

## 7. Entrega **UNA SOLA VEZ** y ligera

El retorno debe ser `PICORADAR_C8_RETORNO_UNICO_LIGERO.zip` **objetivo ≤2 MiB, máximo ≤5 MiB**: `FINAL_REPORT.md` corto (lo implementado por A/B/C, estados, HEAD/tree, GitHub, acciones, actor siguiente); `GATES.csv`; `CODE_DIFF.csv` con hashes de archivos nuevos; `CHANGELOG_FOCAL.md`; `QA/` con salidas focales sanitizadas; `LEGAL_SOURCES.csv` solo si se produjo evidencia nueva; `GITHUB_STATUS.md` con URLs reales, PR/drafts y merge no autorizado; `MANIFEST.csv` SHA-256/CRC/tamaños de todos los miembros salvo él mismo; parche textual de **solo delta C8 respecto de C7** si cabe. Verificar zip CRC y manifiesto localmente antes de devolver. Si parche grande, sustituir por lista de paths/commits; **GitHub es la fuente de código**.

**PROHIBIDO adjuntar** APK/AAB, `SOURCE_RECOVERY*.tar.gz`, bundle Git, fotos privadas, carpetas de pruebas, dependencias, cache, `vendor/`, `node_modules`, reportes repetidos o logs enormes. No pegar informe completo en respuesta; devolver `RESULT` honesto, `A/B/C/INTEGRATION/LEGAL/RELEASE`, SHA/branch/PR, `ZIP_PATH` real y SHA256, `NEXT=CHATGPT_DIRECTOR`.

**Si algo falla:** resolver dentro del lote si es local y causal. Si externo: `BLOCKED_EXTERNAL` con condición de desbloqueo y CONTINUAR frentes restantes. Nunca usar permisos/credenciales no autorizados, fingir fuentes legales, activar ads o inventar una APK.

## 8. Orden de arranque inmediata

1. **NO REINICIAR A CIEGAS**, usa sesión existente si puede acceder a `D:\codex` y a su entorno; si otra tarea corre en el mismo índice, espera a su cierre y crea un worktree **aislado**.
2. Validar C8 HEAD inicial y que A/B/C no pisan rutas.
3. Lanzar agentes A/B/C (D jurídico solo lectura opcional); integrador principal espera deltas y consolida una sola vez.
4. Ejecutar nuevas pruebas focales y registrar pruebas no ejecutadas sin falsos `PASS`.
5. Publicar cambios en C8, preparar integración segura sin merge a main; entregar solo ZIP ligero.

**SIGUE AHORA: CODEX LUNA — EJECUTAR C8, DESARROLLO PARALELO REAL.**

**DESPUÉS DE C8: CHATGPT DIRECTOR — ACEPTAR O RECHAZAR GATES DIFERENCIALES Y CONTINUAR HACIA FREE 1.0.**
