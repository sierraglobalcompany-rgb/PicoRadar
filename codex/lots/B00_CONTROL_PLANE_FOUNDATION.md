# LOT B00 — Control Plane Foundation

**Branch:** `feat/B00-control-plane-foundation`
**Status:** IMPLEMENTED_PENDING_EXTERNAL_AUDIT

## Goal

Establish the Laravel-only control-plane foundation for Hostinger: safe public health, operator authentication, a minimal admin shell, portable operator metadata, and PHP 8.3–8.5 CI coverage.

## Source of truth

- `docs/baseline/11_Cierre_Global_Baseline_v1_0.docx` §11, §21, §29
- `docs/baseline/12_Arquitectura_Tecnica_Android_First_v1.docx` §15, §31, §46–47
- `contracts/API_CONTRACT_BASELINE.md`
- `codex/lots/C28_ADMIN_PUBLISHER.md` (only the auth/control-plane foundation)

## Scope

- `/api/v1/health`, operator login/logout/dashboard, operator role/activity migration, initial super-admin command, Hostinger instructions, and PHP/SQLite/MariaDB CI.

## Out of scope

- Dataset registry/publisher, audit log, 2FA, sources, cameras, partners, ads, reports, leads, proxy routes, users/accounts, subscriptions, Flutter, and Drift.

## Gate

B01 Dataset Registry + Publisher may begin only after external audit approval of B00. No merge is authorized by this lot.
