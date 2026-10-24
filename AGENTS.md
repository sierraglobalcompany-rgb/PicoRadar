# AGENTS.md - PicoRadar: Pico y Placa

## Recuperación vigente (2026-10-21; actualización de portabilidad)

La rama moderna es `recovery/20261019-modern`, HEAD remoto verificado `0d3a6a2a32bff8bd27dbdd92f88433dd8ab3e47a`, fuente B07 `ffe0cbd`. Leer primero `docs/CURRENT.md` y el handoff de recuperación para gates y NEXT. `main` es histórico. Checkout principal **reportado localmente** por MIG-G1C: `D:/codex/PicoRadar` sobre NTFS, autónomo de C:. `D:/Dev/PicoRadar` y `D:/Verification/PicoRadar` son copias heredadas. Las 13 carpetas históricas CAND-01…13 del rescate fueron enviadas de forma reversible a la Papelera, según el último informe de Codex; no hay autorización para vaciar/restaurar ni extender la limpieza. Los respaldos privados de D: permanecen fuera de Git. El checkout principal de D: conserva la eliminación rastreada preexistente del PS1, que no se debe restaurar automáticamente. No crear worktrees nuevos sin necesidad comprobada ni reutilizar rutas históricas como autoridad.

Este rescate conserva la regla un lote por rama. Sin merge automático, force-push, Hostinger, Mi A3 ni activaciones comerciales. No convertir una prueba sintética en aprobación física. Usar confianza Git por ruta exacta, nunca comodín global. Los 720 archivos WIP y el bundle histórico de 196 ramas/13 HEAD están respaldados en carpeta privada de D:, **no en GitHub**; no incorporarlos masivamente, borrarlos ni declarar que se recuperan con `git clone`. PR #74 y PR #75 siguen Draft separados del runtime moderno.


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

## 15. Seis leyes de implementación (L1–L6)

**Canon único:** `docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md` (Maestro Universal V2.0 y anexo PicoRadar). Este apartado es un **índice**, no una copia de las leyes. Mantener íntegramente las secciones 1–14 de este archivo, la precedencia Baseline/Arquitectura, `docs/DESIGN_CONTRACT.md` y las restricciones específicas del proyecto.

**Fuente fijada:** [PingPongLaw@84e961cadf482d234f4c0ee2ca60e8c7e9b388e8](https://github.com/sierraglobalcompany-rgb/PingPongLaw/blob/84e961cadf482d234f4c0ee2ca60e8c7e9b388e8/docs/engineering/LEYES_IMPLEMENTACION_1_A_6.md), blob `0f6e7b4e62d8660c846f135e18dded629d29e0da`. Esta referencia no implica que PingPongLaw esté instalado en Codex ni que PicoRadar remoto ya contenga este WIP.

**ANTES de cada tarea técnica:** identificar repo/ruta/branch/HEAD, estado WIP y permisos del lote; leer este `AGENTS.md` y localizar el canon. Confirmar L1–L6 y consultar solo las secciones pertinentes. Si hay `AGENTS.override.md` local o instrucciones anidadas, comprobar su precedencia y **abrir explícitamente este AGENTS.md**: no suponer carga automática. Si el canon no existe o no puede abrirse, informar `CANON=NO_VERIFICADO` sin inventar PASS.

- **L1 KISS + PONYTAIL:** reutilizar antes de crear; preferir estándar/nativo y dependencia instalada; implementar el mínimo completo con pruebas sin recortar seguridad ni calidad.
- **L2 ANTIRRUIDO:** confirmar equivalencia y consumidores antes de unir o retirar; proteger WIP, privados y reglas existentes.
- **L3 ANTIPARCHES:** reproducir/delimitar, identificar causa raíz y reparar fuente y consumidores con regresión focal.
- **L4 DISEÑO:** respetar Baseline, mockup aprobado y `docs/DESIGN_CONTRACT.md`; UI real, usable, responsive y accesible cuando aplique.
- **L5 VERIFICACIÓN:** evidenciar pruebas del mismo SHA/build, separar PASS/FAIL/BLOCKED/NOT_RUN y la revisión propia de la independiente.
- **L6 ANTIPING-PONG:** ChatGPT dirige y ejecuta lo que permiten sus herramientas; Codex recibe un lote completo, resuelve impedimentos locales seguros y evita microdelegaciones.

**ANTES de cerrar:** registrar L1, L2, L3, L4, L5 y L6 con cumplimiento, evidencia/limitación y resultado; usar `codex/templates/HANDOFF_TEMPLATE.md` sin crear otro formato paralelo. Adjuntar al handoff la evaluación de las seis leyes, pruebas exactas, SHA, `git status`, bloqueos y `NEXT` único o `NINGUNO`. No declarar que Codex cargó las leyes sin comprobar una sesión nueva o su registro de lectura. No autocertificar L5 como auditoría independiente.

**Compatibilidad:** siguen vigentes los límites de Git, secretos, QA y publicación anteriores, especialmente la sección 14: sin ZIP de repositorio ni manifiestos por rutina; solo export package solicitado expresamente. No crear commits/push/PR/merge/deploy ni modificar `AGENTS.override.md` por aplicar esta cláusula, salvo autorización separada.
