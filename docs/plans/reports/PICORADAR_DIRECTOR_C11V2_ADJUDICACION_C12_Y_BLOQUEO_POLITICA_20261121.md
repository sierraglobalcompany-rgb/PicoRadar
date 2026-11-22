# PicoRadar — adjudicación del retorno C11-V2 y correcciones C12

**Corte:** 21 de noviembre de 2026, Colombia.  
**Rol:** ChatGPT Director. **Estado de release:** `NO_GO`.  
**Carácter:** informe de continuidad y decisiones ejecutadas; **NO es un prompt para volver a ejecutar pruebas bloqueadas**.

## 1. Evidencia de entrada realmente revisada

- Archivo recibido: `PICORADAR_C11V2_RETORNO_UNICO_LIGERO.zip`.
- SHA-256 comprobado: `a4f6b5232731745dd0d9a9e6ac127389be440a3afe37bff0341df5c1b64ab270`.
- Tamaño: 6.599 bytes. ZIP con **7 miembros** y **6 archivos** listados en `MANIFEST.csv`; 6/6 hashes SHA-256, 6/6 tamaños y 6/6 CRC coinciden; `testzip()` sin errores.
- En GitHub la rama `feat/C11-docker-bootstrap-cache-fix-20261121` está en `467e25e9534f1c3113df402cf6a80e247f10e933`.
- Delta de C11-V2 respecto a `7d843d39bb57519b3b9b9e2430f578d9e09cf228`: solo se agregó `server/tests/Feature/C11NationalEditorialFlowTest.php`, blob `765da018ae870368495e81fa168a791682a82a42`.
- PR #88 continúa **OPEN/DRAFT** en C10 `77dd816445ee1d0234f9a54ff965f4b5dd99fbcb`. `main` permanece `e9ef37511df3110ffb0fc006ef06be781df432ac`.

## 2. Gates sin falsos positivos

| Frente | C11-V2 verificado | Interpretación correcta |
|---|---|---|
| Docker estático | 10/10 PASS | Solo comprobaciones de archivos; no valida construcción |
| Docker Engine/Compose | Disponibles según informe Codex | Existencia de herramientas no equivale a permiso de ejecución |
| Arranque PowerShell | `BLOCKED_POLICY` | `CreateProcess` rechazado **antes** de iniciar PowerShell; ningún contenedor iniciado ni detenido |
| PHP C8/C9/C10/C11 | 0 clases / 0 pruebas | Ningún resultado funcional PHP, no PASS ni FAIL de aplicación |
| C11 test nuevo | Implementado, sin ejecutar | El código fuente inicialmente tenía un defecto de entrada detectado después |
| Comercial Dart | `BLOCKED_ENV`, 0/7 | SDK Dart/Flutter ausente en PATH de Codex |
| Publicidad pública | OFF, comprobación estática | No activar publicidad real ni envíos de aliados por defecto |
| `main` | HOLD | Historias divergentes sin merge-base; evitar merge, force-push o reemplazo silencioso |
| Free 1.0 | `NO_GO` | También pendientes Android físico, HTTPS, Play 16KB y verificación jurídica |

**Límite no negociable:** un bloqueo de política de ejecución no se «soluciona» cambiando de shell, ejecutor, contenedor, usuario o herramienta. No repetir ni eludir la ejecución rechazada. Solo la autorización explícita del entorno controlado puede habilitar un intento nuevo, y debe hacerse **únicamente en el proyecto/worktree aislado**.

## 3. Problema real encontrado en la prueba C11

En C11-V2, `C11NationalEditorialFlowTest` intentaba crear un borrador con `'coverages' => []`. El controlador exige `required|array|min:1` y `RestrictionFormPayloadBuilder::build()` también rechaza arrays vacíos. Por tanto, la prueba **fallaría de forma determinista aun con PHP/Docker disponibles**; no era una falla de producto.

**CORREGIDO en C12**, reutilizando el contrato schema2 ya empleado por `C10NationalEditorEntryTest`: una cobertura `car|private` con regla sintética de restricción, fechas y URL de prueba. No se introducen datos jurídicos reales ni se publica un release.

## 4. Inconsistencia funcional en Super Admin corregida en C12

- La pantalla `/admin/jurisdictions/create` mostraba geografía municipal inactiva y el POST de creación podía aceptarla, aunque el GET asistido rechazaba una preselección inactiva.
- `JurisdictionController::formData()` ahora filtra `is_active=true` **solo para el formulario de creación**.
- `JurisdictionController::validated()` valida el municipio con modelo y rechaza `is_active=false` **al crear**, sin impedir editar jurisdicciones históricas.
- Se amplió el caso focal C9 para verificar que un POST directo de municipio inactivo devuelve 422 y no crea otra jurisdicción.
- La corrección no habilita ningún municipio para evaluación jurídica, no altera reglas, datasets ni publicaciones.

## 5. Hipótesis comercial descartada, sin modificación

Se sospechó que un array OTA explícitamente vacío de `municipalityCodes` podía reactivar el mapeo comercial histórico. El parser de `restriction_dataset.dart` **rechaza** `municipalityCodes` vacío cuando ese metadato existe; además el test del mapper admite explícitamente fallback histórico para ausencia de códigos. No se modificó el mapper ni se inventó una nueva semántica. **No crear una tarea de código por esta hipótesis sin evidencia contraria.**

