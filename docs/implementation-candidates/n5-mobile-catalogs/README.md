# PicoRadar — N5/02: catálogos manuales publicables en Laravel

**Corte:** 18 de noviembre de 2026 (Colombia). **Estado:** `CODE_IMPLEMENTED_SCOPED_PASS`, `RELEASE=NO_GO`.  
**Responsable:** ChatGPT Director, trabajo aislado sin Codex ni GitHub Actions.

## Desarrollo verificado

- Base N5/01: `7e8cc4dba1c93cba31bac408051c285b17802aad`. Nuevo árbol: `f8e1305624c664e8d02856eb853f7f366d365711`.
- 4 archivos de servidor: se añade `MobileCatalogPayloadValidator`, se conecta con `DatasetReleaseValidator` y se incluyen pruebas PHPUnit unitarias y funcionales.
- El flujo admin existente (`/admin/datasets` → fuente verificada → JSON en borrador → validar → revisor publica → manifest SHA-256 → rollback) acepta tres **nuevas claves**: `cda_catalog`, `cda_geography`, `insurance_directory`, todas con `schemaVersion=1`.
- Se validan antes de publicar campos obligatorios, fuentes HTTPS, fechas, filas no vacías, IDs únicos, cifras de inventario CDA, rangos geográficos de Colombia, evidencias de direcciones, teléfonos/WhatsApp y asistencia de aseguradoras verificada, incluyendo aliases/contactos duplicados.
- Las comprobaciones no permiten convertir contactos sin verificar en servicios asegurados. No se cambian reglas de pico y placa, usuarios, placas, datos particulares, Flutter, Drift, campañas ni el candidato N5/01.
- Assets originales reales contrastados **sin copiarlos ni alterarlos**: cda_catalog 964 records, cda_geography 866 records, insurance_directory 16 records.

## Validación ejecutada

- `php -l` de los 4 archivos: **PASS**.
- Script PHP independiente `QA/mobile_catalog_smoke.php` con los tres JSON reales y entradas maliciosas: **25/25 PASS**.
- `git diff --cached --check`: **PASS**.
- Parche aplicado a clon aislado de N5/01; `git write-tree` coincide exactamente con `f8e1305624c664e8d02856eb853f7f366d365711`: **PASS**.

## Límites (no afirmar más de lo probado)

- `php artisan test` de la suite PHPUnit **NOT_RUN_ENV**: este contenedor no contiene `vendor`, `pdo_sqlite` ni `mbstring`; las pruebas están entregadas para su ejecución cuando haya entorno Laravel.
- Este avance habilita la **publicación manual validada del lado servidor**. El cliente Flutter actual sigue consumiendo CDA/aseguradoras desde `assets/catalogs/`; `datasetSyncServiceProvider` aún no registra sus importadores. Por tanto, **NO** afirmar actualización OTA de CDA/aseguradoras en la APK.
- Para subir un catálogo al panel, además de sus campos originales debe tener `datasetKey` correcto, `version` seguro y `generatedAt` ISO-8601 con zona horaria. No confundir `generatedAt` de empaquetado con `sourceVerifiedAt` de la fuente. Los assets CDA actuales no traen el sobre completo y requieren preparación editorial antes de upload.
- La fuente verificada y activa en `DatasetSource`, revisión independiente, HTTPS del cliente, pruebas de instalación Android y saneamiento `HOLD_SECURITY` siguen siendo requisitos. No habilitar anuncios ni publicar ni sobrescribir contenido productivo desde esta entrega.

## Integración sin perder el N4 incompleto

- Archivo fuente de verdad del candidato: `RECOVERY/N5_01_TO_N5_02.patch` (SHA256 `75209493d77f2988c5830be4574b2058467ff9af9bd03f24753179405ddd13bf`).
- Aplica únicamente sobre **N5/01** `7e8cc4dba1c93cba31bac408051c285b17802aad`; verificar primero el árbol. NO aplicar el parche a `main` antiguo ni a un checkout N4 con WIP sin comparar rutas.
- Pasos en un **clon aislado** con base correcta: `git apply --check RECOVERY/N5_01_TO_N5_02.patch`, `git apply --index RECOVERY/N5_01_TO_N5_02.patch`, `git write-tree`; el último debe dar `f8e1305624c664e8d02856eb853f7f366d365711`.
- El módulo N4-R2 de Codex quedó inconcluso y no se ha recibido su worktree. Mantener los datos privados del usuario exclusivamente locales; conservar las reglas `UNKNOWN/STALE` y un solo motor nacional.

## Próximos cierres de producto (no ejecutados)

1. Implementar **lectores OTA transaccionales para CDA y aseguradoras** y conectar los tres providers Flutter a datos descargados, con fallback al asset y sin perder last-good.
2. Revisar el WIP N4-R2 y completar registro opcional/consentimientos/SuperAdmin de clientes sin mezclar operadores.
3. Infraestructura HTTPS QA, QA Android físico sin pérdida de documentos, firma release, saneamiento GitHub y despliegue humano autorizado.
4. Comercial: campañas/aliados existentes deben recibir QA de publicación/consumo, anuncios feature-off hasta autorización.

**NEXT_ACTOR=CHATGPT_DIRECTOR**. `GITHUB_PRODUCT=HOLD_SECURITY`; `PRODUCT_RELEASE=NO_GO`.