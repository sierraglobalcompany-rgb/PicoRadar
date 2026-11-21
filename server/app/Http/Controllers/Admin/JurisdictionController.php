<?php

namespace App\Http\Controllers\Admin;

use App\Enums\GeographicUnitLevel;
use App\Enums\JurisdictionKind;
use App\Http\Controllers\Controller;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Services\JurisdictionService;
use DomainException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class JurisdictionController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('jurisdictions.view');

        return view('admin.jurisdictions.index', ['operator' => $request->user(), 'jurisdictions' => Jurisdiction::query()->with('primaryGeographicUnit')->orderBy('key')->paginate(50)]);
    }

    public function create(Request $request)
    {
        Gate::authorize('jurisdictions.edit');

        return view('admin.jurisdictions.create', $this->formData($request));
    }

    public function store(Request $request, JurisdictionService $service): RedirectResponse
    {
        Gate::authorize('jurisdictions.edit');
        $data = $this->validated($request, true);
        try {
            $jurisdiction = $service->create($data, [$data['primary_geographic_unit_id']], $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['jurisdiction' => $exception->getMessage()])->withInput();
        }

        return redirect()->route('admin.jurisdictions.show', $jurisdiction);
    }

    public function show(Request $request, Jurisdiction $jurisdiction)
    {
        Gate::authorize('jurisdictions.view');
        $jurisdiction->load(['primaryGeographicUnit.parent', 'geographicUnits.parent']);

        return view('admin.jurisdictions.show', ['operator' => $request->user(), 'jurisdiction' => $jurisdiction, 'geography' => GeographicUnit::query()->where('level', GeographicUnitLevel::Municipality)->orderBy('name')->get()]);
    }

    public function update(Request $request, Jurisdiction $jurisdiction, JurisdictionService $service): RedirectResponse
    {
        Gate::authorize('jurisdictions.edit');
        $data = $this->validated($request, false);
        try {
            $service->update($jurisdiction, $data, $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['jurisdiction' => $exception->getMessage()])->withInput();
        }

        return back();
    }

    public function attach(Request $request, Jurisdiction $jurisdiction, JurisdictionService $service): RedirectResponse
    {
        Gate::authorize('jurisdictions.edit');
        $data = $request->validate(['geographic_unit_id' => ['required', Rule::exists('geographic_units', 'id')]]);
        try {
            $service->attachCoverage($jurisdiction, GeographicUnit::query()->findOrFail($data['geographic_unit_id']), $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['coverage' => $exception->getMessage()]);
        }

        return back();
    }

    public function detach(Request $request, Jurisdiction $jurisdiction, GeographicUnit $unit, JurisdictionService $service): RedirectResponse
    {
        Gate::authorize('jurisdictions.edit');
        try {
            $service->detachCoverage($jurisdiction, $unit, $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['coverage' => $exception->getMessage()]);
        }

        return back();
    }

    /** @return array<string, mixed> */
    private function validated(Request $request, bool $creating): array
    {
        $rules = ['name' => ['required', 'string', 'max:255'], 'kind' => ['required', Rule::enum(JurisdictionKind::class)], 'enabled' => ['required', 'boolean'], 'timezone' => ['required', 'in:America/Bogota'], 'primary_geographic_unit_id' => ['required', Rule::exists('geographic_units', 'id')]];
        if ($creating) {
            $rules['key'] = ['required', 'regex:/^[a-z0-9-]+$/', 'max:64', Rule::unique('jurisdictions', 'key')];
        }
        $data = $request->validate($rules);
        if (GeographicUnit::query()->whereKey($data['primary_geographic_unit_id'])->value('level') !== GeographicUnitLevel::Municipality) {
            abort(422, 'Primary geographic unit must be a municipality.');
        }

        return $data;
    }

    /** @return array<string,mixed> */
    private function formData(Request $request): array
    {
        return ['operator' => $request->user(), 'geography' => GeographicUnit::query()->where('level', GeographicUnitLevel::Municipality)->with('parent')->orderBy('name')->get(), 'kinds' => JurisdictionKind::cases()];
    }
}
