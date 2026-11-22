<?php

namespace App\Services;

use App\Models\GeographicUnit;
use App\Models\ServiceProvider;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ServiceProviderCatalogService
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    /** @param array<string, mixed> $filters */
    public function query(array $filters): Builder
    {
        return ServiceProvider::query()
            ->with(['department', 'municipality'])
            ->when($filters['category'] ?? null, fn (Builder $query, string $category) => $query->where('category', $category))
            ->when($filters['status'] ?? null, fn (Builder $query, string $status) => $query->where('status', $status))
            ->when($filters['department_code'] ?? null, fn (Builder $query, string $code) => $query->where('department_code', $code))
            ->when($filters['municipality_code'] ?? null, fn (Builder $query, string $code) => $query->where('municipality_code', $code))
            ->orderBy('department_code')
            ->orderBy('municipality_code')
            ->orderBy('name');
    }

    /** @param array<string, mixed> $attributes */
    public function create(array $attributes, User $actor): ServiceProvider
    {
        return DB::transaction(function () use ($attributes, $actor): ServiceProvider {
            $provider = new ServiceProvider;
            $provider->fill($attributes);
            $this->assertTerritory($provider);
            $this->assertCoordinates($provider);
            $this->assertPublishable($provider);
            $provider->save();

            $this->audit->log($actor, 'service_provider.created', $provider, $this->auditMetadata($provider, array_keys($attributes)));

            return $provider;
        });
    }

    /** @param array<string, mixed> $attributes */
    public function update(ServiceProvider $provider, array $attributes, User $actor): ServiceProvider
    {
        return DB::transaction(function () use ($provider, $attributes, $actor): ServiceProvider {
            $before = [
                'status' => $provider->status,
                'category' => $provider->category,
                'department_code' => $provider->department_code,
                'municipality_code' => $provider->municipality_code,
            ];
            $provider->fill($attributes);
            $this->assertTerritory($provider);
            $this->assertCoordinates($provider);
            $this->assertPublishable($provider);
            $changedFields = array_keys($provider->getDirty());
            $provider->save();

            if ($changedFields !== []) {
                $this->audit->log($actor, 'service_provider.updated', $provider, [
                    ...$this->auditMetadata($provider, $changedFields),
                    'before' => $before,
                ]);
            }

            return $provider;
        });
    }

    public function departments(): \Illuminate\Support\Collection
    {
        return GeographicUnit::query()
            ->where('level', 'department')
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'code', 'name']);
    }

    public function municipalities(): \Illuminate\Support\Collection
    {
        return GeographicUnit::query()
            ->with('parent:id,code,name')
            ->where('level', 'municipality')
            ->where('is_active', true)
            ->orderBy('name')
            ->get(['id', 'parent_id', 'code', 'name']);
    }

    /** @return list<array<string, mixed>> */
    public function publishedDatasetRecords(): array
    {
        return ServiceProvider::query()
            ->where('status', 'published')
            ->orderBy('department_code')
            ->orderBy('municipality_code')
            ->orderBy('name')
            ->get()
            ->map(fn (ServiceProvider $provider): ?array => $provider->toPublishedDatasetRecord())
            ->filter()
            ->values()
            ->all();
    }

    private function assertTerritory(ServiceProvider $provider): void
    {
        $department = GeographicUnit::query()
            ->where('level', 'department')
            ->where('code', $provider->department_code)
            ->where('is_active', true)
            ->first();

        $municipality = GeographicUnit::query()
            ->where('level', 'municipality')
            ->where('code', $provider->municipality_code)
            ->where('is_active', true)
            ->first();

        if ($department === null) {
            throw ValidationException::withMessages(['department_code' => 'Selecciona un departamento DIVIPOLA activo.']);
        }

        if ($municipality === null || $municipality->parent_id !== $department->id) {
            throw ValidationException::withMessages(['municipality_code' => 'El municipio debe pertenecer al departamento seleccionado.']);
        }
    }

    private function assertCoordinates(ServiceProvider $provider): void
    {
        if (($provider->latitude === null) !== ($provider->longitude === null)) {
            throw ValidationException::withMessages(['latitude' => 'Registra latitud y longitud juntas, o deja ambas vacías.']);
        }
    }

    private function assertPublishable(ServiceProvider $provider): void
    {
        if ($provider->status === 'published' && ! $provider->hasCurrentSourceEvidence()) {
            throw ValidationException::withMessages(['source_url' => 'Para publicar se requiere una fuente HTTPS revisada y vigente.']);
        }
    }

    /** @param list<string> $changedFields
     *  @return array<string, mixed>
     */
    private function auditMetadata(ServiceProvider $provider, array $changedFields): array
    {
        return [
            'category' => $provider->category,
            'department_code' => $provider->department_code,
            'municipality_code' => $provider->municipality_code,
            'status' => $provider->status,
            'changed_fields' => array_values($changedFields),
        ];
    }
}
