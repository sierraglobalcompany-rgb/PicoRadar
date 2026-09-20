<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionImportRow;
use App\Models\RestrictionPublication;
use App\Models\RestrictionPublicationItem;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RestrictionRulePersistenceTest extends TestCase
{
    use RefreshDatabase;

    public function test_city_versions_import_rows_and_publication_history_keep_exact_ownership(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Editor]);
        $jurisdiction = $this->jurisdiction();
        $version = RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id,
            'version' => 1,
            'status' => RestrictionRuleVersionStatus::Validated,
            'payload' => ['id' => 'co-ant-synthetic', 'name' => 'Ciudad sintética', 'coverages' => []],
            'payload_sha256' => str_repeat('a', 64),
            'base_publication_revision' => 0,
            'vehicle_kinds' => ['car'],
            'valid_from' => '2026-09-01',
            'valid_until' => '2026-12-31',
            'stale_after' => '2027-01-15T05:00:00Z',
            'source_checked_at' => '2026-09-01T05:00:00Z',
            'created_by_id' => $operator->id,
            'updated_by_id' => $operator->id,
            'validated_by_id' => $operator->id,
            'validated_at' => now(),
        ]);
        $import = RestrictionImport::query()->create([
            'sha256' => str_repeat('b', 64),
            'original_name' => 'reglas-sinteticas.csv',
            'format' => 'csv',
            'private_path' => 'restriction-imports/synthetic.csv',
            'status' => RestrictionImportStatus::Analyzed,
            'row_count' => 1,
            'valid_count' => 1,
            'invalid_count' => 0,
            'excluded_count' => 0,
            'report' => ['syntheticFixture' => true],
            'created_by_id' => $operator->id,
            'analyzed_at' => now(),
        ]);
        $row = RestrictionImportRow::query()->create([
            'restriction_import_id' => $import->id,
            'row_number' => 2,
            'jurisdiction_id' => $jurisdiction->id,
            'state' => 'valid',
            'publishable' => true,
            'normalized' => ['ruleId' => 'synthetic-rule'],
            'errors' => [],
            'raw' => ['fixture' => 'SYNTHETIC'],
        ]);
        $dataset = Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Restrictions',
            'schema_version' => 1,
            'enabled' => true,
            'publication_revision' => 1,
        ]);
        $release = DatasetRelease::query()->create([
            'dataset_id' => $dataset->id,
            'version' => 'synthetic-v1',
            'status' => 'draft',
        ]);
        $publication = RestrictionPublication::query()->create([
            'dataset_release_id' => $release->id,
            'action' => 'publish',
            'base_publication_revision' => 0,
            'result_publication_revision' => 1,
            'actor_id' => $operator->id,
            'summary' => ['syntheticFixture' => true],
        ]);
        RestrictionPublicationItem::query()->create([
            'restriction_publication_id' => $publication->id,
            'jurisdiction_id' => $jurisdiction->id,
            'restriction_rule_version_id' => $version->id,
            'previous_rule_version_id' => null,
            'action' => 'publish',
        ]);

        $this->assertSame(RestrictionRuleVersionStatus::Validated, $version->fresh()->status);
        $this->assertSame(['car'], $version->fresh()->vehicle_kinds);
        $this->assertSame(RestrictionImportStatus::Analyzed, $import->fresh()->status);
        $this->assertTrue($row->fresh()->publishable);
        $this->assertTrue($import->fresh()->rows->sole()->is($row));
        $this->assertTrue($jurisdiction->fresh()->restrictionRuleVersions->sole()->is($version));
        $item = $release->fresh()->restrictionPublication->items->sole();
        $this->assertTrue($item->ruleVersion->is($version));
        $this->assertTrue($item->jurisdiction->is($jurisdiction));
        $this->assertTrue($publication->fresh()->actor->is($operator));
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
            'key' => 'co-ant-synthetic', 'name' => 'Ciudad sintética', 'kind' => 'city',
            'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota',
        ]);
        $jurisdiction->geographicUnits()->attach($municipality);

        return $jurisdiction;
    }
}
