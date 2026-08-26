# KICKOFF C01 — PicoRadar: Pico y Placa

Ejecuta **únicamente C01** y encárgate también del bootstrap de GitHub descrito abajo.

## Contexto aprobado

C00 está **APPROVED / CLOSED**.

Baseline C00:
- Branch: `feat/C00-picoradar-repo-scaffold-flavors`
- HEAD aprobado: `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`
- C00 tests/builds: aprobados
- C00 no hizo merge
- GitHub remoto canónico: `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
- GitHub estaba vacío al preparar este kickoff

No reescribas ni amendes el commit C00 aprobado.

## Antes de editar

Inspecciona el repo actual y lee:

1. `AGENTS.md`
2. `GITHUB_REPOSITORY.md`
3. `README_START_HERE.md`
4. `docs/baseline/00_NOMBRE_OFICIAL_PICORADAR.md`
5. `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`
6. `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`
7. `docs/baseline/02_Wireframes_Design_System_v1.docx`
8. `docs/baseline/06_Flujo_04_Apps_Launcher_v1.docx`
9. `codex/TECH_BASELINE.md`
10. `codex/GLOBAL_DOD_STOP_CONDITIONS.md`
11. `codex/PROJECT_STATE.md`
12. `codex/lots/C01_APP_SHELL_ROUTER.md`

## Fase A — Bootstrap GitHub

Hazlo tú mismo; no pidas pasos manuales al usuario si tienes acceso al workspace/Git.

1. Verifica que el commit aprobado C00 existe localmente:
   `14f7b1ae1ffa8a4d9b79a8a5f9a1093b7984185b`
2. Verifica que el worktree esté limpio antes de bootstrap.
3. Revisa `git remote -v`.
4. Si `origin` no existe, añádelo:
   `https://github.com/sierraglobalcompany-rgb/PicoRadar.git`
5. Si `origin` apunta a otro repo, **STOP CONDITION**: no lo cambies silenciosamente.
6. Consulta el remoto.
7. Si el remoto sigue vacío, crea/actualiza local `main` apuntando exactamente al SHA C00 aprobado.
8. Publica `main` en origin.
9. Publica `feat/C00-picoradar-repo-scaffold-flavors` si la branch local existe, para trazabilidad.
10. Verifica que `origin/main` apunta exactamente al SHA C00 aprobado.
11. No hagas rebase, squash, amend ni merge del C00.

Si GitHub ya contiene commits inesperados, detente y reporta el grafo antes de modificar remoto.

## Fase B — Branch C01

Desde el `main` publicado y aprobado:

`feat/C01-app-shell-router`

## Objetivo C01

Implementar la fundación visual/global de PicoRadar:

**Inicio · Garaje · Apps · Viaje · Conducir**

Reglas:
- exactamente 5 tabs;
- Apps siempre es la tercera y está en el centro;
- la segunda se llama **Garaje**, nunca “Vehículo”;
- no implementar contenido funcional de C02+;
- no implementar todavía el grid 3x3 de Apps (eso es C12).

## Stack permitido C01

Añade únicamente lo requerido por C01:

- `flutter_riverpod: 3.4.2`
- `go_router: 17.5.0`

No añadas:
- Drift;
- Firebase;
- GetX/BLoC/GetIt;
- Riverpod generator;
- Freezed;
- GPS;
- paquetes de features posteriores.

Si las versiones exactas no son compatibles con Flutter 3.47.1, aplica Stop Condition antes de cambiar el baseline.

## Implementación esperada

### Design tokens
Centraliza como mínimo:
- colores semánticos/base;
- tipografía/escala;
- spacing;
- radius;
- tamaños de iconos/componentes comunes que realmente use C01.

No conviertas C01 en un rediseño exhaustivo.

### AppShell
Usa `go_router` con `StatefulShellRoute.indexedStack` o la solución estable equivalente aprobada en la arquitectura.

Root branches:
- `/home`
- `/garage`
- `/apps`
- `/trip`
- `/drive`

Cada branch tendrá solo una pantalla placeholder visualmente coherente con Design System.

### Bottom Navigation
Orden exacto:

1. Inicio
2. Garaje
3. Apps
4. Viaje
5. Conducir

Apps:
- índice 2;
- iconografía de apps/9 puntos;
- visualmente central;
- no FAB flotante si contradice la baseline.

### Immersive routing
Deja preparada una ruta top-level fuera del shell para probar el patrón de futuras pantallas inmersivas (HUD/scanner/document viewer), sin implementar esas features.

### Estado
Usa Riverpod de forma mínima. No crear un `AppState` gigante.

## Acceptance Criteria

- [ ] Branch C01 parte del SHA aprobado publicado en `main`.
- [ ] `origin/main` conserva C00 aprobado.
- [ ] Exactamente cinco destinos.
- [ ] Orden exacto.
- [ ] Apps es el centro/índice 2.
- [ ] Segunda tab dice Garaje.
- [ ] Cambio de tabs funciona.
- [ ] Estado básico de ramas se conserva con indexed stack.
- [ ] No se crean stacks duplicados.
- [ ] Back behavior está probado y documentado.
- [ ] Existe estructura para immersive route fuera del shell.
- [ ] Tokens de diseño centralizados.
- [ ] Riverpod/go_router son las únicas dependencias de arquitectura de producto añadidas en C01.
- [ ] No existe grid de Apps ni features posteriores.

## Tests / gates obligatorios

Ejecuta y registra:

```text
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --flavor dev
```

Añade tests específicos para:
- labels y orden de las 5 tabs;
- Apps índice 2;
- navegar entre tabs;
- state preservation básico;
- back behavior;
- immersive route fuera del shell.

## GitHub al finalizar

1. Commits acotados en `feat/C01-app-shell-router`.
2. Push de la branch.
3. Abre PR hacia `main`.
4. Título recomendado:
   `[C01] App shell and five-tab router`
5. Completa cuerpo de PR con template del proyecto.
6. **NO MERGE**.

Si no puedes autenticar/push/open PR por una restricción real del entorno, eso es `PARTIAL` o `BLOCKED` según cuánto de C01 esté completo. No pidas al usuario hacerlo manualmente si puedes resolverlo con las credenciales ya disponibles.

## Entrega verificable para ChatGPT

A partir de C01 no necesito que empaquetes todo el source si está correctamente publicado en GitHub.

El handoff debe incluir:
- repo;
- PR URL y número;
- branch;
- base branch;
- HEAD SHA;
- commit list de C01;
- `git diff --stat main...HEAD`;
- tests exactos;
- APK path;
- dependencies añadidas;
- warnings;
- `git status`;
- confirmación `NO MERGE REALIZADO`.

También:
- regenera `SHA256SUMS.txt` / manifests del paquete documental **si modificas archivos que dichos manifests cubren**;
- no presentes hashes obsoletos como válidos.

## Respuesta final

Empieza exactamente por una de estas líneas:

`C01: DONE`
`C01: PARTIAL`
`C01: BLOCKED`

No avances a C02.
