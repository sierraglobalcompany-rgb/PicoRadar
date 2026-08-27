# PicoRadar — SOP de desarrollo con agentes

## Objetivo

Evitar deriva de producto, UI genérica, sobrearquitectura y ruido de repo cuando trabajan ChatGPT/Codex/agentes en paralelo.

## 1. Preflight obligatorio

Antes de modificar código:

1. leer `AGENTS.md`;
2. leer Cierre Global vigente;
3. leer flujo funcional del área;
4. leer referencia visual aprobada;
5. leer lote/objetivo actual;
6. consultar Graphify si el cambio cruza más de una feature o tabla;
7. identificar archivos que NO deben tocarse.

Salida del preflight:

```text
Goal
Source docs
Files expected
Files forbidden
Schema impact
Dependency impact
Physical QA needed?
Visual reference
```

## 2. Clasificar el trabajo

### DATA/DOMAIN

Prioridad:

- pure Dart;
- tests unitarios;
- fail closed;
- sin BuildContext.

### DB

Requiere:

- necesidad de dato persistente;
- migration;
- test desde schema anterior;
- query/index justification.

### UI

Requiere:

- mockup/reference antes de programar;
- primitives existentes;
- screenshot real;
- mismatch ledger.

### PLATFORM

Requiere:

- Android/iOS contract claro;
- prueba física cuando GPS/cámara/background/HUD/biometría lo exijan.

### BACKEND

Primera pregunta:

> ¿Por qué esto no puede ser local o dataset/CDN?

Si no hay respuesta sólida, no crear endpoint.

## 3. KISS construction rule

Orden de preferencia:

1. función privada;
2. clase concreta pequeña;
3. provider simple;
4. repository concreto si hay persistencia real;
5. interface solo si existe una frontera proveedor/plataforma intercambiable real.

Evitar cadenas tipo:

`Widget → Controller → UseCase → Service → Repository → DAO`

si una app local puede resolver:

`Widget/Provider → Repository/Store → Drift`.

## 4. Regla de datos

No persistir si puede derivarse de forma barata y determinística.

No guardar:

- estado `valid/expired` si se deriva de dueDate;
- labels de UI;
- duplicados de enums;
- snapshots diarios innecesarios;
- historial GPS;
- logs de navegación del usuario;
- versiones que Git ya conserva.

## 5. Regla de UI

Está prohibido cerrar una pantalla visual con solo tests funcionales.

Proceso:

```text
REFERENCE
→ EXTRACT TOKENS/LAYOUT
→ IMPLEMENT
→ RENDER
→ COMPARE
→ FIX
→ PASS
```

Defectos como radius, padding, tipografía y jerarquía son defectos funcionales de UX, no “polish opcional”.

## 6. Regla de diseño

No aceptar Material defaults como diseño final.

Las features consumen Design System; no inventan localmente:

- radius;
- spacing;
- status colors;
- typography roles;
- card anatomy;
- common empty/error/loading states.

## 7. Regla de dependencias

Antes de añadir package:

- problema exacto;
- alternativa Flutter/Dart estándar;
- soporte Android/iOS;
- mantenimiento;
- licencia;
- impacto build size;
- tests.

Máximo ideal: 0 dependencias nuevas por lote.

## 8. Regla de schema

Por migration:

- additive preferida;
- no destructive migration;
- no tabla nueva si JSON local/versionado basta;
- test de preservación de datos;
- un índice necesita query real.

## 9. Regla de errores

- stale/unknown nunca se convierte en success;
- fuente no verificada nunca produce afirmación positiva;
- network failure no borra cache local;
- error parcial no derriba toda superficie si hay información útil restante.

## 10. Regla de side effects

No iniciar repetidamente desde `build()`:

- notificaciones;
- writes DB;
- widget updates;
- sync network;
- permission prompts.

Centralizar solo cuando sea una coordinación real, sin crear Manager genérico.

## 11. Regla de repo

Cada archivo cambiado se clasifica antes del commit:

- REQUIRED
- GENERATED_REQUIRED
- NOISE

NOISE se revierte.

Prohibido sin solicitud explícita:

- ZIP;
- hashes globales;
- screenshots temporales;
- format global fuera del scope;
- backup files;
- docs duplicadas.

## 12. Visual QA SOP

Para cada superficie clave:

- screenshot reference;
- screenshot current;
- comparar geometry;
- typography;
- spacing;
- hierarchy;
- color;
- responsive;
- state feedback.

No cerrar hasta agencia-signoff razonable.

## 13. Physical QA SOP

Obligatorio para:

- GPS;
- heading;
- background location;
- camera/scanner;
- TTS/Bluetooth;
- HUD;
- battery;
- biometrics;
- OS notification behavior cuando dependa de versión.

Guardar solo evidencia útil vigente; no convertir el repo en galería histórica.

## 14. PR SOP

Antes de abrir PR:

```text
flutter analyze
flutter test
flutter build apk --debug --flavor dev
git diff --check
```

Más gates específicos.

Después:

1. diff de filenames;
2. eliminar ruido;
3. verificar scope;
4. verificar TODO/FIXME;
5. verificar secrets/PII;
6. verificar visual evidence si UI;
7. worktree limpio.

## 15. Merge SOP

No merge automático.

Revisor debe poder responder:

- ¿cumple producto?
- ¿cumple visual?
- ¿cumple KISS?
- ¿preserva datos?
- ¿introduce deuda innecesaria?
- ¿puede simplificarse eliminando algo?

Solo después autorización humana explícita.

## 16. Paralelismo SOP

Dos agentes pueden trabajar en paralelo si:

- no editan el mismo core;
- sus migrations no compiten;
- una rama no depende de código no mergeado de otra;
- contracts compartidos están congelados.

Ejemplo seguro actual:

- Codex: C13/C14 mobile;
- paralelo: B00/B01 server;
- paralelo: R00 docs/audit;

Ejemplo inseguro:

- dos agentes refactorizando `app_providers.dart` o `AppDatabase` a la vez.

## 17. Stop condition

Detener si para “terminar rápido” hay que:

- inventar fuente;
- falsificar estado;
- saltar policy OS;
- duplicar motor;
- guardar PII innecesaria;
- crear microservicio sin necesidad;
- ignorar referencia visual aprobada.
