# AGENTS.md - PicoRadar: Pico y Placa

## Recuperación vigente (2026-10-20)

La rama moderna es `recovery/20261019-modern`, fuente B07 `ffe0cbd`. Leer primero `docs/CURRENT.md` y el handoff de recuperación de la raíz para HEAD, gates y NEXT. El main histórico no sustituye esa fuente. Checkout canónico `D:/Dev/PicoRadar` sobre exFAT; originales C: preservados. Los planes y paths de workspaces anteriores son antecedentes, no instrucciones activas.

Este rescate autorizado consolida historias existentes; la regla de un lote por rama vuelve a aplicar a desarrollos futuros. Sin merge automático, force-push, Hostinger, Mi A3 ni activaciones comerciales. No convertir una prueba sintética en aprobación física. Git en exFAT usa confianza de proceso para rutas exactas, nunca comodín global.


Estas instrucciones son obligatorias para cualquier agente/Codex que trabaje en este repositorio.

## 1. Fuente de verdad

Antes de modificar comportamiento:
1. leer `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`;
2. leer `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`;
3. leer el flujo funcional especifico del lote;
4. leer el archivo del lote `codex/lots/Cxx_*.md`;
5. leer `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md` y `docs/SOP.md` cuando el cambio toque estado actual, UI o procedimientos.

Precedencia:
`seguridad/privacidad/store > Cierre Global > Arquitectura Tecnica > Flujos 01-08 > Design System > Screen Map > Plan Maestro > docs/CURRENT.md`.

No reinterpretar requisitos desde memoria o desde un documento de menor precedencia.

## 2. Invariantes de producto

- Marca oficial: **PicoRadar**.
- Titulo previsto en tiendas: **PicoRadar: Pico y Placa**.
- Barra inferior exacta: **Inicio · Garaje · Apps · Viaje · Conducir**.
- **Apps siempre al centro**.
- La aplicacion funciona **sin cuenta**.
- Android se implementa primero, pero la arquitectura es Flutter multiplataforma.
- Free 1.0 se termina antes de monetizar.
- Ads/payments/cloud/WhatsApp/email premium permanecen OFF.
- No construir mapa tipo Waze propio.
- Pico y placa se evalua localmente desde datasets versionados.
- Conducir usa camaras locales; no consulta backend por cada posicion.
- No enviar GPS continuo al servidor.
- No almacenar recorrido/historial GPS por defecto.
- No guardar documentos privados en nube por defecto.
- No calcular estimacion de impuesto vehicular.
- No scrapear ni evadir CAPTCHA de SIMIT/RUNT.
- No usar logos oficiales de fabricantes sin licencia.
- Defensa del conductor no promete anulacion de multas.
- Patrocinado y oficial/acreditado son estados separados.
- Cero publicidad durante Conducir/HUD, documentos privados y emergencias.

## 3. Arquitectura KISS

- Feature-first modular monolith.
- Flutter + Riverpod + go_router + Drift/SQLite.
- Laravel control plane; backend fuera del hot path de GPS.
- Datasets estaticos/versionados por CDN.
- No microservicios prematuros.
- No BLoC/GetX/GetIt anadidos junto a Riverpod.
- No package nuevo sin justificar:
  - por que se necesita;
  - alternativa estandar considerada;
  - impacto Android/iOS;
  - mantenimiento/licencia;
  - tests.

## 4. Seguridad

Nunca:
- poner secretos en repo, APK o `dart-define`;
- conectar la app directamente a MySQL/MariaDB;
- loggear placa, cedula, contenido de documentos, GPS exacto o rutas;
- subir imagenes de Billetera al backend por defecto;
- desactivar TLS/validaciones para "hacer funcionar" un entorno;
- borrar datos locales del usuario por una migracion sin plan y tests.

## 5. Datos y privacidad

