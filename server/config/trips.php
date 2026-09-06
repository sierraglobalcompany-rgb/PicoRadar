<?php

return [
    // A key alone never authorizes usage. No live calls until all owner gates are satisfied.
    'enabled' => env('TRIPS_ENABLED', false),
    'api_key' => env('TOLLGURU_API_KEY'),
    'access_authorized' => env('TRIPS_ACCESS_AUTHORIZED', false),
    'license_authorized' => env('TRIPS_LICENSE_AUTHORIZED', false),
    'confirmed_free' => env('TRIPS_CONFIRMED_FREE', false),
    'authorization_expires_at' => env('TRIPS_AUTHORIZATION_EXPIRES_AT'),
    'cache_store' => 'database',
    'budget_id' => env('TRIPS_BUDGET_ID'),
    'budget_currency' => env('TRIPS_BUDGET_CURRENCY'),
    'max_requests' => env('TRIPS_MAX_REQUESTS', 0),
    'max_units' => env('TRIPS_MAX_UNITS', 0),
    'max_money_minor' => env('TRIPS_MAX_MONEY_MINOR', 0),
    // Owner supplies conservative upper bounds covering geocoding AND all alternatives.
    // These are reservations per HTTP operation, not a claim of actual provider billing.
    'units_per_request' => env('TRIPS_UNITS_PER_REQUEST', 0),
    'money_minor_per_request' => env('TRIPS_MONEY_MINOR_PER_REQUEST', 0),
    'timeout_seconds' => 10,
    'connect_timeout_seconds' => 3,
    'lock_seconds' => 30,
    'max_request_bytes' => 4096,
    'max_response_bytes' => 262144,
    'max_routes' => 3,
    'max_tolls' => 200,
    'max_future_days' => 30,

    // Existing durable cache only. Before enabling, an authorized operator must seed
    // trips:tollguru:budget:v1 under trips:tollguru:operation:v1 with reconciled usage:
    // {budget_id, currency, requests, units, money_minor, in_flight:false}.
    // Never initialize from HTTP, expire/reset on a calendar boundary, or refund failure.
    // An absent/corrupt ledger or abandoned in_flight marker requires owner reconciliation.
    // Cache clearing disables access; it is NOT a new allowance. Keep enabled=false
    // throughout reconciliation. No route data, response or geometry is retained.
];
