<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\JurisdictionKind;
use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminContentDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_dashboard_reports_real_content_workflow_counts_in_spanish(): void
    {
        $this->withoutVite();
        $operator = User::factory()->create(['role' => OperatorRole::Admin]);
        $country = GeographicUnit::query()->create([
            'key' => 'co',
            'level' => GeographicUnitLevel::Country,
            'code' => 'CO',
            'name' => 'Colombia',
            'normalized_name' => 'colombia',
            'source_system' => 'synthetic',
            'source_version' => 'test-v1',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'synthetic-city',
            'name' => 'Ciudad sintética',
            'kind' => JurisdictionKind::City,
            'primary_geographic_unit_id' => $country->id,
            'enabled' => true,
        ]);

        foreach ([RestrictionRuleVersionStatus::Draft, RestrictionRuleVersionStatus::Validated] as $index => $status) {
            RestrictionRuleVersion::query()->create([
                'jurisdiction_id' => $jurisdiction->id,
                'version' => $index + 1,
                'status' => $status,
                'payload' => ['id' => 'synthetic-city'],
                'payload_sha256' => str_repeat((string) ($index + 1), 64),
                'base_publication_revision' => 0,
                'created_by_id' => $operator->id,
                'updated_by_id' => $operator->id,
            ]);
        }
        RestrictionImport::query()->create([
            'sha256' => str_repeat('a', 64),
            'original_name' => 'reglas.csv',
            'format' => 'csv',
            'private_path' => 'imports/synthetic.csv',
            'status' => RestrictionImportStatus::Analyzed,
            'created_by_id' => $operator->id,
        ]);
        $dataset = Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Pico y placa',
            'schema_version' => 1,
            'enabled' => true,
        ]);
        $release = DatasetRelease::query()->create([
            'dataset_id' => $dataset->id,
            'version' => 'test-1',
            'status' => DatasetReleaseStatus::Draft,
        ]);
        RestrictionPublication::query()->create([
            'dataset_release_id' => $release->id,
            'action' => 'publish',
            'base_publication_revision' => 0,
            'result_publication_revision' => 1,
            'actor_id' => $operator->id,
            'summary' => ['jurisdictions' => 1],
        ]);

        $this->actingAs($operator)
            ->get(route('admin.dashboard'))
            ->assertOk()
            ->assertSee('Operación de contenidos')
            ->assertSee('Jurisdicciones activas')
            ->assertSee('Borradores de pico y placa')
            ->assertSee('Listas para publicar')
            ->assertSee('Importaciones pendientes')
            ->assertSee('Publicaciones recientes')
            ->assertSee('Ciudad sintética')
            ->assertDontSee('Control plane is available.');
    }
}
