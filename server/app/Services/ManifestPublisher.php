<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\Dataset;
use DomainException;
use Illuminate\Support\Facades\Storage;

class ManifestPublisher
{
    /** @return array<string,mixed> */
    public function regenerate(): array
    {
        $disk = Storage::disk(config('datasets.published_disk'));
        $entries = [];
        foreach (Dataset::query()->where('enabled', true)->whereNotNull('current_version')->orderBy('key')->get() as $dataset) {
            $release = $dataset->releases()->where('version', $dataset->current_version)->first();
            if (! $release || $release->status !== DatasetReleaseStatus::Published || ! $release->asset_path || ! $release->sha256 || ! $disk->exists($release->asset_path) || hash('sha256', $disk->get($release->asset_path)) !== $release->sha256) {
                throw new DomainException("Dataset pointer is inconsistent for {$dataset->key}.");
            }
            $entry = ['version' => $release->version, 'url' => $this->url($release->asset_path), 'sha256' => $release->sha256];
            if ($release->content_encoding) {
                $entry['contentEncoding'] = $release->content_encoding;
            }
            if ($release->expires_at) {
                $entry['expiresAt'] = $release->expires_at->toAtomString();
            }
            $entries[$dataset->key] = $entry;
        }
        $manifest = ['schemaVersion' => 1, 'generatedAt' => now()->toAtomString(), 'minAppVersion' => config('datasets.min_app_version'), 'datasets' => $entries, 'features' => config('datasets.features')];
        $path = config('datasets.manifest_path');
        $temp = $path.'.tmp-'.bin2hex(random_bytes(6));
        $disk->put($temp, json_encode($manifest, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        $disk->move($temp, $path);

        return $manifest;
    }

    private function url(string $path): string
    {
        return rtrim((string) config('datasets.public_base_url'), '/').'/'.ltrim($path, '/');
    }
}
