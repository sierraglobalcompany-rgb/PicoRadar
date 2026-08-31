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
    public function __construct(private readonly DatasetAuditLogger $audit) {}

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
            $this->validateEnvelope($payload, $dataset, $locked);
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
    private function validateEnvelope(array $payload, Dataset $dataset, DatasetRelease $release): void
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
            default => throw new DomainException("No approved validator exists for {$dataset->key}."),
        };
    }

    /** @param array<string,mixed> $payload */
    private function validateRestrictions(array $payload): void
    {
        if (($payload['datasetKey'] ?? null) !== 'restrictions' || ! $this->list($payload['jurisdictions'] ?? null)) {
            throw new DomainException('Restrictions payload does not match the mobile contract.');
        }
        $coverageIds = [];
        $ruleIds = [];
        foreach ($payload['jurisdictions'] as $jurisdiction) {
            if (! is_array($jurisdiction) || array_is_list($jurisdiction)) {
                throw new DomainException('Invalid restrictions jurisdiction.');
            }
            $jurisdictionId = $this->string($jurisdiction, 'id');
            $this->string($jurisdiction, 'name');
            if (! $this->list($jurisdiction['coverages'] ?? null)) {
                throw new DomainException('Restrictions coverages are required.');
            }
            foreach ($jurisdiction['coverages'] as $coverage) {
                if (! is_array($coverage) || array_is_list($coverage)) {
                    throw new DomainException('Invalid restriction coverage.');
                }
                $kind = $this->string($coverage, 'vehicleKind');
                $service = $this->string($coverage, 'serviceType');
                if (! in_array($kind, ['car', 'motorcycle'], true) || ! in_array($service, ['private', 'taxi'], true)) {
                    throw new DomainException('Unsupported restrictions vehicle coverage.');
                }
                $coverageId = "$jurisdictionId:$kind:$service";
                if (isset($coverageIds[$coverageId])) {
                    throw new DomainException('Duplicate restriction coverage.');
                }
                $coverageIds[$coverageId] = true;
                $this->date($coverage, 'verifiedAt');
                $this->date($coverage, 'staleAfter');
                if (! $this->list($coverage['sourceUrls'] ?? null) || $coverage['sourceUrls'] === [] || ! $this->list($coverage['rules'] ?? null)) {
                    throw new DomainException('Restrictions sourceUrls and rules are required.');
                }
                foreach ($coverage['sourceUrls'] as $url) {
                    $this->httpsUrl($url, 'sourceUrls[]');
                }
                foreach ($coverage['rules'] as $rule) {
                    if (! is_array($rule) || array_is_list($rule)) {
                        throw new DomainException('Invalid restriction rule.');
                    }
                    $ruleId = $this->string($rule, 'id');
                    if (isset($ruleIds["$jurisdictionId/$ruleId"])) {
                        throw new DomainException('Duplicate restriction rule id.');
                    }
                    $ruleIds["$jurisdictionId/$ruleId"] = true;
                    if (! is_int($rule['priority'] ?? null) || ! in_array($this->string($rule, 'effect'), ['restrict', 'allow'], true) || ! $this->list($rule['timeWindows'] ?? null) || ! is_bool($rule['appliesOnHolidays'] ?? null)) {
                        throw new DomainException('Restrictions rule has invalid required values.');
                    }
                    $this->date($rule, 'validFrom');
                    $this->date($rule, 'verifiedAt');
                    $this->httpsUrl($rule['sourceUrl'] ?? null, 'sourceUrl');
                    if (array_key_exists('validUntil', $rule) && $rule['validUntil'] !== null) {
                        $this->date($rule, 'validUntil');
                    }
                    $this->validateOptionalRules($rule);
                    foreach ($rule['timeWindows'] as $window) {
                        if (! is_array($window) || array_is_list($window) || ! is_int($window['startMinute'] ?? null) || ! is_int($window['endMinute'] ?? null) || $window['startMinute'] < 0 || $window['startMinute'] >= 1440 || $window['endMinute'] < 0 || $window['endMinute'] >= 1440 || $window['startMinute'] === $window['endMinute']) {
                            throw new DomainException('Restrictions timeWindow is invalid.');
                        }
                    }
                }
            }
        }
    }

    /** @param array<string,mixed> $rule */
    private function validateOptionalRules(array $rule): void
    {
        foreach (['registrationOrigins' => ['local', 'foreign', 'unknown'], 'weekdays' => null, 'digits' => null] as $key => $allowed) {
            if (! array_key_exists($key, $rule) || $rule[$key] === null) {
                continue;
            }
            if (! $this->list($rule[$key])) {
                throw new DomainException("$key must be a list.");
            }
            foreach ($rule[$key] as $value) {
                if (($allowed && (! is_string($value) || ! in_array($value, $allowed, true))) || ($key === 'weekdays' && (! is_int($value) || $value < 1 || $value > 7)) || ($key === 'digits' && (! is_int($value) || $value < 0 || $value > 9))) {
                    throw new DomainException("$key contains an invalid value.");
                }
            }
        }
        foreach (['dateParity' => ['odd', 'even'], 'digitPosition' => ['firstNumeric', 'lastNumeric']] as $key => $allowed) {
            if (array_key_exists($key, $rule) && $rule[$key] !== null && (! is_string($rule[$key]) || ! in_array($rule[$key], $allowed, true))) {
                throw new DomainException("$key is invalid.");
            }
        }
        if (array_key_exists('digits', $rule) && $rule['digits'] !== null && (! array_key_exists('digitPosition', $rule) || $rule['digitPosition'] === null)) {
            throw new DomainException('digitPosition is required with digits.');
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

    private function httpsUrl(mixed $value, string $key): void
    {
        if (! is_string($value) || filter_var($value, FILTER_VALIDATE_URL) === false || strtolower((string) parse_url($value, PHP_URL_SCHEME)) !== 'https') {
            throw new DomainException("$key must be an HTTPS URL.");
        }
    }
}
