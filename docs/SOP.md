# PicoRadar SOP

## SOP-01 Change/Delete Gate

Antes de borrar, fusionar o mover archivos:
1. confirmar alcance del lote;
2. buscar consumidores con `rg --fixed-strings` del path/nombre exacto;
3. revisar Graphify para dependencias estructurales cuando aplique;
4. revisar `git log -- <path>` para trazabilidad;
5. verificar que el contenido normativo unico este en fuente canonica;
6. aplicar el cambio minimo;
7. ejecutar `git diff --check`;
8. correr gates mobile/server relevantes;
9. restaurar el archivo si se rompe capacidad runtime, CI o build.

No crear carpetas de archivo. Git conserva el historial.

## SOP-02 Design To Flutter

Proceso obligatorio para R01+:
1. localizar mockup/ref baseline;
2. leer `docs/DESIGN_CONTRACT.md`;
3. buscar shared component existente;
4. implementar la pantalla o componente;
5. ejecutar widget tests;
6. renderizar viewport 390x844 como minimo;
7. cubrir 360x800, 412x915, textScale 1.0/1.5/2.0 y landscape cuando aplique;
8. ejecutar al menos un smoke visual de superficie raiz en Android fisico cuando haya Mi A3 o dispositivo equivalente disponible;
9. registrar expected/actual/severity/fix;
10. iterar hasta declarar `VISUAL_FIDELITY=PASS`.

No aceptar UI con Critical/High mismatches, overflow, clipping, labels ilegibles/truncados/cortados, estado solo por color, controles sin semantics o espaciado que contradiga el baseline.

## SOP-03 Drift And Local Data

- Drift es la fuente central de queries persistentes.
- Vehiculos, preferencias, documentos y datasets son local-first.
- No crear historiales de GPS, viajes, documentos cloud o notificaciones por defecto.
- Toda migracion requiere version bump, path de migracion, test y evaluacion de riesgo sobre datos existentes.
- FK y constraints se prueban cuando protegen integridad.
- `dataset_versions` representa estado actual aplicado, no bitacora historica.

## SOP-04 Dataset Publisher

Cuando el publisher/control plane sea aprobado debe:
1. validar dataset y contrato;
2. producir manifest inmutable con version, origen, hash y metadata;
3. publicar artefactos estaticos/CDN;
4. permitir rollback seguro a version previa;
5. fallar cerrado si hash, origen o contrato no coinciden;
6. mantener backend fuera del hot path de GPS/camara.

No construir API diaria de "puede circular hoy" para la app Free 1.0.

## SOP-05 Export Integrity

- Git commit, PR y GitHub Actions son la autoridad canonica del codigo.
- ZIPs y manifests SHA de repo no son requeridos rutinariamente por lote.
- Cuando se solicite explicitamente un recovery/export ZIP, los hashes deben representar los bytes finales empaquetados.
- Generar manifests despues del contenido final, excluyendo archivos autorreferenciales cuando haga falta.
- Verificar 0 mismatch, 0 missing y 0 extra antes de entregar.

## SOP-06 Visual QA And Release Gate

Antes de PR visual o release:
- correr tests locales requeridos;
- capturar screenshots/goldens canonicos en 360x800, 390x844 y 412x915 cuando aplique a superficies raiz;
- comprobar no overflow en dispositivos pequenos;
- comprobar accesibilidad basica y textScale 1.0, 1.5 y 2.0;
- ejecutar al menos un smoke visual de superficie raiz en Android fisico cuando haya Mi A3 o dispositivo equivalente disponible;
- probar fisicamente cuando el lote toque camara, GPS, notificaciones OS, foreground/background, TTS/Bluetooth, HUD/brillo, bateria o lifecycle;
- verificar CI si GitHub Actions esta disponible.

Si GitHub Actions queda bloqueado por billing, reportar `CI_INFRA_BLOCKED_GITHUB_BILLING` sin editar workflows para evadirlo.
