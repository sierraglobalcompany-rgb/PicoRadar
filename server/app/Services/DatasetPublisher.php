<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use Closure;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class DatasetPublisher
{
    public function __construct(private readonly ManifestPublisher $manifest, private readonly DatasetAuditLogger $audit) {}

    public function publish(DatasetRelease $release, User $actor, ?int $expectedPublicationRevision = null, ?Closure $afterPublish = null, ?Closure $beforePublish = null): DatasetRelease
    {
        return $this->manifest->mutateAndRegenerate(function () use ($release, $actor, $expectedPublicationRevision, $afterPublish, $beforePublish): DatasetRelease {
            return DB::transaction(function () use ($release, $actor, $expectedPublicationRevision, $afterPublish, $beforePublish): DatasetRelease {
                $dataset = Dataset::query()->lockForUpdate()->findOrFail($release->dataset_id);
                $locked = DatasetRelease::query()->whereKey($release->id)->lockForUpdate()->firstOrFail();
                if ($locked->dataset_id !== $dataset->id) {
                    throw new DomainException('Release does not belong to the dataset.');
                }
                if ($expectedPublicationRevision !== null && $dataset->publication_revision !== $expectedPublicationRevision) {
                    throw new DomainException('The dataset changed after review; refresh the publication preview.');
                }
                if ($locked->status === DatasetReleaseStatus::Published) {
                    return $locked;
                }
                if ($locked->status !== DatasetReleaseStatus::Validated || ! $locked->draft_path || ! $locked->sha256) {
                    throw new DomainException('Only a validated release can be published.');
                }
                if ($dataset->key === 'service_providers' &&
                    (! $locked->expires_at || ! $locked->expires_at->isAfter(now()))) {
                    throw new DomainException('The service provider release has expired and cannot be published.');
                }
                if ($dataset->key === 'service_providers' && ! $this->hasCurrentValidatedSource($dataset, $locked)) {
                    throw new DomainException('A source approved during validation must still be active and current; validate the release again before publishing.');
                }
                if ($beforePublish !== null) {
                    $beforePublish($locked, $dataset);
                }
                $draft = Storage::disk(config('datasets.draft_disk'));
                $published = Storage::disk(config('datasets.published_disk'));
                if (! $draft->exists($locked->draft_path)) {
                    throw new DomainException('Draft file is unavailable.');
                }
                $bytes = $draft->get($locked->draft_path);
                $sha = hash('sha256', $bytes);
                if (! hash_equals($locked->sha256, $sha)) {
                    throw new DomainException('Draft bytes changed after validation.');
                }
                $path = "datasets/{$dataset->key}/{$locked->version}/{$dataset->key}-{$locked->version}.json";
                if ($published->exists($path)) {
                    if (! hash_equals($sha, hash('sha256', $published->get($path)))) {
                        throw new DomainException('An immutable asset already exists with different bytes.');
                    }
                } elseif ($published->put($path, $bytes) === false || ! hash_equals($sha, hash('sha256', $published->get($path)))) {
                    throw new DomainException('Published asset verification failed.');
                }
                $previous = $dataset->current_version;
                $locked->forceFill(['status' => DatasetReleaseStatus::Published, 'asset_path' => $path, 'content_encoding' => null, 'published_at' => now()])->save();
                $dataset->forceFill([
                    'current_version' => $locked->version,
                    'publication_revision' => $dataset->publication_revision + 1,
                ])->save();
                $this->audit->log($actor, 'release.published', $locked, ['datasetKey' => $dataset->key, 'version' => $locked->version, 'sha256' => $sha, 'previousVersion' => $previous]);
                if ($afterPublish !== null) {
                    $afterPublish($locked, $dataset, $previous);
                }

                return $locked->refresh();
            });
        });
    }

    private function hasCurrentValidatedSource(Dataset $dataset, DatasetRelease $release): bool
    {
        $approvedSources = $release->metadata['sources'] ?? null;
        if (! is_array($approvedSources) || ! array_is_list($approvedSources) || $approvedSources === []) {
            return false;
        }

        $approvedById = [];
        foreach ($approvedSources as $approved) {
            if (! is_array($approved) ||
                ! is_int($approved['id'] ?? null) ||
                $approved['id'] < 1 ||
                ! is_string($approved['authority'] ?? null) || trim($approved['authority']) === '' ||
                ! is_string($approved['url'] ?? null) ||
                ! is_string($approved['verifiedAt'] ?? null) ||
                $approved['verifiedAt'] === '' ||
                isset($approvedById[$approved['id']])) {
                return false;
            }
            $approvedById[$approved['id']] = $approved;
        }

        $sources = $dataset->sources()
            ->whereIn('id', array_keys($approvedById))
            ->lockForUpdate()
            ->get()
            ->keyBy('id');
        $now = now();

        foreach ($approvedById as $id => $approved) {
            /** @var \App\Models\DatasetSource|null $source */
            $source = $sources->get($id);
            if ($source === null ||
                $source->authority !== $approved['authority'] ||
                $source->url !== $approved['url'] ||
                $source->verified_at?->toAtomString() !== $approved['verifiedAt'] ||
                ! $source->is_active ||
                $source->verified_at === null ||
                $source->verified_at->isAfter($now) ||
                ($source->valid_from !== null && $source->valid_from->isAfter($now)) ||
                ($source->valid_until !== null && $source->valid_until->isBefore($now)) ||
                ! $this->isValidHttpsSourceUrl($source->url)) {
                continue;
            }

            return true;
        }

        return false;
    }

    private function isValidHttpsSourceUrl(string $url): bool
    {
        $parts = parse_url($url);

        return filter_var($url, FILTER_VALIDATE_URL) !== false &&
            is_array($parts) &&
            strtolower((string) ($parts['scheme'] ?? '')) === 'https' &&
            trim((string) ($parts['host'] ?? '')) !== '' &&
            ! isset($parts['user']) &&
            ! isset($parts['pass']);
    }

    public function rollback(Dataset $dataset, DatasetRelease $target, User $actor): void
    {
        $this->manifest->mutateAndRegenerate(function () use ($dataset, $target, $actor): void {
            DB::transaction(function () use ($dataset, $target, $actor): void {
                $locked = Dataset::query()->lockForUpdate()->findOrFail($dataset->id);
                $release = DatasetRelease::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
                if ($release->dataset_id !== $locked->id || $release->status !== DatasetReleaseStatus::Published || ! $release->asset_path || ! $release->sha256) {
                    throw new DomainException('Rollback target is not an eligible published release.');
                }
                $disk = Storage::disk(config('datasets.published_disk'));
                if (! $disk->exists($release->asset_path) || ! hash_equals($release->sha256, hash('sha256', $disk->get($release->asset_path)))) {
                    throw new DomainException('Rollback target asset is missing or corrupt.');
                }
                if ($locked->current_version === $release->version) {
                    return;
                }
                $previous = $locked->current_version;
                $locked->forceFill([
                    'current_version' => $release->version,
                    'publication_revision' => $locked->publication_revision + 1,
                ])->save();
                $this->audit->log($actor, 'dataset.rollback', $locked, ['datasetKey' => $locked->key, 'previousVersion' => $previous, 'newVersion' => $release->version]);
            });
        });
    }

    public function retire(Dataset $dataset, DatasetRelease $release, User $actor): void
    {
        $this->manifest->mutateAndRegenerate(function () use ($dataset, $release, $actor): void {
            DB::transaction(function () use ($dataset, $release, $actor): void {
                $locked = Dataset::query()->lockForUpdate()->findOrFail($dataset->id);
                $target = DatasetRelease::query()->whereKey($release->id)->lockForUpdate()->firstOrFail();
                if ($target->dataset_id !== $locked->id || $target->status !== DatasetReleaseStatus::Published || $locked->current_version === $target->version) {
                    throw new DomainException('The current or non-published release cannot be retired.');
                }
                $target->forceFill(['status' => DatasetReleaseStatus::Retired, 'retired_at' => now()])->save();
                $this->audit->log($actor, 'release.retired', $target, ['datasetKey' => $locked->key, 'version' => $target->version]);
            });
        });
    }
}
