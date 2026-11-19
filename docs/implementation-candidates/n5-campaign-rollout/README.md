# PicoRadar · Director N5/04 · Control seguro de publicidad y aliados

**Fecha:** 2026-11-18 COT. **Estado:** `CODE_READY_TESTS_DEFERRED`. **RELEASE:** `NO_GO`.

## Resultado implementado

Se complementaron el circuito **existente** de campañas Laravel (Super Admin), publicador de catálogo y cliente Flutter Home C11. No se introdujeron plataformas, SDK de publicidad, proveedores pagos, cuentas, motores de ciudad, nuevas dependencias ni anuncios en Conducir/HUD/documentos.

1. **Free 1.0 fail-closed en ambos lados:** `CAMPAIGN_PUBLIC_CATALOG_ENABLED=false` en Laravel por defecto y `PICORADAR_SPONSORED_CAMPAIGNS_ENABLED=false` en Flutter por defecto. La aplicación mantiene la demostración local y el formulario de aliados independiente.
2. **Servidor / publicación:** las campañas internas y su auditoría sobreviven, pero mientras la entrega comercial está OFF, cada publicación genera un catálogo versionado vacío. `GET /api/v1/campaign-catalog` devuelve 404 aunque exista manifest. El Admin informa que la difusión comercial no está activa.
3. **Activación controlada posterior:** al habilitar el servidor en un entorno autorizado se exige `CAMPAIGN_PUBLIC_BASE_URL` HTTPS absoluta sin credenciales/query/fragment. El comando existente admite `php artisan campaigns:refresh-catalog --publish-now` para emitir una versión inmediatamente sin GitHub Actions ni esperar al programador de tareas.
4. **Flutter:** la carga del catálogo remoto de patrocinados exige el `dart-define` comercial explícito y sigue validando HTTPS/hashes/territorio. Si el servidor responde **404 al manifest**, la aplicación no reutiliza campañas pagadas almacenadas en caché; un error transitorio de conexión sigue pudiendo utilizar una copia válida y no vencida.
5. **Pruebas agregadas (para Codex después):** validación de catálogo con switch OFF→ON; exigencia HTTPS; botón y aviso Admin; bloqueo de remoto desde Flutter; cache offline ante 404 frente a error de conexión. No se reescribieron pruebas históricas.
6. **Variables documentadas:** dos archivos `.env.example` del servidor; no se incluyeron credenciales.

## Recuperación / identidad exacta

- `BASE_TREE_N5_03 = 8060cc1211344bc71c51c74fa6979215f38579b2`
- `FINAL_TREE_N5_04 = 46da2c96277a46f90f4198d081f0d96c3802057e`
- 15 archivos cambiados en N5/04. El parche aplica limpiamente sobre N5/03 y la reconstrucción en clon aislado reproduce ese TREE exactamente.
- El contenido del ZIP incluye diff y versiones finales completas de los 15 archivos.
- **No existe commit del producto en GitHub main:** solo se conserva un parche candidato en rama documental aislada bajo `HOLD_SECURITY`.

## Controles ejecutados aquí (no equivalen a QA funcional)

- `git diff --cached --check`: PASS
- `git apply --cached --check` en clon independiente N5/03: PASS
- `git write-tree` de clon de recuperación: coincide exactamente con final TREE: PASS
- No se ejecutó PHPUnit, Pint, Flutter test/analyze ni APK. El usuario pidió **dejar las pruebas de ejecución para Codex**. No tiene que probar nada personalmente.

## Único bloque futuro de QA para Codex (cuando vuelva a tener tokens)

1. Recuperar N4 WIP del usuario ANTES de aplicar cualquier candidato; no sobrescribir cuenta/perfil ni comenzar suites históricas.
2. Aplicar en orden N5/01 → N5/02 → N5/03 → N5/04 sobre el árbol base verificado; si el WIP tocó alguno de los 15 archivos, detener solo ese archivo para integración causal.
3. Ejecutar pruebas focales existentes y nuevas: Laravel `CampaignCatalogPublisherTest`, `CampaignAdminControllerTest`, `CampaignOperationsTest`, `CampaignRouteIntegrationTest`, incluyendo flag OFF/ON y `--publish-now`; `php -l`, Pint en archivos afectados; Flutter `home_partner_catalog_provider_test.dart`, `home_partner_catalog_test.dart` y `flutter analyze`/format.
4. Si se modificó Dart en el árbol final (N5/03 y N5/04), pasar una suite Flutter global completa UNA vez en ese árbol cuando exista SDK; sin reenviar pruebas anteriores como si correspondieran al nuevo árbol.
5. Hacer E2E Android/HTTPS **solo con QA/CDN aprobados**, no usar HTTP como prueba de producto. Evitar instalar sobre Mi A3 sin verificar firma y preservación de datos.
6. Un ZIP final con logs/resultados y `TREE`, nunca marcar `PASS` lo no ejecutado.

## No confundir con lanzamiento

- El código N5/04 **no está integrado** en la rama pública de producto, ni compilado ni probado en Android.
- Flags OFF por defecto significa que una actualización de campañas desde el panel **no activa anuncios automáticamente**. Para comenzar entrega comercial aprobada será necesario distribuir **una APK que haya sido compilada con el flag ON**; luego las campañas se podrán cambiar por catálogo sin reconstruir la app.
- Activar o apagar servidor requiere publicar de inmediato el manifest con el comando existente `--publish-now` y verificar las reglas HTTPS de mismo origen; un CDN puede conservar archivos históricos inmutables, por lo que el distribuidor debe aplicar su política de caché/purga. No se realizó esa operación.
- Los leads de aliados siguen sujetos a privacidad, consentimiento y configuración independiente. Placas, documentos, GPS y fotografías privadas no se transmiten a publicidad.
- `N4_R2=EXTERNAL_WIP_NOT_RECEIVED`, `ACTIONS_UNAVAILABLE`, `PRODUCT_RELEASE=NO_GO`, `NEXT_ACTOR=CHATGPT_DIRECTOR` para continuar desarrollando sin Codex.