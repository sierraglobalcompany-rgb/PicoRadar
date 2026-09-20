<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\RestrictionPublication;
use App\Models\RestrictionPublicationItem;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\Storage;

final class RestrictionPublicationService
{
    public function __construct(
        private readonly RestrictionPayloadEncoder $encoder,
        private readonly RestrictionContractValidator $validator,
        private readonly DatasetReleaseValidator $releaseValidator,
        private readonly DatasetPublisher $publisher,
    ) {}

    /** @param list<int> $versionIds */
    public function publish(array $versionIds, int $expectedPublicationRevision, User $actor): DatasetRelease
    {
        return $this->publishVersions($versionIds, $expectedPublicationRevision, $actor, 'publish');
    }

    public function rollbackCity(RestrictionRuleVersion $target, int $expectedPublicationRevision, User $actor): DatasetRelease
    {
        if (! RestrictionPublicationItem::query()->where('jurisdiction_id', $target->jurisdiction_id)->where('restriction_rule_version_id', $target->id)->exists()) {
            throw new DomainException('Rollback target was never published for this jurisdiction.');
        }

        return $this->publishVersions([$target->id], $expectedPublicationRevision, $actor, 'rollback');
    }

    /** @param list<int> $versionIds */
    private function publishVersions(array $versionIds, int $expectedPublicationRevision, User $actor, string $action): DatasetRelease
    {
        if ($versionIds === []) {
            throw new DomainException('At least one city rule version must be selected.');
        }
        $dataset = Dataset::query()->where('key', 'restrictions')->firstOrFail();
        if ($dataset->publication_revision !== $expectedPublicationRevision) {
            throw new DomainException('The dataset changed after review; refresh the publication preview.');
        }
        $versions = RestrictionRuleVersion::query()->with('jurisdiction')->whereIn('id', array_values(array_unique($versionIds)))->orderBy('id')->get();
        if ($versions->count() !== count(array_unique($versionIds))) {
            throw new DomainException('A selected city rule version does not exist.');
        }
        if ($versions->pluck('jurisdiction_id')->unique()->count() !== $versions->count()) {
            throw new DomainException('Only one rule version per jurisdiction can be published.');
        }
        foreach ($versions as $version) {
            if ($version->status !== RestrictionRuleVersionStatus::Validated) {
                throw new DomainException('Only validated city rule versions can be published.');
            }
            $this->validator->validateJurisdiction($version->payload, $version->jurisdiction->key);
            if ($action === 'publish') {
                $latest = RestrictionPublicationItem::query()
                    ->where('jurisdiction_id', $version->jurisdiction_id)
                    ->join('restriction_publications', 'restriction_publications.id', '=', 'restriction_publication_items.restriction_publication_id')
                    ->orderByDesc('restriction_publications.result_publication_revision')
                    ->first();
                if ($latest && $latest->restriction_rule_version_id !== $version->id && $latest->result_publication_revision > $version->base_publication_revision) {
                    throw new DomainException('This city changed after the draft was created; duplicate it from the current version.');
                }
            }
        }

        $payload = $this->currentPayload($dataset);
        $selected = $versions->keyBy(fn (RestrictionRuleVersion $version): string => $version->jurisdiction->key);
        $merged = [];
        $changed = 0;
        foreach ($payload['jurisdictions'] as $city) {
            $key = (string) ($city['id'] ?? '');
            if (isset($selected[$key])) {
                if ($this->encoder->encode($selected[$key]->payload) !== $this->encoder->encode($city)) {
                    $changed++;
                }
                $merged[] = $selected[$key]->payload;
            } else {
                $merged[] = $city;
            }
            $selected->forget($key);
        }
        foreach ($selected as $version) {
            $merged[] = $version->payload;
            $changed++;
        }
        if ($changed === 0) {
            throw new DomainException('The selected city rules are already active.');
        }
        $payload['jurisdictions'] = $merged;
        $payload['generatedAt'] = now()->utc()->format('Y-m-d\TH:i:s\Z');
        $payload['version'] = 'r'.($expectedPublicationRevision + 1).'-'.substr(hash('sha256', $this->encoder->encode($merged)), 0, 12);
        $bytes = $this->encoder->encode($payload);
        $path = "dataset-drafts/restrictions/{$payload['version']}.json";
        if (Storage::disk(config('datasets.draft_disk'))->put($path, $bytes) === false) {
            throw new DomainException('The merged restriction draft could not be stored.');
        }
        $release = $dataset->releases()->create([
            'version' => $payload['version'],
            'status' => DatasetReleaseStatus::Draft,
            'draft_path' => $path,
            'metadata' => ['restrictionRuleVersionIds' => $versions->pluck('id')->all(), 'action' => $action],
        ]);
        $release = $this->releaseValidator->validate($release, $actor);
        $previousByJurisdiction = [];
        foreach ($versions as $version) {
            $previousByJurisdiction[$version->jurisdiction_id] = RestrictionPublicationItem::query()
                ->where('jurisdiction_id', $version->jurisdiction_id)
                ->join('restriction_publications', 'restriction_publications.id', '=', 'restriction_publication_items.restriction_publication_id')
                ->orderByDesc('restriction_publications.result_publication_revision')
                ->value('restriction_rule_version_id');
        }

        return $this->publisher->publish(
            $release,
            $actor,
            $expectedPublicationRevision,
            function (DatasetRelease $published, Dataset $lockedDataset) use ($versions, $previousByJurisdiction, $expectedPublicationRevision, $actor, $action): void {
                $publication = RestrictionPublication::query()->create([
                    'dataset_release_id' => $published->id,
                    'action' => $action,
                    'base_publication_revision' => $expectedPublicationRevision,
                    'result_publication_revision' => $lockedDataset->publication_revision,
                    'actor_id' => $actor->id,
                    'summary' => ['jurisdictionCount' => $versions->count(), 'versionIds' => $versions->pluck('id')->all()],
                ]);
                foreach ($versions as $version) {
                    $publication->items()->create([
                        'jurisdiction_id' => $version->jurisdiction_id,
                        'restriction_rule_version_id' => $version->id,
                        'previous_rule_version_id' => $previousByJurisdiction[$version->jurisdiction_id],
                        'action' => $action,
                    ]);
                }
            },
        );
    }

    /** @return array<string,mixed> */
    private function currentPayload(Dataset $dataset): array
    {
        if ($dataset->current_version === null) {
            return ['schemaVersion' => $dataset->schema_version, 'datasetKey' => 'restrictions', 'version' => 'empty', 'generatedAt' => now()->utc()->format('Y-m-d\TH:i:s\Z'), 'jurisdictions' => []];
        }
        $release = $dataset->releases()->where('version', $dataset->current_version)->firstOrFail();
        if (! $release->asset_path || ! $release->sha256) {
            throw new DomainException('The current restriction release is incomplete.');
        }
        $disk = Storage::disk(config('datasets.published_disk'));
        if (! $disk->exists($release->asset_path)) {
            throw new DomainException('The current restriction asset is missing.');
        }
        $bytes = $disk->get($release->asset_path);
        if (! hash_equals($release->sha256, hash('sha256', $bytes))) {
            throw new DomainException('The current restriction asset is corrupt.');
        }
        $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        if (! is_array($payload) || ! isset($payload['jurisdictions']) || ! is_array($payload['jurisdictions'])) {
            throw new DomainException('The current restriction asset is invalid.');
        }

        return $payload;
    }
}
