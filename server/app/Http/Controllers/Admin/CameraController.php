<?php

namespace App\Http\Controllers\Admin;

use App\Enums\CameraStatus;
use App\Enums\CameraType;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CameraRequest;
use App\Http\Requests\Admin\CameraVerificationRequest;
use App\Http\Requests\Admin\LifecycleReasonRequest;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\CameraDuplicateDetector;
use App\Services\CameraIntegrityAuditor;
use App\Services\CameraRegistryService;
use App\Services\CameraVerificationService;
use Carbon\Carbon;
use DomainException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class CameraController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('cameras.view');
        $query = Camera::query()->with(['source', 'jurisdiction', 'geographicUnit']);
        foreach (['status', 'jurisdiction_id', 'geographic_unit_id', 'source_id', 'type'] as $field) {
            if ($request->filled($field)) {
                $query->where($field, $request->input($field));
            }
        }
        if ($request->filled('speed_verified')) {
            $query->where('speed_limit_verified', $request->boolean('speed_verified'));
        }
        if ($request->boolean('needs_reverification')) {
            $query->whereIn('status', [CameraStatus::Active, CameraStatus::Verified, CameraStatus::Inactive])
                ->whereNotNull('verified_at')
                ->where('verified_at', '<=', now()->subDays((int) config('picoradar.camera_reverify_after_days', 180)));
        }
        if ($search = trim((string) $request->input('search'))) {
            $query->where(fn ($builder) => $builder->where('camera_id', 'like', "%{$search}%")->orWhere('external_id', 'like', "%{$search}%")->orWhere('name', 'like', "%{$search}%")->orWhere('corridor', 'like', "%{$search}%"));
        }

        return view('admin.cameras.index', $this->base($request) + ['cameras' => $query->orderBy('camera_id')->paginate(50)->withQueryString()]);
    }

    public function create(Request $request)
    {
        Gate::authorize('cameras.edit');

        return view('admin.cameras.form', $this->base($request) + ['camera' => new Camera, 'action' => route('admin.cameras.store'), 'method' => 'POST']);
    }

    public function municipalities(Request $request, Jurisdiction $jurisdiction)
    {
        Gate::authorize('cameras.edit');

        return response()->json($jurisdiction->geographicUnits()
            ->where('level', 'municipality')
            ->orderBy('name')
            ->get(['geographic_units.id', 'geographic_units.name', 'geographic_units.code']));
    }

    public function store(CameraRequest $request, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');
        try {
            $camera = $registry->create($request->safe()->except('updated_at'), $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['camera' => $exception->getMessage()])->withInput();
        }

        return redirect()->route('admin.cameras.show', $camera);
    }

    public function edit(Request $request, Camera $camera)
    {
        Gate::authorize('cameras.edit');

        return view('admin.cameras.form', $this->base($request) + ['camera' => $camera, 'action' => route('admin.cameras.update', $camera), 'method' => 'PUT']);
    }

    public function update(CameraRequest $request, Camera $camera, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');
        if ($camera->updated_at?->toISOString() !== Carbon::parse($request->validated('updated_at'))->toISOString()) {
            abort(409, 'This camera changed after this form was opened. Reload before editing again.');
        }
        try {
            $registry->updateDraft($camera, $request->safe()->except('updated_at'), $request->user());
        } catch (\LogicException|DomainException $exception) {
            return back()->withErrors(['camera' => $exception->getMessage()])->withInput();
        }

        return redirect()->route('admin.cameras.show', $camera);
    }

    public function show(Request $request, Camera $camera, CameraDuplicateDetector $duplicates)
    {
        Gate::authorize('cameras.view');
        $camera->load(['source', 'jurisdiction', 'geographicUnit', 'verifications']);

        return view('admin.cameras.show', $this->base($request) + ['camera' => $camera, 'duplicates' => $duplicates->candidates($camera)]);
    }

    public function review(Request $request)
    {
        Gate::authorize('cameras.review');

        return $this->queue($request, 'Review queue', Camera::query()->where('status', CameraStatus::InReview)->orderBy('submitted_at')->orderBy('camera_id'));
    }

    public function speedReview(Request $request)
    {
        Gate::authorize('cameras.review');

        return $this->queue($request, 'Speed review queue', Camera::query()->whereIn('status', [CameraStatus::Active, CameraStatus::Verified])->whereIn('type', [CameraType::Speed, CameraType::Combined])->where(fn ($q) => $q->whereNull('speed_limit')->orWhere('speed_limit_verified', false))->orderBy('camera_id'));
    }

    public function reverification(Request $request)
    {
        Gate::authorize('cameras.review');
        $cutoff = now()->subDays((int) config('picoradar.camera_reverify_after_days', 180));

        return $this->queue($request, 'Reverification queue', Camera::query()->whereIn('status', [CameraStatus::Active, CameraStatus::Verified, CameraStatus::Inactive])->whereNotNull('verified_at')->where('verified_at', '<=', $cutoff)->orderBy('verified_at')->orderBy('camera_id'));
    }

    public function duplicates(Request $request, CameraDuplicateDetector $detector)
    {
        Gate::authorize('cameras.view');
        $distance = min(500, max(1, (float) $request->input('distance', 25)));
        $cameras = Camera::query()->with(['source', 'jurisdiction', 'geographicUnit'])->when($request->filled('jurisdiction_id'), fn ($query) => $query->where('jurisdiction_id', $request->input('jurisdiction_id')))->where('status', '!=', CameraStatus::Retired)->orderBy('id')->limit(100)->get();
        $pairs = [];
        foreach ($cameras as $camera) {
            foreach ($detector->candidates($camera, $distance) as $candidate) {
                if ($camera->id < $candidate['camera']->id) {
                    $pairs[] = ['a' => $camera, 'b' => $candidate['camera'], 'distanceMeters' => $candidate['distanceMeters']];
                }
            }
        }

        return view('admin.cameras.duplicates', $this->base($request) + ['pairs' => $pairs, 'distance' => $distance]);
    }

    public function quality(Request $request, CameraIntegrityAuditor $integrity)
    {
        Gate::authorize('cameras.view');
        $all = Camera::query();
        $statuses = Camera::query()->selectRaw('status,count(*) count')->groupBy('status')->pluck('count', 'status');
        $invalidCoverage = 0;
        $fingerprint = 0;
        Camera::query()->with(['source', 'jurisdiction.geographicUnits', 'geographicUnit'])->eachById(function (Camera $camera) use ($integrity, &$invalidCoverage, &$fingerprint): void {
            $errors = $integrity->assess($camera)['errors'];
            $invalidCoverage += in_array('coverage', $errors, true);
            $fingerprint += in_array('fingerprint', $errors, true);
        });

        $operational = [CameraStatus::Active, CameraStatus::Verified, CameraStatus::Inactive];
        $speedReview = Camera::query()->whereIn('status', [CameraStatus::Active, CameraStatus::Verified])->whereIn('type', [CameraType::Speed, CameraType::Combined]);

        return view('admin.cameras.quality', $this->base($request) + [
            'total' => $all->count(), 'byStatus' => $statuses,
            'activeSpeed' => (clone $speedReview)->where('status', CameraStatus::Active)->count(),
            'eligible' => (clone $speedReview)->where('status', CameraStatus::Active)->whereNotNull('speed_limit')->where('speed_limit_verified', true)->count(),
            'speedLimitMissing' => (clone $speedReview)->whereNull('speed_limit')->count(),
            'speedUnverified' => (clone $speedReview)->where('speed_limit_verified', false)->count(),
            'inactiveSources' => Camera::query()->whereHas('source', fn ($query) => $query->where('is_active', false))->count(),
            'unverifiedSources' => Camera::query()->whereHas('source', fn ($query) => $query->whereNull('verified_at'))->count(),
            'bySource' => Camera::query()->where('status', CameraStatus::Active)->join('camera_sources', 'camera_sources.id', '=', 'cameras.source_id')->selectRaw('camera_sources.title, count(*) as total')->groupBy('camera_sources.title')->pluck('total', 'title'),
            'byJurisdiction' => Camera::query()->join('jurisdictions', 'jurisdictions.id', '=', 'cameras.jurisdiction_id')->selectRaw('jurisdictions.name, count(*) as total')->groupBy('jurisdictions.name')->pluck('total', 'name'),
            'byMunicipality' => Camera::query()->join('geographic_units', 'geographic_units.id', '=', 'cameras.geographic_unit_id')->selectRaw('geographic_units.name, count(*) as total')->groupBy('geographic_units.name')->pluck('total', 'name'),
            'invalidCoverage' => $invalidCoverage, 'fingerprintMismatch' => $fingerprint,
            'reverifyCount' => Camera::query()->whereIn('status', $operational)->whereNotNull('verified_at')->where('verified_at', '<=', now()->subDays((int) config('picoradar.camera_reverify_after_days', 180)))->count(),
        ]);
    }

    public function submit(Request $request, Camera $camera, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');

        return $this->action(fn () => $registry->submit($camera, $request->user()), $camera);
    }

    public function withdraw(Request $request, Camera $camera, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');

        return $this->action(fn () => $registry->withdraw($camera, $request->user()), $camera);
    }

    public function verify(CameraVerificationRequest $request, Camera $camera, CameraVerificationService $verification): RedirectResponse
    {
        Gate::authorize('cameras.review');

        return $this->action(fn () => $verification->verify($camera, $request->boolean('speed_limit_verified'), $request->user(), (string) $request->validated('notes', '')), $camera);
    }

    public function reject(LifecycleReasonRequest $request, Camera $camera, CameraVerificationService $verification): RedirectResponse
    {
        Gate::authorize('cameras.review');

        return $this->action(fn () => $verification->reject($camera, $request->validated('reason'), $request->user()), $camera);
    }

    public function activate(Request $request, Camera $camera, CameraVerificationService $verification): RedirectResponse
    {
        Gate::authorize('cameras.review');

        return $this->action(fn () => $verification->activate($camera, $request->user()), $camera);
    }

    public function deactivate(LifecycleReasonRequest $request, Camera $camera, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');

        return $this->action(fn () => $registry->deactivate($camera, $request->validated('reason'), $request->user()), $camera);
    }

    public function reopen(LifecycleReasonRequest $request, Camera $camera, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');

        return $this->action(fn () => $registry->reopen($camera, $request->validated('reason'), $request->user()), $camera);
    }

    public function retire(LifecycleReasonRequest $request, Camera $camera, CameraRegistryService $registry): RedirectResponse
    {
        Gate::authorize('cameras.edit');

        return $this->action(fn () => $registry->retire($camera, $request->validated('reason'), $request->user()), $camera);
    }

    private function queue(Request $request, string $title, $query)
    {
        return view('admin.cameras.queue', $this->base($request) + ['title' => $title, 'cameras' => $query->with(['source', 'jurisdiction', 'geographicUnit'])->paginate(50)->withQueryString()]);
    }

    private function action(callable $action, Camera $camera): RedirectResponse
    {
        try {
            $action();
        } catch (DomainException|\LogicException $exception) {
            return back()->withErrors(['camera' => $exception->getMessage()]);
        }

        return redirect()->route('admin.cameras.show', $camera);
    }

    private function base(Request $request): array
    {
        return ['operator' => $request->user(), 'jurisdictions' => Jurisdiction::query()->orderBy('name')->get(), 'sources' => CameraSource::query()->orderBy('title')->get(), 'municipalities' => GeographicUnit::query()->where('level', 'municipality')->orderBy('name')->get(), 'types' => CameraType::cases()];
    }
}
