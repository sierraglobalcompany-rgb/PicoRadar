# LOT B02 — Geography + Jurisdictions

B02 establishes canonical Colombia political-administrative identity in the Laravel Control Plane from the versioned DANE DIVIPOLA / MGN 2025 fixture. It creates only `geographic_units`, `jurisdictions`, and `jurisdiction_geographic_unit`.

The importer is local, transactional, idempotent, and has no runtime network dependency. It bootstraps `co`, departments, municipalities, PicoRadar jurisdictions, coverage, and append-only audit summaries. It fails closed on invalid hierarchy, duplicate codes, structural contradictions, unresolved catalog records, or invalid source-specific RUNT aliases.

This lot deliberately excludes geometries, GPS boundaries, Flutter changes, datasets/manifests, cameras, camera imports, routes, and B03 work.
