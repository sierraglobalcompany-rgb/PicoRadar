# CODEX LUNA — PICORADAR C8 V2 · EJECUCIÓN PARALELA REAL Y CIERRE DIFERENCIAL

**EJECUTA CODEX LUNA. DIRECTOR: CHATGPT.** Fecha de corte: 21/11/2026, Colombia. `TASK_ID=PICORADAR-C8-V2-CIERRE-DIFERENCIAL-20261121`. **Esta orden REEMPLAZA al C8 original si no comenzó su ejecución. No ejecutar C8 y C8 V2 simultáneamente.** No interrumpir una ejecución C8 ya iniciada; en ese caso devolver su trabajo y conciliarlo una sola vez.

**Misión:** entregar **tres resultados verificables de código** y un respaldo remoto seguro, **en un único lote**, sin reiniciar la app ni dar vueltas con auditorías ya aprobadas. El integrador resuelve dudas locales con los contratos y código existentes; no pide al director otro prompt intermedio. **No reescribir motor, OTA, editor, servidor de campañas o panel de operadores que ya existen.**

## 0. Punto de partida obligatorio y reglas inviolables

| Objeto | Identificador verificado | Uso |
| --- | --- | --- |
| GitHub | `sierraglobalcompany-rgb/PicoRadar` | Repositorio existente |
| C6 completo | `backup/picoradar-c6-source-20261120` / `bc1422c7198607850a49f4a294ed67316fed0805` | Respaldo; **no reconstruirlo** |
| C7 aceptado | PR **#86 Draft**, `feat/C7-national-review-20261121`, `9304aa8d03cfd852a3f8943405cf8250dfe1d3c0` | Matriz municipal y 3 tests/41 aserciones; **no reejecutarlos** salvo regresión causada |
| **C8 lista** | `feat/C8-national-release-hardening-20261121`, HEAD inicial **`dfa8ee13d861f24c3213d424d768305a0ea08d60`** | **Fuente exclusiva de nuevos cambios**; parte de C7 e incorpora consentimiento |
| `main` | `e9ef37511df3110ffb0fc006ef06be781df432ac` al corte | No modificar ni fusionar sin autorización |
| PR #79 | Draft histórico | Intocable |
| Checkout propietario | `D:\codex\PicoRadar` | **43 rutas WIP protegidas**: no editar, limpiar, restaurar, resetear ni instalar |

Usar un **clon/copia de trabajo aislada** de la rama remota C8; no ejecutar `worktree add`, `reset --hard`, `clean -fd`, ni checkout en el directorio propietario. Confirmar HEAD remoto C8 una vez. Si cambió porque ya hay trabajo nuevo, **no sobrescribir**: inspeccionar delta contra `dfa8...`, conservar cambios legítimos y trabajar desde el HEAD actual. Hacer `git fetch` en la copia aislada. Evitar ramas múltiples que compitan por escribir el mismo índice.

Contrato de producto no negociable (`AGENTS.md`, baseline y SOP): Flutter/Riverpod/Drift + Laravel, KISS; navegación **Inicio · Garaje · Apps · Viaje · Conducir**; sin cuenta obligatoria; datos de vehículos/documentos locales; Conducir sin llamadas GPS por posición; sin promesas de circulación segura cuando cobertura es `UNKNOWN` o `STALE`. Free 1.0 **sin activar publicidad, pagos, premium, WhatsApp comercial ni terceros**. No publicar reglamentación no verificada, ni desplegar en Hostinger, ni usar teléfono sin autorización. Las rutas históricas obsoletas de `docs/CURRENT.md` no prevalecen sobre estos HEAD comprobados.

**Evidencia ya aceptada, que NO se repite:** C2 puente Laravel/Flutter; C3 persistencia y permisos; C4 dashboard; C5 filtros y ficha; C6 CSV nacional, matriz de 1.104 municipios y APK DEV; C7 bandeja municipal. APK C6 ya existe en el equipo Codex, debug `1.0.1+2`, firma verificada según C6. **NO PEDIR NI ADJUNTAR NI COMPILAR NUEVA APK**, ni TAR/bundle/snapshot de 1.882 archivos. C7 informó ADB=0, sin emulador y HTTPS sin staging autorizado: anotar estos gates como `BLOCKED_EXTERNAL` sin ejecutarlos de nuevo a falta de nuevas condiciones.

