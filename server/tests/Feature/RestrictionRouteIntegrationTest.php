<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RestrictionRouteIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Pico y placa',
            'schema_version' => 1,
            'enabled' => true,
        ]);
    }

    public function test_editor_reaches_real_rules_import_and_template_routes(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);

        $this->actingAs($editor)
            ->get(route('admin.restrictions.index'))
            ->assertOk()
            ->assertSee('Reglas por ciudad');
        $this->get(route('admin.restrictions.import'))
            ->assertOk()
            ->assertSee('Archivo JSON, CSV o XLSX');
        $this->get(route('admin.restrictions.template'))
            ->assertOk()
            ->assertDownload('restriction-rules-template.csv');
    }

    public function test_commercial_operator_cannot_access_rule_operations(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($commercial)->get(route('admin.restrictions.index'))->assertForbidden();
        $this->get(route('admin.restrictions.import'))->assertForbidden();
    }
}
