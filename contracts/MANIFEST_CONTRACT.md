# Manifest Contract v1

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-26T15:00:00Z",
  "minAppVersion": "1.0.0",
  "datasets": {
    "restrictions": {
      "version": 42,
      "url": "/v1/restrictions/restrictions-42.json.gz",
      "sha256": "<64 hex>",
      "contentEncoding": "gzip",
      "expiresAt": "2026-09-10T00:00:00Z"
    },
    "cameras_antioquia": {
      "version": 18,
      "url": "/v1/cameras/antioquia-18.json.gz",
      "sha256": "<64 hex>"
    }
  },
  "features": {
    "defense": true,
    "services": true,
    "ads": false,
    "cloud": false,
    "paidDocuments": false
  }
}
```

## Rules

- `schemaVersion` incompatible: do not replace current valid local dataset.
- Versioned files are immutable.
- Validate SHA-256 before import.
- Import in a Drift transaction.
- Update `dataset_versions` only after successful commit.
- Unknown compatible fields are ignored.
- `ads`, `cloud`, `paidDocuments` remain false in Free 1.0.
