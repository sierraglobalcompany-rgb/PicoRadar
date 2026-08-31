# B02 Geography + Jurisdictions

B02 adds Colombia-first canonical geography to the Laravel Control Plane. The authority is DANE DIVIPOLA / Marco Geoestadístico Nacional (MGN) 2025. The server fixture contains departments plus municipalities (including the official San Andrés island unit needed by the existing RUNT catalog), but no geometry, polygons, GeoJSON, WKT, centres, or runtime DANE network dependency.

`geographic_units` represents the immutable hierarchy `country → department → municipality`; identity is the string DIVIPOLA code. `jurisdictions` represent PicoRadar operational territories, and `jurisdiction_geographic_unit` records coverage. A primary geographic unit is mandatory and always belongs to its jurisdiction coverage.

The importer is `php artisan picoradar:geography:bootstrap`; `--dry-run` validates every fixture and reports counts without mutating the database. Re-runs are idempotent and fail closed on structural contradictions. Geography is view-only in admin; only jurisdictions have controlled editor/admin mutations. Commercial operators have no B02 access; reviewers are read-only.

Registration-city reconciliation uses the real RUNT mobile catalog as a source-specific input. It first matches normalized municipality and department names exactly. The explicit, versioned `registration_city_divipola_aliases_v1.json` fallback contains only the approved RUNT name variants and resolves them by DIVIPOLA code; it is not a global alias facility. Unknown records, duplicate aliases, wrong departments, or missing codes fail closed.

The existing mobile Pico catalog is not changed. B02 imports its 15 current records as jurisdictions, preserves `picoClassification` and `sourceDate` metadata, and enables only `SUPPORTED_CURRENT`. Bogotá uses its municipal unit as primary/coverage; Medellín / Valle de Aburrá preserves all ten contracted municipalities by official code. No geography dataset is published, no manifest is changed, and Flutter never connects to MariaDB.
