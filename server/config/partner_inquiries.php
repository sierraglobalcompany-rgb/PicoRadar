<?php

return [
    'enabled' => (bool) env('PARTNER_INQUIRIES_ENABLED', false),
    'admin_inbox_enabled' => (bool) env('PARTNER_INQUIRIES_ADMIN_INBOX_ENABLED', false),
    'privacy_version' => env('PARTNER_INQUIRIES_PRIVACY_VERSION'),
    'privacy_url' => env('PARTNER_INQUIRIES_PRIVACY_URL'),
    'allow_insecure_local' => (bool) env('PARTNER_INQUIRIES_ALLOW_INSECURE_LOCAL', false),
    'retention_days' => 180,
];
