<?php

return [
    'camera_reverify_after_days' => (int) env('CAMERA_REVERIFY_AFTER_DAYS', 180),
    'camera_import_max_mb' => (int) env('CAMERA_IMPORT_MAX_MB', 50),
    'camera_import_geojson_max_mb' => (int) env('CAMERA_IMPORT_GEOJSON_MAX_MB', 20),
    'camera_import_max_rows' => (int) env('CAMERA_IMPORT_MAX_ROWS', 100000),
    'camera_import_web_max_rows' => (int) env('CAMERA_IMPORT_WEB_MAX_ROWS', 10000),
    'camera_import_analysis_max_age_hours' => (int) env('CAMERA_IMPORT_ANALYSIS_MAX_AGE_HOURS', 24),
    'camera_import_high_risk_move_meters' => (int) env('CAMERA_IMPORT_HIGH_RISK_MOVE_METERS', 100),
    'camera_import_snapshot_drop_warning_percent' => (int) env('CAMERA_IMPORT_SNAPSHOT_DROP_WARNING_PERCENT', 30),
    'camera_import_apply_stuck_minutes' => (int) env('CAMERA_IMPORT_APPLY_STUCK_MINUTES', 30),
];
