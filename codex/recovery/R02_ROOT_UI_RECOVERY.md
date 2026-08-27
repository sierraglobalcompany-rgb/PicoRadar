# R02 — Root UI Recovery

## Goal

Hacer que las superficies raíz visibles se parezcan al baseline aprobado sin tocar motores ni persistencia.

## Source

- `docs/design/UI_FIDELITY_GATE.md`
- Wireframes + Design System v1
- Screen Map H/V/A/G
- R01 primitives

## Scope IN

- Home;
- Garaje;
- Apps;
- onboarding/alta vehículo;
- shell header/bottom nav únicamente si R01 lo requiere.

## Home target

Jerarquía obligatoria:

1. ciudad/contexto;
2. vehicle summary;
3. status circulación dominante;
4. mañana/próxima restricción;
5. SOAT + RTM / obligación próxima;
6. accesos Comparendos/CDA donde corresponda;
7. CTA dominante Iniciar conducción;
8. ad slot colapsado/inexistente;
9. bottom nav.

No presentar todas las cards con el mismo peso.

## Garage target

Cada vehículo comunica sin abrir detalle:

- visual genérico;
- tipo/apodo;
- placa;
- circulación;
- SOAT;
- RTM;
- impuestos;
- active indicator.

Después servicios rápidos + CTA Agregar.

## Apps target

- 3 columnas;
- active vehicle compact;
- 9 primarios congelados;
- secundarios claramente separados;
- misma anatomía de tile;
- badges funcionales solamente.

## Onboarding target

- pantallas/steps visualmente limpios;
- elección Carro particular/Moto/Taxi;
- un CTA dominante;
- inputs usando design system;
- draft actual preservado;
- no pedir permisos prematuros.

## Scope OUT

- reglas nuevas;
- schema;
- backend;
- C14+;
- ilustraciones finales si no existen assets aprobados.

## Required evidence

Por root surface:

- referencia;
- screenshot implementación;
- mismatch ledger;
- mobile portrait;
- horizontal al menos smoke;
- textScale 1.5.

## Acceptance

No cerrar si aún se percibe como Material default genérico o si jerarquía/geometría difiere materialmente de la referencia.
