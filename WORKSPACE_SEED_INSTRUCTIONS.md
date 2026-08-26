# PicoRadar C00 Workspace Seed

Este ZIP está diseñado para **descomprimirse directamente en la raíz del repositorio Git existente**.

Después de extraer, la raíz debe verse así:

```text
PicoRadar_ Pico y Placa/
├─ .git/
├─ README_START_HERE.md
├─ AGENTS.md
├─ 00_NOMBRE_OFICIAL_PICORADAR.md
├─ C00_EXACT_PROMPT_PICORADAR_FOR_CODEX.md
├─ docs/
├─ codex/
├─ contracts/
├─ data/
├─ scripts/
└─ ...
```

## IMPORTANTE

No extraigas el ZIP dentro de otra subcarpeta como:

`PicoRadar_C00_Workspace_Seed_v1/`

dentro del repo.

Los **contenidos** del ZIP deben quedar al mismo nivel que `.git`.

## Después de extraer

Ejecuta:

```powershell
Get-ChildItem -Force
Test-Path README_START_HERE.md
Test-Path AGENTS.md
Test-Path codex\lots\C00_REPO_SCAFFOLD_FLAVORS.md
Test-Path docs\baseline\11_Cierre_Global_Baseline_v1_0.docx
Test-Path docs\baseline\12_Arquitectura_Tecnica_Android_First_v1.docx
git status --short --branch
```

Los cuatro `Test-Path` deben devolver `True`.

Luego vuelve a ejecutar el prompt:

`C00_EXACT_PROMPT_PICORADAR_FOR_CODEX.md`

El repo puede seguir sin commits; C00 puede crear la primera branch/commit según el lote y documentarlo.
