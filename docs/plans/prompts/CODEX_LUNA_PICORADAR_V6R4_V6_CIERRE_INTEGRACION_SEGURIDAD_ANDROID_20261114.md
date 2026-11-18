# CODEX LUNA — PICO RADAR V6R4 V6 — UN MACROBLOQUE DE CIERRE DE INTEGRACIÓN, GITHUB Y ANDROID

**TASK_ID:** `PICORADAR-V6R4-V6-ONEPASS-STAGING-GITLEAKS-ANDROID-20261114`  
**Reemplaza exclusivamente** cualquier orden de seguimiento POST-V5 que todavía no haya empezado. **Si existe otro Codex activo, NO iniciar V6 en paralelo ni interrumpirlo.**  
**Responsables:** ChatGPT = director de decisiones y aceptación; Codex Luna = ejecutor de este bloque exacto.  
**Estado inicial verificado por director:** `PRODUCT_RELEASE=NO_GO`, `NEXT_ACTOR=CODEX_LUNA_IF_IDLE`.

## 0. Propósito y límites de este único bloque

Cerrar, **sin repetir las suites ya certificadas**, las tres brechas operativas entre el software actual y el lanzamiento: (i) escaneo de secretos y respaldo GitHub del **candidato LAB**; (ii) prueba de integración real del publicador Laravel -> manifiesto/bytes -> cliente Flutter/Drift en **QA aislada**; (iii) APK debug solo si los recursos y la firma permiten hacerlo sin riesgo. Avanzar en frentes independientes aunque uno resulte bloqueado; no más diagnósticos generales.

**NO:** reiniciar R1/R2/V5/V6R3/V6R4; rehacer 14 Python, 33 PHP o 3 tests Flutter del mismo SHA; inventariar de nuevo 1.104 municipios ni 50 fuentes; construir motor por ciudad; modificar esquema 2, dependencias, lockfiles o migraciones sin causa RED real; usar DB/credenciales/vehículos/producto reales; tocar Hostinger/CDN/producción, Mi A3, main, PR #71 o merge. NO `git clean`, `reset --hard`, `force-push`, eliminar ramas o WIP, crear PR automáticamente, ni GitHub Actions de pago. Sin commits innecesarios ni duplicar clases/test suites. Un solo ZIP final.

**Arquitectura congelada:** un motor nacional schema2 tipado, fuentes/autoridades habilitables mediante datos para ciudad, departamento, municipio, pueblo o corredor solo con ámbito acreditado; snapshot OTA **completo respecto del conjunto aprobado**, firmado por versión/hash y con rollback; una alta/cambio ordinario NO exige nueva APK; ausencias de datos, festivos, ubicación o exención -> `UNKNOWN`/`STALE`, nunca «libre». Un comunicado oficial de alcaldía/gobernación/tránsito sirve para **los campos que documenta**, sin exigir siempre PDF de decreto. El LAB no es publicación legal.

## 1. Línea base inmutable y preflight de 1 vez

- Repositorio: `sierraglobalcompany-rgb/PicoRadar`; Windows 11, raíz operativa `D:\codex\`.
- Candidato previamente usado: `D:\codex\_isolated\PicoRadar-V6R4-Close-Runtime-QA-20261113`.
- ZIP restaurable: `D:\codex\_REPORTES\PicoRadar\V6R4-V5-20261114\delivery\PICORADAR_V6R4_V5_EVIDENCIA_UNICA.zip`.
- `HEAD=15948a50332589ff3d1fb3157b6976809fe5a680`; `TREE=8e0b8cd1de0607e9baeeffcfac93c8f141afb67f`; rama LAB `feat/picoradar-v6r4-lab-candidate`; PR71 ancestor `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a` (12 commits); ZIP V5 SHA256 `d9252ca2b690daaec6867c3c904885da30c0b69d7221698a611b22c71b785fca`; `GIT/full-final.bundle` SHA256 `dad16fccb97493add593bbacbd13edfb1db60219f14b445fd5e22141356639a1`.
- `F0=PASS`, `F1 Flutter/Drift/OTA/UI=PASS` en ese código, `F2 PHP=F2_FULL_PASS_SCOPED_QA` (33 tests/279 assertions, exit0) con R2 auténtica, `F5=ZIP_VERIFY_PASS`. Estos gates son **CONGELADOS** si árbol y contratos iguales. `F3=BLOCKED_RESOURCE`, `F4=HOLD_SCANNER`.

Una sola lectura: `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`, `git status --porcelain`, base ancestor y `git remote -v` (redactar credenciales). Si el estado difiere, **NO tocar el checkout**; restaurar bundle V5 en clon nuevo bajo `D:\codex\_isolated\` y documentar el cambio de fuente. Si otro escritor activo -> parar solo este trabajo. Preservar WIP ajeno. Seleccionar exactamente un candidato.

**No verificar de nuevo CRC/ZIP anterior** salvo al abrir el bundle en un clon necesario. No modificar datos sin prueba causal; si se produce delta permitido, nuevo commit local aislado y pruebas focales solo del delta. Este preflight no cuenta como repetir F0.

## 2. G4 — Escaneo de secretos + respaldo remoto de la rama LAB (prioridad alta)

### G4.1 Obtener scanner gratis en una única tentativa acotada

Se comprobó que Gitleaks no existe en el host anterior. No repetir búsquedas recursivas. Usar **Gitleaks CLI portable v8.30.0 Windows x64** desde el release oficial:

`https://github.com/gitleaks/gitleaks/releases/download/v8.30.0/gitleaks_8.30.0_windows_x64.zip`

