<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class NationalDatasetIntegrityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Storage::fake('public');
        config(['datasets.published_disk' => 'public']);
        config(['datasets.public_base_url' => '/storage']);
        config(['datasets.manifest_path' => 'manifest/v1/manifest.json']);
    }

    public function test_regular_dashboard_does_not_verify_or_read_dataset_assets(): void
    {
        $admin = $this->admin();

        $this->actingAs($admin)
            ->get(route('admin.operations.national'))
            ->assertOk()
            ->assertSeeText('NO_VERIFICADO')
            ->assertSeeText('Verificar integridad técnica ahora')
            ->assertDontSeeText('Comprobado en esta solicitud');
    }

    public function test_explicit_verification_checks_streamed_hash_and_manifest_per_dataset(): void
    {
        $admin = $this->admin();
        $restriction = $this->publishedDataset('restrictions', 'r-test', 'restrictions/r-test.json', '{"version":"r-test"}');
        $services = $this->publishedDataset('service_providers', 's-test', 'services/s-test.json', 'stored bytes differ');
        $entries = [
            'restrictions' => $this->manifestEntry($restriction, '{"version":"r-test"}'),
            'service_providers' => $this->manifestEntry($services, 'stored bytes differ'),
        ];
        Storage::disk('public')->put('manifest/v1/manifest.json', json_encode([
            'schemaVersion' => 1,
            'generatedAt' => now()->toAtomString(),
            'datasets' => $entries,
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));

        $response = $this->actingAs($admin)
            ->get(route('admin.operations.national', ['verify_assets' => '1']));

        $response->assertOk()
            ->assertSeeText('Comprobado en esta solicitud')
            ->assertSeeText('INTEGRIDAD_LOCAL_OK')
            ->assertSeeText('HASH_INCORRECTO')
            ->assertSeeText('Integridad técnica de servidor comprobada; no acredita legalidad, entrega OTA ni datos del dispositivo');
    }

    public function test_disabled_and_missing_current_release_states_take_precedence(): void
    {
        $admin = $this->admin();
        $restrictions = Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Restricciones nacionales',
            'schema_version' => 1,
            'enabled' => false,
            'current_version' => 'historical-pointer',
            'publication_revision' => 3,
        ]);
        Dataset::query()->create([
            'key' => 'service_providers',
            'title' => 'Servicios',
            'schema_version' => 1,
            'enabled' => true,
            'current_version' => null,
        ]);

        $this->actingAs($admin)
            ->get(route('admin.operations.national', ['verify_assets' => '1']))
            ->assertOk()
            ->assertSeeText('OFF')
            ->assertSeeText('SIN_RELEASE')
            ->assertDontSeeText('INTEGRIDAD_LOCAL_OK');

        $services = Dataset::query()->where('key', 'service_providers')->firstOrFail();
        $restrictions->update(['enabled' => true, 'current_version' => 'expired-r']);
        $services->update(['current_version' => 'current-s']);
        $expired = $this->publishRelease($restrictions, 'expired-r', 'restrictions/expired.json', '{"version":"expired"}', now()->subDay());
        $serviceRelease = $this->publishRelease($services, 'current-s', 'services/current.json', '{"version":"services"}');
        Storage::disk('public')->put('restrictions/expired.json', '{"version":"expired"}');
        Storage::disk('public')->put('services/current.json', '{"version":"services"}');
        $restrictionEntry = $this->manifestEntry($expired, '{"version":"expired"}');
        $serviceEntry = $this->manifestEntry($serviceRelease, '{"version":"services"}');
        $serviceEntry['version'] = 'different-version';
        Storage::disk('public')->put('manifest/v1/manifest.json', json_encode([
            'schemaVersion' => 1,
            'generatedAt' => now()->toAtomString(),
            'datasets' => [
                'restrictions' => $restrictionEntry + ['expiresAt' => $expired->expires_at->toAtomString()],
                'service_providers' => $serviceEntry,
            ],
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));

        $this->get(route('admin.operations.national', ['verify_assets' => '1']))
            ->assertOk()
            ->assertSeeText('VENCIDO')
            ->assertSeeText('MANIFEST_NO_COINCIDE');
    }

    public function test_missing_dataset_and_invalid_release_are_not_reported_as_storage_failures(): void
    {
        $admin = $this->admin();
        $services = Dataset::query()->create([
            'key' => 'service_providers',
            'title' => 'Servicios',
            'schema_version' => 1,
            'enabled' => true,
            'current_version' => 'draft-only',
        ]);
        $draft = $services->releases()->create([
            'version' => 'draft-only',
            'status' => DatasetReleaseStatus::Draft,
            'asset_path' => null,
            'sha256' => null,
        ]);

        $this->actingAs($admin)
            ->get(route('admin.operations.national', ['verify_assets' => '1']))
            ->assertOk()
            ->assertSeeText('DATASET_AUSENTE')
            ->assertSeeText('RELEASE_INVALIDO')
            ->assertDontSeeText('ASSET_NO_DISPONIBLE');

        $draft->update(['status' => DatasetReleaseStatus::Validated, 'sha256' => hash('sha256', 'asset bytes')]);
        $draft->update(['status' => DatasetReleaseStatus::Published, 'asset_path' => 'services/missing.json']);
        $this->get(route('admin.operations.national', ['verify_assets' => '1']))
            ->assertOk()
            ->assertSeeText('ASSET_NO_DISPONIBLE');
    }

    private function admin(): User
    {
        return User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
    }

    private function publishedDataset(string $key, string $version, string $path, string $bytes): DatasetRelease
    {
        $dataset = Dataset::query()->create([
            'key' => $key,
            'title' => $key,
            'schema_version' => 1,
            'enabled' => true,
            'current_version' => $version,
            'publication_revision' => 7,
        ]);
        $release = $this->publishRelease($dataset, $version, $path, $bytes);
        Storage::disk('public')->put($path, $key === 'service_providers' ? 'actual bytes differ' : $bytes);

        return $release->refresh();
    }

    private function publishRelease(Dataset $dataset, string $version, string $path, string $bytes, mixed $expiresAt = null): DatasetRelease
    {
        $release = $dataset->releases()->create([
            'version' => $version,
            'status' => DatasetReleaseStatus::Draft,
            'sha256' => hash('sha256', $bytes),
            'expires_at' => $expiresAt,
        ]);
        $release->status = DatasetReleaseStatus::Validated;
        $release->validated_at = now();
        $release->save();
        $release->status = DatasetReleaseStatus::Published;
        $release->asset_path = $path;
        $release->published_at = now();
        $release->save();

        return $release->refresh();
    }

    /** @return array<string, mixed> */
    private function manifestEntry(DatasetRelease $release, string $bytes): array
    {
        return [
            'version' => $release->version,
            'url' => '/storage/'.$release->asset_path,
            'sha256' => hash('sha256', $bytes),
            'publicationRevision' => (int) $release->dataset->publication_revision,
        ];
    }
}
