<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Models\GeographicUnit;
use App\Models\ServiceProvider;
use App\Models\ServiceProviderImport;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ServiceProviderBulkImportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
    }

    public function test_bulk_import_review_is_non_mutating_and_confirmation_creates_only_drafts_idempotently(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->createGeography();
        $verifiedAt = now()->subHour()->toAtomString();
        $validUntil = now()->addYear()->toDateString();
        $rows = [
            ['cda', '05', '05001', 'CDA Alfa', 'Calle 1', '6.25', '-75.56', 'https://source.example.test/cda', $verifiedAt, $validUntil, ''],
            ['workshop', '05', '05615', 'Taller Beta', 'Calle 2', '6.15', '-75.37', 'https://source.example.test/workshop', $verifiedAt, $validUntil, ''],
            ['tow', '11', '11001', 'Grúa Gamma', 'Calle 3', '4.65', '-74.08', 'https://source.example.test/tow', $verifiedAt, $validUntil, ''],
            ['cda', '05', '05001', 'CDA Alfa', 'Calle 1', '6.25', '-75.56', 'https://source.example.test/cda', $verifiedAt, $validUntil, ''],
            ['soat', '11', '11001', 'SOAT Delta', '', '', '', 'http://invalid.example.test/source', $verifiedAt, $validUntil, ''],
            ['ally', '05', '05001', '=2+2', '', '', '', 'https://source.example.test/ally', $verifiedAt, $validUntil, ''],
        ];
        $csv = "category,department_code,municipality_code,name,address,latitude,longitude,source_url,verified_at,valid_until,contact_url\n";
        foreach ($rows as $row) {
            $csv .= implode(',', $row)."\n";
        }

        $this->actingAs($admin)->post(route('admin.service-providers.imports.analyze'), [
            'file' => UploadedFile::fake()->createWithContent('providers.csv', $csv),
        ])->assertRedirect();

        $import = ServiceProviderImport::query()->firstOrFail();
        $this->assertSame(0, ServiceProvider::query()->count());
        Storage::disk('local')->assertExists($import->private_path);
        $review = $this->actingAs($admin)->get(route('admin.service-providers.imports.review', $import));
        $review->assertOk()->assertSee('NUEVA')->assertSee('SIN_CAMBIOS');
        $this->assertSame(['NUEVA' => 5, 'SIN_CAMBIOS' => 1], $import->report['counts']);
        $formulaRow = $import->rows()->get()->first(fn ($row) => ($row->raw['name'] ?? null) === '=2+2');
        $this->assertNotNull($formulaRow);
        $this->assertFalse($formulaRow->publishable);

        $selected = $import->rows()->where('publishable', true)->pluck('id')->all();
        $this->assertCount(3, $selected);
        $this->actingAs($admin)->post(route('admin.service-providers.imports.confirm', $import), [
            'row_ids' => $selected,
        ])->assertRedirect();

        $this->assertSame(3, ServiceProvider::query()->count());
        $this->assertSame(3, ServiceProvider::query()->where('status', 'draft')->count());
        $this->assertSame('confirmed', $import->fresh()->status);
        $this->assertSame(0, ServiceProvider::query()->where('status', 'published')->count());

        $this->actingAs($admin)->post(route('admin.service-providers.imports.confirm', $import), [
            'row_ids' => $selected,
        ])->assertRedirect();
        $this->assertSame(3, ServiceProvider::query()->count());
        $this->assertDatabaseMissing('datasets', ['key' => 'service_providers']);
        Storage::disk('public')->assertMissing('manifest/v1/manifest.json');
    }

    public function test_bulk_import_never_changes_a_published_provider(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->createGeography();
        $provider = ServiceProvider::query()->create([
            'category' => 'cda',
            'department_code' => '05',
            'municipality_code' => '05001',
            'name' => 'CDA Publicado',
            'address' => 'Dirección original',
            'source_url' => 'https://source.example.test/published',
            'verified_at' => now()->subHour(),
            'valid_until' => now()->addYear()->toDateString(),
            'status' => 'published',
        ]);
        $csv = "category,department_code,municipality_code,name,address,source_url,verified_at,valid_until\n".
            "cda,05,05001,CDA Publicado,Dirección cambiada,https://source.example.test/published,".
            now()->subHour()->toAtomString().','.now()->addYear()->toDateString()."\n";

        $this->actingAs($admin)->post(route('admin.service-providers.imports.analyze'), [
            'file' => UploadedFile::fake()->createWithContent('published.csv', $csv),
        ])->assertRedirect();

        $import = ServiceProviderImport::query()->firstOrFail();
        $row = $import->rows()->firstOrFail();
        $this->assertSame('EXISTENTE_CON_CAMBIOS', $row->status);
        $this->assertFalse($row->publishable);
        $this->actingAs($admin)->post(route('admin.service-providers.imports.confirm', $import), [
            'row_ids' => [$row->id],
        ])->assertSessionHasErrors('row_ids');

        $this->assertSame('Dirección original', $provider->fresh()->address);
        $this->assertSame('published', $provider->fresh()->status);
    }

    public function test_confirmation_updates_only_selected_existing_drafts(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $this->createGeography();
        $draft = ServiceProvider::query()->create([
            'category' => 'workshop',
            'department_code' => '05',
            'municipality_code' => '05001',
            'name' => 'Taller editable',
            'address' => 'Dirección anterior',
            'source_url' => 'https://source.example.test/workshop',
            'verified_at' => now()->subHour(),
            'valid_until' => now()->addYear()->toDateString(),
            'status' => 'draft',
        ]);
        $csv = "category,department_code,municipality_code,name,address,source_url,verified_at,valid_until\n".
            "workshop,05,05001,Taller editable,Dirección revisada,https://source.example.test/workshop,".
            now()->subHour()->toAtomString().','.now()->addYear()->toDateString()."\n".
            "cda,05,05001,CDA sin seleccionar,Dirección 2,https://source.example.test/cda,".
            now()->subHour()->toAtomString().','.now()->addYear()->toDateString()."\n";

        $this->actingAs($admin)->post(route('admin.service-providers.imports.analyze'), [
            'file' => UploadedFile::fake()->createWithContent('drafts.csv', $csv),
        ])->assertRedirect();

        $import = ServiceProviderImport::query()->firstOrFail();
        $rows = $import->rows()->orderBy('row_number')->get();
        $this->assertSame('EXISTENTE_CON_CAMBIOS', $rows[0]->status);
        $this->assertSame('NUEVA', $rows[1]->status);
        $this->assertTrue($rows[0]->publishable);

        $this->actingAs($admin)->post(route('admin.service-providers.imports.confirm', $import), [
            'row_ids' => [$rows[0]->id],
        ])->assertRedirect();

        $this->assertSame('Dirección revisada', $draft->fresh()->address);
        $this->assertSame('draft', $draft->fresh()->status);
        $this->assertSame(1, ServiceProvider::query()->count());
    }
    public function test_users_without_provider_edit_permission_cannot_open_importer(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);

        $this->actingAs($reviewer)
            ->get(route('admin.service-providers.import'))
            ->assertForbidden();
    }

    private function createGeography(): void
    {
        $country = GeographicUnit::query()->create([
            'key' => 'co',
            'level' => GeographicUnitLevel::Country,
            'code' => 'CO',
            'name' => 'Colombia sintética',
            'normalized_name' => 'colombia sintetica',
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
        $antioquia = GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-05',
            'level' => GeographicUnitLevel::Department,
            'code' => '05',
            'name' => 'Antioquia sintética',
            'normalized_name' => 'antioquia sintetica',
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
        $bogota = GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-11',
            'level' => GeographicUnitLevel::Department,
            'code' => '11',
            'name' => 'Bogotá D.C. sintética',
            'normalized_name' => 'bogota dc sintetica',
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
        foreach ([
            [$antioquia, '05001', 'Medellín sintética'],
            [$antioquia, '05615', 'Rionegro sintético'],
            [$bogota, '11001', 'Bogotá sintética'],
        ] as [$department, $code, $name]) {
            GeographicUnit::query()->create([
                'parent_id' => $department->id,
                'key' => 'co-'.$code,
                'level' => GeographicUnitLevel::Municipality,
                'code' => $code,
                'name' => $name,
                'normalized_name' => strtolower($name),
                'is_active' => true,
                'source_system' => 'test-fixture',
                'source_version' => '2026-11',
            ]);
        }
    }
}