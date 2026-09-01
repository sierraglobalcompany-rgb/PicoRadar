<?php

namespace App\Services;

class CameraImportIssueCatalog
{
    public const CODES = ['missing_external_id', 'invalid_lat', 'invalid_lon', 'invalid_speed_limit', 'unknown_jurisdiction', 'unknown_municipality', 'municipality_outside_coverage', 'ambiguous_municipality', 'unsupported_geometry', 'duplicate_candidate', 'duplicate_scan_capped', 'duplicate_external_id_conflict', 'source_not_operational', 'file_hash_mismatch', 'profile_mismatch', 'suspicious_snapshot_drop'];
}