SHA-256 esperado del ZIP **`54fe94f644b832dd08e8c3a5915efb3bfa862386d59fb27ca0792cb687a83573`**. Comprobar `Get-FileHash -Algorithm SHA256` **antes** de extraer. Destino aislado de herramientas en `D:\codex\_tools\gitleaks-8.30.0\`, sin administrador ni instalador global. No incluir ejecutable, archivo descargado ni credenciales en evidencia. Si checksum difiere, descarga falla o GitHub 403 -> `G4=HOLD_TOOL_UNAVAILABLE`, conservar bundle, continuar G2/G3 y **no push**. NO sustituir por solo búsquedas regex ni alterar el gate. No es obligatorio bajar v8.30.1 (hubo inconsistencia pública de checksum Windows).

### G4.2 Ejecutar sobre historia exacta y estado actual

Escanear usando configuración default de Gitleaks v8.30.0, **sin allowlist nueva y sin suppress**. Rango `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a..15948a50332589ff3d1fb3157b6976809fe5a680` mediante `gitleaks git --log-opts="BASE..HEAD" <clon>`; además `gitleaks dir <clon>` sobre estado final (excluir `.git` solo por comportamiento nativo, sin esconder product files). Ejecutar reportes JSON **privados**, `--redact=100`, guardar en el ZIP **solo resumen saneado** de versión/comando/código de salida/cantidad/reglas/commit/ruta genérica, NO valores de secretos ni tokens. Confirmar que se escanearon los 12 commits correctos. Cualquier hallazgo verdadero: `G4=HOLD_SECRET_FOUND`, **no push**. Falso positivo: no ignorar por cuenta propia; registrar la evidencia **sin valor sensible** y devolver al director para decisión. `PASS` requiere ambos scans exit0, 0 hallazgos y logs creíbles.

### G4.3 Publicar solo respaldo LAB si G4 PASS

Verificar una vez `git ls-remote` (sin imprimir URLs con tokens), acceso GitHub y ausencia de rama remota. **No cambiar permanentemente `origin` si apunta al bundle**; para push usar URL/remote temporal de GitHub autorizado. Empujar exclusivamente **la rama `feat/picoradar-v6r4-lab-candidate`** con HEAD verificado, sin `--force`, sin tags, sin `main`, sin merge, sin CI de pago ni PR. Hacer `ls-remote` y `fetch` focal para confirmar exactamente el mismo SHA remoto. Si GitHub falla 403/suspended/auth/costo, `G4=BLOCKED_REMOTE` y conservar bundle; máximo **un intento** de push después de preflight, no volver a intentarlo en bucle.

**No pedir al usuario token ni ponerlo en chat/ZIP.** Si G2 genera un commit más nuevo después del escaneo, **repetir el scanner solo sobre el nuevo delta antes de push** y sincronizar HEAD final, no el anterior.

## 3. G2 — Probar la unión real Laravel -> OTA -> Flutter (necesario para producto)

**Hechos ya certificados sin reejecución:** 33 PHP/279 aserciones con MariaDB QA, R2 `ACTUAL_R2_LARAVEL_RELEASE.json` SHA `c879a27ce3fc0ef983575a069e995c95c4f9a03fe2b5f89509386dfa8090d5e5`, tests Flutter OTA/Drift 2 + UI 1. Falta probar que **los bytes publicados por el Laravel REAL** son justamente los que acepta la app, sin inventar reemplazos de dataset.

1. Inspeccionar una sola vez el flujo existente `server/app/Services/RestrictionPublicationService.php`, `server/app/Services/DatasetReleaseValidator.php`, `server/app/Services/DatasetPublisher.php`, `server/tests/Feature/RestrictionNationalLabPublicationTest.php`, `mobile/lib/features/pico_placa/` y pruebas OTA existentes. Reutilizar el publicador, el manifest y el consumidor; no crear segunda API, segundo motor, schema3 ni generador paralelo.
2. En entorno QA aislado **con entradas sintéticas y cero producción**, generar o recuperar desde el servicio de publicación existente un **snapshot completo respecto de las versiones QA aprobadas**. Comprobar que no se borran autoridades previamente aprobadas al añadir otra, que `revision/version` y `sha256` corresponden exactamente a los bytes servidos, y que el reemplazo de dataset del consumidor es seguro. Si los 14 registros V6R4 son `partial` LAB no aprobados, **NO promocionarlos como productivos**: usar approvals simuladas de QA y etiquetar el resultado `QA_ONLY`, nunca `national-complete`.
3. Consumir por HTTP loopback controlado **exactamente esos bytes Laravel** en `DatasetSyncService` + Drift real (no solo JSON incrustado en test). Verificar: versión mayor válida importa, se conserva Garaje/preferencias, `UNKNOWN/STALE` donde corresponde, rechazo de SHA inválido, actualización fallida conserva último válido, rollback administrativo/manifest de versión anterior recuperable y reinicio conserva datos. No correr nuevamente las suites completas: crear **máximo un único test de puente focal**, o invocar un puente ya existente si realmente cubre la unión entre publicador y consumidor con bytes idénticos.
4. Para Laravel usar solo una DB **temporal vacía y efímera** si el puente necesita DB; portar controles de F2: bind 127.0.0.1, puerto libre, identidad de datadir/PID/DB/user verificada vía SQL y configuración Laravel resuelta antes de `RefreshDatabase`, `APP_KEY` sintética, `explicit_defaults_for_timestamp=ON`, cerrar instancia y puerto al final. No modificar migraciones ni autenticar contra DB real. Las cinco `PICORADAR_...` solo si el test realmente las consume, no crear fixtures falsos.
5. Si algún contrato de puente no existe o resulta imposible sin infraestructura nueva: **no reinventar el backend**; documentar `G2=BLOCKED_BRIDGE_CONTRACT` con pieza exacta, ejecutar los subgates independientes y terminar el macrobloque. Solo corregir un defecto causal que se reproduzca en código existente con test RED->GREEN focal; nada de refactor cosmético. Si todo pasa: `G2=PASS_QA_BRIDGE_ONLY`, NO release.

**Veracidad jurídica:** Dosquebradas 66170 tiene calendario parcial; festivos/ámbito personal no comprobados, `staleAfter` no debe extenderse para poner verde pruebas. El dataset QA de 14 autoridades/33 DIVIPOLA/21 coberturas/115 reglas **no representa toda Colombia**, taxis/buses/carga aún sin cobertura en este snapshot. Los seis HOLD históricos siguen, pero no bloquean una prueba QA de transporte.

## 4. G3 — Android debug solamente con gate de recursos real

No hay APK V6R4. Último preflight heredado: RAM libre 9.51 GiB, commit libre 6.18 GiB, **pagefile libre 3.37 GiB**; mínimo histórico de seguridad 6 GiB; `mobile/android/gradle.properties` rastreado contiene `-Xmx8G -XX:MaxMetaspaceSize=4G`. **No bajar unilateralmente el umbral aprobado ni iniciar Gradle a ciegas.**

- Medir recursos **una sola vez** al iniciar este gate; si el margen >=6 GiB exigido y CPU/SDK/firma aptos, ejecutar **un solo build debug** según contrato existente: `flutter build apk --debug --flavor dev --dart-define=APP_ENV=dev --no-pub` desde `mobile` con Flutter compatible probado 3.47.9. Capturar exit, SHA/bytes APK, configuración/firma `debug`, logs sin secretos y verificación de package name/flavor. NO ADB, NO desinstalar APK, NO usar Mi A3 sin autorización. Un build debug no equivale a release ni firma productiva.
- Si pagefile sigue bajo 6 GiB, `G3=BLOCKED_RESOURCE` sin intento. Si existe **otro entorno gratuito ya disponible y autorizado** con memoria suficiente, usarlo en clon aislado para un build QA; nunca mover datos privados a un servidor gratuito no confiable, ni activar CI de pago. Sin alterar configuración permanente de Windows/pagefile o Gradle. Registrar requisitos exactos de hardware para cerrar este gate con mínima intervención futura, no crear otro prompt solo para medir de nuevo.
- Si el build llega a fallar por **causa nueva confirmada**, se admite una corrección mínima de entorno dentro del mismo bloque, un solo reintento justificado; si no, `FAIL_BUILD_CAUSE` y entregar. No cambiar versión de Flutter, dependencias o ajustes JVM del producto por intentar forzar PASS.

## 5. Orden y entrega — cero pingpong

Orden de trabajo recomendado: **preflight -> G4 scanner (antes de publicar) -> G2 puente QA -> G4 re-scan delta si G2 cambió código -> push LAB condicional -> G3 build condicional -> G5 empaquetado**. Si alguna fase queda bloqueada, continuar las otras **independientes** sin volver atrás ni pedir otra ronda de auditoría. No modificar el HEAD base salvo correcciones causales permitidas y commiteadas en aislado. Si no hay delta, conservar `15948a5` tal cual.

**Entrega única:** `D:\codex\_REPORTES\PicoRadar\V6R4-V6-ONEPASS-20261114\delivery\PICORADAR_V6R4_V6_EVIDENCIA_UNICA.zip`, compuesto por:
- `FINAL_REPORT.md` corto: TASK_ID, HEAD/TREE, baseline, F0/F1/F2 heredados, resultado G2/G3/G4/G5, causas, cambio/commit, bloqueos y `NEXT_ACTOR=CHATGPT_DIRECTOR`, `PRODUCT_RELEASE=NO_GO`;
- `GATE_MATRIX.csv` con comando exacto, código exit realmente capturado, cantidad de tests/aserciones, SHA del fixture y SHA de código/manifest; `MANIFEST_SHA256.csv` con tamaño/SHA/CRC de los otros miembros;
- prueba independiente recuperable: **Git bundle completo** del HEAD final más `RESTORE.md`, `git status`, diff focal, hashes; logs crudos de QA sin secretos, evidencia Gitleaks **saneada**, prueba HTTP puente y bytes/manifest **sintéticos públicos únicamente** si resultan indispensables;
- hash del APK debug y reporte de verificación de firma **solo si se construyó**, no APK de producción ni APK con credenciales. Si es muy grande, el APK QA puede ir en el ZIP si no expone datos privados, y debe documentarse expresamente si no se incluye;
- prueba de restauración de bundle en clon vacío y de integridad del ZIP (CRC/miembros/manifest) al final. No incluir R2 histórico completo, contraseñas QA, tokens, `.env`, DB, registros de Garaje ni ZIP anteriores. Los logs de scanner pueden contener secretos aun con `--redact=100`: analizar/sanear antes de empaquetar.

Respuesta final de Codex: UNA línea `TASK_ID | G2=... | G3=... | G4=... | G5=... | HEAD=... | TREE=... | RELEASE=NO_GO | NEXT=CHATGPT_DIRECTOR` + ruta de UN ZIP + SHA-256. No adjuntar múltiples archivos sueltos, no redactar otra propuesta de V7 ni remitir al director decisiones que ya están resueltas aquí. No suponer que un path `D:\...` se descarga en ChatGPT: el usuario debe adjuntar el ZIP físico.

## 6. Criterio de terminación real del producto (NO confundir con este macro)

La app podrá evaluarse para release **solo** después de: (a) puente de publicación con snapshot íntegro aprobado y rollback real; (b) build y QA física Android, firma compatible y persistencia; (c) fuentes/ámbitos legales vigentes por la cobertura efectivamente ofrecida, sin falso permiso en municipios/categorías no cubiertos; (d) revisión de seguridad, privacidad, accesibilidad y permisos; (e) autorización explícita del propietario. La cobertura nacional completa es un programa editorial alimentado por JSON/manifiestos aprobados, no un motivo para crear un motor por ciudad o un APK por calendario.

**QUIÉN SIGUE TRAS ENVIAR ESTE MARKDOWN: CODEX LUNA (si no hay escritor activo). DESPUÉS DE UN SOLO ZIP: CHATGPT DIRECTOR.**
