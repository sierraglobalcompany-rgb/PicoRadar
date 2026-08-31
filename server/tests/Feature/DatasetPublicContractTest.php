<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\AuditLog;
use App\Models\Dataset;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DatasetPublicContractTest extends TestCase
{
    use RefreshDatabase;

    public function test_static_public_paths_match_the_mobile_manifest_contract(): void
    {
        $links = config('filesystems.links');
        $this->assertSame(storage_path('app/public'), $links[public_path('storage')]);
        $this->assertSame(storage_path('app/public/manifest/v1'), $links[public_path('v1')]);
        $this->assertSame('manifest/v1/manifest.json', config('datasets.manifest_path'));
        $this->assertSame('/v1/manifest.json', config('datasets.manifest_public_url'));
        $this->assertSame('/storage/datasets/restrictions/2026.08.31/restrictions-2026.08.31.json', rtrim(config('datasets.public_base_url'), '/').'/datasets/restrictions/2026.08.31/restrictions-2026.08.31.json');
    }

    public function test_audit_log_uses_read_only_newest_first_pagination(): void
    {
        $this->withoutVite();
        $operator = User::factory()->create(['role' => OperatorRole::Admin, 'is_active' => true]);
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        foreach (range(1, 51) as $index) {
            AuditLog::query()->create(['action' => "dataset.updated.$index", 'subject_type' => Dataset::class, 'subject_id' => $dataset->id]);
        }
        $response = $this->actingAs($operator)->get(route('admin.audit.index'));
        $response->assertOk()->assertViewHas('logs', fn ($logs): bool => $logs->perPage() === 50 && $logs->total() === 51 && $logs->first()->id > $logs->last()->id);
        $this->actingAs($operator)->get(route('admin.audit.index', ['page' => 2]))->assertOk();
    }
}
