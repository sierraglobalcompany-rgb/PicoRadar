# C24 V2 — cierre Android, Vite y HTTP

## Status
`PARTIAL`

## Git
- Base/HEAD_CODE: `6802ceaa9abcc7a51c15fb348109456c73f206b1`.
- Branch: `codex/c24-integrator`; worktree integrador C24.
- Destino autorizado: `feat/platform-integral-national-20261122`.
- `HEAD_FINAL`: ejecutar `git rev-parse HEAD`; SHA remoto final y `main` constan en `GITHUB_STATE.md` del ZIP.

## Resultado
- No se encontró defecto funcional reproducible ni se cambió código de producto.
- A `BLOCKED_OS_SYMLINK`: Flutter 3.50.0/Dart 3.14.0, Java 21 y Android SDK disponibles; Windows denegó crear symlink en la copia aislada antes de `pub get`. Sin APK, ADB ni AVD. Lock intacto, SHA-256 `9D68CE85ABA7E40C4E484D34B0F449E3BFFB98BE3D9F0118B7775ECC1E5F4834`; el checksum esperado del prompt tenía un carácter omitido.
- B `VITE_BUILD_PASS / WEB_ASSETS_PASS / VISUAL_NOT_RUN`: `npm ci` exit 0; Vite 7.3.6 compiló; manifest, CSS y JS reales se sirvieron por HTTP con status/MIME/hashes correctos. Lock intacto. npm informó 5 advisories (3 high, 2 critical); no se intentó corregir dependencias.
- C `LOGIN_BLOCKED_PHP_SAPI_SQLITE / ACL_NOT_RUN`: SQLite sintética migrada y usuarios sintéticos creados. Login GET 200 con tags Vite, nacional anónimo 302 y catálogo 404. Los dos POST login devolvieron 500 por `PDOException: could not find driver`: `artisan serve` lanzó un worker sin la extensión SQLite cargada explícitamente para CLI. No hay evidencia de fallo de auth/ACL de producto. Stop rule alcanzada; no más POST. Ninguna acción mutante de negocio.

## Archivos y pruebas
- Cambios versionados: solo `docs/CURRENT.md` y este handoff.
- `npm ci`; `npm run build`; GET HTTP del manifest/CSS/JS; migraciones Laravel sobre SQLite efímera; GET `/login`, nacional anónimo y catálogo; dos POST login sintéticos bloqueados por entorno PHP.
- No se repitieron suites C13–C23. `server/package-lock.json`, `server/composer.lock`, `mobile/pubspec.lock` y fuentes permanecen sin cambios.

## QA / seguridad / datos
- Sin APK, ADB, Mi A3, AVD, publicación, Hostinger, release o cambio legal.
- DB, sesiones, vistas compiladas, logs de excepción y copia `public/build` de C se retiraron tras conservar evidencia sanitizada. Sin cookies, contraseñas ni SQLite en el ZIP.
- WIP preexistente del checkout original, C22 y la rama local C13 permanece intacto.

## Siguiente
- Resolver en un runtime PHP hijo aislado que cargue `pdo_sqlite` desde el arranque y completar una sola ejecución focal de cookies/CSRF/ACL; habilitar en Windows symlinks de forma aprobada o usar entorno legítimo ya disponible antes de retomar el gate Flutter. `LEGAL=NO_GO`, `RELEASE=NO_GO`, `MAIN_BRIDGE=HOLD`, `NEXT=CHATGPT_DIRECTOR`.
