<?php

return [
    'enabled' => (bool) env('PICORADAR_ACCOUNTS_ENABLED', false),
    'privacy_url' => env('PICORADAR_ACCOUNT_PRIVACY_URL'),
    'privacy_version' => env('PICORADAR_ACCOUNT_PRIVACY_VERSION'),
    'transactional_email_enabled' => (bool) env('PICORADAR_ACCOUNT_EMAIL_ENABLED', false),
    'marketing_send_enabled' => (bool) env('PICORADAR_MARKETING_SEND_ENABLED', false),
    'marketing_version' => env('PICORADAR_MARKETING_VERSION', '2026-11-17'),
    'allow_insecure_local' => (bool) env('PICORADAR_ACCOUNTS_ALLOW_INSECURE_LOCAL', false),
];
