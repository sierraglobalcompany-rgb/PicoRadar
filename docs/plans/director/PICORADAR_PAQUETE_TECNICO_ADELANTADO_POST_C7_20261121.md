# PICORADAR — PAQUETE TÉCNICO ADELANTADO PARA LA SIGUIENTE OLA (POST C7)

**DIRECTOR:** ChatGPT | **Corte:** 21/11/2026, Colombia | **Estado:** preparación independiente terminada; **NO ES UNA ORDEN PARA CODEX**.

**Regla inmediata:** Codex Luna continúa `PICORADAR-C7-V2-IMPLEMENTACION-NACIONAL-20261121`. **No detenerlo, reiniciarlo, modificar su checkout ni remitirle este archivo mientras trabaja.** Este paquete es una **adición técnica concreta** al plan director ya aprobado; **NO lo sustituye y NO crea C8**. Al recibir C7 se integra su diff una única vez y se redacta una sola instrucción nueva, si corresponde.

**Fuente de código inspeccionada:** `backup/picoradar-c6-source-20261120`, commit `bc1422c7198607850a49f4a294ed67316fed0805`, árbol `2c0fd2e7a4ef8eed5b342101afb7320982d3c07c`, 1.882 blobs. ZIP C6 local, `SOURCE_RECOVERY_C6.tar.gz`, leído selectivamente para cotejar implementación; **no se duplicó ni transportó**. `main` observado `e9ef37511df3110ffb0fc006ef06be781df432ac`; PR #79 Draft. **C7 aún no auditado ni dado por finalizado.**

---

## 1. Hechos técnicos NUEVOS que el siguiente lote no debe redescubrir

| Hallazgo comprobado en C6 | Archivo o evidencia exactos | Consecuencia de ejecución |
|---|---|---|
| Ya existe controlador nacional, importación, validación, aprobación, publicación, rollback y exportación | `server/app/Http/Controllers/Admin/RestrictionRuleController.php`, `server/app/Services/RestrictionRuleVersionService.php`, `server/app/Services/RestrictionPublicationService.php` | **No crear otro editor, publicador ni motor**; C7 está implementando la interfaz municipal. No pedir otra exportación CSV. |
| C6 no prueba HTTPS público ni Android físico | `GATES.csv`, `PRODUCT_DELIVERY_MATRIX.csv`, APK DEV con hash ya documentado | Gates separados y no bloqueantes; no volver a compilar APK por rutina, no adjuntar APK. |
| Un aviso legal para Bogotá está **codificado para noviembre de 2026** en la presentación Flutter | `mobile/lib/features/pico_placa/presentation/restriction_scope_notice.dart`: `bogotaUrbanRestrictionScopeNotice`, `co-dc-bogota`, `2026`, `month == 11`, días 2/16 | **Candidato técnico concreto post-C7**: reemplazar el acoplamiento temporal por advertencia derivada de metadatos OTA cuando existan; si no existen, conservar aviso conservador de alcance no evaluado. No suprimir avisos sin equivalencia demostrada. |
| El aviso se usa en **dos recorridos de usuario** y tiene un test existente | `mobile/lib/features/pico_placa/presentation/today_restriction_summary.dart`, `mobile/lib/features/trip/presentation/trip_plan_result.dart`, `mobile/test/features/pico_placa/presentation/bogota_scope_notice_test.dart` | Cambios de A deben probar Pico **y** Viaje y actualizar solo el test causal; **no borrar** el test anterior para fabricar PASS. |
| Publicidad: ya existen editor, previsualización, sponsors, catálogo y permisos | `server/app/Http/Controllers/Admin/CampaignController.php` (`preview`, `activate`, `pause`, `archive`), `server/resources/views/admin/campaigns/preview.blade.php`, `server/app/Services/CampaignCatalogPublisher.php`, `server/app/Services/CampaignAccess.php` | **Prohibido ordenar “construir módulo de publicidad” desde cero**. Elegir solo una brecha de uso/seguridad demostrada, sin habilitar monetización. |
| Flutter tiene bandera explícita de campañas remotas OFF | `mobile/lib/features/home/application/home_partner_catalog_provider.dart`: `PICORADAR_SPONSORED_CAMPAIGNS_ENABLED` false por defecto; repositorio remoto nulo, fallback local | El `OFF` de red está implementado. **Auditar solo si el contenido fallback local se presenta engañosamente como patrocinio comercial**; no asumir que el fallback equivale a ads pagados. |
| El registro de normas en el servidor tiene borradores y validación independiente | `RestrictionRuleVersionService::createDraft`, `updateDraft`, `validate`, `archive` y hashes | El trabajo legal útil es **calidad y vigencia de la fuente y revisor**, no reemplazar el modelo ni saltar aprobación manual. |
| La página de Medellín tiene información 2026 y FAQ históricos 2022 en el mismo HTML | Página oficial `https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/` | **No extraer reglas por scraping indiscriminado de toda la página**; usar solo bloque 2026 y contrastar acto íntegro vigente. |

