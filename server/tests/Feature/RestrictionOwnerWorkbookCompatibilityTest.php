<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\RestrictionImportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class RestrictionOwnerWorkbookCompatibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_delivered_multicity_workbook_is_safely_analyzed_without_publishing_or_inventing_missing_cities(): void
    {
        Storage::fake('local');
        Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $actor = User::factory()->create(['role' => OperatorRole::Editor]);
        $path = dirname(base_path()).'/data/sources/restrictions/PicoRadar_Pico_y_Placa_Colombia_CONSOLIDADO_2026-09-10.xlsx';

        $import = app(RestrictionImportService::class)->analyze($path, basename($path), 'xlsx', 'Calendarios_dinamicos', $actor);

        $this->assertSame('Calendarios_dinamicos', $import->sheet);
        $this->assertSame(435, $import->row_count);
        $this->assertGreaterThan(400, $import->excluded_count);
        $this->assertGreaterThan(0, $import->invalid_count);
        $this->assertSame(0, $import->valid_count);
        $this->assertSame(0, RestrictionRuleVersion::query()->count());
        Storage::disk('local')->assertExists($import->private_path);
    }
}
