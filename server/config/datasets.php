<?php

return [
    'draft_disk' => env('DATASET_DRAFT_DISK', 'local'),
    'published_disk' => env('DATASET_PUBLISHED_DISK', 'public'),
    'public_base_url' => env('DATASET_PUBLIC_BASE_URL', '/storage'),
    'max_upload_kb' => (int) env('DATASET_MAX_UPLOAD_KB', 5120),
    'min_app_version' => env('PICORADAR_MIN_APP_VERSION', '1.0.0'),
    'manifest_path' => 'manifest/v1/manifest.json',
    'features' => ['defense' => true, 'services' => true, 'ads' => false, 'cloud' => false, 'paidDocuments' => false],
];
