<?php

use App\Http\Controllers\Api\HealthController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')
    ->middleware('throttle:health')
    ->group(function (): void {
        Route::get('/health', HealthController::class)->name('api.v1.health');
    });
