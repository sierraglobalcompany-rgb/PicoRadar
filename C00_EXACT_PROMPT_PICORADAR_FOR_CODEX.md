# AUTONOMOUS PACKAGE NOTE

If these files are not yet in the Git repository root, copy/extract them there yourself before executing C00. Do not ask the user to do that manually unless the workspace permissions genuinely prevent you.

# KICKOFF C00 — PicoRadar: Pico y Placa

Quiero que ejecutes **únicamente el lote C00** del proyecto **PicoRadar**.

**Marca:** PicoRadar  
**Título previsto en tiendas:** PicoRadar: Pico y Placa

## Antes de editar cualquier archivo

Lee, en este orden:

1. `README_START_HERE.md`
2. `AGENTS.md`
3. `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx`
4. `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx`
5. `codex/TECH_BASELINE.md`
6. `codex/GLOBAL_DOD_STOP_CONDITIONS.md`
7. `codex/PROJECT_STATE.md`
8. `codex/lots/C00_REPO_SCAFFOLD_FLAVORS.md`
9. La decisión de naming `00_NOMBRE_OFICIAL_PICORADAR.md` si está disponible en el workspace.

Después inspecciona el workspace actual antes de modificarlo.

## Objetivo

Ejecuta C00 exactamente como está definido:

**Repository foundation + Flutter/Laravel scaffold + flavors**

Crea la fundación KISS del monorepo y demuestra que Android dev + Laravel tests funcionan antes de empezar cualquier UI de producto.

## Naming e IDs congelados para C00

Usa:

### Marca / app labels
- Prod: `PicoRadar: Pico y Placa`
- Staging: `PicoRadar Staging`
- Dev: `PicoRadar Dev`

### Application IDs propuestos
- Prod: `co.picoradar.app`
- Staging: `co.picoradar.app.staging`
- Dev: `co.picoradar.app.dev`

Si el tooling de flavors necesita una estructura base diferente, mantén como base `co.picoradar.app` y usa suffixes equivalentes.

**No cambies estos IDs por tu cuenta.** Si detectas conflicto técnico real, aplica Stop Condition y reporta opciones.

## Reglas críticas

- Trabaja **solo C00**.
- No avances C01.
- No implementes todavía la barra inferior, pantallas o features.
- No agregues Drift, Riverpod, go_router, Firebase, GPS ni paquetes de producto salvo que C00 lo requiera explícitamente.
- No uses secretos reales.
- Android debe quedar preparado para **targetSdk 36**, minSdk 24 y Java 17.
- Flutter debe mantenerse multiplataforma aunque Android se pruebe primero.
- Laravel 13 / PHP 8.3+.
- No hagas merge.
- No cambies decisiones congeladas de producto.
- No inventes arquitectura adicional.
- Si encuentras una Stop Condition, detente y reporta evidencia + opciones.

## Branch

Si el repositorio ya tiene Git y la rama base está limpia:

`feat/C00-picoradar-repo-scaffold-flavors`

Si todavía no existe repositorio Git, inicialízalo solo si C00 y el workspace lo permiten, documenta la decisión y no hagas merge.

## Resultado esperado

Debe existir una estructura equivalente a:

```text
picoradar/
├─ mobile/
├─ server/
├─ docs/
├─ data/
├─ scripts/
├─ .github/
├─ AGENTS.md
└─ README.md
```

Con:

- Flutter app creada en `mobile/`.
- Laravel app creada en `server/`.
- flavors `dev`, `staging`, `prod`.
- labels PicoRadar diferenciados por flavor.
- application IDs según la sección anterior.
- Android minSdk 24.
- Android targetSdk 36.
- Java 17.
- `.env.example` / ejemplos de configuración sin secretos.
- smoke tests mínimos.
- README con comandos exactos de instalación y ejecución.
- documentación baseline disponible dentro del repo o referenciada de forma inequívoca.

## Acceptance Criteria obligatorios

No declares DONE hasta que todos los criterios aplicables estén comprobados:

- [ ] `flutter --version` baseline registrado.
- [ ] `flutter pub get` exitoso.
- [ ] `flutter analyze` exitoso.
- [ ] `flutter test` exitoso.
- [ ] `flutter build apk --debug --flavor dev` exitoso.
- [ ] Laravel arranca.
- [ ] `php artisan test` exitoso.
- [ ] Prod application ID = `co.picoradar.app`.
- [ ] Staging y Dev tienen IDs distintos.
- [ ] Labels correctos por flavor.
- [ ] No hay secretos reales en el repo.
- [ ] La estructura del monorepo coincide con C00.
- [ ] No se implementó ninguna feature de C01+.
- [ ] Worktree limpio al cerrar, salvo artefactos de handoff expresamente documentados.

## Evidencia que quiero al final

Usa `codex/templates/HANDOFF_TEMPLATE.md`.

Tu respuesta final debe comenzar con:

`C00: DONE`
o
`C00: PARTIAL`
o
`C00: BLOCKED`

e incluir:

1. Branch.
2. HEAD SHA.
3. Árbol final relevante del repo.
4. Cambios realizados.
5. Application IDs y labels resultantes.
6. Dependencias/tooling añadidos.
7. Comandos exactos ejecutados.
8. Resultado exacto de cada test/build.
9. Cualquier warning relevante.
10. Stop conditions encontradas.
11. `git status`.
12. Qué queda desbloqueado para C01/C02/C03.
13. Confirmación explícita: **NO MERGE REALIZADO**.

No continúes a C01 aunque C00 termine correctamente.
