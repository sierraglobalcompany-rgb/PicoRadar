# PicoRadar — Plan de ejecución v2 KISS

## Objetivo

Corregir la desviación visual, activar el backend que realmente hace falta y terminar Free 1.0 sin convertir el proyecto en un sistema innecesariamente complejo.

## Estrategia

Trabajar en tres carriles paralelos con límites claros de archivos para evitar conflictos:

### Carril R — Recovery UI/UX

- R00 — Auditoría forense, hygiene, SOP y tooling.
- R01 — Design System Flutter 2.0.
- R02 — Root surfaces: Inicio, Garaje, Apps, Onboarding.
- R03 — Pico y Placa + Vehicle Status surfaces.
- R04 — Visual regression/physical QA gate.

### Carril B — Backend/control plane

- B00 — Laravel control-plane foundation.
- B01 — Dataset registry + publisher + manifest/CDN.
- B02 — Cameras/road data publication contracts.
- B03 — Routes/Places proxy para Viaje.
- B04 — Admin/publisher UI mínimo.
- B05 — Invalidación urgente/push cuando sea necesaria.
- B06 — Backend hardening/rate limits/observability.

### Carril F — Features de producto

Después de R02/R03:

- C14 Comparendos.
- C15 Billetera/scanner.
- C16 Cámara repository.
- C17 Location.
- C18 Camera matcher.
- C19 Driving alerts/UI.
- C20 Background/HUD.
- C21 Viaje UI.
- C22 Routes backend proxy (si B03 no lo absorbió).
- C23 Viaje enrichment.
- C24 Servicios/CDA.
- C25 Reports/leads.
- C26 Defensa engine.
- C27 Defensa PDF/deadlines.
- C28 Admin/publisher se alinea con B04, sin duplicarlo.
- C29 Hardening Free 1.0.

## Cambio de prioridad

No continuar en modo cinta transportadora `feature → feature → feature` mientras la UI base esté desviada.

C13 puede cerrarse técnicamente. Después:

1. R01/R02 deben ejecutarse antes de añadir más pantallas visibles masivas.
2. B00/B01 pueden avanzar en paralelo porque tocan `server/` y contratos, no las pantallas Flutter.
3. C14 puede retomarse cuando R02 haya congelado los primitives visuales.

## Macro-bloques de trabajo

### Bloque A — Product Surface Recovery

Salida observable:

- app visualmente reconocible respecto a los mockups;
- componentes base reales;
- no Material-default look;
- screenshots Android aprobados.

Incluye R01–R04.

### Bloque B — Control Plane Real

Salida observable:

- admin operator;
- catálogo de datasets;
- fuente/verificación/vigencia;
- publicación versionada;
- manifest generado;
- asset listo para CDN;
- rollback de release.

Incluye B00–B01.

### Bloque C — Driving Core

Salida observable:

- cámaras locales;
- GPS;
- matcher direccional;
- alertas por distancia;
- voz/vibración;
- background;
- HUD;
- radio Android responsive.

Incluye C16–C20.

### Bloque D — Ecosistema Free 1.0

Salida observable:

- Viaje;
- Servicios/CDA;
- Comparendos;
- Billetera;
- Defensa;
- Ajustes/centro de notificaciones;
- iOS adaptation;
- hardening.

## Regla de lote KISS

Cada lote debe responder sí a estas preguntas:

1. ¿Tiene un solo resultado observable?
2. ¿Se puede revertir sin afectar lotes no relacionados?
3. ¿No introduce una abstracción si una función/clase concreta basta?
4. ¿No guarda un dato que puede derivarse?
5. ¿No crea una tabla si un JSON/dataset/versioned asset cumple mejor?
6. ¿No crea un historial que Git/telemetría ya cubre?
7. ¿No agrega una dependencia por comodidad?
8. ¿Tiene tests de comportamiento, no solo getters?

## Presupuesto por lote

Valores objetivo, no dogma:

- dependencia directa nueva: 0, excepcionalmente 1;
- migración DB: 0–1;
- tablas nuevas: 0–1;
- archivos producción nuevos: ideal 2–5;
- interfaces nuevas: 0 salvo frontera plataforma/proveedor real;
- repositorios: uno por agregado persistente, no uno por pantalla;
- managers/services/usecases: 0 salvo necesidad demostrable.

## Gate visual obligatorio

Todo lote que cambie UI debe adjuntar:

- referencia visual aprobada;
- screenshot real dev;
- mismatch ledger;
- estado final `PASS` solo si no quedan diferencias de jerarquía, spacing, geometría, color o tipografía materialmente visibles.

## Gate DB obligatorio

Toda migración:

- preserva datos anteriores;
- tiene test desde schema previo real;
- índice solo con query demostrada;
- evita guardar campos duplicados/derivados.

## Gate backend obligatorio

Todo endpoint nuevo debe justificar por qué no puede ser dataset/CDN/local.

Preferencia:

1. local;
2. CDN/versioned file;
3. API dinámica cacheable;
4. DB request directa al control plane solo cuando realmente es operación dinámica.

## Gate Free 1.0 reforzado

No se publica hasta que:

- root UI aprobada visualmente;
- Pico y Placa real y fail-closed;
- widgets Android + iOS según decisión de producto;
- Garaje/obligaciones completos;
- Comparendos;
- Billetera cifrada;
- Conducir con QA físico;
- Viaje con degradación parcial;
- Servicios básicos;
- Defensa beta;
- backend publisher operativo;
- CI restablecido;
- accesibilidad/offline/permisos/batería validados.
