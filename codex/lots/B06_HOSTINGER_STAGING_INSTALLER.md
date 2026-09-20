# B06 - Hostinger Staging Installer

## Objective

Create a one-time, browser-guided installer for PicoRadar's private Laravel staging environment on Hostinger without SSH or Composer on the target host.

## Frozen base

- Base commit: `e6406f2f7841d49ef2653f83b728c2cdfe68274f`
- Branch: `feat/B06-hostinger-staging-installer`
- Public URL: `https://picoradar.bodegadigitalmedellin.com`
- Public root: `/home/u390570745/domains/bodegadigitalmedellin.com/public_html/picoradar`
- Private root: `/home/u390570745/domains/bodegadigitalmedellin.com/picoradar_app/current`

## Constraints

- PHP 8.3 through 8.5 and an empty MySQL/MariaDB database.
- Prebuilt package with production dependencies and compiled assets.
- No SSH, deploy, push, merge, mobile changes, registration, monetization, WhatsApp, OSRM, or real data.
- Installer is for first use only and permanently locks after completion.
- Laravel, `.env`, storage, logs, and dependencies stay outside `public_html`.

## Acceptance

- Local clean-room installation from the final ZIP.
- Package manifest and SHA-256 verification.
- One initial active `super_admin` created through shared domain logic.
- Secure configuration, migrations, public links, caches, health, login, cron lock, and irreversible installer lock verified.
- Exact manual Hostinger instructions and separate installation token delivered.