### Riesgos de semántica que deben conservarse

- `UNKNOWN`, `STALE`, `PARTIAL` y `NO_JURISDICTION` **nunca equivalen a permiso para circular**.
- `coverageCompleteness = partial` **no equivale** a restricción completa en toda un área; `staleAfter` vencido obliga a advertencia y revisión.
- `schemaVersion` del manifest y del dataset no son necesariamente la misma capa; no volver a “corregir” una diferencia de numeración sin contrato.
- `ads/payments/premium = OFF` en Free 1.0. Contenido editorial local y campaña pagada son categorías diferentes; no mezclarlas.
- `source-only backup PASS` **no** equivale a merge de producto con `main`, ni a `RELEASE=GO`.

## 2. Registro de tres pilotos jurídicos comparado contra el código (trabajo hecho por Director)

**Estado de las filas:** observaciones para auditoría editorial, **NO reglas autorizadas para publicar**. Corte de fuentes web: 21/11/2026. C7 investiga estos pilotos en paralelo: **si trae evidencia más reciente, esa evidencia prevalece**. No encargar otra búsqueda general; incorporar solo discrepancias nuevas.

| Municipio / categoría | Artefacto C6 realmente presente | Descubrimiento oficial actual | Decisión editorial y bloqueo pendiente |
|---|---|---|---|
| **Medellín (05001), carro particular y moto particular** | `server/database/data/restrictions/official/g34/2026-11-medellin.json`; dos `coverages` `partial`, 5 reglas cada una; `staleAfter=2026-11-17T23:34:08Z`; fecha ya vencida | Alcaldía muestra rotación desde 03/08/2026; página oficial de segundo semestre, Decreto 1490/2026 citado por portal municipal | Marcar `STALE` para revisión, no “VERIFIED” por el nombre `official/`. Contrastar texto íntegro Decreto 1490/2026, excepciones, alcance y vigencia antes de actualizar la fecha. **No modificar dataset durante C7**. |
| **Bogotá (11001), particulares** | `server/database/data/restrictions/official/2026-11-bogota.json`: reglas por par/impar, `validUntil=2026-11-30T23:59:59-05:00`, `staleAfter=2026-12-01T05:00:00Z`; falta `coverageCompleteness` en ese artefacto | Secretaría de Movilidad: página actualizada 10/11/2026 remite a Decreto Distrital **652 de 2025, arts. 227–230** (particulares, excepciones y retorno); calendario oficial noviembre | Confrontar el acto 652/2025 con la rotación y distinguir **ordinario urbano vs. regional**. No extrapolar reglas de noviembre a diciembre. Verificar compatibilidad de esquema y estado editorial antes de publicar. |
| **Bogotá (11001), motocicletas / taxis** | Moto: 0 reglas, `staleAfter=2026-09-23T05:00:00Z`; taxis: 23 reglas de fechas específicas noviembre | SDM documenta taxis en régimen distinto y remite a Decreto 652/2025; calendario mensual por modalidad | No marcar moto “sin restricción legal” solo por lista vacía; revisar otras medidas puntuales/excepciones. Para taxis no extrapolar 23 reglas como calendario perpetuo. |
| **Cali (76001), carro particular** | `server/database/data/restrictions/lab/2026-11-cali-official-calendar-partial.json`: `coverageCompleteness=partial`, 5 reglas, `staleAfter=2026-12-01T00:00:00-05:00`, **`inside_scope_ref=co-vac-cali-calendar-unknown-scope@2026-s2`** | Boletín Oficial de Cali registra **Decreto 4112.010.20.0814**, de **26/06/2026**, segundo semestre; enlace automatizado al boletín devolvió 403 y la web refiere ajustes temporales de agosto | `PARTIAL`: el ámbito territorial no está resuelto. Obtener acto íntegro y modificaciones por vía oficial autorizada, **sin evadir CAPTCHA ni 403**. Hasta entonces no afirmar cobertura espacial completa ni publicar norma nueva. |

