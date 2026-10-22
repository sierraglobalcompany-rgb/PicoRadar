<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\CameraController;
use App\Http\Controllers\Admin\CameraCsvImportController;
use App\Http\Controllers\Admin\CameraSourceController;
use App\Http\Controllers\Admin\CampaignController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\DatasetController;
use App\Http\Controllers\Admin\GeographyController;
use App\Http\Controllers\Admin\JurisdictionController;
use App\Http\Controllers\Admin\OperatorController;
use App\Http\Controllers\Admin\PartnerInquiryController;
use App\Http\Controllers\Admin\ProfileController;
use App\Http\Controllers\Admin\RestrictionRuleController;
use App\Http\Controllers\Admin\SponsorController;
use App\Http\Controllers\Auth\AuthenticatedSessionController;
use App\Http\Middleware\EnsureActiveOperator;
use App\Http\Middleware\SecurityHeaders;
use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome');

Route::middleware(['guest', SecurityHeaders::class])->group(function (): void {
    Route::get('/login', [AuthenticatedSessionController::class, 'create'])->name('login');
    Route::post('/login', [AuthenticatedSessionController::class, 'store'])
        ->middleware('throttle:operator-login')
        ->name('login.store');
});

Route::middleware(['auth', EnsureActiveOperator::class, SecurityHeaders::class])->group(function (): void {
    Route::get('/admin', DashboardController::class)->name('admin.dashboard');
    Route::get('/admin/audit', [AuditLogController::class, 'index'])->name('admin.audit.index');
    Route::get('/admin/profile', [ProfileController::class, 'edit'])->name('admin.profile.edit');
    Route::put('/admin/profile/password', [ProfileController::class, 'updatePassword'])->name('admin.profile.password');
    Route::get('/admin/operators', [OperatorController::class, 'index'])->name('admin.operators.index');
    Route::post('/admin/operators', [OperatorController::class, 'store'])->name('admin.operators.store');
    Route::put('/admin/operators/{operator}', [OperatorController::class, 'update'])->name('admin.operators.update');
    Route::get('/admin/restrictions', [RestrictionRuleController::class, 'index'])->name('admin.restrictions.index');
    Route::get('/admin/restrictions/create', [RestrictionRuleController::class, 'create'])->name('admin.restrictions.create');
    Route::post('/admin/restrictions', [RestrictionRuleController::class, 'store'])->name('admin.restrictions.store');
    Route::get('/admin/restrictions/import', [RestrictionRuleController::class, 'importForm'])->name('admin.restrictions.import');
    Route::post('/admin/restrictions/imports', [RestrictionRuleController::class, 'analyzeImport'])->name('admin.restrictions.imports.analyze');
    Route::get('/admin/restrictions/imports/{import}', [RestrictionRuleController::class, 'reviewImport'])->name('admin.restrictions.imports.review');
    Route::post('/admin/restrictions/imports/{import}/confirm', [RestrictionRuleController::class, 'confirmImport'])->name('admin.restrictions.imports.confirm');
    Route::get('/admin/restrictions/imports/{import}/report', [RestrictionRuleController::class, 'report'])->name('admin.restrictions.imports.report');
    Route::get('/admin/restrictions/template', [RestrictionRuleController::class, 'template'])->name('admin.restrictions.template');
    Route::get('/admin/restrictions/publish', [RestrictionRuleController::class, 'publicationPreview'])->name('admin.restrictions.publish.preview');
    Route::post('/admin/restrictions/publish', [RestrictionRuleController::class, 'publish'])->name('admin.restrictions.publish');
    Route::get('/admin/restrictions/history', [RestrictionRuleController::class, 'history'])->name('admin.restrictions.history');
    Route::get('/admin/restrictions/{version}/edit', [RestrictionRuleController::class, 'edit'])->name('admin.restrictions.edit');
    Route::put('/admin/restrictions/{version}', [RestrictionRuleController::class, 'update'])->name('admin.restrictions.update');
    Route::post('/admin/restrictions/{version}/duplicate', [RestrictionRuleController::class, 'duplicate'])->name('admin.restrictions.duplicate');
    Route::post('/admin/restrictions/{version}/validate', [RestrictionRuleController::class, 'validateVersion'])->name('admin.restrictions.validate');
    Route::post('/admin/restrictions/{version}/archive', [RestrictionRuleController::class, 'archive'])->name('admin.restrictions.archive');
    Route::post('/admin/restrictions/{version}/rollback', [RestrictionRuleController::class, 'rollback'])->name('admin.restrictions.rollback');
    Route::resource('/admin/sponsors', SponsorController::class)
        ->except(['destroy'])
        ->names('admin.sponsors');
    Route::delete('/admin/sponsors/{sponsor}', [SponsorController::class, 'archive'])->name('admin.sponsors.archive');
    Route::resource('/admin/campaigns', CampaignController::class)
        ->except(['destroy'])
        ->names('admin.campaigns');
    Route::post('/admin/campaigns/{campaign}/duplicate', [CampaignController::class, 'duplicate'])->name('admin.campaigns.duplicate');
    Route::get('/admin/campaigns/{campaign}/preview', [CampaignController::class, 'preview'])->name('admin.campaigns.preview');
    Route::get('/admin/campaigns/{campaign}/image', [CampaignController::class, 'image'])->name('admin.campaigns.image');
    Route::post('/admin/campaigns/{campaign}/activate', [CampaignController::class, 'activate'])->name('admin.campaigns.activate');
    Route::post('/admin/campaigns/{campaign}/pause', [CampaignController::class, 'pause'])->name('admin.campaigns.pause');
    Route::delete('/admin/campaigns/{campaign}', [CampaignController::class, 'archive'])->name('admin.campaigns.archive');
    Route::get('/admin/geography', [GeographyController::class, 'index'])->name('admin.geography.index');
    Route::get('/admin/jurisdictions', [JurisdictionController::class, 'index'])->name('admin.jurisdictions.index');
    Route::get('/admin/jurisdictions/create', [JurisdictionController::class, 'create'])->name('admin.jurisdictions.create');
    Route::post('/admin/jurisdictions', [JurisdictionController::class, 'store'])->name('admin.jurisdictions.store');
    Route::get('/admin/jurisdictions/{jurisdiction}', [JurisdictionController::class, 'show'])->name('admin.jurisdictions.show');
    Route::get('/admin/partner-inquiries', [PartnerInquiryController::class, 'index'])->name('admin.partner-inquiries.index');
    Route::get('/admin/partner-inquiries/audit', [PartnerInquiryController::class, 'audit'])->name('admin.partner-inquiries.audit');
    Route::put('/admin/partner-inquiries/{inquiry}/status', [PartnerInquiryController::class, 'updateStatus'])->name('admin.partner-inquiries.status');
    Route::resource('/admin/camera-sources', CameraSourceController::class)->except('destroy')->parameters(['camera-sources' => 'source'])->names('admin.camera-sources');
    Route::get('/admin/cameras/imports', [CameraCsvImportController::class, 'index'])->name('admin.camera-csv-imports.index');
    Route::get('/admin/cameras/imports/create', [CameraCsvImportController::class, 'create'])->name('admin.camera-csv-imports.create');
    Route::get('/admin/cameras/imports/template', [CameraCsvImportController::class, 'template'])->name('admin.camera-csv-imports.template');
    Route::post('/admin/cameras/imports', [CameraCsvImportController::class, 'store'])->middleware('throttle:6,1')->name('admin.camera-csv-imports.store');
    Route::get('/admin/cameras/imports/{batch}', [CameraCsvImportController::class, 'show'])->name('admin.camera-csv-imports.show');
    Route::get('/admin/cameras/imports/{batch}/report', [CameraCsvImportController::class, 'report'])->name('admin.camera-csv-imports.report');
    Route::post('/admin/cameras/imports/{batch}/apply', [CameraCsvImportController::class, 'apply'])->middleware('throttle:30,1')->name('admin.camera-csv-imports.apply');
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
