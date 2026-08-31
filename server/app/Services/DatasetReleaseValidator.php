<?php

namespace App\Services;

use App\Enums\DatasetReleaseStatus;
use App\Models\DatasetRelease;
use App\Models\User;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Support\Facades\Storage;
use JsonException;

class DatasetReleaseValidator
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function validate(DatasetRelease $release, User $actor): DatasetRelease
    {
        $release->loadMissing('dataset.sources');
        if ($release->status !== DatasetReleaseStatus::Draft || ! $release->draft_path || ! Storage::disk(config('datasets.draft_disk'))->exists($release->draft_path)) {
            throw new DomainException('Only an existing draft can be validated.');
        }
        $bytes = Storage::disk(config('datasets.draft_disk'))->get($release->draft_path);
        try {
            $payload = json_decode($bytes, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new DomainException('The draft is not valid JSON.');
        }
        if (! is_array($payload)) {
            throw new DomainException('The dataset payload must be a JSON object.');
        }
        $this->string($payload, 'version');
        $this->date($payload, 'generatedAt');
        if (($payload['schemaVersion'] ?? null) !== $release->dataset->schema_version || $payload['version'] !== $release->version) {
            throw new DomainException('Release version or schemaVersion does not match the dataset contract.');
        }
        $sources = $release->dataset->sources->filter(fn ($source) => $source->is_active && $source->authority !== '' && $source->url !== '' && $source->verified_at !== null);
        if ($sources->isEmpty()) {
            throw new DomainException('At least one verified active source is required.');
        }
        if ($release->dataset->key === 'restrictions') {
            $this->validateRestrictions($payload);
        }
        if (isset($payload['expiresAt'])) {
            $this->date($payload, 'expiresAt');
        }
        $release->forceFill(['status' => DatasetReleaseStatus::Validated, 'sha256' => hash('sha256', $bytes), 'generated_at' => CarbonImmutable::parse($payload['generatedAt']), 'verified_at' => $release->verified_at ?? $sources->max('verified_at'), 'validated_at' => now(), 'metadata' => ['sources' => $sources->map(fn ($source) => ['id' => $source->id, 'authority' => $source->authority, 'url' => $source->url, 'verifiedAt' => $source->verified_at->toAtomString()])->values()->all()]])->save();
        $this->audit->log($actor, 'release.validated', $release, ['datasetKey' => $release->dataset->key, 'version' => $release->version, 'sha256' => $release->sha256]);

        return $release->refresh();
    }

    /** @param array<string, mixed> $payload */
    private function validateRestrictions(array $payload): void
    {
        if (($payload['datasetKey'] ?? null) !== 'restrictions' || ! is_array($payload['jurisdictions'] ?? null)) {
            throw new DomainException('Restrictions payload does not match the mobile contract.');
        }
        $coverageIds = [];
        $ruleIds = [];
        foreach ($payload['jurisdictions'] as $jurisdiction) {
            if (! is_array($jurisdiction)) {
                throw new DomainException('Invalid restrictions jurisdiction.');
            } $jid = $this->string($jurisdiction, 'id');
            $this->string($jurisdiction, 'name');
            if (! is_array($jurisdiction['coverages'] ?? null)) {
                throw new DomainException('Restrictions coverages are required.');
            } foreach ($jurisdiction['coverages'] as $coverage) {
                if (! is_array($coverage)) {
                    throw new DomainException('Invalid restriction coverage.');
                } $kind = $this->string($coverage, 'vehicleKind');
                $service = $this->string($coverage, 'serviceType');
                if (! in_array($kind, ['car', 'motorcycle'], true) || ! in_array($service, ['private', 'taxi'], true)) {
                    throw new DomainException('Unsupported restrictions vehicle coverage.');
                } $id = "$jid:$kind:$service";
                if (isset($coverageIds[$id])) {
                    throw new DomainException('Duplicate restriction coverage.');
                } $coverageIds[$id] = true;
                $this->date($coverage, 'verifiedAt');
                $this->date($coverage, 'staleAfter');
                if (! is_array($coverage['sourceUrls'] ?? null) || $coverage['sourceUrls'] === [] || ! is_array($coverage['rules'] ?? null)) {
                    throw new DomainException('Restrictions sourceUrls and rules are required.');
                }
                foreach ($coverage['sourceUrls'] as $url) {
                    $this->httpsUrl($url, 'sourceUrls[]');
                }
                foreach ($coverage['rules'] as $rule) {
                    if (! is_array($rule)) {
                        throw new DomainException('Invalid restriction rule.');
                    }
                    $rid = $this->string($rule, 'id');
                    if (isset($ruleIds["$jid/$rid"])) {
                        throw new DomainException('Duplicate restriction rule id.');
                    }
                    $ruleIds["$jid/$rid"] = true;
                    if (! is_int($rule['priority'] ?? null) || ! in_array($this->string($rule, 'effect'), ['restrict', 'allow'], true) || ! is_array($rule['timeWindows'] ?? null) || ! is_bool($rule['appliesOnHolidays'] ?? null)) {
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
                        if (! is_array($window) || ! is_int($window['startMinute'] ?? null) || ! is_int($window['endMinute'] ?? null) || $window['startMinute'] < 0 || $window['startMinute'] >= 1440 || $window['endMinute'] < 0 || $window['endMinute'] >= 1440 || $window['startMinute'] === $window['endMinute']) {
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
        $sets = [
            'registrationOrigins' => ['local', 'foreign', 'unknown'],
            'weekdays' => null,
            'digits' => null,
        ];
        foreach ($sets as $key => $allowed) {
            if (! array_key_exists($key, $rule) || $rule[$key] === null) {
                continue;
            }
            if (! is_array($rule[$key])) {
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
        try {
            CarbonImmutable::parse($this->string($value, $key));
        } catch (\Throwable) {
            throw new DomainException("$key must be a valid date.");
        }
    }

    private function httpsUrl(mixed $value, string $key): void
    {
        if (! is_string($value) || filter_var($value, FILTER_VALIDATE_URL) === false || strtolower((string) parse_url($value, PHP_URL_SCHEME)) !== 'https') {
            throw new DomainException("$key must be an HTTPS URL.");
        }
    }
}