**Fuentes web oficiales consultadas, sin pretender aprobación normativa:**

1. Medellín, Secretaría de Movilidad, segundo semestre 2026: https://www.medellin.gov.co/es/secretaria-de-movilidad/pico-y-placa-medellin-2023-segundo-semestre/
2. Medellín, ficha de Decreto 1490/2026 y vías exentas: https://www.medellin.gov.co/giscatalogacion/srv/api/records/2d9cb19a-e7c7-4e1d-8a38-fb055997b043
3. Bogotá, Secretaría Distrital de Movilidad, normativa por tipo: https://www.movilidadbogota.gov.co/pico-y-placa
4. Bogotá, SDM, particulares / Decreto 652/2025, actualización 10/11/2026: https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-establecida-para-vehiculos-particulares
5. Bogotá, SDM, taxis: https://www.movilidadbogota.gov.co/preguntas-frecuentes/en-que-consiste-la-restriccion-para-los-taxis-servicio-publico-individual-en
6. Cali, Boletín Oficial No. 103, registro Decreto 0814/2026 (portal puede denegar acceso automatizado): https://web1.cali.gov.co/aplicaciones/boletin_publico/detalle_boletin.php?id=3434&num=103
7. Cali, portal oficial de boletines con cambio temporal agosto 2026: https://www.cali.gov.co/boletines/publicaciones/193804/abc-cali-restablece-el-pico-y-placa-ordinario-y-adopta-una-medida-focalizada-en-la-zona-de-mayor-afectacion/

**Regla de incorporación de C7:** no duplicar sus fichas. Comparar fuente, fecha y estado; incorporar solamente actos/categorías adicionales no registrados. Si C7 ya valida Medellín/Bogotá/Cali con texto íntegro y aprobación, reemplazar la observación previa mediante evidencia del ZIP C7; no “descartar” resultados sin verlos.

## 3. Tres paquetes de trabajo preparados para la ola siguiente — NO EJECUTAR HASTA CERRAR C7

### A. Flutter / motor / UX segura — propietario exclusivo `AGENTE_A`

**Base conocida:** `mobile/lib/features/pico_placa/`, `mobile/lib/features/trip/`, `mobile/lib/core/sync/`. Existe `DatasetSyncService` con ETag/304, hash, almacenamiento local y rutas de rollback; hay tests G2 y pruebas de migración ya aprobadas. No reconstruir arquitectura.

**Tarea candidata concreta A1:** eliminar el **aviso Bogotá–noviembre 2026 codificado en pantalla**, sin borrar la protección legal: extraer la razón de alcance desde los metadatos de catálogo/reglas **solo si el contrato existente la soporta**; en caso contrario mostrar aviso conservador general de “restricciones adicionales o regionales no evaluadas” sin indicar falsamente que se puede circular. **No tocar el resultado del motor ni cambiar una norma jurídica.** Usar `restriction_scope_notice.dart`, sus dos consumidores y test. Demostrar que Pico y Viaje muestran aviso correcto ante caso conocido, fuente parcial, fuera de rango y ausencia de metadata. No crear schema 3 ni añadir reglas particulares en el cliente.

**Tarea A2 condicionada a diff C7:** recorrido *vehículo guardado → municipio → particular/moto/taxi según cobertura disponible → regla vigente/UNKNOWN → fuente/fecha → sin red → último bueno*. Reutilizar pruebas ya aprobadas; **solo implementar** un vacío verificable detectado entre los dos consumidores. Un test de loopback C2 **no es HTTPS real**, y `EMULATOR_PASS` **no es físico**.

**Aceptación de A:** un commit del agente con diff productivo si falta comportamiento, **2 recorridos UI vinculados** (Pico/Viaje), test causal y ausencia de nuevas ramas `if(cityId == ...)` para reglas. Si el C7 ya solucionó A1, aceptar su commit y elegir A2 no cubierto; nunca fabricar un parche redundante.

### B. Laravel / editor normativo — propietario exclusivo `AGENTE_B`

**Evitar colisión C7:** C7 trabaja `RestrictionRuleController.php`, `server/routes/web.php`, vistas de bandeja municipal. No editar esos archivos mientras corre C7. Después del cierre de C7 se usa su commit como base; **no repetir la pantalla municipal**.

