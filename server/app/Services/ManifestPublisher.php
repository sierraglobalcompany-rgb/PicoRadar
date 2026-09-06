<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\Dataset;
use Closure;
use DomainException;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;

class ManifestPublisher
{
    /** @return array<string,mixed> */
    public function regenerate(): array
    {
        return $this->withPublicationLock(fn (): array => $this->regenerateLocked());
    }

    /** @template T @param Closure(): T $mutation @return T */
    public function mutateAndRegenerate(Closure $mutation): mixed
    {
        return $this->withPublicationLock(function () use ($mutation): mixed {
            $result = $mutation();
            $this->regenerateLocked();

            return $result;
        });
    }

    public function assertDatasetCanBeManifested(Dataset $dataset): void
    {
        $this->entryFor($dataset, Storage::disk(config('datasets.published_disk')));
    }

    /** @return array<string,mixed> */
    private function regenerateLocked(): array
    {
        $disk = Storage::disk(config('datasets.published_disk'));
        $entries = [];
        foreach (Dataset::query()->where('enabled', true)->whereNotNull('current_version')->orderBy('key')->get() as $dataset) {
            $entries[$dataset->key] = $this->entryFor($dataset, $disk);
        }
        $manifest = ['schemaVersion' => 1, 'generatedAt' => now()->toAtomString(), 'minAppVersion' => config('datasets.min_app_version'), 'datasets' => $entries, 'features' => config('datasets.features')];
        $path = config('datasets.manifest_path');
        $temp = $path.'.tmp-'.bin2hex(random_bytes(6));
        $json = json_encode($manifest, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        if ($disk->put($temp, $json) === false) {
            throw new DomainException('The temporary manifest could not be written.');
        }
        if ($disk->move($temp, $path) === false) {
            throw new DomainException('The manifest could not be atomically replaced.');
        }

        return $manifest;
    }

    /** @return array<string,mixed> */
    private function entryFor(Dataset $dataset, $disk): array
    {
        $release = $dataset->releases()->where('version', $dataset->current_version)->first();
        if (! $release || $release->status !== DatasetReleaseStatus::Published || ! $release->asset_path || ! $release->sha256 || ! $disk->exists($release->asset_path) || ! hash_equals($release->sha256, hash('sha256', $disk->get($release->asset_path)))) {
            throw new DomainException("Dataset pointer is inconsistent for {$dataset->key}.");
        }
        $entry = ['version' => $release->version, 'url' => $this->url($release->asset_path), 'sha256' => $release->sha256, 'publicationRevision' => $dataset->publication_revision];
        if ($release->content_encoding) {
            $entry['contentEncoding'] = $release->content_encoding;
        }
        if ($release->expires_at) {
            $entry['expiresAt'] = $release->expires_at->toAtomString();
        }

        return $entry;
    }

    /** @template T @param Closure(): T $operation @return T */
    private function withPublicationLock(Closure $operation): mixed
    {
        try {
            return Cache::lock(config('datasets.manifest_lock_name'), config('datasets.manifest_lock_seconds'))
                ->block(config('datasets.manifest_lock_wait_seconds'), $operation);
        } catch (LockTimeoutException) {
            throw new DomainException('Dataset publication is busy; retry shortly.');
        }
    }

    private function url(string $path): string
    {
        return rtrim((string) config('datasets.public_base_url'), '/').'/'.ltrim($path, '/');
    }
}
