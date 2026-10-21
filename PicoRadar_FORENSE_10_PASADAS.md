# PicoRadar: diez pasadas forenses V2

Corte inicial: 2026-10-20. Resultados observados y límites en `PicoRadar_RECOVERY_HANDOFF.md`. Detalle privado: `D:/PicoRadar_Rescue/manifests/`; no publicar sus archivos por referencia.

| # | Pasada / evidencia | Resultado y límite |
| --- | --- | --- |
| 1 | Búsqueda acotada C:/D:, rutas conocidas y `.git`; `discovery.json` registra profundidades | 13 worktrees identificados, sin barrido indiscriminado. Word3D/World3D no identificado; no se incorporaron proyectos ajenos |
| 2 | `worktrees.json`, refs y common-dir | Un almacén común / 13 worktrees; original `d26ba84`, moderno `ffe0cbd` |
| 3 | WIP, ignored relevantes, stashes, reflogs; snapshots y almacén Git | 1.723 archivos verificados por hash; 792 archivos Git coincidentes. Bundle complementario, no sustituto del WIP |
| 4 | GitHub actual y ancestry/cherry/diffs | Main `e9ef375`; PR 55/56/63/64 conservados; B07 contiene ancestros owner/C11/B06; sin merge |
| 5 | Índice por cwd y handoffs versionados | Dos sesiones PicoRadar accesibles; chats históricos no exportados NOT_ACCESSIBLE. No se inventaron aprobaciones |
| 6 | Código, contratos y consumidores | Móvil, Laravel, datasets, B06/B07 presentes. Implementación no equivale a QA física/deploy; estado en CURRENT |
| 7 | Árbol, fuentes y toolchain | Fuente B07: 1.758 archivos / 126.719.192 bytes; mayor fuente ~42 MB. 93 entregables externos y 3 archivos privados B06 respaldados |
| 8 | Escaneo del historial candidato, nombres sensibles, duplicados | Gitleaks 8.30.1: tres alertas en 207 commits del rango ampliado, falsos positivos revisados (URL pública Power BI e identificador ledgerKey); alcance final en handoff. `.local`, sesiones y capturas privadas excluidos |
| 9 | Volumen D: PS4 / FAE6FCED / exFAT, copia y clon reales | Desarrollo directo en D:, confianza Git por ruta/proceso; APK/tests nativos reconstruidos. Cleanup .NET y procedencia detached corregidos en tooling, sin reformateo, VHDX ni traslado de SDK |
| 10 | Reconstrucción y continuidad | Clon exclusivamente GitHub; APK, servidor y build/verificador de paquete PASS; suite móvil FAIL e instalación MariaDB bloqueada por enlaces en exFAT. Resultados exactos en handoff |

## Historias y selección

Clasificación de las diez pasadas: **1 GAP** (originales artísticos no localizados), **2 PASS**, **3 PASS**, **4 PASS** para inventario/publicación (CI bloqueada), **5 GAP** (chats antiguos no accesibles), **6 PASS** para fuentes/contratos (QA física pendiente), **7 GAP** por originales editables desconocidos, **8 PASS** dentro del alcance escaneado, **9 PASS** para checkout/build real en exFAT con excepción de archivo denegado, **10 GAP** por suite móvil fallida, instalación MariaDB bloqueada por enlaces en exFAT y otros gates bloqueados. PASS no acredita datos o dispositivos fuera del alcance. Ninguna incógnita autoriza descartar las variantes preservadas.

`ffe0cbd` contiene por ancestry `d26ba84`, `13190d0`, `2e8f2ed`, `e6406f2` y `c9dbaf1`. Se conserva esa evolución sin restaurar layouts anteriores. Cambios auxiliares owner A/B/D/EF y funciones principales B07 reglas/campañas tienen cherry-picks equivalentes; mantenimiento y fallback de campañas incluyen correcciones posteriores.

El inventario registra 21 tips locales distintos no cubiertos por el ancestro moderno ni las refs origin inspeccionadas. Incluyen variantes antiguas, checkpoints y handoffs, no 21 funciones faltantes. Sus objetos, refs, reflogs e índices se preservan privados. B04 comparador permanece pendiente. Checkpoints QA incluyen copias históricas de código, patches y evidencia: conservación no implica integración ni permiso de publicación.

La comparación del reflog con las refs identifica cinco commits adicionales, todos anteriores al moderno B07 del 2026-09-20. Están preservados mediante el almacén Git completo; no se presupone que el bundle los incluya. Ninguno acredita un estado posterior al seleccionado. No se ejecutó fsck costoso al no quedar un hueco de objetos conocidos.

## Destino de los tips históricos y WIP

Los identificadores siguientes permiten localizar cada tip en el almacén Git privado verificado. **Privado** significa conservación recuperable, no publicación ni equivalencia funcional certificada. No se afirma que el runtime sea un superset de todas estas variantes. La comparación por patch-id respalda los casos indicados; no sustituye la aceptación física.

