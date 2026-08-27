# B00 — Backend Control Plane Foundation

## Goal

Convertir el scaffold Laravel en un control plane mínimo verificable sin crear cuentas móviles ni microservicios.

## Scope IN

- `/api/v1/health` JSON;
- admin operators only;
- role mínimo si se necesita `admin/editor`;
- rate limiting API;
- environment diagnostics sin secrets;
- server tests;
- API version namespace;
- DB config MySQL/MariaDB production-compatible;
- SQLite test path preserved.

## Scope OUT

- mobile login;
- public registration;
- vehicles/users cloud;
- datasets publisher completo;
- Routes API proxy;
- push;
- admin visual complejo.

## KISS DB

No agregar tablas de negocio todavía salvo mínima extensión del user/admin actual si realmente hace falta.

Preferir usar el `users` de Laravel como operadores del control plane en vez de crear otro sistema auth.

## Security

- no secrets in repo;
- no debug data público;
- health no expone DB password/path;
- rate limit;
- HTTPS requirement documented for staging/prod.

## Tests

- health success;
- response schema;
- no secret leak;
- rate limit configured;
- server test suite/pint/migrate.

## Acceptance

El backend deja de ser scaffold, pero sigue siendo pequeño.
