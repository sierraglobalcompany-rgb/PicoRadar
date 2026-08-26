# Data / Privacy / Security Rules

## Never send to analytics
- plate;
- ID number;
- scanned document content;
- exact GPS;
- route history;
- legal-case text.

## Never send continuously to backend
- GPS samples;
- camera matching state.

## Private documents
- AES-256-GCM;
- master key in secure storage;
- ciphertext in app-private storage;
- plaintext temp deleted;
- no cloud backup by default.

## Server
- no direct DB connection from mobile;
- secrets only server-side;
- rate limits;
- input validation;
- admin 2FA/roles before production;
- audit publishing.

## Legal / business
- official/accredited != sponsored;
- no “guaranteed annulment” wording;
- leads require explicit consent and named partner.
