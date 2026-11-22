<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DatasetReleaseStatus;
use App\Http\Controllers\Controller;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\DatasetSource;
use App\Services\DatasetAuditLogger;
use App\Services\DatasetPublisher;
use App\Services\DatasetReleaseValidator;
use App\Services\ManifestPublisher;
use DomainException;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class DatasetController extends Controller
{
    public function __construct(private readonly DatasetAuditLogger $audit, private readonly ManifestPublisher $manifest) {}

    public function index(Request $request)
    {
        Gate::authorize('datasets.view');

        return view('admin.datasets.index', ['operator' => $request->user(), 'datasets' => Dataset::query()->withCount(['sources', 'releases'])->orderBy('key')->get()]);
    }

    public function create(Request $request)
    {
        Gate::authorize('datasets.edit');

        return view('admin.datasets.create', ['operator' => $request->user()]);
    }

    public function store(Request $request): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $data = $request->validate(['key' => ['required', 'regex:/^[a-z0-9_]+$/', 'max:64', 'unique:datasets,key'], 'title' => ['required', 'string', 'max:255'], 'schema_version' => ['required', 'integer', 'min:1']]);
        $dataset = Dataset::query()->create($data + ['enabled' => true]);
        $this->audit->log($request->user(), 'dataset.created', $dataset, ['datasetKey' => $dataset->key]);

        return redirect()->route('admin.datasets.show', $dataset);
    }

    public function show(Request $request, Dataset $dataset)
    {
        Gate::authorize('datasets.view');
        $dataset->load(['sources', 'releases' => fn ($query) => $query->latest('id')]);

        return view('admin.datasets.show', ['operator' => $request->user(), 'dataset' => $dataset]);
    }

    public function update(Request $request, Dataset $dataset): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $data = $request->validate(['title' => ['required', 'string', 'max:255'], 'enabled' => ['required', 'boolean']]);
        try {
            $update = function () use ($dataset, $data, $request): void {
                DB::transaction(function () use ($dataset, $data, $request): void {
                    $locked = Dataset::query()->lockForUpdate()->findOrFail($dataset->id);
                    if (! $locked->enabled && $data['enabled']) {
                        $this->manifest->assertDatasetCanBeManifested($locked);
                    }
                    $locked->update($data);
                    $this->audit->log($request->user(), 'dataset.updated', $locked, ['datasetKey' => $locked->key, 'enabled' => $locked->enabled]);
                });
            };
            if ((bool) $dataset->enabled !== (bool) $data['enabled']) {
                $this->manifest->mutateAndRegenerate($update);
            } else {
                $update();
            }
        } catch (DomainException $error) {
            return back()->withErrors(['dataset' => $error->getMessage()]);
        }

        return back();
    }

    public function storeSource(Request $request, Dataset $dataset): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        $data = $request->validate(['title' => ['required', 'string', 'max:255'], 'authority' => ['required', 'string', 'max:255'], 'url' => ['required', 'url', 'max:2048'], 'verified_at' => ['required', 'date'], 'valid_from' => ['nullable', 'date'], 'valid_until' => ['nullable', 'date'], 'notes' => ['nullable', 'string', 'max:4000'], 'is_active' => ['nullable', 'boolean']]);
        $this->assertHttpUrl($data['url']);
        $source = $dataset->sources()->create($data + ['is_active' => $request->boolean('is_active', true)]);
        $this->audit->log($request->user(), 'source.created', $source, ['datasetKey' => $dataset->key, 'sourceId' => $source->id]);

        return back();
    }

    public function updateSource(Request $request, Dataset $dataset, DatasetSource $source): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        abort_unless($source->dataset_id === $dataset->id, 404);
        $data = $request->validate(['title' => ['required', 'string', 'max:255'], 'authority' => ['required', 'string', 'max:255'], 'url' => ['required', 'url', 'max:2048'], 'verified_at' => ['required', 'date'], 'valid_from' => ['nullable', 'date'], 'valid_until' => ['nullable', 'date'], 'notes' => ['nullable', 'string', 'max:4000'], 'is_active' => ['required', 'boolean']]);
        $this->assertHttpUrl($data['url']);
        $source->update($data);
        $this->audit->log($request->user(), 'source.updated', $source, ['datasetKey' => $dataset->key, 'sourceId' => $source->id]);

        return back();
    }

    public function storeRelease(Request $request, Dataset $dataset, ServiceProviderCatalogService $providers): RedirectResponse
    {
        Gate::authorize('datasets.edit');
        if ($request->boolean('generate_from_provider_catalog')) {
            return $this->storeProviderCatalogDraft($request, $dataset, $providers);
        }
        $request->validate(['dataset' => ['required', 'file', 'max:'.config('datasets.max_upload_kb')], 'verified_at' => ['nullable', 'date'], 'expires_at' => ['nullable', 'date']]);
        $file = $request->file('dataset');
        if (strtolower($file->getClientOriginalExtension()) !== 'json') {
            throw ValidationException::withMessages(['dataset' => 'Only JSON uploads are allowed.']);
        } try {
            $payload = json_decode($file->get(), true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            throw ValidationException::withMessages(['dataset' => 'The upload is not valid JSON.']);
        }
        if (! is_array($payload) || array_is_list($payload) || ! is_string($payload['version'] ?? null) || ! preg_match('/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/', $payload['version'])) {
            throw ValidationException::withMessages(['dataset' => 'The JSON version is required and unsafe versions are rejected.']);
        }
        $this->createDraft($dataset, $request, $payload, $file->get());

        return back();
    }

    private function storeProviderCatalogDraft(Request $request, Dataset $dataset, ServiceProviderCatalogService $providers): RedirectResponse
    {
        if ($dataset->key !== 'service_providers' || $dataset->schema_version !== 1 || ! $dataset->enabled) {
            throw ValidationException::withMessages(['dataset' => 'El dataset service_providers debe estar habilitado con schema 1.']);
        }
        $data = $request->validate([
            'version' => ['required', 'string', 'regex:/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/'],
            'generated_at' => ['required', 'string'],
            'preview_sha256' => ['required', 'regex:/^[a-f0-9]{64}$/'],
        ]);
        if (! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/', $data['generated_at'])) {
            throw ValidationException::withMessages(['generated_at' => 'La fecha de la vista previa debe incluir zona horaria.']);
        }

        $payload = $providers->publishedDatasetPayload($data['version'], Carbon::parse($data['generated_at']));
        if ($payload['providers'] === []) {
            throw ValidationException::withMessages(['dataset' => 'No hay fichas vigentes para generar un borrador.']);
        }
        $bytes = json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        if (! hash_equals($data['preview_sha256'], hash('sha256', $bytes))) {
            throw ValidationException::withMessages(['dataset' => 'Las fichas cambiaron después de la vista previa. Revisa el snapshot actualizado.']);
        }

        $expiresAt = null;
        foreach ($payload['providers'] as $provider) {
            $validUntil = Carbon::parse($provider['validUntil'], 'America/Bogota')->endOfDay();
            if ($expiresAt === null || $validUntil->isBefore($expiresAt)) {
                $expiresAt = $validUntil;
            }
        }
        if ($expiresAt === null || ! $expiresAt->isAfter(now())) {
            throw ValidationException::withMessages(['dataset' => 'La vigencia de las fichas venció; no se creó el borrador.']);
        }

        $release = $this->createDraft($dataset, $request, $payload, $bytes, $expiresAt);

        return redirect()->route('admin.datasets.show', $dataset)
            ->with('status', "Borrador {$release->version} listo para validar y revisar manualmente.");
    }

    /** @param array<string,mixed> $payload */
    private function createDraft(Dataset $dataset, Request $request, array $payload, string $bytes, ?Carbon $expiresAt = null): DatasetRelease
    {
        $path = "dataset-drafts/{$dataset->key}/".Str::uuid().'.json';
        if (Storage::disk(config('datasets.draft_disk'))->put($path, $bytes) === false) {
            throw ValidationException::withMessages(['dataset' => 'The draft could not be stored.']);
        }
        $release = $dataset->releases()->create([
            'version' => $payload['version'],
            'status' => DatasetReleaseStatus::Draft,
            'draft_path' => $path,
            'verified_at' => $request->input('verified_at'),
            'expires_at' => $expiresAt ?? $request->input('expires_at'),
        ]);
        $this->audit->log($request->user(), 'release.created', $release, ['datasetKey' => $dataset->key, 'version' => $release->version]);

        return $release;
    }

    public function validateRelease(Request $request, Dataset $dataset, DatasetRelease $release, DatasetReleaseValidator $validator): RedirectResponse
    {
        Gate::authorize('datasets.review');
        $this->belongs($dataset, $release);
        try {
            $validator->validate($release, $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['release' => $error->getMessage()]);
        }

        return back();
    }

    public function publish(Request $request, Dataset $dataset, DatasetRelease $release, DatasetPublisher $publisher): RedirectResponse
    {
        Gate::authorize('datasets.review');
        $this->belongs($dataset, $release);
        try {
            $publisher->publish($release, $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['release' => $error->getMessage()]);
        }

        return back();
    }

    public function rollback(Request $request, Dataset $dataset, DatasetRelease $release, DatasetPublisher $publisher): RedirectResponse
    {
        Gate::authorize('datasets.review');
        try {
            $publisher->rollback($dataset, $release, $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['release' => $error->getMessage()]);
        }

        return back();
    }

    public function retire(Request $request, Dataset $dataset, DatasetRelease $release, DatasetPublisher $publisher): RedirectResponse
    {
        Gate::authorize('datasets.review');
        try {
            $publisher->retire($dataset, $release, $request->user());
        } catch (DomainException $error) {
            return back()->withErrors(['release' => $error->getMessage()]);
        }

        return back();
    }

    private function belongs(Dataset $dataset, DatasetRelease $release): void
    {
        abort_unless($release->dataset_id === $dataset->id, 404);
    }

    private function assertHttpUrl(string $url): void
    {
        if (! in_array(parse_url($url, PHP_URL_SCHEME), ['http', 'https'], true)) {
            throw ValidationException::withMessages(['url' => 'Only HTTP(S) source URLs are allowed.']);
        }
    }
}
