<?php

namespace App\Services;

use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\Jurisdiction;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

final class RestrictionRuleVersionService
{
    public function __construct(
        private readonly RestrictionContractValidator $validator,
        private readonly RestrictionPayloadEncoder $encoder,
        private readonly DatasetAuditLogger $audit,
    ) {}

    /** @param array<string,mixed> $payload */
    public function createDraft(Jurisdiction $jurisdiction, array $payload, User $actor): RestrictionRuleVersion
    {
        return $this->persistDraft($jurisdiction, $payload, $actor, 'restriction_rule.created');
    }

    public function duplicate(RestrictionRuleVersion $source, User $actor): RestrictionRuleVersion
    {
        return $this->persistDraft(
            $source->jurisdiction,
            $source->payload,
            $actor,
            'restriction_rule.duplicated',
            ['sourceVersionId' => $source->id],
        );
    }

    /**
     * @param  array<string,mixed>  $payload
     * @param  array<string,mixed>  $auditMetadata
     */
    private function persistDraft(Jurisdiction $jurisdiction, array $payload, User $actor, string $action, array $auditMetadata = []): RestrictionRuleVersion
    {
        return DB::transaction(function () use ($jurisdiction, $payload, $actor, $action, $auditMetadata): RestrictionRuleVersion {
            $lockedJurisdiction = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            $versionNumber = ((int) RestrictionRuleVersion::query()->where('jurisdiction_id', $lockedJurisdiction->id)->lockForUpdate()->max('version')) + 1;
            $datasetRevision = (int) Dataset::query()->where('key', 'restrictions')->lockForUpdate()->value('publication_revision');
            $version = RestrictionRuleVersion::query()->create([
                'jurisdiction_id' => $lockedJurisdiction->id,
                'version' => $versionNumber,
                'status' => RestrictionRuleVersionStatus::Draft,
                'payload' => $payload,
                'payload_sha256' => $this->hash($payload),
                'base_publication_revision' => $datasetRevision,
                'created_by_id' => $actor->id,
                'updated_by_id' => $actor->id,
            ]);
            $this->audit->log($actor, $action, $version, $auditMetadata + ['jurisdictionKey' => $lockedJurisdiction->key, 'version' => $versionNumber]);

            return $version;
        });
    }

    /** @param array<string,mixed> $payload */
    public function updateDraft(RestrictionRuleVersion $version, array $payload, User $actor): RestrictionRuleVersion
    {
        return DB::transaction(function () use ($version, $payload, $actor): RestrictionRuleVersion {
            $locked = RestrictionRuleVersion::query()->lockForUpdate()->findOrFail($version->id);
            $this->assertDraft($locked);
            $locked->update(['payload' => $payload, 'payload_sha256' => $this->hash($payload), 'updated_by_id' => $actor->id]);
            $this->audit->log($actor, 'restriction_rule.updated', $locked, ['jurisdictionId' => $locked->jurisdiction_id, 'version' => $locked->version]);

            return $locked->refresh();
        });
    }

    public function validate(RestrictionRuleVersion $version, User $actor): RestrictionRuleVersion
    {
        return DB::transaction(function () use ($version, $actor): RestrictionRuleVersion {
            $locked = RestrictionRuleVersion::query()->with('jurisdiction')->lockForUpdate()->findOrFail($version->id);
            $this->assertDraft($locked);
            $summary = $this->validator->validateJurisdiction($locked->payload, $locked->jurisdiction->key);
            $locked->update([
                'status' => RestrictionRuleVersionStatus::Validated,
                'vehicle_kinds' => $summary['vehicleKinds'],
                'valid_from' => $summary['validFrom'],
                'valid_until' => $summary['validUntil'],
                'stale_after' => $summary['staleAfter'],
                'source_checked_at' => $summary['sourceCheckedAt'],
                'validated_by_id' => $actor->id,
                'validated_at' => now(),
            ]);
            $this->audit->log($actor, 'restriction_rule.validated', $locked, ['jurisdictionId' => $locked->jurisdiction_id, 'version' => $locked->version, 'sha256' => $locked->payload_sha256]);

            return $locked->refresh();
        });
    }

    public function archive(RestrictionRuleVersion $version, User $actor): RestrictionRuleVersion
    {
        return DB::transaction(function () use ($version, $actor): RestrictionRuleVersion {
            $locked = RestrictionRuleVersion::query()->lockForUpdate()->findOrFail($version->id);
            if ($locked->status === RestrictionRuleVersionStatus::Archived) {
                return $locked;
            }
            $locked->update(['status' => RestrictionRuleVersionStatus::Archived, 'archived_by_id' => $actor->id, 'archived_at' => now()]);
            $this->audit->log($actor, 'restriction_rule.archived', $locked, ['jurisdictionId' => $locked->jurisdiction_id, 'version' => $locked->version]);

            return $locked->refresh();
        });
    }

    private function assertDraft(RestrictionRuleVersion $version): void
    {
        if ($version->status !== RestrictionRuleVersionStatus::Draft) {
            throw new DomainException('Only draft rule versions can be edited.');
        }
    }

    /** @param array<string,mixed> $payload */
    private function hash(array $payload): string
    {
        return hash('sha256', $this->encoder->encode($payload));
    }
}
