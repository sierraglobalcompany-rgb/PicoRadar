<?php

return [
    'private_disk' => env('CAMPAIGN_PRIVATE_DISK', 'local'),
    'public_disk' => env('CAMPAIGN_PUBLIC_DISK', 'public'),
    'public_base_url' => env('CAMPAIGN_PUBLIC_BASE_URL', env('DATASET_PUBLIC_BASE_URL', '/storage')),
    'placement' => 'home_c11',
    'max_image_bytes' => (int) env('CAMPAIGN_MAX_IMAGE_BYTES', 2 * 1024 * 1024),
    'min_image_width' => 720,
    'min_image_height' => 180,
    'max_image_width' => 4096,
    'max_image_height' => 4096,
    'cache_ttl_seconds' => (int) env('CAMPAIGN_CACHE_TTL_SECONDS', 3600),
    'catalog_manifest_path' => 'campaigns/v1/catalog.json',
    'catalog_release_directory' => 'campaigns/v1/releases',
    'publication_lock_name' => 'picoradar:campaign-catalog-publication',
    'publication_lock_seconds' => 60,
    'publication_lock_wait_seconds' => 10,
];
