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
| 8 | Escaneo del historial candidato, nombres sensibles, duplicados | Gitleaks 8.30.1: un hallazgo moderno, URL pública Power BI clasificada como falso positivo; alcance final en handoff. `.local`, sesiones y capturas privadas excluidos |
| 9 | Volumen D: PS4 / FAE6FCED / exFAT, copia y clon reales | Desarrollo directo en D:, confianza Git por ruta/proceso; sin reformateo, VHDX ni traslado de SDK |
| 10 | Reconstrucción y continuidad | Clon exclusivamente GitHub, gates móvil/servidor y B06/B07. Solo el handoff final acredita ejecución/resultados |

## Historias y selección

Clasificación de las diez pasadas: **1 GAP** (originales artísticos no localizados), **2 PASS**, **3 PASS**, **4 PASS** para inventario/publicación (CI bloqueada), **5 GAP** (chats antiguos no accesibles), **6 PASS** para fuentes/contratos (QA física pendiente), **7 GAP** por originales editables desconocidos, **8 PASS** dentro del alcance escaneado, **9 PASS** para checkout/build real en exFAT con excepción de archivo denegado, **10 GAP** por suite móvil fallida y gates bloqueados. PASS no acredita datos o dispositivos fuera del alcance. Ninguna incógnita autoriza descartar las variantes preservadas.

`ffe0cbd` contiene por ancestry `d26ba84`, `13190d0`, `2e8f2ed`, `e6406f2` y `c9dbaf1`. Se conserva esa evolución sin restaurar layouts anteriores. Cambios auxiliares owner A/B/D/EF y funciones principales B07 reglas/campañas tienen cherry-picks equivalentes; mantenimiento y fallback de campañas incluyen correcciones posteriores.

El inventario registra 21 tips locales distintos no cubiertos por el ancestro moderno ni las refs origin inspeccionadas. Incluyen variantes antiguas, checkpoints y handoffs, no 21 funciones faltantes. Sus objetos, refs, reflogs e índices se preservan privados. B04 comparador permanece pendiente. Checkpoints QA incluyen copias históricas de código, patches y evidencia: conservación no implica integración ni permiso de publicación.

La comparación del reflog con las refs identifica cinco commits adicionales, todos anteriores al moderno B07 del 2026-09-20. Están preservados mediante el almacén Git completo; no se presupone que el bundle los incluya. Ninguno acredita un estado posterior al seleccionado. No se ejecutó fsck costoso al no quedar un hueco de objetos conocidos.

## KISS / anti-parse

Se conservan fuentes → importador/validador del dominio → dataset versionado → consumidor. JSON/CSV/XLSX son entradas existentes B07; no se añadió parser de recuperación. No se borraron duplicados. Graphify local es histórico (2026-08-27: 1.306 nodos / 1.731 aristas), contrastado con Git, no prueba suficiente del estado actual.

## Incógnitas

No se localizaron las carpetas artísticas históricas `PicoRadar_Vehiculos_3D` en el Escritorio actual ni un proyecto Word3D/World3D dentro de la cobertura. Assets consumidos por la app están versionados; no se afirma recuperación de originales editables no localizados.

OSRM: el HEAD de la URL histórica del PBF respondió 404 el 2026-10-20. El inventario sí encontró el PBF original en el árbol C: preservado; su copia verificada coincide con `a71df1f2064d0536c053aa4bcd872e6aa0a4fa3e7b35964dd03de59793370a70`. Se conservó como asset en el borrador privado GitHub `recovery-osrm-input-20260907`, con licencia/atribución y digest remoto coincidente. README explica recuperación autenticada sin depender de C:/D:. Se preserva el input; no se declara regenerado el grafo ni activado el proveedor. No es entrada del build móvil con fixtures.