**Métricas de corte:** score de *evidencia* 61/100; 58 % producto y 83 % núcleo son **estimaciones históricas no medidas**. Ningún PASS/porcentaje automático por commits, líneas o tests ya aprobados. No confundir 1.104 municipios en catálogo con 1.104 jurisdicciones jurídicamente verificadas.

## 1. Operación real en paralelo: un solo integrador

**Preflight máximo, una sola vez:** `git status --short`, HEAD, contrato de archivos, herramientas PHP/Dart disponibles, y existencia de los tests nuevos; 5–10 minutos como tope de diagnóstico repetible (no como estimación de entrega). Los agentes NO repiten la preinspección ni se pasan informes antes de implementar.

| Agente | Propiedad de escritura | Resultado NO negociable | No toca |
| --- | --- | --- | --- |
| **A Flutter** | `mobile/lib/features/pico_placa/presentation/restriction_scope_notice.dart`, sus 2 consumidores si son indispensables, `mobile/test/features/pico_placa/presentation/bogota_scope_notice_test.dart` | Advertencia segura para Bogotá después de nov-2026 sin fijar derecho no documentado | Laravel, aliados, manifest/rules schema |
| **B Laravel** | `server/app/Http/Controllers/Admin/RestrictionRuleController.php`, vista `municipalities.blade.php`, CSV y pruebas Laravel focales | **Estado editorial separado del dato efectivamente público** + entradas GET malformadas sin 500 | Flutter, assets, migraciones |
| **C Consentimiento** | **Primero SOLO prueba**, luego los 3 paths de aliados si hay defecto | `false → 0 HTTP`, `true → 1 HTTP`, serialización y UI coherentes | Editor, campañas comerciales, backend |
| **D jurídico (optativo)** | **Solo lectura** sobre actos oficiales, reporta en CSV existente | Acto exacto/vigencia/excepciones comprobadas o `NO_CONFIRMADO` | Cualquier archivo runtime, publicación, bloquea 0 agentes |
| **Integrador principal** | Única rama C8, GitHub, pruebas intersección y ZIP | Consolida deltas y envía UNA sola entrega | No hace merge a `main` ni instala APK |

Si hay subagentes: usar copias aisladas o áreas de escritura disjuntas, entregar únicamente diff/commit de trabajo al integrador; evitar pushes concurrentes. Si el entorno no admite subagentes: ejecutar A, B, C **consecutivamente en el mismo lote**, sin pedir ayuda a ChatGPT entre ellos. **Nunca bloquear B/C por un problema del motor Flutter, una web jurídica 403, falta de Android ni CI de GitHub.**

## 2. Agente A — corregir aviso de Bogotá SIN fabricar reglas

**Hecho comprobado en C8:** `bogotaUrbanRestrictionScopeNotice(...)` contiene `localDate.year != 2026 || localDate.month != 11`, con excepción textual para **2 y 16 de noviembre de 2026**. Dos consumidores ya activos: `today_restriction_summary.dart` y `trip_plan_result.dart`. `bogota_scope_notice_test.dart` cubre esos textos y la ausencia de mensaje para taxi/moto/Medellín. Es un aviso complementario, **NO** el algoritmo de elegibilidad ni una norma para todas las carreteras.

**Implementa exactamente:**

1. Leer la función de 21 líneas, sus dos consumidores, 1 prueba focal existente y **solo el campo de alcance** del dataset Bogotá aplicable. Conservar firma y contratos; no crear parser, esquema 3, tabla de fechas, proveedor externo ni paquete. Confirmar que el aviso no se use como sustituto de `RestrictionDayEvaluation`.
2. Para **carro particular Bogotá** en fechas distintas de noviembre de 2026, mostrar un **aviso conservador de alcance** cuando el evaluador usado siga cubriendo solo el ámbito urbano: *«La evaluación corresponde al pico y placa urbano disponible; no determina restricciones regionales, corredores de retorno ni excepciones individuales.»* No afirmar que una regla ordinaria aplica/no aplica en una fecha no comprobada. **No copiar la excepción de 2/16 de noviembre a otros años o meses.** Si la cobertura regional llegara a estar expresamente evaluada por dataset, no mostrar un mensaje inexacto de “no evaluado”; ajustar a metadata existente comprobada, no a una suposición.
3. Preservar para el **2 y 16/11/2026** la semántica del mensaje original **solo donde la base histórica realmente la soporte**, sin convertir esos días en festivos nacionales recurrentes. Evitar duplicar avisos, modificar el resultado principal `ALLOWED/RESTRICTED/UNKNOWN` o activar avisos en taxi, motos u otros municipios.
4. Pruebas **nuevas/actualizadas únicamente en** `bogota_scope_notice_test.dart`: noviembre ya cubierto, diciembre 2026, enero 2027, ciudad distinta, carro taxi, moto y **consistencia visible en Inicio y Viaje**. Verificar que el aviso no implica que puede circular si el dataset es `UNKNOWN/STALE`. Si metadata de alcance resulta insuficiente, aplicar únicamente la advertencia conservadora y registrar límite contractual real; no falsear PASS de cobertura regional.

