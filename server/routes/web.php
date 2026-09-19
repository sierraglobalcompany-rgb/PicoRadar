<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\CameraController;
use App\Http\Controllers\Admin\CameraSourceController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\DatasetController;
use App\Http\Controllers\Admin\GeographyController;
use App\Http\Controllers\Admin\JurisdictionController;
use App\Http\Controllers\Admin\PartnerInquiryController;
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
    Route::get('/admin/geography', [GeographyController::class, 'index'])->name('admin.geography.index');
    Route::get('/admin/jurisdictions', [JurisdictionController::class, 'index'])->name('admin.jurisdictions.index');
    Route::get('/admin/jurisdictions/create', [JurisdictionController::class, 'create'])->name('admin.jurisdictions.create');
    Route::post('/admin/jurisdictions', [JurisdictionController::class, 'store'])->name('admin.jurisdictions.store');
    Route::get('/admin/jurisdictions/{jurisdiction}', [JurisdictionController::class, 'show'])->name('admin.jurisdictions.show');
    Route::get('/admin/partner-inquiries', [PartnerInquiryController::class, 'index'])->name('admin.partner-inquiries.index');
    Route::get('/admin/partner-inquiries/audit', [PartnerInquiryController::class, 'audit'])->name('admin.partner-inquiries.audit');
    Route::put('/admin/partner-inquiries/{inquiry}/status', [PartnerInquiryController::class, 'updateStatus'])->name('admin.partner-inquiries.status');
    Route::resource('/admin/camera-sources', CameraSourceController::class)->except('destroy')->parameters(['camera-sources' => 'source'])->names('admin.camera-sources');
    Route::get('/admin/cameras/quality', [CameraController::class, 'quality'])->name('admin.cameras.quality');
    Route::get('/admin/cameras/review', [CameraController::class, 'review'])->name('admin.cameras.review');
    Route::get('/admin/cameras/speed-review', [CameraController::class, 'speedReview'])->name('admin.cameras.speed-review');
    Route::get('/admin/cameras/reverification', [CameraController::class, 'reverification'])->name('admin.cameras.reverification');
    Route::get('/admin/cameras/duplicates', [CameraController::class, 'duplicates'])->name('admin.cameras.duplicates');
    Route::get('/admin/cameras', [CameraController::class, 'index'])->name('admin.cameras.index');
    Route::get('/admin/cameras/create', [CameraController::class, 'create'])->name('admin.cameras.create');
    Route::get('/admin/cameras/jurisdictions/{jurisdiction}/municipalities', [CameraController::class, 'municipalities'])->name('admin.cameras.municipalities');
    Route::post('/admin/cameras', [CameraController::class, 'store'])->name('admin.cameras.store');
    Route::get('/admin/cameras/{camera}', [CameraController::class, 'show'])->name('admin.cameras.show');
    Route::get('/admin/cameras/{camera}/edit', [CameraController::class, 'edit'])->name('admin.cameras.edit');
    Route::put('/admin/cameras/{camera}', [CameraController::class, 'update'])->name('admin.cameras.update');
    Route::post('/admin/cameras/{camera}/submit', [CameraController::class, 'submit'])->name('admin.cameras.submit');
    Route::post('/admin/cameras/{camera}/withdraw', [CameraController::class, 'withdraw'])->name('admin.cameras.withdraw');
    Route::post('/admin/cameras/{camera}/verify', [CameraController::class, 'verify'])->name('admin.cameras.verify');
    Route::post('/admin/cameras/{camera}/reject', [CameraController::class, 'reject'])->name('admin.cameras.reject');
    Route::post('/admin/cameras/{camera}/activate', [CameraController::class, 'activate'])->name('admin.cameras.activate');
    Route::post('/admin/cameras/{camera}/deactivate', [CameraController::class, 'deactivate'])->name('admin.cameras.deactivate');
    Route::post('/admin/cameras/{camera}/reopen', [CameraController::class, 'reopen'])->name('admin.cameras.reopen');
    Route::post('/admin/cameras/{camera}/retire', [CameraController::class, 'retire'])->name('admin.cameras.retire');
    Route::put('/admin/jurisdictions/{jurisdiction}', [JurisdictionController::class, 'update'])->name('admin.jurisdictions.update');
    Route::post('/admin/jurisdictions/{jurisdiction}/coverage', [JurisdictionController::class, 'attach'])->name('admin.jurisdictions.coverage.attach');
    Route::delete('/admin/jurisdictions/{jurisdiction}/coverage/{unit}', [JurisdictionController::class, 'detach'])->name('admin.jurisdictions.coverage.detach');
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
