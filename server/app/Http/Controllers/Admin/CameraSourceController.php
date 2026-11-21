<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CameraSourceRequest;
use App\Models\CameraSource;
use App\Services\CameraSourceService;
use Carbon\Carbon;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class CameraSourceController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('camera_sources.view');

        return view('admin.camera-sources.index', ['operator' => $request->user(), 'sources' => CameraSource::query()->withCount('cameras')->orderBy('key')->paginate(50)]);
    }

    public function create(Request $request)
    {
        Gate::authorize('camera_sources.edit');

        return view('admin.camera-sources.form', ['operator' => $request->user(), 'source' => new CameraSource, 'action' => route('admin.camera-sources.store'), 'method' => 'POST']);
    }

    public function store(CameraSourceRequest $request, CameraSourceService $service): RedirectResponse
    {
        Gate::authorize('camera_sources.edit');
        $source = $service->create($request->safe()->except('updated_at'), $request->user());

        return redirect()->route('admin.camera-sources.show', $source);
    }

    public function show(Request $request, CameraSource $source)
    {
        Gate::authorize('camera_sources.view');
        $source->load(['cameras' => fn ($query) => $query->latest()->limit(25)]);

        return view('admin.camera-sources.show', ['operator' => $request->user(), 'source' => $source]);
    }

    public function edit(Request $request, CameraSource $source)
    {
        Gate::authorize('camera_sources.edit');

        return view('admin.camera-sources.form', ['operator' => $request->user(), 'source' => $source, 'action' => route('admin.camera-sources.update', $source), 'method' => 'PUT']);
    }

    public function update(CameraSourceRequest $request, CameraSource $source, CameraSourceService $service): RedirectResponse
    {
        Gate::authorize('camera_sources.edit');
        if ($source->updated_at?->toISOString() !== Carbon::parse($request->validated('updated_at'))->toISOString()) {
            abort(409, 'This source changed after this form was opened. Reload before editing again.');
        }
        $service->update($source, $request->safe()->except('updated_at'), $request->user());

        return redirect()->route('admin.camera-sources.show', $source);
    }
}