## 6. Código C12 realmente publicado en GitHub

- Rama: `feat/C12-national-editor-runtime-ready-20261121`.
- HEAD verificado: `bc2c90743437a017a989adf9f00d38b1ca9459e7`.
- Padre original de C12: `467e25e9534f1c3113df402cf6a80e247f10e933`.
- Tres archivos modificados, y solo estos:
  1. `server/tests/Feature/C11NationalEditorialFlowTest.php` — blob `5d83f6a27015409aeabec82ffbec54da87046924`.
  2. `server/app/Http/Controllers/Admin/JurisdictionController.php` — blob `1f22ee9aa287575a6b7350f17ac24bd31ad78c0e`.
  3. `server/tests/Feature/C9JurisdictionOnboardingTest.php` — blob `652e1ceb1d28724bd542e6967c8744f4411d5745`.
- Los SHA de contenido fueron cotejados con GitHub. No hubo merge a C11/C10/PR #88 ni a `main`.
- **No reclamar PASS PHP de C12**: ejecución todavía no autorizada/verificada.

Enlace: https://github.com/sierraglobalcompany-rgb/PicoRadar/tree/feat/C12-national-editor-runtime-ready-20261121

## 7. Avance real y criterio de porcentajes

- Selector Pico y Placa: **1.104/1.104 municipios seleccionables**, equivalente a 100% geográfico **solo en el selector**.
- Pruebas Flutter previamente acreditadas C9: **29 PASS, 1 SKIP**; no repetir si ni código ni dependencias cambiaron en esos frentes.
- Motor nacional histórico: **83% estimado**, sin nueva certificación.
- Desarrollo integral histórico: **58% estimado**, sin nueva medición.
- Puntuación histórica de evidencia: **61/100**, no aumentarla por pruebas escritas/no ejecutadas.
- Cobertura de restricciones jurídicamente verificadas para 1.104 municipios: **NO CERTIFICADA**. Prohibido confundir catálogo geográfico con normas aprobadas.

## 8. Próxima decisión para terminar Free 1.0 sin ping-pong

**Ahora:** no emitir otro macrobloque para repetir la invocación rechazada; preservar el código C12 y comunicar el bloqueo de política a quien administre las aprobaciones de la instancia Codex.

**Solo cuando haya autorización explícita y el ejecutor esté permitido:** una ejecución PHP focal **única** y combinada de C8, C9, C10 y C11 sobre un checkout limpio aislado. Usar SQLite de memoria para tests y MariaDB temporal únicamente para el gate de migraciones posterior; nombres de proyecto Docker únicos, sin puertos compartidos ni volúmenes persistentes, sin `down -v`, sin limpieza global, sin tocar otros proyectos. No repetir suite Flutter C9. Si vuelve a denegarse por política, detener, clasificar `BLOCKED_POLICY` y seguir con otros trabajos permitidos sin nuevos intentos.

**Si Dart/Flutter ya están disponibles bajo una configuración autorizada:** ejecutar solo los siete casos comerciales C10, sin instalar dependencias por sorpresa. Si no están, `BLOCKED_ENV` real.

**Para integración GitHub:** no realizar merge a `main` hasta decidir formalmente su historia canónica. El ZIP C11 reportó 23 commits exclusivos de C11, 55 exclusivos de `main` y cientos de archivos compartidos divergentes; un PR Draft basado en C9/C10 no acredita compatibilidad con `main`. Mantener el origen C12 como candidato protegido y requerir un plan de preservación para los dos archivos exclusivos de `main` antes de intentar reconciliar árboles.

**Ruta de producto tras gates:** 1) aprobar editor + dataset nacional con restricciones UNKNOWN/STALE seguras, 2) comprobar consentimiento y segmentación comercial con publicidad todavía OFF por defecto, 3) certificar Android físico, HTTPS, empaquetado 16 KB, firma y permisos, 4) verificar evidencias jurídicas y decidir Free 1.0. No agregar otro motor paralelo, esquema o catálogo nacional duplicado.

## 9. Reglas persistentes del proyecto

ChatGPT Director decide; Codex Luna implementa. KISS, «ponytail», sin parches, sin ping-pong, sin volver a auditar gates PASS, sin declarar pruebas no ejecutadas como PASS, sin habilitar `ALLOWED` en ausencia de fuentes, sin almacenar datos sensibles innecesarios. Priorizar código y producto terminado sobre papeleo. Varios proyectos corren en simultáneo: **PHP y BD solo dentro de Docker aislado por proyecto** en la PC del usuario cuando la política de ejecución lo autorice. Cualquier nuevo retorno de Codex: **un solo ZIP ligero con manifiesto, hashes, pruebas focales y commits**, sin APK/TAR/repositorio/secretos completos.

**NEXT_ACTOR=CHATGPT_DIRECTOR** para organización; ejecución PHP requiere autorización fuera del chat. **No enviar a Codex un prompt que repita el proceso bloqueado.**
