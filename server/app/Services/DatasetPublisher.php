<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class DatasetPublisher
{
    public function __construct(private readonly ManifestPublisher $manifest, private readonly DatasetAuditLogger $audit) {}

    public function publish(DatasetRelease $release, User $actor): DatasetRelease
    {
        $release->loadMissing('dataset');
        if ($release->status === DatasetReleaseStatus::Published) {
            $this->manifest->regenerate();

            return $release;
        }
        if ($release->status !== DatasetReleaseStatus::Validated || ! $release->draft_path || ! $release->sha256) {
            throw new DomainException('Only a validated release can be published.');
        }
        $draft = Storage::disk(config('datasets.draft_disk'));
        $published = Storage::disk(config('datasets.published_disk'));
        if (! $draft->exists($release->draft_path)) {
            throw new DomainException('Draft file is unavailable.');
        } $bytes = $draft->get($release->draft_path);
        $sha = hash('sha256', $bytes);
        if (! hash_equals($release->sha256, $sha)) {
            throw new DomainException('Draft bytes changed after validation.');
        }
        $path = "datasets/{$release->dataset->key}/{$release->version}/{$release->dataset->key}-{$release->version}.json";
        if ($published->exists($path)) {
            if (! hash_equals($sha, hash('sha256', $published->get($path)))) {
                throw new DomainException('An immutable asset already exists with different bytes.');
            }
        } else {
            $published->put($path, $bytes);
            if (! hash_equals($sha, hash('sha256', $published->get($path)))) {
                throw new DomainException('Published asset verification failed.');
            }
        }

        return DB::transaction(function () use ($release, $actor, $path, $sha): DatasetRelease {
            $dataset = Dataset::query()->lockForUpdate()->findOrFail($release->dataset_id);
            $locked = DatasetRelease::query()->findOrFail($release->id);
            $locked->forceFill(['status' => DatasetReleaseStatus::Published, 'asset_path' => $path, 'sha256' => $sha, 'content_encoding' => null, 'published_at' => now()])->save();
            $previous = $dataset->current_version;
            $dataset->forceFill(['current_version' => $locked->version])->save();
            $this->manifest->regenerate();
            $this->audit->log($actor, 'release.published', $locked, ['datasetKey' => $dataset->key, 'version' => $locked->version, 'sha256' => $sha, 'previousVersion' => $previous]);

            return $locked->refresh();
        });
    }

    public function rollback(Dataset $dataset, DatasetRelease $target, User $actor): void
    {
        if ($target->dataset_id !== $dataset->id || $target->status !== DatasetReleaseStatus::Published) {
            throw new DomainException('Rollback target is not an eligible published release.');
        } DB::transaction(function () use ($dataset, $target, $actor): void {
            $locked = Dataset::query()->lockForUpdate()->findOrFail($dataset->id);
            $previous = $locked->current_version;
            $locked->update(['current_version' => $target->version]);
            $this->manifest->regenerate();
            $this->audit->log($actor, 'dataset.rollback', $locked, ['datasetKey' => $locked->key, 'previousVersion' => $previous, 'newVersion' => $target->version]);
        });
    }

    public function retire(Dataset $dataset, DatasetRelease $release, User $actor): void
    {
        if ($release->dataset_id !== $dataset->id || $release->status !== DatasetReleaseStatus::Published || $dataset->current_version === $release->version) {
            throw new DomainException('The current or non-published release cannot be retired.');
        } $release->update(['status' => DatasetReleaseStatus::Retired, 'retired_at' => now()]);
        $this->audit->log($actor, 'release.retired', $release, ['datasetKey' => $dataset->key, 'version' => $release->version]);
    }
}
