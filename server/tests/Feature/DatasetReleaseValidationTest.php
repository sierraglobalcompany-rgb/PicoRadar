<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use App\Services\DatasetAuditLogger;
use App\Services\DatasetReleaseValidator;
use DomainException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use LogicException;
use Tests\TestCase;

class DatasetReleaseValidationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
    }

    public function test_validator_rejects_malformed_schema_mismatch_version_mismatch_and_unknown_contracts(): void
    {
        $operator = $this->operator();
        $dataset = $this->dataset();
        Storage::disk('local')->put('dataset-drafts/restrictions/malformed.json', '{');
        $malformed = $dataset->releases()->create(['version' => 'malformed', 'status' => DatasetReleaseStatus::Draft, 'draft_path' => 'dataset-drafts/restrictions/malformed.json']);
        $this->assertValidationFails($malformed, $operator);
        $schema = $this->draft($dataset, 'schema-mismatch', ['schemaVersion' => 2]);
        $this->assertValidationFails($schema, $operator);
        $version = $this->draft($dataset, 'version-mismatch', ['version' => 'different']);
        $this->assertValidationFails($version, $operator);
        $unknown = Dataset::query()->create(['key' => 'cameras_antioquia', 'title' => 'Cameras', 'schema_version' => 1, 'enabled' => true]);
        $unknown->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/cameras', 'verified_at' => now(), 'is_active' => true]);
        $unsupported = $this->draft($unknown, '2026.08.30-pilot', ['datasetKey' => 'cameras_antioquia']);
        $this->assertValidationFails($unsupported, $operator);
    }

    public function test_validator_enforces_flutter_lists_and_strict_iso_dates_and_accepts_the_canonical_fixture(): void
    {
        $operator = $this->operator();
        $dataset = $this->dataset();
        $badList = $this->draft($dataset, 'bad-list', ['jurisdictions' => ['one' => $this->payload()['jurisdictions'][0]]]);
        $this->assertValidationFails($badList, $operator);
        $badDate = $this->draft($dataset, 'bad-date', ['generatedAt' => 'tomorrow']);
        $this->assertValidationFails($badDate, $operator);
        $fixture = file_get_contents(dirname(base_path()).'/mobile/assets/datasets/restrictions/restrictions_v1.json');
        $this->assertNotFalse($fixture);
        $payload = json_decode($fixture, true, 512, JSON_THROW_ON_ERROR);
        $canonical = $this->draft($dataset, $payload['version'], $payload, $fixture);
        app(DatasetReleaseValidator::class)->validate($canonical, $operator);
        $this->assertSame(DatasetReleaseStatus::Validated, $canonical->refresh()->status);
    }

    public function test_release_versions_are_path_safe_and_release_state_machine_is_closed(): void
    {
        $dataset = $this->dataset();
        $valid = $dataset->releases()->create(['version' => '2026.08.27-pilot', 'status' => DatasetReleaseStatus::Draft]);
        $this->assertSame('2026.08.27-pilot', $valid->version);
        foreach (['.', '..', 'bad/path', 'bad\\path', str_repeat('a', 129)] as $unsafe) {
            try {
                $dataset->releases()->create(['version' => $unsafe, 'status' => DatasetReleaseStatus::Draft]);
                $this->fail("Unsafe version $unsafe was persisted.");
            } catch (LogicException) {
                $this->addToAssertionCount(1);
            }
        }
        $validated = $dataset->releases()->create(['version' => 'validated', 'status' => DatasetReleaseStatus::Validated]);
        $this->assertTransitionFails($validated, DatasetReleaseStatus::Draft);
        $published = $dataset->releases()->create(['version' => 'published', 'status' => DatasetReleaseStatus::Published]);
        $this->assertTransitionFails($published, DatasetReleaseStatus::Draft);
        $retired = $dataset->releases()->create(['version' => 'retired', 'status' => DatasetReleaseStatus::Retired]);
        $this->assertTransitionFails($retired, DatasetReleaseStatus::Published);
    }

    public function test_validation_transition_rolls_back_when_its_audit_insert_fails(): void
    {
        $operator = $this->operator();
        $release = $this->draft($this->dataset(), 'audit-failure');
        $failingAudit = new class extends DatasetAuditLogger
        {
            public function log(?User $actor, string $action, Model $subject, array $metadata = []): void
            {
                throw new \RuntimeException('Audit insert failed.');
            }
        };
        try {
            (new DatasetReleaseValidator($failingAudit))->validate($release, $operator);
            $this->fail('Validation was committed without its audit event.');
        } catch (\RuntimeException) {
            $this->assertSame(DatasetReleaseStatus::Draft, $release->refresh()->status);
            $this->assertDatabaseMissing('audit_logs', ['action' => 'release.validated']);
        }
    }

    /** @param array<string,mixed> $overrides */
    private function draft(Dataset $dataset, string $version, array $overrides = [], ?string $bytes = null): DatasetRelease
    {
        $payload = array_replace_recursive($this->payload($version), $overrides);
        $path = "dataset-drafts/{$dataset->key}/$version.json";
        Storage::disk('local')->put($path, $bytes ?? json_encode($payload, JSON_THROW_ON_ERROR));

        return $dataset->releases()->create(['version' => $version, 'status' => DatasetReleaseStatus::Draft, 'draft_path' => $path]);
    }

    /** @return array<string,mixed> */
    private function payload(string $version = 'placeholder'): array
    {
        return [
            'schemaVersion' => 1,
            'datasetKey' => 'restrictions',
            'version' => $version,
            'generatedAt' => '2026-08-27T00:00:00Z',
            'jurisdictions' => [[
                'id' => 'co-test',
                'name' => 'Test',
                'coverages' => [[
                    'vehicleKind' => 'car',
                    'serviceType' => 'private',
                    'verifiedAt' => '2026-08-27T00:00:00Z',
                    'staleAfter' => '2027-01-01T00:00:00Z',
                    'sourceUrls' => ['https://example.test/rules'],
                    'rules' => [[
                        'id' => 'rule-1',
                        'priority' => 1,
                        'effect' => 'restrict',
                        'validFrom' => '2026-08-27T00:00:00Z',
                        'timeWindows' => [],
                        'appliesOnHolidays' => false,
                        'sourceUrl' => 'https://example.test/rules',
                        'verifiedAt' => '2026-08-27T00:00:00Z',
                    ]],
                ]],
            ]],
        ];
    }

    private function dataset(): Dataset
    {
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->sources()->create(['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test/rules', 'verified_at' => now(), 'is_active' => true]);

        return $dataset;
    }

    private function operator(): User
    {
        return User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
    }

    private function assertValidationFails(DatasetRelease $release, User $operator): void
    {
        try {
            app(DatasetReleaseValidator::class)->validate($release, $operator);
            $this->fail('Validation unexpectedly succeeded.');
        } catch (DomainException) {
            $this->assertSame(DatasetReleaseStatus::Draft, $release->refresh()->status);
        }
    }

    private function assertTransitionFails(DatasetRelease $release, DatasetReleaseStatus $status): void
    {
        try {
            $release->status = $status;
            $release->save();
            $this->fail('Invalid transition unexpectedly succeeded.');
        } catch (LogicException) {
            $this->addToAssertionCount(1);
        }
    }
}