**A_SCOPE=PASS** exige diff runtime y prueba Flutter focal ejecutada (no basta modificar el texto). Error sin Flutter: `WRITTEN_NOT_EXECUTED`, mientras B y GitHub prosiguen. No exigir tests de todo el motor.

## 3. Agente B — resolver la publicación efectiva de municipio + filtros malformados

**Defecto probado en C8:** `municipalityCoverageEntries()` usa solo la **última** `RestrictionRuleVersion` para producir `publishedReleaseForVersion($version)`, y el CSV hace lo mismo. Con `v1` activa y `v2` nueva Draft/Validated puede decir “sin release” aunque el dataset actual ya contenga `v1`. Más importante, `DatasetPublisher::rollback()` cambia `Dataset.current_version` **sin crear un `RestrictionPublicationItem`**; por tanto, usar solo “último item” es **incorrecto**. Un release anterior puede estar retirado y sus datos persistir dentro de un release nacional posterior: **`status=Retired` en release de origen NO prueba que las reglas sean inactivas hoy**. No hacer inferencias por versión editorial ni fecha.

**Definición operacional a aplicar:**

- `editor_latest`: mayor versión editorial de la jurisdicción (estado Draft/Validated/...), independiente de lo público.
- `national_current_release`: `Dataset(key=restrictions).current_version` **si existe, es efectivamente Published y el asset verificado es el actualmente señalado**; no la versión de cualquier evento histórico.
- `current_jurisdiction_coverage`: datos que **realmente están presentes** para la jurisdicción/categoría dentro del **payload del release nacional actual**. Si no se puede comprobar, mostrar `PUBLICATION_NOT_CONFIRMED` / estado prudente, **nunca una publicación pasada como actual**.
- `source_editor_version`: versión editorial que concuerda con el payload actual **solo si identificable de forma fiable**; si no, `NO_IDENTIFICADA`, sin afectar la visualización correcta del release nacional.
- `evidence_state`: `VERIFIED/PARTIAL/STALE/UNKNOWN` permanece separado; un `PUBLISHED` técnico **no certifica vigencia jurídica**, y `NO_JURISDICTION` sigue `UNKNOWN`.

**Implementación KISS precisa:**

1. Leer `Dataset`, `DatasetRelease`, `RestrictionPublication/Item` y **el patrón existente** `RestrictionPublicationService::currentPayload()` y `DatasetPublisher::rollback()` para interpretar `current_version`. Usar consultas limitadas/eager loading y cargar/validar el payload actual **una vez por petición**, no leerlo 1.104 veces ni hacer N+1 por municipio. Si ya existe un servicio de lectura segura y hash, reutilizarlo; no duplicar reglas de publicación ni crear tablas/migraciones.
2. Presentar en la bandeja C7 dos columnas/dimensiones claras: última editorial vs **release nacional actual con cobertura efectiva de ese municipio**. Que un editor cambie v2 **no** cambie la consulta pública v1. Si rollback del dataset restaura un release anterior, representar el payload restaurado, aunque los últimos `RestrictionPublicationItem` tengan mayor revision. Para CSV administrativo C6, conservar **los encabezados existentes** `editor_version`, `editor_version_status`, `published_release`, `publication_state`: corregir sus significados. Añadir **solo si es inevitable** `source_editor_version` / detalle público, consistente en las dos exportaciones y prueba de encabezados. No romper protección `spreadsheetSafe` contra inyección CSV.
3. Corregir **ambos** filtros `restrictionFilters()` y `municipalityMatrixFilters()`: en C8 se hace `(string) $request->query('q')` y `(string) $request->query('department')`; recibir `q[]=...` / `department[]=...` produce conversión array-string y no se debe declarar PASS. Rechazar entradas no escalares (`422`) o normalizarlas a vacío **de forma explícita y comprobada**. Recortar búsqueda a 100 caracteres, departamento DIVIPOLA de 2 dígitos, paginación acotada; no devolver `500` por tipo erróneo. Manejar strings vacíos y parámetros de filtro de estado inconsistentes.
4. Añadir pruebas **solo para la semántica nueva** en test PHP focal nuevo (o amplía el C7 afectado con tests adicionales, sin repetir los antiguos): (a) v1 publicada + v2 Draft: se ven v2 editorial y v1 efectiva; (b) release nacional posterior de otra ciudad: v1 sigue efectiva aunque su release origen sea histórico; (c) rollback genérico del dataset: refleja snapshot restaurado y **no última operación**; (d) municipio sin jurisdicción sigue `UNKNOWN`; (e) `q[]`/`department[]` con respuesta contractual, sin PHP warning ni 500; (f) usuario sin `datasets.view` → 403; (g) export CSV con estados y protección de fórmulas. Reusar los fixtures existentes; no repetir suite total.
5. Si no hay release o no existe asset o el hash no coincide: **FAIL CLOSED** sin mostrar permiso de circulación. No leer medios/archivos arbitrarios del usuario. No publicar reglas, no tocar revisión real del dataset, no mover producción.

