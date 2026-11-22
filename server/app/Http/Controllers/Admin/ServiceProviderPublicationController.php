<?php

namespace App\Http\Controllers\Admin;

use App\Enums\DatasetReleaseStatus;
use App\Http\Controllers\Controller;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\ServiceProvider;
use App\Services\ServiceProviderCatalogService;
use DomainException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;
use Throwable;

final class ServiceProviderPublicationController extends Controller
{
    public function index(Request $request, ServiceProviderCatalogService $catalog): View
    {
        Gate::authorize('datasets.view');

        $dataset = Dataset::query()
            ->with('sources')
            ->where('key', ServiceProvider::DATASET_KEY)
            ->first();
        $blockers = [];
        $snapshot = null;
        $diff = ['added' => 0, 'changed' => 0, 'removed' => 0];

        if ($dataset === null) {
            $blockers[] = 'Crea primero el dataset service_providers con schema 1.';
        } else {
            if ($dataset->schema_version !== 1) {
                $blockers[] = 'El dataset debe conservar schema_version 1.';
            }
            if (! $dataset->enabled) {
                $blockers[] = 'El dataset está deshabilitado.';
            }
            if (! $this->hasCurrentHttpsSource($dataset)) {
                $blockers[] = 'Agrega una fuente HTTPS activa, verificada y vigente en el registro del dataset.';
            }

            try {
                $generatedAt = now();
                $version = 'sp-'.now()->format('Ymd-His').'-'.bin2hex(random_bytes(4));
                $payload = $catalog->publishedDatasetPayload($version, $generatedAt);
                if ($payload['providers'] === []) {
                    $blockers[] = 'No hay fichas aprobadas con fuente vigente para generar un snapshot.';
                }
                $previous = $this->currentPublishedProviders($dataset);
                $diff = $this->diff($previous, $payload['providers']);
                $bytes = json_encode(
                    $payload,
                    JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE,
                );
                $snapshot = [
                    'version' => $version,
                    'generatedAt' => $generatedAt->toAtomString(),
                    'sha256' => hash('sha256', $bytes),
                    'count' => count($payload['providers']),
                    'firstValidUntil' => $this->firstValidUntil($payload['providers']),
                ];
            } catch (Throwable $error) {
                report($error);
                $blockers[] = 'No se pudo verificar el snapshot vigente; revisa el registro de releases.';
            }
        }

        return view('admin.service-providers.publication', [
            'dataset' => $dataset,
            'snapshot' => $snapshot,
            'diff' => $diff,
            'blockers' => $blockers,
            'canCreateDraft' => $request->user()?->can('datasets.edit') === true,
        ]);
    }

    /** @param list<array<string,mixed>> $records */
    private function firstValidUntil(array $records): ?string
    {
        $dates = array_column($records, 'validUntil');
        sort($dates, SORT_STRING);

        return $dates[0] ?? null;
    }

    private function hasCurrentHttpsSource(Dataset $dataset): bool
    {
        return $dataset->sources->contains(function ($source): bool {
            $parts = parse_url((string) $source->url);
            $now = now();

            return $source->is_active
                && trim((string) $source->authority) !== ''
                && $source->verified_at !== null
                && ! $source->verified_at->isAfter($now)
                && ($source->valid_from === null || ! $source->valid_from->isAfter($now))
                && ($source->valid_until === null || ! $source->valid_until->isBefore($now))
                && is_array($parts)
                && strtolower((string) ($parts['scheme'] ?? '')) === 'https'
                && trim((string) ($parts['host'] ?? '')) !== ''
                && ! isset($parts['user'])
                && ! isset($parts['pass']);
        });
    }

    /** @return list<array<string,mixed>> */
    private function currentPublishedProviders(Dataset $dataset): array
    {
        if (! $dataset->current_version) {
            return [];
        }
        $release = DatasetRelease::query()
            ->where('dataset_id', $dataset->id)
            ->where('version', $dataset->current_version)
            ->first();
        if (! $release || $release->status !== DatasetReleaseStatus::Published ||
            ! $release->asset_path || ! $release->sha256) {
            throw new DomainException('El puntero de la publicación actual no es válido.');
        }
        $disk = Storage::disk(config('datasets.published_disk'));
        if (! $disk->exists($release->asset_path)) {
            throw new DomainException('El snapshot publicado no está disponible.');
        }
        $bytes = $disk->get($release->asset_path);
        if (! hash_equals($release->sha256, hash('sha256', $bytes))) {
            throw new DomainException('El hash del snapshot actual no coincide.');
        }
        $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        if (! is_array($payload) ||
            ($payload['datasetKey'] ?? null) !== ServiceProvider::DATASET_KEY ||
            ! is_array($payload['providers'] ?? null) ||
            ! array_is_list($payload['providers'])) {
            throw new DomainException('El snapshot publicado no cumple el contrato service_providers.');
        }

        return $payload['providers'];
    }

    /** @param list<array<string,mixed>> $before @param list<array<string,mixed>> $after @return array{added:int,changed:int,removed:int} */
    private function diff(array $before, array $after): array
    {
        $old = [];
        foreach ($before as $row) {
            if (is_array($row) && is_string($row['id'] ?? null)) {
                $old[$row['id']] = $row;
            }
        }
        $new = [];
        foreach ($after as $row) {
            if (is_array($row) && is_string($row['id'] ?? null)) {
                $new[$row['id']] = $row;
            }
        }
        $added = 0;
        $changed = 0;
        foreach ($new as $id => $row) {
            if (! array_key_exists($id, $old)) {
                $added++;
            } elseif ($this->canonicalRow($old[$id]) !== $this->canonicalRow($row)) {
                $changed++;
            }
        }

        return [
            'added' => $added,
            'changed' => $changed,
            'removed' => count(array_diff_key($old, $new)),
        ];
    }

    /** @param array<string,mixed> $row */
    private function canonicalRow(array $row): string
    {
        ksort($row);

        return json_encode($row, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }
}
