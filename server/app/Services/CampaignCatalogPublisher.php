<?php

namespace App\Services;

use App\Enums\CampaignStatus;
use App\Enums\SponsorStatus;
use App\Models\Campaign;
use App\Models\CampaignCatalogRelease;
use App\Models\User;
use Closure;
use DomainException;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

class CampaignCatalogPublisher
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function publish(?User $actor): CampaignCatalogRelease
    {
        return $this->withPublicationLock(fn (): CampaignCatalogRelease => $this->publishLocked($actor));
    }

    private function publishLocked(?User $actor): CampaignCatalogRelease
    {
        $disk = Storage::disk(config('campaigns.public_disk'));
        $generatedAt = now();
        $expiresAt = $generatedAt->copy()->addSeconds(config('campaigns.catalog_validity_seconds'));
        $version = ((int) CampaignCatalogRelease::query()->max('version')) + 1;

        $campaigns = Campaign::query()
            ->with(['sponsor', 'geographicUnit'])
            ->where('status', CampaignStatus::Active->value)
            ->where('placement', config('campaigns.placement'))
            ->where('ends_at', '>', $generatedAt)
            ->whereHas('sponsor', fn ($query) => $query->where('status', SponsorStatus::Active->value))
            ->orderBy('priority')
            ->orderBy('public_id')
            ->get();

        $entries = $campaigns->map(function (Campaign $campaign) use ($disk): array {
            if (! $campaign->public_image_path || ! $disk->exists($campaign->public_image_path)) {
                throw new DomainException("Published image is missing for campaign {$campaign->public_id}.");
            }
            $imageBytes = $disk->get($campaign->public_image_path);
            if (! hash_equals($campaign->image_sha256, hash('sha256', $imageBytes))) {
                throw new DomainException("Published image is corrupt for campaign {$campaign->public_id}.");
            }

            $entry = [
                'id' => $campaign->public_id,
                'sponsorId' => $campaign->sponsor->public_id,
                'kind' => 'sponsored',
                'label' => $campaign->eyebrow,
                'title' => $campaign->title,
                'subtitle' => $campaign->subtitle,
                'ctaText' => $campaign->cta_text,
                'targetUrl' => $campaign->cta_url,
                'imageUrl' => $this->url($campaign->public_image_path),
                'priority' => $campaign->priority,
                'placement' => $campaign->placement,
                'territory' => ['scope' => $campaign->scope->value],
                'startsAt' => $campaign->starts_at->toAtomString(),
                'endsAt' => $campaign->ends_at->toAtomString(),
            ];
            if ($campaign->geographicUnit) {
                $entry['territory']['code'] = $campaign->geographicUnit->code;
                $entry['territory']['key'] = $campaign->geographicUnit->key;
            }

            return $entry;
        })->all();

        $catalog = [
            'schemaVersion' => 1,
            'version' => $version,
            'generatedAt' => $generatedAt->toAtomString(),
            'expiresAt' => $expiresAt->toAtomString(),
            'campaigns' => $entries,
        ];
        $bytes = json_encode($catalog, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $sha256 = hash('sha256', $bytes);
        $assetPath = rtrim(config('campaigns.catalog_release_directory'), '/')."/catalog-{$version}.json";
        if ($disk->exists($assetPath)) {
            throw new DomainException("Campaign catalog release {$version} already exists.");
        }
        if ($disk->put($assetPath, $bytes) === false || ! hash_equals($sha256, hash('sha256', $disk->get($assetPath)))) {
            throw new DomainException('Campaign catalog release verification failed.');
        }

        try {
            $release = DB::transaction(function () use ($actor, $assetPath, $sha256, $entries, $generatedAt, $expiresAt, $version): CampaignCatalogRelease {
                $release = CampaignCatalogRelease::query()->create([
                    'version' => $version,
                    'asset_path' => $assetPath,
                    'sha256' => $sha256,
                    'campaign_count' => count($entries),
                    'generated_at' => $generatedAt,
                    'expires_at' => $expiresAt,
                    'published_by_id' => $actor?->id,
                ]);
                $this->audit->log($actor, 'campaign_catalog.published', $release, [
                    'version' => $version,
                    'sha256' => $sha256,
                    'campaignCount' => count($entries),
                ]);

                return $release;
            });
        } catch (Throwable $exception) {
            $disk->delete($assetPath);
            throw $exception;
        }

        $manifest = json_encode([
            'schemaVersion' => 1,
            'version' => $version,
            'generatedAt' => $generatedAt->toAtomString(),
            'expiresAt' => $expiresAt->toAtomString(),
            'url' => $this->url($assetPath),
            'sha256' => $sha256,
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $manifestPath = config('campaigns.catalog_manifest_path');
        $temporaryPath = $manifestPath.'.tmp-'.bin2hex(random_bytes(6));
        if ($disk->put($temporaryPath, $manifest) === false) {
            throw new DomainException('The temporary campaign catalog pointer could not be written.');
        }
        if ($disk->move($temporaryPath, $manifestPath) === false) {
            $disk->delete($temporaryPath);
            throw new DomainException('The campaign catalog pointer could not be atomically replaced.');
        }

        return $release;
    }

    /** @template T @param Closure(): T $operation @return T */
    private function withPublicationLock(Closure $operation): mixed
    {
        try {
            return Cache::lock(config('campaigns.publication_lock_name'), config('campaigns.publication_lock_seconds'))
                ->block(config('campaigns.publication_lock_wait_seconds'), $operation);
        } catch (LockTimeoutException) {
            throw new DomainException('Campaign catalog publication is busy; retry shortly.');
        }
    }

    private function url(string $path): string
    {
        return rtrim((string) config('campaigns.public_base_url'), '/').'/'.ltrim($path, '/');
    }
}
