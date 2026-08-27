# PicoRadar — Estrategia de tooling para agentes

## Objetivo

Mejorar calidad visual, comprensión del repo y QA sin meter herramientas que no corresponden al stack Flutter.

## Decisión por herramienta

### Graphify — SÍ, PRIORIDAD ALTA

Uso:

- grafo de imports/calls;
- estructura repo;
- impacto de cambios;
- relaciones de DB/código/docs;
- detección de acoplamientos y código huérfano.

Instalación documentada por el proyecto Graphify:

```text
uv tool install graphifyy
graphify install
```

Luego en Codex/agente:

```text
/graphify .
```

Política PicoRadar:

- generar localmente;
- no commit automático de `graphify-out/`;
- convertir hallazgos durables en documentación canónica;
- no usar Graphify como sustituto de tests.

### Figma MCP — SÍ, PRIORIDAD ALTA CUANDO HAYA ARCHIVO FIGMA

Figma ofrece MCP oficial con soporte para Codex/ChatGPT/Claude Code.

Uso PicoRadar:

- leer frames aprobados;
- variables/tokens;
- comparar componentes;
- design-to-code handoff;
- reducir interpretación visual libre por parte del agente.

No bloquea R01: podemos reconstruir el Design System desde los mockups actuales y luego llevarlo a Figma.

### Frontend Design skill — SÍ COMO DISCIPLINA DE DISEÑO, NO COMO STACK WEB

El skill oficial de Anthropic y variantes Codex se enfocan en evitar interfaces genéricas.

Valor para PicoRadar:

- dirección estética fuerte;
- tipografía/jerarquía;
- evitar “AI slop”;
- revisión visual.

Límite:

- muchas instrucciones están pensadas para web/CSS;
- no copiar patrones HTML/CSS a Flutter;
- usarlo para criterio visual, no para cambiar framework.

En este entorno ya existe un skill de frontend visual con workflow de referencia → implementación → comparación. Sus principios se incorporan al `UI_FIDELITY_GATE.md`.

### UI/UX Pro Max — SÍ, EXPERIMENTAL/PINNED

El proyecto declara soporte para Codex mediante `uipro init --ai codex`.

Puede aportar:

- paletas;
- jerarquía;
- patrones mobile;
- checklist UX.

Regla:

- usar versión/commit revisado;
- no permitir que reemplace el Design System PicoRadar;
- PicoRadar baseline siempre prevalece.

### Playwright CLI — SÍ, PERO PARA WEB/ADMIN/PREVIEWS

Playwright CLI oficial de Microsoft está orientado a agentes y browser automation.

Útil para:

- futuro admin Laravel web;
- Figma/web previews;
- una Flutter Web preview si se crea específicamente para review.

NO es el gate principal de UI nativa Android.

Para Flutter Android usar:

- widget tests;
- golden tests;
- integration tests;
- ADB screenshots;
- QA física.

### Framer Motion — NO PARA MOBILE FLUTTER

Framer Motion pertenece al ecosistema React/web.

Instalarlo en PicoRadar móvil sería dependencia sin uso.

Equivalentes Flutter:

- AnimatedContainer;
- AnimatedSwitcher;
- TweenAnimationBuilder;
- AnimationController cuando haga falta.

Motion baseline:

- 150–250 ms;
- funcional, no decorativo;
- reducir movimiento si OS lo pide;
- mínimo movimiento en Conducir.

## Herramientas recomendadas finales

### Obligatorio

- Graphify
- Flutter analyze/test/build
- Drift migration tests
- ADB/device screenshots
- GitHub PR/CI

### Visual recovery

- Figma MCP cuando haya archivo Figma
- Frontend Design principles
- UI/UX Pro Max como segunda opinión, no source of truth
- Flutter goldens para primitives

### Backend web

- Playwright CLI para admin panel y flujos web

### No instalar

- Framer Motion en `mobile/`
- librerías React para resolver UI Flutter
- múltiples skills que hagan exactamente lo mismo sin una función diferenciada.

## Orden de adopción

1. Graphify.
2. UI Fidelity Gate.
3. R01 Design System Flutter.
4. Figma MCP / Figma source of truth si se habilita.
5. UI/UX Pro Max opcional durante review.
6. Playwright al iniciar B04 admin web.

## Seguridad supply-chain

Antes de instalar un skill/repo externo:

- verificar repositorio canónico;
- revisar licencia;
- revisar scripts de instalación;
- evitar ejecutar hooks arbitrarios sin inspección;
- fijar commit/tag cuando sea práctico;
- no dar secretos del proyecto a herramientas no necesarias;
- no subir repo privado a servicios externos si el valor puede obtenerse on-device.
