# PicoRadar — integración recuperable N4-R2 + N5/01–04

**Estado:** `INTEGRATED_TREE_REPRODUCED`, **NO release**. Fecha: 19-nov-2026, Colombia. Desarrollador: ChatGPT Director; Codex Luna hará pruebas de ejecución y ajustes causales.

## Artefactos

- `PATCHES/N3R1_TO_N4R2_N504_INTEGRADO.patch`: aplicar solo si el árbol base Git es exactamente `a883b64fffb53d3d9ec263739c169561ddf8b49d` (N3-R1). SHA256: `04b23709133b1b6fb02e6bea7c9b735305d8670c223b8df319602a3862a1b19b`.
- `PATCHES/RC2_TO_N4R2_N504_INTEGRADO.patch`: **alternativa**, aplicar solo si se tiene el commit base RC2 `7e2e1f3f311b18e29f63d3a5e05e9439a11c4289`. SHA256: `1c67468d5555d915137640332b1c203900b76582db5322b4e9ec7628b278d5eb`.
- Los dos parches conducen al **MISMO árbol de contenido** `986a24831aef2bcc6d261be771839f71c1129d40`. **Nunca se aplican ambos.**
- `CODEX_LUNA_PICORADAR_N5R5_INTEGRACION_N4R2_N5_QA_APK_20261119.md`: única instrucción siguiente, también como Markdown descargable independiente.
- `SOURCE_FILES.csv`: lista de rutas incluidas en la fusión, clasificación de procedencia.
- `MANIFEST.csv`: SHA-256, bytes y CRC32 de todos los otros archivos del ZIP.

## Qué quedó comprobado por ChatGPT Director

1. El ZIP N4-R2 original que entregó Codex coincide con el SHA256 `80093d37e862a4a6c8ed50392f9ba2b74a1955fc9860a61262dfd7163201643c`, CRC PASS y manifiesto 8/8.
2. RC2→V4→V5→R2→N3-R1 produjo los árboles respectivos `24408f30…`, `10ab7af9…`, `07f93bac…`, `a883b64f…` con los parches originales. Solo el parche V5 necesitó normalización **de los finales de línea del parche** CRLF→LF en copia temporal.
3. N4 aplicado solo sobre N3-R1 obtuvo exactamente `1e57a8363bdcf9c6bbf453ba21e8e3022edc54b2`. Los N5/01→04 aplicados en cadena sobre N3-R1 obtuvieron `7e8cc4db…` → `f8e13056…` → `8060cc12…` → `46da2c96…`.
4. `git merge --no-commit --no-ff n5` sobre N4 **resolvió automáticamente** el único archivo superpuesto, `server/.env.example`, conservando flags de cuentas y campañas OFF por defecto. El diff N3→integrado contiene **61 rutas, 4.184 inserciones y 35 eliminaciones**. No se detectaron conflictos.
5. Parche combinado desde N3 comprobado con `git apply --cached --check`, aplicado en clon aislado y `git write-tree == 986a24831aef2bcc6d261be771839f71c1129d40`. Parche desde RC2 se comprobó de forma independiente y reprodujo exactamente el mismo árbol; ambos pasaron `git diff --cached --check`.
6. Búsqueda focal de claves privadas, credenciales GitHub y AWS en el diff: cero coincidencias. Los emails encontrados son direcciones sintéticas `example.test` de pruebas, no usuarios reales.

## Qué NO quedó comprobado ni autorizado

- No se ejecutaron PHPUnit ni Flutter sobre el **árbol combinado**. Las 17 pruebas / 189 assertions de N4 se refieren a su árbol anterior. N5/01–04 contienen pruebas escritas pendientes de ejecutar. No se hicieron APK, HTTPS staging ni prueba Android física de esta integración.
- El `FINAL_REPORT.md` de N4 incluyó algunas variables de informe sin interpolar (`$repo`, `$branch`, `$base`, `$finalTree`) y caracteres de control. **No usar esas variables textuales como identidad de código**: la reproducibilidad real se comprobó leyendo el ZIP/parche y recalculando árboles Git.
- La rama pública `main` continúa desfasada, la PR #79 es documental y `HOLD_SECURITY` sigue. No empujar el producto al repo público, no desplegar campañas, cuentas, SMTP ni firmar release sin autorización.
- La APK DEV antigua `1.0.1+2` no contiene N4/N5 y no sirve para certificar este árbol. El motor nacional no tiene por ello cobertura legal de los 1.104 municipios catalogados.

## Ejecución de Codex

Usar **únicamente el Markdown adjunto** y un clon aislado; preservar el checkout N4 con sus 43 entradas WIP. Aplicar exactamente un parche. Ejecutar test focal de los módulos integrados, `flutter analyze`, luego suite global **una sola vez** con fixtures auténticos si están disponibles. Si RAM comprometida disponible es menor a 6 GiB no compilar APK; registrar `BLOCKED_RESOURCE_GATE`. Entregar **UN ZIP** con informe, gates, evidencias, delta final y APK solo si se pudo compilar de forma segura.
