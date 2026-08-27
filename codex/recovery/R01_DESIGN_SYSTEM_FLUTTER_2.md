# R01 — Design System Flutter 2.0

## Goal

Corregir la base visual sin cambiar comportamiento de negocio.

## Depends on

- C13 merge recomendado, pero R01 puede prepararse desde main sin tocar DB/domain.

## Scope IN

- tokens completos del baseline;
- card radius 20–24;
- spacing 3XL;
- typography Display/H1/H2/Body/Caption;
- AppHeader;
- AppCard;
- StatusCard;
- VehicleCard visual primitive;
- DocumentExpiryCard;
- AppLauncherTile;
- SourceBadge;
- EmptyState;
- PermissionSheet;
- NavigationBar theme PicoRadar;
- light surface system;
- dedicated dark Driving theme primitive.

## Scope OUT

- cambiar reglas Pico;
- cambiar DB;
- backend;
- reescribir Home/Garage completos;
- ads;
- animation framework.

## KISS

No crear un package interno separado.

Ubicación preferida:

```text
mobile/lib/core/design_system/
```

Solo primitives que se reutilizarán realmente.

No wrappers de cada widget Flutter.

## Visual contract

Usar `docs/design/UI_FIDELITY_GATE.md`.

## Acceptance

- ningún token contradice baseline;
- primitives tienen variantes necesarias;
- no hardcode duplicate status colors en features nuevas;
- text scale 1.0/1.5/2.0;
- targets >=48dp;
- semantics básicos;
- golden/reference screenshots de primitives o showcase mínimo de test;
- no comportamiento de features modificado.

## Tests

- widget tests de variants;
- text scaling;
- theme colors/radius;
- dark driving surface;
- flutter analyze/test/APK.

## Stop

Si una primitive solo se usa una vez y no reduce duplicación, dejarla en la feature.
