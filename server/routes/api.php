<?php

use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\PartnerInquiryController;
use App\Http\Controllers\Api\TripPreviewController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')
    ->middleware('throttle:health')
    ->group(function (): void {
        Route::get('/health', HealthController::class)->name('api.v1.health');
    });

Route::post('v1/trips/preview', TripPreviewController::class)
    ->middleware('throttle:trips-preview')
    ->name('api.v1.trips.preview');

Route::post('v1/partner-inquiries', PartnerInquiryController::class)
    ->middleware('throttle:partner-inquiries')
    ->name('api.v1.partner-inquiries.store');
