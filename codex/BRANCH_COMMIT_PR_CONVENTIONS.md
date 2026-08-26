# Branch / Commit / PR Conventions

## Branches

- `feat/C00-repo-foundation`
- `feat/C01-app-shell`
- `fix/C20-driving-background`
- `chore/C02-ci-quality-gates`

One active lot per branch unless explicitly authorized.

## Commits

Preferred:
- `C00: scaffold Flutter and Laravel workspace`
- `C03: add Drift schema and migration tests`
- `C18: implement camera matcher track fixtures`

Avoid:
- `updates`
- `fix stuff`
- `wip final final`

## Pull requests

Title:
`[Cxx] <short outcome>`

PR body:
1. Goal
2. Source of truth / flow IDs
3. Scope in/out
4. Changes
5. Tests
6. Manual/physical QA
7. Risks
8. Screenshots/artifacts if relevant
9. Stop conditions encountered
10. Handoff

## Merge

- Human approval required.
- Agent never merges autonomously.
- No merge with failing required checks.
