<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\ServiceProvider;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ServiceProviderPublicationFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        Storage::fake('public');
    }

    public function test_preview_draft_validation_publication_and_rollback_share_the_dataset_release_flow(): void
    {
        $admin = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create([
            'key' => 'service_providers',
            'title' => 'Service providers',
            'schema_version' => 1,
            'enabled' => true,
        ]);
        $dataset->sources()->create([
            'title' => 'Source registry',
            'authority' => 'Synthetic authority',
            'url' => 'https://authority.example.test/providers',
            'verified_at' => now()->subHour(),
            'valid_from' => now()->subDay(),
            'valid_until' => now()->addYear(),
            'is_active' => true,
        ]);
        $this->createSyntheticProvider();

        $firstSnapshot = $this->preview($admin, $dataset);
        $first = $this->createDraft($admin, $dataset, $firstSnapshot);
        $this->validateAndPublish($admin, $dataset, $first);
        $this->assertSame($first->version, $dataset->fresh()->current_version);

        ServiceProvider::query()->firstOrFail()->update(['name' => 'CDA sintético actualizado']);
        $secondSnapshot = $this->preview($admin, $dataset);
        $this->assertSame(1, $secondSnapshot['diff']['changed']);
        $second = $this->createDraft($admin, $dataset, $secondSnapshot);
        $this->validateAndPublish($admin, $dataset, $second);
        $this->assertSame($second->version, $dataset->fresh()->current_version);

        $this->actingAs($admin)
            ->post(route('admin.datasets.releases.rollback', [$dataset, $first]))
            ->assertRedirect();
        $this->assertSame($first->version, $dataset->fresh()->current_version);
        $this->assertTrue(Storage::disk('public')->exists($first->fresh()->asset_path));
    }

    /** @return array{version:string,generatedAt:string,sha256:string,diff:array<string,int>} */
    private function preview(User $admin, Dataset $dataset): array
    {
        $response = $this->actingAs($admin)
            ->get(route('admin.service-providers.publication'))
            ->assertOk()
            ->assertSee('Revisar publicación OTA')
            ->assertSee('SHA-256 comprueba integridad');
        $data = $response->viewData('snapshot');
        $this->assertNotNull($data);
        $diff = $response->viewData('diff');

        return $data + ['diff' => $diff];
    }

    /** @param array{version:string,generatedAt:string,sha256:string} $snapshot */
    private function createDraft(User $admin, Dataset $dataset, array $snapshot): DatasetRelease
    {
        $this->actingAs($admin)
            ->post(route('admin.datasets.releases.store', $dataset), [
                'generate_from_provider_catalog' => '1',
                'version' => $snapshot['version'],
                'generated_at' => $snapshot['generatedAt'],
                'preview_sha256' => $snapshot['sha256'],
            ])
            ->assertRedirect(route('admin.datasets.show', $dataset));

        return $dataset->releases()->where('version', $snapshot['version'])->firstOrFail();
    }

    private function validateAndPublish(User $admin, Dataset $dataset, DatasetRelease $release): void
    {
        $this->actingAs($admin)
            ->post(route('admin.datasets.releases.validate', [$dataset, $release]))
            ->assertRedirect();
        $this->assertSame(DatasetReleaseStatus::Validated, $release->fresh()->status);

        $this->actingAs($admin)
            ->post(route('admin.datasets.releases.publish', [$dataset, $release]))
            ->assertRedirect();
        $this->assertSame(DatasetReleaseStatus::Published, $release->fresh()->status);
    }

    private function createSyntheticProvider(): void
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
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'co-ant',
            'level' => GeographicUnitLevel::Department,
            'code' => '05',
            'name' => 'Antioquia sintética',
            'normalized_name' => 'antioquia sintetica',
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
        GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => 'co-ant-med',
            'level' => GeographicUnitLevel::Municipality,
            'code' => '05001',
            'name' => 'Medellín sintética',
            'normalized_name' => 'medellin sintetica',
            'is_active' => true,
            'source_system' => 'test-fixture',
            'source_version' => '2026-11',
        ]);
        ServiceProvider::query()->create([
            'category' => 'cda',
            'department_code' => '05',
            'municipality_code' => '05001',
            'name' => 'CDA sintético',
            'address' => 'Dirección de prueba',
            'latitude' => 6.25,
            'longitude' => -75.56,
            'source_url' => 'https://authority.example.test/cda',
            'contact_url' => 'https://provider.example.test/contact',
            'verified_at' => now()->subHour(),
            'valid_until' => now()->addYear()->toDateString(),
            'status' => 'published',
        ]);
    }
}
