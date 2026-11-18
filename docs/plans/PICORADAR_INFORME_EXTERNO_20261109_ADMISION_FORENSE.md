# PicoRadar — admisión documental del informe externo v3.0 (2026-11-09)
**Estado: STAGING_ONLY; 0 reglas nuevas aprobadas, 0 activaciones, 0 archivos de código modificados.**
## Evidencia recibida
Informe externo suministrado por el propietario el 9-nov-2026, sha256 original: `19e4e13a581941dd197f419fe79242211cd3d56adf2fdf1ef8bcb8dff2f78d02`. Se preserva textualmente en `docs/data/external-research/EXTERNAL_PICO_20261109_UNVERIFIED.txt`, sin convertir afirmaciones de otra IA en autoridad jurídica.
## Alcance transformado en datos revisables
- 65 **filas** del catálogo externo (incluye dos filas de corredores/grupos, no equivalentes a 65 municipios únicos verificados).
- 31 **filas** de medidas de la tabla principal, sin aprobación.
- 22 grupos de regímenes en YAML originalmente, útiles como índice de hipótesis, nunca pipeline productivo.
- CSV municipales y reglas conservan todas las columnas originales, añaden procedencia y marcan `runtime_eligible=false` / `publish_allowed=false`.
- El original proclama investigación de 1.103 municipios, pero no adjunta actas/consultas de todos; NO es M1.3 DONE.
## Errores críticos con respaldo
1. **Bogotá:** invierte pares/impares. SDM confirma días **pares** restringe 1–5, **impares** 6–0. La sentencia contraria aparece en tabla, ficha y YAML.
2. **Cartagena:** no separa temporada especial 11-dic-2026→22-ene-2027 prevista por el comunicado oficial; DATT además rectificó la supuesta temporada 24 horas de mitad de año en junio. No inferir reglas por anuncios no reconciliados.
3. **Soledad:** conserva prohibición general de motos del día 30, reportada como derogada por Decreto 00021/2024. Falta recuperar original oficial para cerrar.
4. **Quibdó:** conflicto con calendarios atribuidos al Decreto 0245/2026; no se resolvió por fuente primaria.
5. **Cali:** la afirmación universal «solo hay sábado en Bucaramanga/PNN» ignora medida especial sabatina en polígono temporal.
6. **Agrupaciones:** los renglones 64 y 65 del catálogo son varios municipios de Cundinamarca; los 20 del Decreto 000362 solo describen vías bajo competencia departamental y no toda la superficie de los pueblos.
## Coincidencias parciales oficiales verificadas
- Medellín: dígitos de 2026-II y 05-20; requiere ámbito y excepciones por municipio.
- Bucaramanga: Q4 2026 y sábado; revisar municipios del área.
- Manizales: noviembre 3–30; vence en el mes.
- Barranquilla: derogatoria de taxi mediante Decreto 0450/2025, exclusivamente la clase/lugar.
- Pereira: esquema habitual restaurado 28-sep-2026 después del sismo.
En `EXTERNAL_PICO_CONTRASTES_20261109.csv` constan URLs exactas, estatus y severidad. No se adjuntaron bytes oficiales de HTML/PDF a este commit; `OFFICIAL_PARTIAL_MATCH` **no** equivale a regla validada.
## Juicio adversarial
**Verdugo (10):** V1 universo no demostrado; V2 sin snapshots por afirmación; V3 Bogotá invertido; V4 Cartagena temporada omitida; V5 Soledad derogado; V6 Quibdó sin acto; V7 sábados falsos por caso Cali; V8 polígonos y corredores; V9 categorías mezcladas; V10 riesgo de ingesta YAML automática.
**Juez (10):** J1 conservar fuente sin editar; J2 no activar; J3 fuente primaria por dato; J4 separar regímenes temporales; J5 no-medida ≠ ausencia de búsqueda; J6 no arbitrar conflictos con prensa; J7 mapear DIVIPOLA por autoridad; J8 reutilizar compilador/Laravel/Flutter; J9 respetar Codex M3-X01 activo; J10 un único lote M1 por deltas al terminar M3.
## Handoff sin ping-pong
**Codex sigue ocupado con `PICORADAR-M3-X01-LARAVEL-MANIFEST-FLUTTER-CONTRACT-20261109-DIRECTOR` (V2.1). NO enviarlo a recalcular M1 ni cambiarle prompt ahora.** Después de su ZIP, director reconciliará cada nueva afirmación de fuente oficial y el contrato del motor (zonas/nocturnos/festivos/taxi) mediante el pipeline actual. No publicar JSON ni reactivar TTL. Esta es incorporación **documental y estructural**, no integración al runtime.