**B_PUBLICATION=PASS** exige UI/CSV corregidos, tests PHP nuevos ejecutados y `php -l` / Pint de archivos tocados PASS. Si la lectura del payload actual tiene un bloqueo causal de infraestructura, separar claramente `WRITTEN_NOT_EXECUTED`; no marcar como publicado. Los filtros pueden pasar como subgate aunque el payload quede bloqueado.

## 4. Agente C — consentimientos YA implementados (cierre, no refactor)

**Antes de Codex ya fueron trasladados a C8 estos blobs verificados:**

- `mobile/lib/features/home/data/partner_inquiry_client.dart`: Git blob `b2e6ff1b1325a090e8a98bbe189b4d1b1cbb725e`.
- `mobile/lib/features/home/presentation/home_partner_carousel.dart`: `33f12e6e2565e57e579a8a33208f8c8ed716d515`.
- `mobile/test/features/home/data/partner_inquiry_client_test.dart`: `c232965664f1e8aadb710a2008cc1a03850c3307`.

**NO copiar de nuevo.** Buscar con `rg 'PartnerInquiryDraft\(' mobile/lib mobile/test` (o `git grep`) para confirmar que cualquier otro constructor tenga `consentAccepted` explícito. Desde `mobile/`: ejecutar únicamente `flutter test test/features/home/data/partner_inquiry_client_test.dart`; formato en paths modificados, análisis Dart de esos archivos/consumidores si se puede. Con consentimiento `false`, **cero llamadas al adaptador HTTP**; con `true`, una llamada permitida solo al servidor de **prueba inyectado**; payload no fuerza `true`. Si falla, corregir solamente el defecto causal en la misma rama, sin más refactor. Bandera de leads comercial sigue OFF; no hacer tráfico real.

**C_CONSENT=PASS** solo si test ejecutado. Si SDK no disponible, `WRITTEN_NOT_EXECUTED`, no bloqueo de A/B. La ausencia de una nueva línea de código en C no significa que no haya progreso: ese código ya existe y requiere validación.

## 5. Integrador — GitHub, integración con `main` y alcance de release

**Primero garantizar A/B/C y subir C8.** El integrador recibe los diffs de A/B/C y hace una única revisión de conflictos; crea los commits necesarios en `feat/C8-national-release-hardening-20261121` por push normal, verifica el HEAD/tree remoto y deja trabajo recuperable. **No abrir PR nuevo mientras los gates mínimos no pasen** y no alterar PR #86, #79 o `main`.

**Solo DESPUÉS, preparar compatibilidad con `main` sin bloquear la entrega C8:**

