<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\CameraImportItem;
use App\Models\CameraImportRun;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use App\Services\CameraImportResolutionService;
use App\Services\CameraImportRunComparator;
use App\Services\CameraImportService;
use Carbon\Carbon;
use DomainException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class CameraImportController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('camera_imports.view');
        $runs = CameraImportRun::query()->with('source');
        foreach (['source_id', 'status', 'format', 'import_mode', 'created_by_id'] as $field) {
            if ($request->filled($field)) {
                $runs->where($field, $request->input($field));
            }
        }
        if ($search = trim((string) $request->input('search'))) {
            $runs->where(fn ($query) => $query->where('original_filename', 'like', "%{$search}%")->orWhere('file_sha256', 'like', "%{$search}%")->orWhereHas('source', fn ($source) => $source->where('key', 'like', "%{$search}%")->orWhere('title', 'like', "%{$search}%")));
        }

        return view('admin.camera-imports.index', ['operator' => $request->user(), 'runs' => $runs->latest('id')->paginate(50)->withQueryString()]);
    }

    public function create(Request $request)
    {
        Gate::authorize('camera_imports.edit');

        return view('admin.camera-imports.create', ['operator' => $request->user(), 'sources' => CameraSource::query()->orderBy('title')->get(), 'jurisdictions' => Jurisdiction::query()->where('enabled', true)->orderBy('name')->get()]);
    }

    public function store(Request $request, CameraImportService $imports): RedirectResponse
    {
        Gate::authorize('camera_imports.edit');
        $data = $request->validate(['source_id' => ['required', Rule::exists('camera_sources', 'id')], 'default_jurisdiction_id' => ['nullable', Rule::exists('jurisdictions', 'id')], 'import_mode' => ['required', Rule::in(['snapshot', 'delta'])], 'file' => ['required', 'file', 'max:'.((int) config('picoradar.camera_import_max_mb') * 1024), 'mimes:csv,txt,ndjson,jsonl,geojson,json']]);
        try {
            $run = $imports->upload($request->file('file'), CameraSource::query()->findOrFail($data['source_id']), $data['import_mode'], isset($data['default_jurisdiction_id']) ? Jurisdiction::query()->findOrFail($data['default_jurisdiction_id']) : null, $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['file' => $exception->getMessage()])->withInput();
        }

        return redirect()->route('admin.camera-imports.show', $run);
    }

    public function show(Request $request, CameraImportRun $run)
    {
        Gate::authorize('camera_imports.view');
        $items = $run->items()->orderBy('row_number');
        foreach (['classification', 'status'] as $field) {
            if ($request->filled($field)) {
                $items->where($field, $request->input($field));
            }
        }
        if ($request->boolean('has_errors')) {
            $items->whereNotNull('errors');
        }
        if ($request->boolean('has_warnings')) {
            $items->whereNotNull('warnings');
        }
        if ($request->filled('resolved')) {
            $request->boolean('resolved') ? $items->whereNotNull('resolved_at') : $items->whereNull('resolved_at');
        }
        if ($search = trim((string) $request->input('search'))) {
            $items->where(fn ($query) => $query->where('external_id', 'like', "%{$search}%")->orWhere('row_number', $search)->orWhereHas('matchedCamera', fn ($camera) => $camera->where('camera_id', 'like', "%{$search}%")));
        }

        return view('admin.camera-imports.show', ['operator' => $request->user(), 'run' => $run->load('source'), 'items' => $items->paginate(100)->withQueryString()]);
    }

    public function compare(Request $request, CameraImportRun $run, CameraImportRun $otherRun, CameraImportRunComparator $comparator)
    {
        Gate::authorize('camera_imports.view');
        try {
            $comparison = $comparator->compare($run, $otherRun);
        } catch (DomainException $exception) {
            abort(422, $exception->getMessage());
        }

        return view('admin.camera-imports.compare', ['operator' => $request->user(), 'run' => $run, 'otherRun' => $otherRun, 'comparison' => $comparison]);
    }

    public function analyze(Request $request, CameraImportRun $run, CameraImportService $imports): RedirectResponse
    {
        Gate::authorize('camera_imports.edit');
        try {
            $imports->analyze($run, $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['run' => $exception->getMessage()]);
        }

        return redirect()->route('admin.camera-imports.show', $run);
    }

    public function apply(Request $request, CameraImportRun $run, CameraImportService $imports): RedirectResponse
    {
        Gate::authorize('camera_imports.admin');
        try {
            $imports->apply($run, $request->user());
        } catch (DomainException $exception) {
            return back()->withErrors(['run' => $exception->getMessage()]);
        }

        return redirect()->route('admin.camera-imports.show', $run);
    }

    public function skip(Request $request, CameraImportRun $run, CameraImportItem $item, CameraImportResolutionService $resolution): RedirectResponse
    {
        return $this->resolve($request->merge(['action' => 'skip']), $run, $item, $resolution);
    }

    public function resolve(Request $request, CameraImportRun $run, CameraImportItem $item, CameraImportResolutionService $resolution): RedirectResponse
    {
        $action = (string) $request->input('action');
        Gate::authorize($action === 'allow_create' ? 'camera_imports.admin' : 'camera_imports.edit');
        abort_unless($item->run_id === $run->id, 404);
        $data = $request->validate(['action' => ['required', Rule::in(['link_existing', 'allow_create', 'municipality_override', 'type_override', 'skip', 'choose_canonical_file_row'])], 'updated_at' => ['required', 'date'], 'reason' => ['nullable', 'string', 'max:1000'], 'camera_id' => ['nullable', 'integer'], 'geographic_unit_id' => ['nullable', 'integer'], 'type' => ['nullable', 'string'], 'row_number' => ['nullable', 'integer']]);
        try {
            $resolution->resolve($item, Carbon::parse($data['updated_at']), $data['action'], $data, $request->user());
        } catch (DomainException $exception) {
            if (str_starts_with($exception->getMessage(), 'This import item changed')) {
                abort(409, $exception->getMessage());
            }

            return back()->withErrors(['item' => $exception->getMessage()]);
        }

        return redirect()->route('admin.camera-imports.show', $run);
    }
}