**Tarea B1:** implementar, solo si falta, una **puerta editorial explícita para fuente vencida/incompleta** en los servicios de validación/publicación existentes (`RestrictionRuleVersionService`, `RestrictionPublicationService`, `RestrictionContractValidator`) con señal de revisión y razón, preservando los controles de aprobación ya existentes. El código actual sí tiene borrador/validación/publicación/rollback; comparar la regla actual antes de editarla. Una fuente `STALE` o perímetro no verificado no puede ascender implícitamente a `VERIFIED`. Si ya está cerrada la puerta, entregar evidencia focal y pasar a la siguiente brecha verdadera del flujo de revisión normativa; no crear otra puerta equivalente.

**Tarea B2:** llevar una ficha de fuente oficial hasta **borrador inactivo/NO_PUBLICADO** únicamente si se obtuvo acto íntegro, fecha, vehículo, servicio, perímetro y excepciones. Contrastar con JSON de `official/` y `lab/` y no tratar el nombre de carpeta `official` como aprobación. **Cero publicación automática**, cero cambios en reglas sin aprobación humana. Cada variante (particular/moto/taxi/servicio público) debe tener su propio estado y vigencia.

**Aceptación de B:** código runtime solo si había una brecha real, un recorrido admin *fuente → estado editorial → validación → aprobación por rol → publicación exclusivamente manual*, tests focales de rechazo de fuente vencida y de no publicación sin autorización. Si depende de acto oficial inaccesible, `BLOCKED_SOURCE` en esa jurisdicción, pero continuar con infraestructura de revisión y demás agentes.

### C. Campañas/aliados y seguridad Free 1.0 — propietario exclusivo `AGENTE_C`

**Lo que YA existe:** `CampaignController::preview`, `activate`, `pause`, `archive`; `CampaignCatalogPublisher`, `CampaignAccess`, catálogo Flutter remoto OFF, pantallas de sponsors/campañas y tests. **No volver a construir previsualizador, patrocinadores, catálogo ni roles**.

**Tarea C1 focal:** auditar la **semántica de contenido local fallback** (`fallbackHomePartnerCampaigns`) frente al requisito *publicidad comercial OFF*: que no se confunda anuncio pagado/patrocinado con contenido editorial/propio; revisar rotulación y no presentar promoción como oficial. Si ya cumple, acreditar con test/commit y elegir únicamente una brecha de seguridad observada en el recorrido de campaña; **no fabricar cambios**.

**Tarea C2:** demostrar admin *crear borrador → preview → revisión/activación autorizada* **sin** activar el catálogo remoto de Free 1.0, sin llamadas HTTP al cargar Inicio ni patrocinio durante Conducir/HUD/documentos/emergencias. Solo cambios de código si falla un comportamiento documentado. `PICORADAR_SPONSORED_CAMPAIGNS_ENABLED` permanece false por defecto y `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false` en servidor. No añadir SDK de anuncios, pagos ni telemetría por el lote.

**Aceptación de C:** frente autónomo y disjunto (home/partners y backend campañas), sin tocar motor, OTA ni rutas comunes; prueba causal de fail-closed y rotulación; sin declararlo «monetización completa». Si no hay brecha real, reasignar trabajo al siguiente recorrido Free incompleto **solo con aprobación de alcance del integrador**, no pedir al director un prompt entero nuevo.

### I. Integración única / liberación — propietario exclusivo `INTEGRADOR`

- Esperar **SHA del código C7 real**, contrastar con C6; un solo repositorio base común, subagentes en worktrees aislados. `A || B || C → integrador → pruebas causales → push rama descendiente → PR Draft contra base apta → ZIP ligero`.
- No escribir al mismo tiempo sobre `mobile/lib/core/sync/**`, `server/routes/**` o índice compartido. Rutas comunes solo integrador.
- No forzar `main` ni hacer merge del backup root a `main`. Integración `main` sigue **separada** y exige evidencia de diff/cambio de base.
- Una compilación Android **solo si** el código integrado cambia plataforma/runtime relevante y RAM suficiente, jamás pedir ni adjuntar APK. Ejecutar QA físico solo con autorización de instalación; preservar datos ante firma incompatible.
- HTTPS real solo con staging aprobado: sin `verify=false`, sin dar permisos por supuesto. Fallo externo no cancela A/B/C.
- Un único ZIP final **ligero** (objetivo 2 MiB, máximo 5 MiB), diffs textuales/hashes, cero APK/TAR/bundle/base64/snapshots gigantes/placas/GPS.

## 4. Indicadores nuevos para evitar otro «58 %» engañoso

No inventar porcentajes por número de pruebas. Mantener cifras con nombre y denominador explícito.