1. En un **clon aislado nuevo** crear rama temporal **desde el HEAD más reciente de `origin/main`**, dejando su historia como ancestro. Recalcular exactamente el diff con C8 (los números históricos 806 iguales, 408 distintos, 668 solo C6 y 2 solo main son del **corte C6**, NO del nuevo C8). Nada de `merge --allow-unrelated-histories`, rebase masivo, cherry-pick de historia sintética, `force-push` ni sobrescritura del checkout WIP.
2. Preparar una **copia de integración del árbol completo C8** en ese clon desde `main`, y registrar toda alta/modificación/baja, incluidas las **dos rutas solo-main**. No preservarlas por inercia: `RootPlaceholderScreen` y `HomeBannerSlot` parecen rutas legacy; decidir por consumidor real, compilación y test. El árbol C8 debe contener **todos** los recursos, pruebas, server y móvil relevantes; no un parche aislado incapaz de arrancar. Verificar manifiesto, `.gitignore`, assets, migraciones, workflows y ausencia de artefactos privados. No realizar ningún deploy.
3. Limitar esta actividad al **candidato**: si scanner estándar disponible, pasarlo al delta C8 y commits nuevos; inspeccionar `.env`, llaves, credenciales, APK/TAR/DB/PII y **la historia que vaya a publicarse**. C6 ya tuvo respaldo y escaneo acotados; no repetirlo entero salvo que cambie el árbol o haya alerta real. Si la integración exige resolver conflictos sustantivos o amplias suites que no están listas, **documentar `MAIN_COMPATIBILITY_HOLD` con diferencia concreta**, no dejar C8 `PARTIAL` por ello.
4. **PR Draft contra `main` SOLO SI** el candidato está completo, análisis de seguridad suficiente, controles de ejecución compatibles y sin pérdida de funciones; nunca fusionarlo. Si no cumple, conservar únicamente C8 seguro remoto y entregar un registro reproducible mínimo del paso pendiente. Los bloqueos HTTPS/ADB/legal/Google Play no impiden C8 implementado, pero **sí** mantienen `RELEASE=NO_GO`.

**Presupuesto de esfuerzo por prioridades:** A y B funcionales + C ejecutado **antes** de cualquier análisis histórico; reservar integración main como parte final acotada, no convertirla en nuevo proyecto de días. No ejecutar Actions si cuota agotada, ni builds Android sin causa. La rama C8 publicada es progreso aun si main sigue separado.

## 6. QA diferencial y aceptación honesta

| Gate | PASS verdadero | Reportar otro estado cuando... |
| --- | --- | --- |
| `A_SCOPE` | Nuevo comportamiento seguro + **Flutter focal ejecutado**, Inicio y Viaje coherentes | `WRITTEN_NOT_EXECUTED` sin SDK; `HOLD_SCOPE` si requeriría inventar ámbito jurídico |
| `B_PUBLICATION` | v1 pública + v2 Draft, actualización de otra ciudad, rollback real, filtros y CSV correctos; tests PHP/Pint PASS | No hay release verificable, hash de asset no cuadra, prueba no ejecutada o lógica de publicación errónea |
| `C_CONSENT` | Test Flutter sobre 0 HTTP sin autorización y 1 HTTP en test consentido | SDK ausente, errores de compilación o tests fallidos |
| `GITHUB_C8` | Nuevo código A/B/C visible por SHA/tree en rama remota C8 | Solo documento, solo commit local o seguridad no comprobable |
| `MAIN_CANDIDATE` | Rama basada en `main` con árbol integral correcto y gates; PR Draft **si** es segura | `MAIN_COMPATIBILITY_HOLD` causal **sin impedir C8** |
| `LEGAL` | Actos oficiales íntegros con fechas, categorías, excepción y zona acreditadas | Solo boletín, indexación 403 o caducidad: `NO_CONFIRMADO`; no auto-publicar |
| `RELEASE` | Teléfono/OS real, HTTPS autorizado, compatibilidad Play/16KB y normativa/UX listas | `NO_GO`; jamás falsear con APK debug o pruebas de escritorio |

Comandos focales desde sus raíces (`mobile/`, `server/`) y respetando las herramientas detectadas. Para Flutter: `flutter test test/features/pico_placa/presentation/bogota_scope_notice_test.dart` y `flutter test test/features/home/data/partner_inquiry_client_test.dart`; `flutter analyze` solo sobre archivos afectados y Dart formatting. Para PHP: `php artisan test --filter=<nuevo_test>` o `vendor/bin/phpunit <path>` si SQLite/entorno lo exigen, `php -l` de cambios y `vendor/bin/pint --test` solo paths modificados. Registrar **comando, cwd, exit code, conteo, hash/HEAD**. No reportar test como PASS por estar escrito. **No hacer regresión histórica C2–C7** salvo dependencia realmente modificada. La corrección del controlador justifica **solo** pruebas cruzadas C6/C7 afectadas cuando aparezcan fallos, no todos los tests del repositorio.

