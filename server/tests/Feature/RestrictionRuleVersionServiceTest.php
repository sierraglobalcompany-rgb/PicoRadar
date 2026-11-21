<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\AuditLog;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\RestrictionRuleVersionService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RestrictionRuleVersionServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_draft_lifecycle_is_versioned_audited_and_validated_versions_are_immutable(): void
    {
        $actor = User::factory()->create(['role' => OperatorRole::Editor]);
        $jurisdiction = $this->jurisdiction();
        $dataset = Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1,
            'enabled' => true, 'publication_revision' => 7,
        ]);
        $service = app(RestrictionRuleVersionService::class);

        $draft = $service->createDraft($jurisdiction, $this->payload(), $actor);
        $this->assertSame(1, $draft->version);
        $this->assertSame(7, $draft->base_publication_revision);
        $this->assertSame(RestrictionRuleVersionStatus::Draft, $draft->status);

        $updatedPayload = $this->payload();
        $updatedPayload['coverages'][0]['rules'][0]['digits'] = [7, 8];
        $draft = $service->updateDraft($draft, $updatedPayload, $actor);
        $this->assertSame([7, 8], $draft->payload['coverages'][0]['rules'][0]['digits']);

        $validated = $service->validate($draft, $actor);
        $this->assertSame(RestrictionRuleVersionStatus::Validated, $validated->status);
        $this->assertSame(['car'], $validated->vehicle_kinds);
        $this->assertSame('2026-09-01', $validated->valid_from->toDateString());
        $this->assertNotNull($validated->validated_at);

        try {
            $service->updateDraft($validated, $this->payload(), $actor);
            $this->fail('A validated version was edited.');
        } catch (DomainException $error) {
            $this->assertSame('Only draft rule versions can be edited.', $error->getMessage());
        }

        $duplicate = $service->duplicate($validated, $actor);
        $this->assertSame(2, $duplicate->version);
        $this->assertSame(RestrictionRuleVersionStatus::Draft, $duplicate->status);
        $this->assertSame($validated->payload, $duplicate->payload);
        $service->archive($duplicate, $actor);
        $this->assertSame(RestrictionRuleVersionStatus::Archived, $duplicate->refresh()->status);
        $this->assertSame(
            ['restriction_rule.created', 'restriction_rule.updated', 'restriction_rule.validated', 'restriction_rule.duplicated', 'restriction_rule.archived'],
            AuditLog::query()->orderBy('id')->pluck('action')->all(),
        );
        $this->assertSame(7, $dataset->fresh()->publication_revision);
    }

    private function jurisdiction(): Jurisdiction
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05', 'name' => 'Antioquia',
            'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1',
        ]);
        $municipality = GeographicUnit::query()->create([
            'parent_id' => $department->id, 'key' => 'co-05001', 'level' => 'municipality', 'code' => '05001', 'name' => 'Ciudad sintética',
            'normalized_name' => 'ciudad sintetica', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'co-test-synthetic', 'name' => 'Ciudad sintética', 'kind' => 'city',
            'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota',
        ]);
        $jurisdiction->geographicUnits()->attach($municipality);

        return $jurisdiction;
    }

    /** @return array<string,mixed> */
    private function payload(): array
    {
        return [
            'id' => 'co-test-synthetic',
            'name' => 'Ciudad sintética',
            'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private',
                'verifiedAt' => '2026-09-01T05:00:00Z', 'staleAfter' => '2027-01-15T05:00:00Z',
                'sourceUrls' => ['https://example.test/rules'],
                'rules' => [[
                    'id' => 'synthetic-rule-1', 'priority' => 100, 'effect' => 'restrict',
                    'validFrom' => '2026-09-01T00:00:00-05:00', 'validUntil' => '2026-12-31T23:59:59-05:00',
                    'weekdays' => [1], 'digitPosition' => 'lastNumeric', 'digits' => [1, 2],
                    'timeWindows' => [['startMinute' => 360, 'endMinute' => 1200]],
                    'appliesOnHolidays' => false, 'sourceUrl' => 'https://example.test/rules',
                    'verifiedAt' => '2026-09-01T05:00:00Z',
                ]],
            ]],
        ];
    }
}
