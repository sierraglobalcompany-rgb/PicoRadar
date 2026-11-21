# PicoRadar — PHP/MariaDB QA aislado con Docker (pendiente ejecución física)

Fecha: 2026-11-21. Código diseñado sobre C8 (SHA base `dfa8ee13d861f24c3213d424d768305a0ea08d60`) en rama separada, sin modificaciones del C8 activo, main, PR #79/#86 ni checkout protegido.

## Propósito y límites

Cuando se ejecutan distintos proyectos y agentes Codex en el mismo Windows, cada QA PHP/MariaDB debe tener su propio proceso, red, base y almacenamiento temporal; nada de usar MySQL/MariaDB/PHP globales, puertos fijos o bases del usuario. El entorno de esta rama sirve **solo para QA sintética**, no es un despliegue, no abre puerto web, no contiene datos productivos ni certificados TLS.

## Archivos y aislamiento aplicado

- `infra/docker/compose.qa.yml`: proyecto Compose **obligatorio y único por invocación**, red `internal`, sin `ports`, sin `container_name`, sin volúmenes persistentes, sin enlaces externos. Servicio MariaDB 11.8 con `tmpfs` temporal para datadir de pruebas y contraseña sintética aleatoria. `db` no publica 3306 en Windows.
- `server/Dockerfile.qa`: PHP 8.3 + PDO SQLite/MariaDB + extensiones de Laravel, dependencias de `composer.lock` copiadas dentro de una imagen sintética. Sin volúmenes que monten el checkout. Compila a partir de una copia **limpia** del proyecto; el host puede usar sus propios PHP/DB sin ser afectado.
- `server/.dockerignore`: excluye `.env`, otras variables sensibles, bases SQLite, `vendor`, `node_modules`, cachés y enlaces de storage del host del contexto de construcción. No mete secretos de otros proyectos.
- `scripts/run_picoradar_docker_qa.ps1`: rechaza checkouts sucios, genera una identidad aleatoria por ejecución, claves sintéticas en TEMP y controla el ciclo **solo de ese proyecto**. Limita el modo de prueba a un filtro; no toca otros contenedores. El `finally` ejecuta `docker compose down` sobre ese identificador, **nunca `down -v` ni `system prune`**.
- `scripts/tests/test_picoradar_docker_isolation.py`: 7 comprobaciones estáticas del contrato de aislamiento.

## Ejecución posterior (NO iniciar mientras Codex C8 esté trabajando)

Trabajar sobre un **clon limpio** y aislado del proyecto (no `D:\codex\PicoRadar` con WIP protegido), dentro de un proceso PowerShell nuevo. Docker Desktop debe estar activo con contenedores Linux.

```powershell
# Desde la raíz del clon limpio de PicoRadar, sin cambiar servicios globales:
pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode schema

# Solo test focal; phpunit.xml selecciona SQLite :memory: para las suites antiguas:
pwsh -NoProfile -File scripts/run_picoradar_docker_qa.ps1 -Mode test -Filter RestrictionMunicipalityMatrixTest
```

`schema` crea MariaDB de prueba en `tmpfs`, espera salud, ejecuta migraciones y muestra el estado. `test` **no levanta MariaDB**; usa los tests existentes de Laravel con SQLite en memoria y exige filtro concreto. No transforma pruebas SQLite en supuestas pruebas MariaDB. Si una prueba exige MariaDB, se debe señalar y crear un test focal con aislamiento, no reusar una base real. No hay autorización para migrar datos del propietario, ni para conectar Hostinger, ni para instalar servicios o modificar `php.ini` global.

No usar `docker compose` directamente sin el wrapper y sus variables. No ejecutar `docker system prune`, `docker volume prune`, `docker compose down -v` ni limpiar volúmenes de otros proyectos. Si Docker falla por cuota o falta de red, entregar **BLOCKED_ENV** con error preciso; no inventar PASS ni volver a migraciones sobre otros procesos.

## Verificación y evidencia

En el entorno de revisión sin Docker ni PowerShell se ejecutaron **7/7 pruebas estáticas Python y parsing de YAML: PASS**. No se ejecutaron imágenes, Composer ni migraciones MariaDB reales. Esta rama no se integra a C8 hasta que se valide en Docker de Windows. El paquete ligero de retorno posterior debe contener comandos ejecutados, exit codes, logs mínimos saneados, SHA/commit; sin APK, dumps SQL, bases de datos ni secretos. El porcentaje funcional sigue sin incrementarse por preparar infraestructura.

## Continuidad

Al terminar C8-V2, ChatGPT director debe leer primero el ZIP nuevo de Codex, hacer comparación diferencial y evaluar incorporar esta rama al siguiente lote sin duplicar el trabajo. Priorizar código funcional de motor/servidor/OTA/Android y no convertir el aislamiento en un nuevo bloqueo de varias rondas.
