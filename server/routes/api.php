<?php

use App\Http\Controllers\Api\AppAccountController;
use App\Http\Controllers\Api\CampaignCatalogController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\PartnerInquiryController;
use App\Http\Controllers\Api\TripPreviewController;
use App\Http\Middleware\AuthenticateAppAccount;
use App\Http\Middleware\RequireSecureAppAccountTransport;
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

Route::get('v1/campaign-catalog', CampaignCatalogController::class)
    ->name('api.v1.campaign-catalog');

Route::prefix('v1/app-accounts')
    ->middleware([RequireSecureAppAccountTransport::class, 'throttle:app-account-otp'])
    ->group(function (): void {
        Route::post('/otp', [AppAccountController::class, 'requestOtp'])->name('api.v1.app-accounts.otp');
        Route::post('/otp/verify', [AppAccountController::class, 'verifyOtp'])
            ->withoutMiddleware('throttle:app-account-otp')
            ->middleware('throttle:app-account-verify')
            ->name('api.v1.app-accounts.otp.verify');
    });

Route::prefix('v1/app-account')
    ->middleware([RequireSecureAppAccountTransport::class, AuthenticateAppAccount::class])
    ->group(function (): void {
        Route::get('/', [AppAccountController::class, 'show'])->name('api.v1.app-account.show');
        Route::patch('/', [AppAccountController::class, 'update'])->name('api.v1.app-account.update');
        Route::patch('/marketing', [AppAccountController::class, 'updateMarketing'])->name('api.v1.app-account.marketing');
        Route::post('/logout', [AppAccountController::class, 'logout'])->name('api.v1.app-account.logout');
        Route::delete('/', [AppAccountController::class, 'destroy'])->name('api.v1.app-account.destroy');
    });
