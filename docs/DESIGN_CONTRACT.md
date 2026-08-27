# PicoRadar Design Contract

Este contrato traduce el baseline visual a reglas operables para Flutter. Autoridad: `docs/baseline/02_Wireframes_Design_System_v1.docx` y flujos 01-08, subordinados a seguridad, privacidad, store, Cierre Global y Arquitectura Tecnica.

## Tokens

- Color primario: navy `#17324D`.
- Acento funcional: teal `#0B7A75`.
- Accion/enlace: blue `#2F6FED`.
- Exito: green `#1B8A5A`.
- Alerta: orange `#D97706`.
- Riesgo: red `#C2413B`.
- Background/surface: off-white/white con bordes suaves.
- Radio de cards principales: 20-24 dp.
- Botones/chips: radio tipo pill solo cuando el componente lo requiere.
- Spacing base: 4/8/12/16/24/32, aplicado con jerarquia consistente.
- Tipografia: jerarquia sobria, no Material-default generico; textos compactos en cards y paneles.

## Componentes compartidos esperados

- `AppBottomNav` para la barra inferior exacta.
- Cards base de estado/vehiculo/modulo.
- Botones primarios/secundarios/terciarios coherentes.
- Chips de vehiculo, ciudad, estado y cobertura.
- Skeleton loaders para cargas de pantalla o tarjetas.
- Empty/error states con copy especifico y accion clara.

No duplicar widgets privados equivalentes entre Inicio, Garaje, Apps y Pico si pueden ser shared components.

## Contratos por raiz

Navigation:
- Tabs exactas: Inicio, Garaje, Apps, Viaje, Conducir.
- Apps siempre al centro.
- Estados activo/inactivo accesibles por texto, semantica e iconografia, no solo color.

Inicio/Pico:
- Debe hacer evidente si el usuario puede conducir hoy.
- Debe incluir CTA dominante "Iniciar conduccion" cuando el contexto lo permita.
- "Cambiar vehiculo" debe resolver el flujo H-005/selector rapido, no saltar al Garaje completo.
- Pico Detail debe ser util con ciudad/vehiculo configurados y tener estado claro cuando falten datos.

Garaje:
- Vehiculo activo visible y facil de cambiar.
- Obligaciones/estado integral deben usar componentes compartidos y jerarquia escaneable.

Apps:
- Grid 3x3 sin overflow en dispositivos pequenos.
- Los modulos premium/off deben diferenciar disponibilidad sin parecer errores.
- No usar texto que se corte dentro de tiles.

Loading:
- Usar skeletons para cargas visibles de pantalla/tarjeta.
- Reservar spinners para acciones cortas o estados inevitables de sistema.

Accesibilidad:
- Objetivos tactiles de al menos 44x44.
- Soporte `TextScaler`/textScale 1.0, 1.5 y 2.0 sin overflow.
- Contraste suficiente y estado no dependiente solo de color.
- Semantics labels en controles iconicos y estados importantes.

## Gate visual R01+

Cada cambio visual debe:
1. localizar mockup/ref baseline;
2. leer este contrato;
3. buscar componente compartido antes de crear uno nuevo;
4. implementar la pantalla/componente;
5. ejecutar widget tests;
6. renderizar viewports 360x800, 390x844 y 412x915;
7. probar textScale 1.0, 1.5 y 2.0;
8. probar landscape cuando aplique;
9. registrar mismatch ledger;
10. iterar hasta `VISUAL_FIDELITY=PASS`.

No se requieren cientos de goldens. El set canonico debe cubrir raiz, densidad, estado semantico y overflow.

## Mismatch ledger R00

| Finding | Esperado | Actual | Severidad | Impacto | Fix phase |
|---|---|---|---|---|---|
| Card radius | 20-24 dp | `AppRadius.card = 8.0` en `mobile/lib/app/theme/app_tokens.dart` | High | La UI se siente Material/default y no baseline | R01 |
| Theme incompleto | Component families propios | `ThemeData` minimo en `mobile/lib/app/theme/app_theme.dart` | High | Inconsistencia visual entre pantallas | R01 |
| Bottom nav | `AppBottomNav` compartido | Stock `NavigationBar` en `mobile/lib/app/shell/app_shell.dart` | Medium | Navegacion funcional pero no fiel | R01/R02 |
| CTA Inicio | "Iniciar conduccion" dominante | Inicio prioriza detalle/cambiar ciudad | High | El trabajo primario queda oculto | R02 |
| Cambiar vehiculo | Selector rapido H-005 | `context.go(AppRoute.garage.path)` | Medium | Flujo mas lento y pierde contexto | R02 |
| Loading | Skeletons estables | `CircularProgressIndicator` repetido | Medium | Sensacion generica y saltos visuales | R01/R02 |
| Componentes | Shared cards/chips/tiles | Widgets privados `_StatusCard`, `_VehicleCard`, `_ModuleTile`, etc. | Medium | Duplica decisiones visuales | R01 |
| Apps grid | Sin overflow | Mi A3 fisico muestra `BOTTOM OVERFLOWED BY 14 PIXELS` | Critical | UI rota en dispositivo real | R02 |
