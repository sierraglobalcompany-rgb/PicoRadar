# G34 — auditoría del flujo editorial

**Alcance:** revisión del código y pruebas Laravel contra SQLite/Storage fake. No se ejecutó publicación de estas tres propuestas ni se usó una cuenta real.

## Camino operativo implementado

1. `/admin/restrictions/publish` obtiene una vista previa por versión con SHA de ciudad anterior/propuesta, cambios, IDs de reglas, coberturas, fuentes, fecha de consulta y `staleAfter`.
2. `POST /admin/restrictions/{version}/approve-material-change` atraviesa el middleware existente `web`/autenticación y el Gate `restriction.material_change.approve`; el formulario incluye CSRF.
3. El servicio solo acepta versión `Validated`, revisión de publicación actual y payload cuyo SHA siga coincidiendo con el hash de validación. El revisor debe ser Admin/SuperAdmin activo y diferente de autor y último editor.
4. Motivo de 10–1.000 caracteres; evidencia HTTPS que coincida exactamente con una fuente del payload; todas las fuentes deben ser HTTPS sin credenciales y figurar activas en el registro del dataset de restricciones. La revisión debe incluir `sourceCheckedAt` y `staleAfter` futuro.
5. El evento append-only `restriction.material_change.approved` guarda versión, autor/revisor, revisión, SHA de base/propuesta/diff, cambios, reglas/coberturas, fuentes, vigencia, motivo y URL de evidencia. Un reintento idéntico es idempotente; una versión, diff, revisión o revisor diferentes no reutilizan el evento.
6. Publicar es una acción distinta. Antes de crear release se vuelve a comparar el evento con contenido, base, fuentes, SHA, revisión y rol actuales. Sin coincidencia se registra `REVIEW_REQUIRED`. La cobertura `complete` se bloquea y requiere QA espacial; rollback histórico conserva el camino específico existente.

## Evidencia de pruebas

- `RestrictionMaterialApprovalWorkflowTest.php`: 5 tests / 49 assertions PASS. Incluye HTTP/Gate, roles, autor distinto, evidencia, idempotencia, aprobación separada de publicación, revisión obsoleta, payload alterado, cobertura completa y revisor inactivo.
- `RestrictionG34EditorialImportLabTest.php`: 2 tests / 197 assertions PASS. Las tres propuestas se analizaron, confirmaron y validaron; Cartagena/Manizales se habilitaron únicamente en la base fake; no se generó release/manifest; el hash del catálogo público no cambió.
- `RestrictionSchemaV2LabRoundTripTest.php`: los tests focales de retiro material, complete y vigencia expandida pasan (3 tests / 25 assertions). La suite entera mantiene tres escenarios bloqueados porque requiere el payload R2 exacto y su directorio de evidencia; no se suplió con R4 ni fixture inventado.
- La suite de PHPUnit utiliza entorno de pruebas. El `APP_KEY` requerido por el test HTTP fue temporal, sólo en el proceso de prueba, sin modificar `.env`.

## Revisión adversarial interna

Se corrigió la discrepancia temporal detectada en `expiresAt`: las fechas de expiración ahora exigen `Z` u offset explícito en PHP y Dart. El test PHP mostró primero el fallo esperado y quedó verde tras la corrección. El formateador Pint pasó después.

No se publicó ninguna propuesta G34. El test de publicación HTTP usa identidades y Storage/DB fake; eso demuestra el camino de código, no autorización jurídica ni publicación real. CSRF está en el grupo `web` y en el formulario; el test no simula la validación CSRF del navegador porque Laravel la omite en sus pruebas por defecto.

La revisión fue interna al mismo agente implementador, no certificación independiente. La falta del R2 exacto y del SDK Flutter deja sin verificar el release/manifest byte a byte en Flutter.