**Seguridad y eficiencia:** NO nueva tabla/migración, no cambios ORM estructurales, no esquema OTA nuevo ni dependencia adicional; no activar publicidad, GPS backend, ni pagos. Si surge un verdadero defecto que exige cambio de esquema, documentarlo causalmente y continuar los otros frentes; no crear campo parche ni borrar datos. No esconder fallos bajo `PASS_SCOPED`. No hacer 10+10 auditorías exhaustivas en Codex: esa revisión del PROMPT ya se hizo aquí.

## 7. Entrega exactamente un ZIP, ligero y útil

**Un solo** `PICORADAR_C8_V2_RETORNO_UNICO_LIGERO.zip` (objetivo ≤2 MiB, máximo ≤5 MiB), con:

- `FINAL_REPORT.md`: A/B/C, qué se implementó, qué ya existía, SHAs, ramas, PR Draft, `RELEASE=NO_GO`, actor siguiente.
- `GATES.csv`: gate, `PASS|PARTIAL|HOLD|FAIL|WRITTEN_NOT_EXECUTED`, comando, exit code, causa.
- `CHANGELOG_DIFF.md`: archivos modificados respecto al HEAD C8 **`dfa8...`**, comportamiento antes/después y tests **solo nuevos o afectados**.
- `QA/`: logs cortos con **salidas reales**, sin PII ni secretos.
- `GITHUB_STATUS.md`: URL branch, HEAD/tree comprobados y estado real de `main`/PR #86/#79; `LEGAL_SOURCES.csv` **solo si se verificaron fuentes nuevas**.
- `MANIFEST.csv` hash SHA256, CRC32, bytes de los otros miembros; ZIP comprobado CRC y manifiesto localmente.

**NO ADJUNTAR** APK/AAB, `SOURCE_RECOVERY` TAR, Git bundle, repo/snapshot completo, dependencias, caches, screenshots privados ni pruebas y logs ya aprobados. Si el delta textual cabe en 5 MB y ayuda, añadir patch `C8_vs_C7.patch`; si no, los commits GitHub remotos son la fuente. Dar **una sola** respuesta Codex con `RESULT`, `A_SCOPE`, `B_PUBLICATION`, `C_CONSENT`, `GITHUB_C8`, `MAIN_CANDIDATE`, `LEGAL`, `RELEASE`, `HEAD`, `PR`, `ZIP_PATH`, `ZIP_SHA256`, `NEXT=CHATGPT_DIRECTOR`. No nueva ronda de auditorías, no pedir otro prompt, no solicitar APK.

## 8. Auditoría adversarial de esta orden (hecha por el director, NO repetir por Codex)

| Pasada VERDUGO | Fallo buscado y corrección | Pasada JUEZ | Control de solución |
| --- | --- | --- | --- |
| V1 | Probar la fuente equivocada: C8 anclado a SHA real | J1 | Rama/HEAD C8 únicos, no C6 ni C7 aislado |
| V2 | Consumidores Flutter dispares | J2 | Una sola función y pruebas Inicio/Viaje |
| V3 | Generalizar festivo de noviembre | J3 | 2/16 solo históricos; sin inventar 2027 |
| V4 | Confundir aviso con resultado del motor | J4 | `UNKNOWN` intacto; texto solo informativo |
| V5 | Marcar v1 retirada aunque siga en release nuevo | J5 | Dataset actual y payload, no estado del release origen |
| V6 | Falso positivo de rollback genérico | J6 | Test específico con `Dataset.current_version` restaurado |
| V7 | N+1 en 1.104 municipios | J7 | Cargar dataset vigente una vez, consultas acotadas |
| V8 | Duplicar consentimiento y test | J8 | Tres blobs ya portados, test real 0 HTTP |
| V9 | Main absorbe tiempo de programación | J9 | Candidato main solo al final, HOLD no bloquea código C8 |
| V10 | Declarar release o porcentaje ficticio | J10 | Evidencia ejecutada + gates físicos/TLS separados |

**ACTOR QUE EJECUTA AHORA: CODEX LUNA.** **ÚNICA ENTREGA: ZIP C8 V2 LIGERO.**

**DESPUÉS DE ESE ZIP SIGUE: CHATGPT DIRECTOR — DECIDIR ACEPTACIÓN DIFERENCIAL Y PRÓXIMO CIERRE FREE 1.0.**
