<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\DatasetController;
use App\Http\Controllers\Auth\AuthenticatedSessionController;
use App\Http\Middleware\EnsureActiveOperator;
use App\Http\Middleware\SecurityHeaders;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::middleware(['guest', SecurityHeaders::class])->group(function (): void {
    Route::get('/login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('/login', [AuthenticatedSessionController::class, 'store'])
        ->middleware('throttle:operator-login')
        ->name('login.store');
});

Route::middleware(['auth', EnsureActiveOperator::class, SecurityHeaders::class])->group(function (): void {
    Route::get('/admin', DashboardController::class)->name('admin.dashboard');
    Route::get('/admin/audit', [AuditLogController::class, 'index'])->name('admin.audit.index');
    Route::post('/logout', [AuthenticatedSessionController::class, 'destroy'])->name('logout');
    Route::get('/admin/datasets', [DatasetController::class, 'index'])->name('admin.datasets.index');
    Route::get('/admin/datasets/create', [DatasetController::class, 'create'])->name('admin.datasets.create');
    Route::post('/admin/datasets', [DatasetController::class, 'store'])->name('admin.datasets.store');
    Route::get('/admin/datasets/{dataset}', [DatasetController::class, 'show'])->name('admin.datasets.show');
    Route::put('/admin/datasets/{dataset}', [DatasetController::class, 'update'])->name('admin.datasets.update');
    Route::post('/admin/datasets/{dataset}/sources', [DatasetController::class, 'storeSource'])->name('admin.datasets.sources.store');
    Route::put('/admin/datasets/{dataset}/sources/{source}', [DatasetController::class, 'updateSource'])->name('admin.datasets.sources.update');
    Route::post('/admin/datasets/{dataset}/releases', [DatasetController::class, 'storeRelease'])->name('admin.datasets.releases.store');
    Route::post('/admin/datasets/{dataset}/releases/{release}/validate', [DatasetController::class, 'validateRelease'])->name('admin.datasets.releases.validate');
    Route::post('/admin/datasets/{dataset}/releases/{release}/publish', [DatasetController::class, 'publish'])->name('admin.datasets.releases.publish');
    Route::post('/admin/datasets/{dataset}/releases/{release}/rollback', [DatasetController::class, 'rollback'])->name('admin.datasets.releases.rollback');
    Route::post('/admin/datasets/{dataset}/releases/{release}/retire', [DatasetController::class, 'retire'])->name('admin.datasets.releases.retire');
});
