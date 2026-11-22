<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\AuditLog;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\Jurisdiction;
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
        private readonly DatasetAuditLogger $audit,
    ) {}

    /** @param list<int> $versionIds */
    public function publish(array $versionIds, int $expectedPublicationRevision, User $actor): DatasetRelease
    {
        return $this->publishVersions($versionIds, $expectedPublicationRevision, $actor, 'publish');
    }

    /** @return array<string,mixed> */
    public function materialChangePreview(RestrictionRuleVersion $version, int $expectedPublicationRevision): array
    {
        $version->loadMissing('jurisdiction');
        $dataset = Dataset::query()->where('key', 'restrictions')->firstOrFail();
        if ((int) $dataset->schema_version !== 2) {
            throw new DomainException('Editorial material approval is only available for schema2 datasets.');
        }
        if ($dataset->publication_revision !== $expectedPublicationRevision) {
            throw new DomainException('The dataset changed after review; refresh the publication preview.');
        }
        if ($version->status !== RestrictionRuleVersionStatus::Validated) {
            throw new DomainException('Only validated city rule versions can be approved.');
        }
        $proposed = $version->payload;
        $proposedSha = hash('sha256', $this->encoder->encode($proposed));
        if (! hash_equals((string) $version->payload_sha256, $proposedSha)) {
            throw new DomainException('The validated city payload changed after validation.');
        }
        $this->assertMunicipalityCodesBelongToJurisdiction($version->jurisdiction, $proposed);
        $payload = $this->currentPayload($dataset);
        $current = null;
        foreach ($payload['jurisdictions'] as $city) {
            if (($city['id'] ?? null) === $version->jurisdiction->key) {
                $current = $city;
                break;
            }
        }
        $before = $this->materialEvidence($current);
        $after = $this->materialEvidence($proposed);
        $ruleDiff = $this->ruleDiff($current, $proposed);
        $coverageIdentities = $this->coverageIdentities($proposed);
        $changes = $this->materialChanges($current, $proposed);
        $diff = [
            'changes' => $changes,
            'coverageIdentities' => $coverageIdentities,
            'ruleDiff' => $ruleDiff,
            'beforeSha256' => $before['sha256'],
            'afterSha256' => $after['sha256'],
        ];

        return [
            'versionId' => $version->id,
            'jurisdictionId' => $version->jurisdiction->key,
            'publicationRevision' => $expectedPublicationRevision,
            'authorId' => $version->created_by_id,
            'updatedById' => $version->updated_by_id,
            'changes' => $changes,
            'before' => $before,
            'after' => $after,
            'coverageIdentities' => $coverageIdentities,
            'ruleDiff' => $ruleDiff,
            'sources' => $this->sources($proposed),
            'sourceCheckedAt' => $version->source_checked_at?->toIso8601String(),
            'staleAfter' => $version->stale_after?->toIso8601String(),
            'proposedCitySha256' => $after['sha256'],
            'baseCitySha256' => $before['sha256'],
            'diffSha256' => hash('sha256', $this->encoder->encode($diff)),
        ];
    }

    public function approveMaterialChange(
        RestrictionRuleVersion $version,
        int $expectedPublicationRevision,
        User $reviewer,
        string $reason,
        string $evidenceUrl,
    ): AuditLog {
        $reviewer = User::query()->findOrFail($reviewer->id);
        if (! $reviewer->isActive() || ! in_array($reviewer->role, [OperatorRole::Admin, OperatorRole::SuperAdmin], true)) {
            throw new DomainException('Only an active administrator can approve a material restriction change.');
        }
        if (in_array($reviewer->id, [$version->created_by_id, $version->updated_by_id], true)) {
            throw new DomainException('The author or last editor cannot approve their own restriction version.');
        }
        $reason = trim($reason);
        if (mb_strlen($reason) < 10 || mb_strlen($reason) > 1000) {
            throw new DomainException('The editorial reason must contain 10 to 1000 characters.');
        }
        $preview = $this->materialChangePreview($version, $expectedPublicationRevision);
        if ($preview['changes'] === []) {
            throw new DomainException('This version has no material change to approve.');
        }
        if (collect($preview['changes'])->contains(fn (string $change): bool => str_starts_with($change, 'coverage_marked_complete'))) {
            throw new DomainException('COVERAGE_COMPLETE_REQUIRES_SPATIAL_QA: editorial approval cannot mark coverage complete.');
        }
        $this->assertCurrentOfficialSources($version, $preview, $evidenceUrl);

        $existing = AuditLog::query()
            ->where('action', 'restriction.material_change.approved')
            ->where('subject_type', RestrictionRuleVersion::class)
            ->where('subject_id', $version->id)
            ->orderBy('id')
            ->get();
        if ($existing->isNotEmpty()) {
            foreach ($existing as $event) {
                if ($event->actor_id === $reviewer->id && $this->approvalMetadataMatches($event->metadata ?? [], $preview, $reason, $evidenceUrl, $reviewer)) {
                    return $event;
                }
            }
            throw new DomainException('This validated version already has an editorial event; create a new version for changed content or revision.');
        }

        $this->audit->log($reviewer, 'restriction.material_change.approved', $version, [
            ...$this->approvalMetadata($preview),
            'reviewerId' => $reviewer->id,
            'reviewerRole' => $reviewer->role->value,
            'reason' => $reason,
            'evidenceUrl' => $evidenceUrl,
            'approvedAt' => now()->utc()->toIso8601String(),
            'classification' => 'EDITORIAL_APPROVAL_ONLY',
        ]);

        return AuditLog::query()
            ->where('action', 'restriction.material_change.approved')
            ->where('subject_type', RestrictionRuleVersion::class)
            ->where('subject_id', $version->id)
            ->where('actor_id', $reviewer->id)
            ->latest('id')
            ->firstOrFail();
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
            if (! $version->jurisdiction->enabled) {
                $this->validator->assertOffSchema2Payload($version->jurisdiction, $version->payload);
            }
            if ($version->status !== RestrictionRuleVersionStatus::Validated) {
                throw new DomainException('Only validated city rule versions can be published.');
            }
            $this->validator->validateJurisdictionForEnvelope($version->payload, $version->jurisdiction->key, (int) $dataset->schema_version);
            $this->assertMunicipalityCodesBelongToJurisdiction($version->jurisdiction, $version->payload);
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
        $materialReviews = [];
        if ($action === 'publish' && (int) $dataset->schema_version === 2) {
            foreach ($selected as $key => $version) {
                $preview = $this->materialChangePreview($version, $expectedPublicationRevision);
                foreach ($preview['changes'] as $change) {
                    $materialReviews[] = [
                        'version' => $version,
                        'jurisdictionId' => $key,
                        'change' => $change,
                        'before' => $preview['before'],
                        'after' => $preview['after'],
                    ];
                }
            }
        }
        foreach ($payload['jurisdictions'] as $city) {
            $key = (string) ($city['id'] ?? '');
            if (isset($selected[$key])) {
                if ($action === 'publish') {
                    $this->assertCoverageIdentitiesPreserved($city, $selected[$key]->payload);
                }
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
        if ($materialReviews !== []) {
            $approvalRequired = [];
            foreach ($materialReviews as $review) {
                if (str_starts_with($review['change'], 'coverage_marked_complete')) {
                    $approvalRequired[] = $review;

                    continue;
                }
                if (! $this->hasMatchingMaterialApproval(
                    $review['version'],
                    $expectedPublicationRevision,
                    $review['before'],
                    $review['after'],
                )) {
                    $approvalRequired[] = $review;
                }
            }
            if ($approvalRequired !== []) {
                foreach ($approvalRequired as $review) {
                    $this->audit->log($actor, 'restriction.material_change.review_required', $review['version'], [
                        'classification' => 'REVIEW_REQUIRED',
                        'jurisdictionId' => $review['jurisdictionId'],
                        'publicationRevision' => $expectedPublicationRevision,
                        'change' => $review['change'],
                        'before' => $review['before'],
                        'after' => $review['after'],
                        'reason' => str_starts_with($review['change'], 'coverage_marked_complete')
                            ? 'Complete coverage requires spatial QA and cannot be authorized by editorial approval.'
                            : 'No matching independent editorial approval exists for this version, content, and publication revision.',
                    ]);
                }
                $hasCompleteCoverageChange = collect($approvalRequired)->contains(
                    fn (array $review): bool => str_starts_with($review['change'], 'coverage_marked_complete'),
                );
                if ($hasCompleteCoverageChange) {
                    throw new DomainException('COVERAGE_COMPLETE_REQUIRES_SPATIAL_QA: editorial approval cannot mark coverage complete.');
                }
                throw new DomainException('REVIEW_REQUIRED: material restriction changes need a matching independent editorial approval.');
            }
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
            function (DatasetRelease $_release, Dataset $lockedDataset) use ($versions): void {
                $jurisdictions = Jurisdiction::query()
                    ->whereKey($versions->pluck('jurisdiction_id')->unique()->all())
                    ->orderBy('id')
                    ->lockForUpdate()
                    ->get()
                    ->keyBy('id');
                foreach ($versions as $version) {
                    $jurisdiction = $jurisdictions->get($version->jurisdiction_id);
                    if ($jurisdiction === null) {
                        throw new DomainException('A selected jurisdiction no longer exists.');
                    }
                    if (! $jurisdiction->enabled) {
                        if ((int) $lockedDataset->schema_version !== 2) {
                            throw new DomainException('OFF jurisdictions cannot publish a new restriction version under schema1.');
                        }
                        $this->validator->assertOffSchema2Payload($jurisdiction, $version->payload);
                    }
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

    /** @param array<string,mixed> $current @param array<string,mixed> $proposed */
    private function assertCoverageIdentitiesPreserved(array $current, array $proposed): void
    {
        $existing = [];
        foreach ($current['coverages'] ?? [] as $coverage) {
            $existing[] = ($coverage['vehicleKind'] ?? '').'/'.($coverage['serviceType'] ?? '');
        }
        $proposedIdentities = [];
        foreach ($proposed['coverages'] ?? [] as $coverage) {
            $proposedIdentities[] = ($coverage['vehicleKind'] ?? '').'/'.($coverage['serviceType'] ?? '');
        }
        $missing = array_values(array_diff($existing, $proposedIdentities));
        if ($missing !== []) {
            throw new DomainException('REJECT_COVERAGE_LOSS: '.$current['id'].' is missing '.implode(', ', $missing).'.');
        }
    }

    /**
     * @param  array<string,mixed>|null  $current
     * @param  array<string,mixed>  $proposed
     * @return list<string>
     */
    private function materialChanges(?array $current, array $proposed): array
    {
        $changes = [];
        if ($current === null) {
            $changes[] = 'new_jurisdiction';
        } elseif (($current['name'] ?? null) !== ($proposed['name'] ?? null) ||
            ($current['schemaVersion'] ?? 1) !== ($proposed['schemaVersion'] ?? 1)) {
            $changes[] = 'jurisdiction_metadata_changed';
        }
        $availabilityKeys = ['municipalityCodes' => true, 'consultationEnabled' => true];
        $beforeAvailability = array_intersect_key($current ?? [], $availabilityKeys);
        $afterAvailability = array_intersect_key($proposed, $availabilityKeys);
        if ($this->encoder->encode($beforeAvailability) !== $this->encoder->encode($afterAvailability)) {
            $changes[] = 'jurisdiction_availability_changed';
        }

        $currentByIdentity = $this->coverageMap($current['coverages'] ?? []);
        $proposedByIdentity = $this->coverageMap($proposed['coverages'] ?? []);
        foreach ($proposedByIdentity as $identity => $coverage) {
            $previous = $currentByIdentity[$identity] ?? null;
            if ($previous === null) {
                $changes[] = 'coverage_added';
                if (($coverage['coverageCompleteness'] ?? null) === 'complete') {
                    $changes[] = 'coverage_marked_complete_without_spatial_qa';
                }
                if (($coverage['rules'] ?? []) !== []) {
                    $changes[] = 'restriction_rule_added';
                }

                continue;
            }

            if (($previous['coverageCompleteness'] ?? null) !== 'complete' &&
                ($coverage['coverageCompleteness'] ?? null) === 'complete') {
                $changes[] = 'coverage_marked_complete_without_spatial_qa';
            }
            $beforeMetadata = $previous;
            $afterMetadata = $coverage;
            unset($beforeMetadata['rules'], $afterMetadata['rules']);
            // Historical schema2 coverages without the field were evaluated as enabled.
            $beforeMetadata['consultationEnabled'] ??= true;
            $afterMetadata['consultationEnabled'] ??= true;
            if ($this->encoder->encode($beforeMetadata) !== $this->encoder->encode($afterMetadata)) {
                $changes[] = 'coverage_metadata_changed';
            }

            $beforeRules = $this->ruleMap($previous['rules'] ?? []);
            $afterRules = $this->ruleMap($coverage['rules'] ?? []);
            foreach ($afterRules as $id => $rule) {
                $oldRule = $beforeRules[$id] ?? null;
                if ($oldRule === null) {
                    $changes[] = 'restriction_rule_added';
                } elseif ($this->encoder->encode($oldRule) !== $this->encoder->encode($rule)) {
                    $changes[] = $this->restrictionSemantics($oldRule) !== $this->restrictionSemantics($rule)
                        ? ($this->validityExpanded($oldRule, $rule) && ! $this->hasNewSource($previous, $coverage)
                            ? 'restriction_validity_expanded_without_source'
                            : 'restrictive_rule_changed')
                        : 'restriction_rule_metadata_changed';
                }
            }
            foreach ($beforeRules as $id => $rule) {
                if (! isset($afterRules[$id])) {
                    $changes[] = ($rule['effect'] ?? null) === 'restrict'
                        ? 'restrictive_rule_removed'
                        : 'rule_removed';
                }
            }
        }
        foreach ($currentByIdentity as $identity => $_coverage) {
            if (! isset($proposedByIdentity[$identity])) {
                $changes[] = 'coverage_removed';
            }
        }

        return array_values(array_unique($changes));
    }

    /** @param array<string,mixed> $payload */
    private function assertMunicipalityCodesBelongToJurisdiction(Jurisdiction $jurisdiction, array $payload): void
    {
        $this->validator->assertMunicipalityCodesBelongToJurisdiction($jurisdiction, $payload);
    }

    /** @param list<array<string,mixed>> $coverages @return array<string,array<string,mixed>> */
    private function coverageMap(array $coverages): array
    {
        $map = [];
        foreach ($coverages as $coverage) {
            $map[($coverage['vehicleKind'] ?? '').'/'.($coverage['serviceType'] ?? '')] = $coverage;
        }

        return $map;
    }

    /** @param list<array<string,mixed>> $rules @return array<string,array<string,mixed>> */
    private function ruleMap(array $rules): array
    {
        $map = [];
        foreach ($rules as $rule) {
            $map[(string) ($rule['id'] ?? '')] = $rule;
        }

        return $map;
    }

    /** @param array<string,mixed>|null $before @param array<string,mixed> $after @return array<string,list<string>> */
    private function ruleDiff(?array $before, array $after): array
    {
        $oldRules = [];
        foreach ($before['coverages'] ?? [] as $coverage) {
            $oldRules += $this->ruleMap($coverage['rules'] ?? []);
        }
        $newRules = [];
        foreach ($after['coverages'] ?? [] as $coverage) {
            $newRules += $this->ruleMap($coverage['rules'] ?? []);
        }
        $added = array_values(array_diff(array_keys($newRules), array_keys($oldRules)));
        $removed = array_values(array_diff(array_keys($oldRules), array_keys($newRules)));
        $modified = [];
        foreach (array_intersect(array_keys($oldRules), array_keys($newRules)) as $id) {
            if ($this->encoder->encode($oldRules[$id]) !== $this->encoder->encode($newRules[$id])) {
                $modified[] = $id;
            }
        }
        foreach ([$added, $removed, $modified] as &$ids) {
            sort($ids, SORT_STRING);
        }
        unset($ids);

        return ['added' => $added, 'removed' => $removed, 'modified' => $modified];
    }

    /** @param array<string,mixed> $payload @return list<string> */
    private function coverageIdentities(array $payload): array
    {
        $identities = array_keys($this->coverageMap($payload['coverages'] ?? []));
        sort($identities, SORT_STRING);

        return $identities;
    }

    /** @param array<string,mixed> $payload @return list<string> */
    private function sources(array $payload): array
    {
        $sources = [];
        foreach ($payload['coverages'] ?? [] as $coverage) {
            foreach ($coverage['sourceUrls'] ?? [] as $url) {
                $sources[] = (string) $url;
            }
            foreach ($coverage['rules'] ?? [] as $rule) {
                if (isset($rule['sourceUrl'])) {
                    $sources[] = (string) $rule['sourceUrl'];
                }
            }
        }
        $sources = array_values(array_unique($sources));
        sort($sources, SORT_STRING);

        return $sources;
    }

    /** @param array<string,mixed> $preview @return array<string,mixed> */
    private function approvalMetadata(array $preview): array
    {
        return [
            'versionId' => $preview['versionId'],
            'jurisdictionId' => $preview['jurisdictionId'],
            'publicationRevision' => $preview['publicationRevision'],
            'authorId' => $preview['authorId'],
            'updatedById' => $preview['updatedById'],
            'proposedCitySha256' => $preview['proposedCitySha256'],
            'baseCitySha256' => $preview['baseCitySha256'],
            'diffSha256' => $preview['diffSha256'],
            'changes' => $preview['changes'],
            'coverageIdentities' => $preview['coverageIdentities'],
            'ruleDiff' => $preview['ruleDiff'],
            'sources' => $preview['sources'],
            'sourceCheckedAt' => $preview['sourceCheckedAt'],
            'staleAfter' => $preview['staleAfter'],
        ];
    }

    /** @param array<string,mixed> $metadata @param array<string,mixed> $preview */
    private function approvalMetadataMatches(array $metadata, array $preview, string $reason, string $evidenceUrl, User $reviewer): bool
    {
        foreach ($this->approvalMetadata($preview) as $key => $value) {
            if (($metadata[$key] ?? null) !== $value) {
                return false;
            }
        }

        return ($metadata['reviewerId'] ?? null) === $reviewer->id &&
            ($metadata['reviewerRole'] ?? null) === $reviewer->role->value &&
            ($metadata['classification'] ?? null) === 'EDITORIAL_APPROVAL_ONLY' &&
            ($metadata['reason'] ?? null) === $reason &&
            ($metadata['evidenceUrl'] ?? null) === $evidenceUrl &&
            $reason !== '' && in_array($evidenceUrl, $preview['sources'], true);
    }

    /** @param array<string,mixed> $before @param array<string,mixed> $after */
    private function hasMatchingMaterialApproval(
        RestrictionRuleVersion $version,
        int $revision,
        array $before,
        array $after,
    ): bool {
        try {
            $preview = $this->materialChangePreview($version, $revision);
        } catch (DomainException) {
            return false;
        }
        if (($preview['before']['sha256'] ?? null) !== ($before['sha256'] ?? null) ||
            ($preview['after']['sha256'] ?? null) !== ($after['sha256'] ?? null) ||
            $preview['changes'] === []) {
            return false;
        }

        $events = AuditLog::query()
            ->where('action', 'restriction.material_change.approved')
            ->where('subject_type', RestrictionRuleVersion::class)
            ->where('subject_id', $version->id)
            ->orderBy('id')
            ->get();
        foreach ($events as $event) {
            $reviewer = User::query()->find($event->actor_id);
            if (! $reviewer || ! $reviewer->isActive() ||
                ! in_array($reviewer->role, [OperatorRole::Admin, OperatorRole::SuperAdmin], true) ||
                in_array($reviewer->id, [$version->created_by_id, $version->updated_by_id], true)) {
                continue;
            }
            $metadata = $event->metadata ?? [];
            $reason = is_string($metadata['reason'] ?? null) ? $metadata['reason'] : '';
            $evidenceUrl = is_string($metadata['evidenceUrl'] ?? null) ? $metadata['evidenceUrl'] : '';
            if ($this->approvalMetadataMatches($metadata, $preview, $reason, $evidenceUrl, $reviewer)) {
                try {
                    $this->assertCurrentOfficialSources($version, $preview, $evidenceUrl);
                } catch (DomainException) {
                    return false;
                }

                return true;
            }
        }

        return false;
    }

    /** @param array<string,mixed> $preview */
    private function assertCurrentOfficialSources(RestrictionRuleVersion $version, array $preview, string $evidenceUrl): void
    {
        if (! is_string($preview['sourceCheckedAt']) || ! is_string($preview['staleAfter']) ||
            ! $version->stale_after || ! $version->stale_after->isFuture()) {
            throw new DomainException('The source review is missing or stale.');
        }
        if ($preview['sources'] === [] || ! in_array($evidenceUrl, $preview['sources'], true)) {
            throw new DomainException('The evidence URL must be one of the approved HTTPS sources in the proposal.');
        }
        foreach ($preview['sources'] as $url) {
            if (! is_string($url) || filter_var($url, FILTER_VALIDATE_URL) === false ||
                strtolower((string) parse_url($url, PHP_URL_SCHEME)) !== 'https' ||
                parse_url($url, PHP_URL_USER) !== null || parse_url($url, PHP_URL_PASS) !== null) {
                throw new DomainException('Only registered official HTTPS sources can support editorial approval.');
            }
        }
        $registered = Dataset::query()
            ->where('key', 'restrictions')
            ->firstOrFail()
            ->sources()
            ->where('is_active', true)
            ->whereIn('url', $preview['sources'])
            ->pluck('url')
            ->all();
        if (array_diff($preview['sources'], $registered) !== []) {
            throw new DomainException('Every approval source must be registered and active for the restrictions dataset.');
        }
    }

    /** @param array<string,mixed> $rule */
    private function restrictionSemantics(array $rule): string
    {
        unset($rule['sourceUrl'], $rule['verifiedAt']);

        return hash('sha256', $this->encoder->encode($rule));
    }

    /** @param array<string,mixed> $before @param array<string,mixed> $after */
    private function validityExpanded(array $before, array $after): bool
    {
        try {
            $oldStart = new \DateTimeImmutable((string) ($before['validFrom'] ?? ''));
            $newStart = new \DateTimeImmutable((string) ($after['validFrom'] ?? ''));
            $oldEnd = isset($before['validUntil']) ? new \DateTimeImmutable((string) $before['validUntil']) : null;
            $newEnd = isset($after['validUntil']) ? new \DateTimeImmutable((string) $after['validUntil']) : null;
        } catch (\Throwable) {
            return false;
        }

        return $newStart < $oldStart || ($oldEnd !== null && ($newEnd === null || $newEnd > $oldEnd));
    }

    /** @param array<string,mixed> $before @param array<string,mixed> $after */
    private function hasNewSource(array $before, array $after): bool
    {
        $oldSources = array_fill_keys($before['sourceUrls'] ?? [], true);
        foreach ($before['rules'] ?? [] as $rule) {
            if (isset($rule['sourceUrl'])) {
                $oldSources[$rule['sourceUrl']] = true;
            }
        }
        foreach ($after['sourceUrls'] ?? [] as $source) {
            if (! isset($oldSources[$source])) {
                return true;
            }
        }
        foreach ($after['rules'] ?? [] as $rule) {
            if (isset($rule['sourceUrl']) && ! isset($oldSources[$rule['sourceUrl']])) {
                return true;
            }
        }

        return false;
    }

    /** @param array<string,mixed>|null $payload @return array<string,mixed> */
    private function materialEvidence(?array $payload): array
    {
        if ($payload === null) {
            return ['sha256' => 'NO_BASELINE', 'coverages' => []];
        }
        $coverages = [];
        foreach ($payload['coverages'] ?? [] as $coverage) {
            $ruleIds = [];
            foreach ($coverage['rules'] ?? [] as $rule) {
                if (($rule['effect'] ?? null) === 'restrict') {
                    $ruleIds[] = (string) ($rule['id'] ?? '');
                }
            }
            sort($ruleIds);
            $coverages[] = [
                'identity' => ($coverage['vehicleKind'] ?? '').'/'.($coverage['serviceType'] ?? ''),
                'coverageCompleteness' => $coverage['coverageCompleteness'] ?? 'legacy',
                'consultationEnabled' => $coverage['consultationEnabled'] ?? true,
                'restrictiveRuleIds' => $ruleIds,
                'sourceUrls' => array_values($coverage['sourceUrls'] ?? []),
                'sha256' => hash('sha256', $this->encoder->encode($coverage)),
            ];
        }

        return [
            'sha256' => hash('sha256', $this->encoder->encode($payload)),
            'coverages' => $coverages,
        ];
    }
}