- Vehiculos/preferencias: local-first.
- Documentos: storage privado + cifrado.
- GPS de Conducir: buffer temporal en memoria.
- Analytics: agregados y sin PII.
- Leads: consentimiento explicito + partner visible.
- Crash logs: sanitizados.

## 6. Reglas de implementacion

- Ejecutar **un solo lote Cxx** por branch/PR salvo indicacion explicita.
- No ampliar scope "porque conviene".
- No refactor grande en el mismo lote que una feature nueva.
- No cambiar arquitectura/base tecnologica fuera de un ADR/lote especifico.
- Mantener nombres/IDs funcionales aprobados.
- No esconder TODO/FIXME para declarar DONE.
- No atrapar excepciones silenciosamente.
- Domain/application no depende de `BuildContext`.
- Queries persistentes se centralizan en Drift.
- Cambios de schema llevan migracion + test.

## 7. Quality gates

Antes de cerrar un lote movil:
- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- tests especificos del lote
- build Android dev cuando el lote toca integracion/plataforma

Antes de cerrar lote server:
- tests Laravel
- formatter/static checks definidos
- migraciones/contract tests aplicables

Si el lote exige QA fisica, emulador no basta.

## 8. Android fisico

Requieren evidencia en dispositivo real:
- scanner/camara;
- notificaciones sensibles al OS;
- GPS/heading;
- foreground/background Conducir;
- TTS/Bluetooth;
- HUD/brillo/keep-awake;
- bateria;
- lifecycle lock/background/restore.

## 9. Git

- Branch por lote: `feat/Cxx-slug`, `fix/Cxx-slug`, `chore/Cxx-slug`.
- Un lote no hace merge.
- No force-push sobre branch compartida.
- Commits claros y acotados.
- Handoff con SHA/branch/tests/worktree.
- Worktree limpio al finalizar, salvo artefactos explicitos del handoff.

## 10. Stop conditions

Detener y reportar opciones si:
- hay conflicto con Baseline;
- falta una API key/credencial real;
- un package no soporta baseline/API 36;
- una migracion arriesga datos;
- la solucion exigiria violar privacidad/arquitectura;
- una policy de Play/App Store contradice el diseno;
- arreglar tests exige ampliar significativamente scope;
- hay ambiguedad legal/seguridad que no puede resolverse desde fuentes del lote.

No improvisar un atajo que cambie producto o arquitectura.

## 11. Tooling advisory

- Graphify se usa para estructura, dependencias, hubs, orfandad y acoplamiento. Su salida `graphify-out/` es evidencia local ignorada por Git y no se commitea.
- UI/UX Pro Max se usa solo como asesor visual. No es dependencia runtime y no puede cambiar decisiones congeladas de producto.
- Flutter tests validan comportamiento; goldens/screenshots validan fidelidad visual.
- `docs/DESIGN_CONTRACT.md` y los mockups/baseline son la autoridad visual para R01+.

## 12. Cierre obligatorio

Completar `codex/templates/HANDOFF_TEMPLATE.md` con:
- branch + HEAD;
- que cambio;
- archivos;
- tests exactos;
- QA manual/fisica;
- riesgos;
- deuda conocida;
- siguiente lote desbloqueado;
- `git status`.

No decir solo "todo funciona".

## 13. GitHub canonical repository

- Remote: `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
- Canonical repository: `sierraglobalcompany-rgb/PicoRadar`
- Default branch: `main`
- Push feature branches and open PRs when the active lot requires it.
- Never merge a PR without explicit human approval.
- Never force-push `main`.
- Do not rewrite approved C00 SHA `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`.

## 14. Evidencia canonica

- Git commit SHA, pull request y GitHub Actions son la evidencia canonica de cada lote.
- `docs/CURRENT.md`, `docs/DESIGN_CONTRACT.md` y `docs/SOP.md` son documentos vivos. `codex/PROJECT_STATE.md` fue retirado para evitar duplicidad.
- No generar ZIPs, carpetas de archivo ni manifiestos SHA del repositorio salvo solicitud explicita de export package.
