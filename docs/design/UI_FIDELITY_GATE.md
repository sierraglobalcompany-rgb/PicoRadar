# PicoRadar — UI Fidelity Gate

## Propósito

Evitar que una pantalla sea declarada DONE solo porque compila y funciona cuando visualmente se aleja del baseline aprobado.

## Fuente visual de verdad

Precedencia visual:

1. Cierre Global vigente.
2. Flujo funcional específico.
3. Wireframes + Design System aprobado.
4. Screen Map.
5. Plan Maestro.

Si existe un mockup posterior aprobado explícitamente para una pantalla, ese mockup se convierte en referencia visual de esa superficie sin alterar reglas de producto superiores.

## Defectos base ya detectados

Antes de diseñar más pantallas corregir:

- card radius actual 8 px → baseline 20–24 px;
- falta escala `3XL = 48`;
- falta tipografía completa Display/H1/H2/Body/Caption;
- falta capa real de componentes visuales reutilizables;
- exceso de Material widgets sin tratamiento propio;
- ausencia de skeletons donde el baseline pide evitar spinner global;
- Home no reproduce todavía la composición prioritaria del mockup;
- Garaje y módulos status se sienten funcionales pero no diseñados como el sistema aprobado.

## Tokens obligatorios

### Colores

- Navy `#17324D`
- Teal `#0B7A75`
- Blue `#2F6FED`
- Green `#1B8A5A`
- Orange `#D97706`
- Red `#C2413B`
- Surface `#FFFFFF`
- Background `#F6F8FA`
- Border `#D9E2EA`

### Spacing

- XS 4
- S 8
- M 12
- L 16
- XL 24
- 2XL 32
- 3XL 48

No offsets arbitrarios salvo razón documentada.

### Radius

- Card 20–24
- Primary button 20–24
- Chip 999
- Sheet/modal 24–28
- Input 16–20

### Typography

- Display 32–40 / 700
- H1 24–28 / 700
- H2 18–22 / 600–700
- Body 15–17 / 400
- Caption 12–14 / 400–600

## Primitives Flutter obligatorios

Crear solo los que realmente se repiten:

- `AppHeader`
- `AppCard`
- `StatusCard`
- `VehicleCard`
- `DocumentExpiryCard`
- `AppLauncherTile`
- `SourceBadge`
- `EmptyState`
- `PermissionSheet`

`AppBottomNav` puede envolver/estilizar NavigationBar existente sin reescribir navegación.

Regla: después de R01, una feature no debe redefinir card geometry, status colors o title styles localmente salvo una variante explícita.

## Home — contrato visual

Debe conservar esta jerarquía:

1. Header `Inicio` / contexto ciudad.
2. Vehículo activo compacto.
3. Estado principal de circulación dominante.
4. Próxima restricción / mañana.
5. SOAT + RTM / obligación próxima.
6. Accesos rápidos relevantes.
7. CTA dominante `Iniciar conducción`.
8. Ad slot futuro colapsado/ausente cuando monetización OFF.
9. Bottom nav.

No convertir Home en una lista larga de cards equivalentes.

## Garaje — contrato visual

Cada VehicleCard debe expresar en una sola lectura:

- representación genérica;
- tipo/apodo;
- placa;
- circulación;
- SOAT;
- RTM;
- impuestos;
- estado activo.

Después:

- Servicios rápidos;
- CTA Agregar vehículo.

No obligar a entrar al detalle solo para conocer el estado básico.

## Apps — contrato visual

- 3 columnas en teléfono.
- jerarquía visual uniforme.
- badges solo por pendiente/alerta.
- orden congelado por producto.
- active vehicle context compacto.
- secundarios separados visualmente de los 9 primarios.

## Conducir — contrato visual

Única raíz con fondo oscuro dedicado.

Prioridad visual:

1. velocidad;
2. límite verificado;
3. cámara/distancia;
4. alerta contextual;
5. voz/HUD/finalizar.

Cero publicidad y mínima interacción.

## Estados transversales

- Loading: skeleton local; spinner solo acción corta.
- Offline: banner discreto + fecha de actualización.
- Stale: warning, nunca estado positivo.
- Unknown: `Por verificar/No podemos confirmar`.
- Error API: mensaje humano, conservar dato local.
- Sin vehículo: empty state + CTA.
- Permiso denegado: explicar degradación y permitir continuar.

## Flujo visual obligatorio por PR

### Paso 1 — Reference

Guardar/identificar referencia exacta del estado que se implementará.

### Paso 2 — Design extraction

Antes de código, extraer:

- jerarquía;
- medidas principales;
- padding;
- radios;
- colores;
- tipografía;
- componentes;
- estados responsive.

### Paso 3 — Implementation

Usar primitives del Design System; no re-crear estilos locales.

### Paso 4 — Render evidence

Android físico o emulador válido según lote:

- screenshot 390×aprox.844;
- screenshot horizontal si aplica;
- text scale relevante si aplica.

### Paso 5 — Mismatch ledger

Tabla mínima:

| Elemento | Referencia | Implementación | Estado |
|---|---|---|---|
| Header | ... | ... | PASS/FIX |
| Card geometry | ... | ... | PASS/FIX |
| Typography | ... | ... | PASS/FIX |
| Spacing | ... | ... | PASS/FIX |
| Color | ... | ... | PASS/FIX |
| Hierarchy | ... | ... | PASS/FIX |

### Paso 6 — DONE

No cerrar mientras haya `FIX` visual material.

## Herramientas

Para Flutter nativo priorizar:

- Flutter widget/golden tests para primitives estables;
- `integration_test` donde aporte;
- ADB screenshots para Android real;
- comparación visual humana/agente contra mockup;
- Figma MCP cuando el diseño esté en Figma.

Playwright es útil para panel admin web o una preview Flutter Web, pero NO sustituye QA nativa Android/iOS.

Framer Motion NO forma parte del stack Flutter. Para movimiento usar animaciones Flutter y respetar 150–250 ms del baseline; no añadir React/Framer al proyecto móvil.
