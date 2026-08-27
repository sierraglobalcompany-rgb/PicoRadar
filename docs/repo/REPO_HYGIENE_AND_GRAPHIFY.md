# PicoRadar — Repo Hygiene + Graphify

## Objetivo

Mantener el repositorio pequeño, navegable y útil para humanos/agentes sin guardar ruido que Git ya conserva.

## Principio

El árbol activo debe contener únicamente:

- código vigente;
- contratos vigentes;
- tests vigentes;
- assets productivos;
- documentación operativa vigente;
- baseline realmente canónica;
- fuentes de datos necesarias para trazabilidad.

No usar el repo como carpeta de exportación histórica.

## Regla de borrado/fusión

Antes de conservar un archivo preguntar:

> ¿Puede eliminarse o fusionarse sin perder una capacidad operativa, contrato vigente, dato fuente, prueba o decisión actual?

Si sí, eliminar/fusionar.

Git ya conserva la historia.

No crear `archive/`, `old/`, `backup/`, `vfinal2/` para evitar decidir.

## Clasificación de archivos

### KEEP

- `AGENTS.md`
- `docs/baseline/` vigente
- `contracts/`
- `codex/lots/` vigentes mientras siga el sistema Cxx
- `codex/PROJECT_STATE.md`
- `codex/data_sources/`
- código/tests/assets
- CI

### REVIEW → DELETE IF UNREFERENCED

- prompts exactos de C00/C01 en root;
- one-click bootstrap antiguo;
- PACKAGE_AUDIT iniciales;
- handoff summaries supersedidos;
- READMEs de arranque redundantes;
- capturas QA históricas no usadas como golden/reference vigente;
- build pack overview antiguo;
- hash manifests legacy.

### DO NOT COMMIT

- APKs;
- build outputs;
- screenshots temporales QA;
- Graphify output generado en cada ejecución;
- caches;
- logs;
- local env;
- editor state.

## Graphify

Graphify es adecuado para PicoRadar porque el repo mezcla:

- Dart/Flutter;
- Kotlin Android;
- PHP/Laravel;
- SQL/migrations;
- contratos/docs.

Uso esperado:

```text
uv tool install graphifyy
graphify install
/graphify .
```

El comando genera una representación local del grafo de código para consultas estructurales.

## Política Graphify PicoRadar

Aunque Graphify permite guardar sus outputs, PicoRadar prioriza un repo sin ruido.

Por defecto:

```text
graphify-out/
```

debe estar ignorado por Git.

No versionar automáticamente:

- `graph.html`
- `graph.json`
- caches Graphify
- snapshots por cada lote

Si un reporte arquitectónico aporta una decisión durable, copiar únicamente el hallazgo relevante a un documento canónico y citar commit/paths.

## Usos obligatorios propuestos

Antes de cambios cross-feature importantes:

- qué importa `AppDatabase`;
- qué depende de `VehicleRepository`;
- qué rutas consumen un screen;
- qué providers dependen de una preferencia;
- qué tablas/índices están realmente consultados;
- qué código se volvería huérfano si se elimina una abstracción.

Graphify NO sustituye tests ni review.

## Índices DB — política KISS

Un índice nuevo necesita demostrar:

1. query exacta;
2. tabla afectada;
3. columnas del filtro/order/join;
4. por qué PK/índice actual no basta.

No indexar:

- booleanos aislados;
- columnas pequeñas de baja cardinalidad sin query compuesta real;
- todas las foreign keys “porque sí” si SQLite/query real no lo justifica.

Sí priorizar:

- lookups por claves de negocio;
- joins/foreign keys frecuentes;
- lookup compuesto de coverage;
- fechas cuando existe búsqueda/range real.

## SOP de limpieza por PR

Antes de cerrar:

```text
1. git diff --name-only base...HEAD
2. clasificar cada archivo: REQUIRED / GENERATED REQUIRED / NOISE
3. revertir NOISE
4. buscar referencias antes de borrar
5. ejecutar tests
6. confirmar worktree limpio
```

No ejecutar formateadores globales si cambian archivos fuera del scope del lote.

## Definition of Done de hygiene

Un PR no está limpio si contiene:

- hashes regenerados sin pedido;
- ZIPs;
- screenshots temporales;
- docs duplicadas;
- archivos solo reformateados fuera de scope;
- generated files que no son necesarios en la estrategia del repo;
- dead code conocido.
