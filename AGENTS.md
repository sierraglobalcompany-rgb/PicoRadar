# AGENTS.md — PicoRadar: Pico y Placa

Estas instrucciones son obligatorias para cualquier agente/Codex que trabaje en este repositorio.

## 1. Fuente de verdad

Antes de modificar comportamiento:
1. leer `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`;
2. leer `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`;
3. leer el flujo funcional específico del lote;
4. leer el archivo del lote `codex/lots/Cxx_*.md`.

Precedencia:
`Cierre Global > Arquitectura Técnica > Flujos 01–08 > Design System > Screen Map > Plan Maestro`.

No reinterpretar requisitos desde memoria o desde un documento de menor precedencia.

## 2. Invariantes de producto

- Marca oficial: **PicoRadar**.
- Título previsto en tiendas: **PicoRadar: Pico y Placa**.

- Barra inferior exacta: **Inicio · Garaje · Apps · Viaje · Conducir**.
- **Apps siempre al centro**.
- La aplicación funciona **sin cuenta**.
- Android se implementa primero, pero la arquitectura es Flutter multiplataforma.
- Free 1.0 se termina antes de monetizar.
- Ads/payments/cloud/WhatsApp/email premium permanecen OFF.
- No construir mapa tipo Waze propio.
- Pico y placa se evalúa localmente desde datasets versionados.
- Conducir usa cámaras locales; no consulta backend por cada posición.
- No enviar GPS continuo al servidor.
- No almacenar recorrido/historial GPS por defecto.
- No guardar documentos privados en nube por defecto.
- No calcular estimación de impuesto vehicular.
- No scrapear ni evadir CAPTCHA de SIMIT/RUNT.
- No usar logos oficiales de fabricantes sin licencia.
- Defensa del conductor no promete anulación de multas.
- Patrocinado y oficial/acreditado son estados separados.
- Cero publicidad durante Conducir/HUD, documentos privados y emergencias.

## 3. Arquitectura KISS

- Feature-first modular monolith.
- Flutter + Riverpod + go_router + Drift/SQLite.
- Laravel control plane; backend fuera del hot path de GPS.
- Datasets estáticos/versionados por CDN.
- No microservicios prematuros.
- No BLoC/GetX/GetIt añadidos junto a Riverpod.
- No package nuevo sin justificar:
  - por qué se necesita;
  - alternativa estándar considerada;
  - impacto Android/iOS;
  - mantenimiento/licencia;
  - tests.

## 4. Seguridad

Nunca:
- poner secretos en repo, APK o `dart-define`;
- conectar la app directamente a MySQL/MariaDB;
- loggear placa, cédula, contenido de documentos, GPS exacto o rutas;
- subir imágenes de Billetera al backend por defecto;
- desactivar TLS/validaciones para “hacer funcionar” un entorno;
- borrar datos locales del usuario por una migración sin plan y tests.

## 5. Datos y privacidad

- Vehículos/preferencias: local-first.
- Documentos: storage privado + cifrado.
- GPS de Conducir: buffer temporal en memoria.
- Analytics: agregados y sin PII.
- Leads: consentimiento explícito + partner visible.
- Crash logs: sanitizados.

## 6. Reglas de implementación

- Ejecutar **un solo lote Cxx** por branch/PR salvo indicación explícita.
- No ampliar scope “porque conviene”.
- No refactor grande en el mismo lote que una feature nueva.
- No cambiar arquitectura/base tecnológica fuera de un ADR/lote específico.
- Mantener nombres/IDs funcionales de los documentos cuando existan.
- No esconder TODO/FIXME para declarar DONE.
- No atrapar excepciones silenciosamente.
- Domain/application no depende de `BuildContext`.
- Queries persistentes se centralizan en Drift.
- Cambios de schema llevan migración + test.

## 7. Quality gates

Antes de cerrar un lote móvil:
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- tests específicos del lote
- build Android dev cuando el lote toca integración/plataforma

Antes de cerrar lote server:
- tests Laravel
- formatter/static checks definidos
- migraciones/contract tests aplicables

Si el lote exige QA física, emulador no basta.

## 8. Android físico

Requieren evidencia en dispositivo real:
- scanner/cámara;
- notificaciones sensibles al OS;
- GPS/heading;
- foreground/background Conducir;
- TTS/Bluetooth;
- HUD/brillo/keep-awake;
- batería;
- lifecycle lock/background/restore.

## 9. Git

- Branch por lote: `feat/Cxx-slug`, `fix/Cxx-slug`, `chore/Cxx-slug`.
- Un lote no hace merge.
- No force-push sobre branch compartida.
- Commits claros y acotados.
- Handoff con SHA/branch/tests/worktree.
- Worktree limpio al finalizar, salvo artefactos explícitos del handoff.

## 10. Stop conditions

Detener y reportar opciones si:
- hay conflicto con Baseline;
- falta una API key/credencial real;
- un package no soporta baseline/API 36;
- una migración arriesga datos;
- la solución exigiría violar privacidad/arquitectura;
- una policy de Play/App Store contradice el diseño;
- arreglar tests exige ampliar significativamente scope;
- hay ambigüedad legal/seguridad que no puede resolverse desde fuentes del lote.

No improvisar un atajo que cambie producto o arquitectura.

## 11. Cierre obligatorio

Completar `codex/templates/HANDOFF_TEMPLATE.md` con:
- branch + HEAD;
- qué cambió;
- archivos;
- tests exactos;
- QA manual/física;
- riesgos;
- deuda conocida;
- siguiente lote desbloqueado;
- `git status`.

No decir solo “todo funciona”.

## 12. GitHub canonical repository

- Remote: `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
- Canonical repository: `sierraglobalcompany-rgb/PicoRadar`
- Default branch: `main`
- Push feature branches and open PRs when the active lot requires it.
- Never merge a PR without explicit human approval.
- Never force-push `main`.
- Do not rewrite approved C00 SHA `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`.

## 13. Canonical evidence

- Git commit SHA, pull request and GitHub Actions are the canonical evidence for each lot.
- Do not generate ChatGPT ZIP packages for every lot.
- Do not regenerate `SHA256SUMS.txt` or `manifest_sha256.txt` for every lot.
- Generate hashes or ZIP packages only when the user explicitly requests an export package.