| Tip / procedencia | SHA preservado | Destino y límite |
| --- | --- | --- |
| V01A-A home/garage | `eb581b334739e416a3064f1b9f1e9d340eeabaf1` | Privado; variante anterior, equivalencia completa UNKNOWN; no restaurar visual por fecha |
| V01A-B pico/driving | `01b2fb44d0df4c16e80308e0f7f01aaf3f205264` | Privado; variante anterior, equivalencia completa UNKNOWN |
| V01A-C trip | `ba72ea7785795616796960b1604dca984aab1d49` | Privado; variante anterior, equivalencia completa UNKNOWN |
| V01B-A roots | `318a9412e844435b578fe2c5876d5a103bc2ee1b` | Privado; variante anterior, equivalencia completa UNKNOWN |
| V01B-B obligations | `c4eb6e35d189269bca9a2baaafbee09a6742d396` | Privado; variante anterior, equivalencia completa UNKNOWN |
| V01B-C tools | `6929c4148de919db49233e0ca2b1e31d892ad56e` | Privado; variante anterior, equivalencia completa UNKNOWN |
| Root checkpoint | `b86c787253b9d222bf123f829aaed67ecd2e385c` | Privado; snapshot histórico, no aplicar sobre B07 |
| Owner A driving | `bebd823c2b98383dce341eb6e32ad2e0bbb097dd` | Cambios equivalentes por patch-id en historia moderna; tip original privado |
| Owner B wallet | `db9ed940dc62abee1f6785dff4fc64f02209b3f1` | Cambios equivalentes por patch-id en historia moderna; tip original privado |
| Owner C maintenance | `b5159e47b638109c62a6afc69935c2bbaf0bdf52` | Privado; evolución posterior de mantenimiento conservada; equivalencia exacta no afirmada |
| Owner D home | `9da0d362e522939f97f8738ca3a014f0085fa39b` | Cambios equivalentes por patch-id en historia moderna; tip original privado |
| Owner EF coverage | `471601479ee0fc07ff3b667d8249513be08928d4` | Cambios equivalentes por patch-id en historia moderna; tip original privado |
| Pending B04 | `fe0d8d46bf7c6abb223d246e7af43fbe1648439c` | GitHub recovery/20261019-pending-b04; pendiente, sin integrar ni certificar |
| QA supplements | `af7df94de6cef95bad91b02ed315c152669d1536` | Privado; fuentes/evidencia histórica, sin publicar checkpoints crudos |
| Root QA supplements | `6fc47b502aacde7d2d4ddfead231351524b15094` | Privado; fuentes/evidencia histórica, sin publicar checkpoints crudos |
| Audio combined QA | `132f7eefb706f0e192d0cd599ae40b1366f4e42c` | Privado; combinación temporal de QA, no aceptación actual |
| Viaje/Conducir combined QA | `00352a3ee5fb80ee57f9fa2b507f31e4fa831589` | Privado; combinación temporal de QA, no aceptación actual |
| B04 importer | `994d8df01710d7473e70e139950acdd2801f6ac1` | Cubierto por rama pending-B04; no producto integrado |
| B07 campaigns | `832733002ab54d266bbbeee49c1a2780f90f9c1c` | Funciones principales equivalentes; fallback corregido posteriormente; handoff auxiliar privado |
| B07 rules | `487de4dd837f97eacec253cf9fcfd44f9433d331` | Funciones equivalentes; handoff auxiliar privado |
| P04 amended backup | `e1141cea327ab7feae6d7c3528534e9e08373059` | Privado; variante, equivalencia completa UNKNOWN |

WIP sin seguimiento e ignored relevante: 1.723 archivos preservados por ruta/hash en snapshots privados, sin convertir capturas, datos o credenciales en fuente publicable. Los tres archivos privados B06 y los 93 entregables externos tienen respaldos separados verificados. Fuente rastreada reconstruible: rama moderna; insumo grande público OSRM: asset GitHub. Los cinco objetos exclusivos del reflog están en el common-dir copiado; el índice privado contiene sus SHA. Las equivalencias UNKNOWN son gaps del rescate, no una afirmación de pérdida ni autorización para sobrescribir C:.

Una revisión independiente posterior, solo mediante Git en D:, contrastó los deltas de siete variantes con `ffe0cbd`. No encontró comportamiento exclusivo ausente en lo contrastado: V01A-A conserva expiración GPS, selector/subtipos y acciones de Garaje; V01A-B conserva aviso legal y manejo/test de error GPS; V01A-C conserva catálogo municipal idéntico, evaluación local, borrador y navegación externa; V01B-A conserva acciones destructivas/filtros; V01B-B conserva callbacks documentales; V01B-C conserva `Semantics.onTap`, estado habilitado y alternativa textual; P04 conserva resumen de reglas, dígitos y rotación con caducidad posterior. Esta evidencia no prueba todas las ramas ni regresiones visuales: accesibilidad exhaustiva de V01B-B y equivalencia global permanecen UNKNOWN. No justifica publicar ramas adicionales, eliminar variantes ni reintroducir UI antigua.

## KISS / anti-parse

Se conservan fuentes → importador/validador del dominio → dataset versionado → consumidor. JSON/CSV/XLSX son entradas existentes B07; no se añadió parser de recuperación. No se borraron duplicados. Graphify local es histórico (2026-08-27: 1.306 nodos / 1.731 aristas), contrastado con Git, no prueba suficiente del estado actual.

## Incógnitas

No se localizaron las carpetas artísticas históricas `PicoRadar_Vehiculos_3D` en el Escritorio actual ni un proyecto Word3D/World3D dentro de la cobertura. Assets consumidos por la app están versionados; no se afirma recuperación de originales editables no localizados.

OSRM: el HEAD de la URL histórica del PBF respondió 404 el 2026-10-20. El inventario sí encontró el PBF original en el árbol C: preservado; su copia verificada coincide con `a71df1f2064d0536c053aa4bcd872e6aa0a4fa3e7b35964dd03de59793370a70`. Se conservó como asset en el borrador privado GitHub `recovery-osrm-input-20260907`, con licencia/atribución y digest remoto coincidente. README explica recuperación autenticada sin depender de C:/D:. Se preserva el input; no se declara regenerado el grafo ni activado el proveedor. No es entrada del build móvil con fixtures.
