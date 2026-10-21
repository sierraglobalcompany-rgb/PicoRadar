<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\DatasetSource;
use App\Models\User;
use Carbon\CarbonImmutable;
use DateTimeImmutable;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use JsonException;

class DatasetReleaseValidator
{
    private readonly RestrictionContractValidator $restrictions;

    public function __construct(private readonly DatasetAuditLogger $audit, ?RestrictionContractValidator $restrictions = null)
    {
        $this->restrictions = $restrictions ?? new RestrictionContractValidator;
    }

    public function validate(DatasetRelease $release, User $actor): DatasetRelease
    {
        if (! $release->draft_path || ! Storage::disk(config('datasets.draft_disk'))->exists($release->draft_path)) {
            throw new DomainException('Only an existing draft can be validated.');
        }
        $bytes = Storage::disk(config('datasets.draft_disk'))->get($release->draft_path);
        try {
            $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new DomainException('The draft is not valid JSON.');
        }
        if (! is_array($payload) || array_is_list($payload)) {
            throw new DomainException('The dataset payload must be a JSON object.');
        }

        return DB::transaction(function () use ($release, $actor, $bytes, $payload): DatasetRelease {
            $dataset = Dataset::query()->lockForUpdate()->findOrFail($release->dataset_id);
            $locked = DatasetRelease::query()->whereKey($release->id)->lockForUpdate()->firstOrFail();
            if ($locked->dataset_id !== $dataset->id || $locked->status !== DatasetReleaseStatus::Draft || ! $locked->draft_path) {
                throw new DomainException('Only an existing draft can be validated.');
            }
            $this->validateEnvelope($payload, $dataset, $locked, $bytes);
            $sources = DatasetSource::query()->where('dataset_id', $dataset->id)->lockForUpdate()->get()->filter(fn (DatasetSource $source): bool => $source->is_active && trim($source->authority) !== '' && filter_var($source->url, FILTER_VALIDATE_URL) !== false && in_array(strtolower((string) parse_url($source->url, PHP_URL_SCHEME)), ['http', 'https'], true) && $source->verified_at !== null);
            if ($sources->isEmpty()) {
                throw new DomainException('At least one verified active source is required.');
            }
            $locked->forceFill(['status' => DatasetReleaseStatus::Validated, 'sha256' => hash('sha256', $bytes), 'generated_at' => CarbonImmutable::parse($payload['generatedAt']), 'verified_at' => $locked->verified_at ?? $sources->max('verified_at'), 'validated_at' => now(), 'metadata' => ['sources' => $sources->map(fn (DatasetSource $source): array => ['id' => $source->id, 'authority' => $source->authority, 'url' => $source->url, 'verifiedAt' => $source->verified_at->toAtomString()])->values()->all()]])->save();
            $this->audit->log($actor, 'release.validated', $locked, ['datasetKey' => $dataset->key, 'version' => $locked->version, 'sha256' => $locked->sha256]);

            return $locked->refresh();
        });
    }

    /** @param array<string,mixed> $payload */
    private function validateEnvelope(array $payload, Dataset $dataset, DatasetRelease $release, string $bytes): void
    {
        $this->string($payload, 'version');
        $this->date($payload, 'generatedAt');
        if (($payload['schemaVersion'] ?? null) !== $dataset->schema_version || $payload['version'] !== $release->version) {
            throw new DomainException('Release version or schemaVersion does not match the dataset contract.');
        }
        if (array_key_exists('expiresAt', $payload)) {
            $this->date($payload, 'expiresAt');
        }
        match ($dataset->key) {
            'restrictions' => $this->validateRestrictions($payload),
            'tax_calendars' => (new TaxCalendarPayloadValidator)->validate((array) json_decode($bytes, false, 512, JSON_THROW_ON_ERROR)),
            default => throw new DomainException("No approved validator exists for {$dataset->key}."),
        };
    }

    /** @param array<string,mixed> $payload */
    private function validateRestrictions(array $payload): void
    {
        if (($payload['datasetKey'] ?? null) !== 'restrictions' || ! $this->list($payload['jurisdictions'] ?? null)) {
            throw new DomainException('Restrictions payload does not match the mobile contract.');
        }
        $jurisdictionIds = [];
        foreach ($payload['jurisdictions'] as $jurisdiction) {
            if (! is_array($jurisdiction) || array_is_list($jurisdiction)) {
                throw new DomainException('Invalid restrictions jurisdiction.');
            }
            $jurisdictionId = $this->string($jurisdiction, 'id');
            if (isset($jurisdictionIds[$jurisdictionId])) {
                throw new DomainException('Duplicate restrictions jurisdiction.');
            }
            $jurisdictionIds[$jurisdictionId] = true;
            $this->restrictions->validateJurisdiction($jurisdiction, $jurisdictionId);
        }
    }

    /** @param array<string,mixed> $value */
    private function string(array $value, string $key): string
    {
        if (! is_string($value[$key] ?? null) || trim($value[$key]) === '') {
            throw new DomainException("$key is required.");
        }

        return trim($value[$key]);
    }

    /** @param array<string,mixed> $value */
    private function date(array $value, string $key): void
    {
        $date = $this->string($value, $key);
        if (! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?$/', $date)) {
            throw new DomainException("$key must be an ISO-8601 date.");
        }
        try {
            new DateTimeImmutable($date);
        } catch (\Throwable) {
            throw new DomainException("$key must be a valid date.");
        }
    }

    private function list(mixed $value): bool
    {
        return is_array($value) && array_is_list($value);
    }
}