| Indicador principal | Fórmula y unidad | Fuente / momento de actualización | Prohibición de falso avance |
|---|---|---|---|
| **Recorridos críticos aceptados** | `Nº recorridos Free 1.0 con evidencia de aceptación / Nº de recorridos Free 1.0 enumerados y congelados` | Contrato baseline + matriz `PRODUCT_SCOPE_1_0`; firmar denominador una vez al aceptar C7 | No contar dos veces una pantalla y su test; un recorrido requiere caso normal y fallback crítico. Sin denominador firmado = **NO_MEDIBLE**. |
| **Cobertura jurídica publicable** | `Nº pares (jurisdicción × vehículo/servicio × periodo) con acto íntegro y doble aprobación / Nº pares elegibles y priorizados` | Registro legal con fuente, vigencia y control de dos personas | La geografía de **1.104 municipios** no es el denominador de actos normativos. `UNKNOWN` y borrador no cuentan como publicados. Sin denominador de pares = **NO_MEDIBLE**. |
| **Gates reales de salida Free** | `Nº gates release PASADOS / Nº gates release obligatorios` | QA de release único, por plataforma y entorno; indicador separado, nunca sustituye desarrollo | Build APK debug, emulador y TLS loopback **no equivalen** a release físico/HTTPS. |

**Indicadores auxiliares:** `NEW_RUNTIME_FEATURES`, `NEW_RUNTIME_FILES`, `TESTS_CAUSAL_PASS`, `REMOTE_CODE_SHA`, `DEVICE_PHYSICAL`, `HTTPS_REAL`, `ACT_FULLTEXT_VERIFIED`, `ADS_PUBLIC_ENABLED` (debe seguir `false`).

**Históricos separados:** `58 %` desarrollo y `83 %` núcleo técnico eran estimaciones **no validadas**; **61/100** mide evidencia local C6 y no corresponde al desarrollo total. **No recalcular** hasta congelar denominadores. Evitar objetivos porcentuales artificiales por cada prompt.

## 5. Control de entrada una vez llegue C7 — 8 operaciones, NO otra auditoría general

1. Validar ZIP ligero y manifiesto, sin exigir APK ni TAR.
2. Obtener `C7_HEAD_SHA`, árbol y cambios remotos; comprobar origen C6 (o documentar divergencia).
3. Validar nueva interfaz municipal, permisos y pagination únicamente con pruebas nuevas; no repetir el CSV de C6.
4. Integrar hallazgos jurídicos C7; **resolver solo conflictos de fuentes**, no repetir búsquedas oficiales ya hechas.
5. Marcar flujos A/B/C como `ALREADY_CLOSED`, `IMPLEMENTABLE_GAP`, `BLOCKED_EXTERNAL` según diff C7.
6. Emitir **una** orden macrobloque después de ese diff, con archivos disjuntos y pruebas causales. No publicar C8 y luego pedir C8-V2 salvo error material inequívoco.
7. Usar rama descendiente del **último commit remoto seguro**, no de `main`, para trabajo de agentes; evitar otra raíz source-only si ya hay ancestro C6.
8. Un ZIP ≤5 MiB, logs breves, commit remoto y `NEXT=CHATGPT_DIRECTOR`. Si la entrega no trae código, decir exactamente qué frente fue bloqueado; no anunciar 100 %.

**Leyes operativas:** L1 KISS, L2 antirruido, L3 antiparches, L4 UX humana, L5 verificación causal, L6 antiping-pong. Riesgos absolutos: no tocar WIP protegido (43 rutas), no `flutter clean`/Actions por rutina, no secretos, no placas/documentos/GPS reales, no publicidad activada, no publicación normativa sin aprobación y no merge automático a `main`.

---

## 6. Decisión ya tomada

**Mientras C7 corre:** el director puede seguir verificando documentación y fuentes públicas **sin cambiar código ni ramas de Codex**. No enviar este documento como orden de ejecución; no solicitar reinicio ni APK.

**Después de C7:** el director toma el SHA real, descontamina las tareas ya cerradas y genera una sola orden de 2–3 funciones útiles, no otra serie de auditorías. Este paquete conserva trabajo técnico adelantado para que esa orden no comience investigando de cero.

# 🔴🔴🔴 CONTINÚA CODEX LUNA CON C7-V2. DESPUÉS SIGUE CHATGPT DIRECTOR 🔴🔴🔴

**NO REINICIAR NI INTERRUMPIR A CODEX. ESTE DOCUMENTO NO ES UN PROMPT NUEVO.**
