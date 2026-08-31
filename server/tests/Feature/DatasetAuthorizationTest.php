<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

class DatasetAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_commercial_is_denied_and_editor_can_open_registry(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        $this->actingAs($commercial)->get('/admin/datasets')->assertForbidden();
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->get('/admin/datasets')->assertOk();
    }

    public function test_editor_can_create_but_reviewer_cannot_edit_datasets(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->post('/admin/datasets', ['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1])->assertRedirect();
        $this->assertDatabaseHas('datasets', ['key' => 'restrictions']);
        $this->actingAs($editor)->post('/admin/datasets', ['key' => '../unsafe', 'title' => 'Unsafe', 'schema_version' => 1])->assertSessionHasErrors('key');
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $this->actingAs($reviewer)->post('/admin/datasets', ['key' => 'another', 'title' => 'Another', 'schema_version' => 1])->assertForbidden();
    }

    public function test_editor_cannot_register_a_source_with_an_unsafe_url(): void
    {
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->post(route('admin.datasets.sources.store', $dataset), ['title' => 'Unsafe', 'authority' => 'Unknown', 'url' => 'javascript:alert(1)', 'verified_at' => now()->toDateTimeString()])->assertSessionHasErrors('url');
    }

    public function test_editor_can_mutate_sources_and_drafts_but_cannot_review_releases(): void
    {
        $dataset = $this->dataset();
        $release = $this->release($dataset);
        $editor = User::factory()->create(['role' => OperatorRole::Editor, 'is_active' => true]);
        $this->actingAs($editor)->post(route('admin.datasets.sources.store', $dataset), ['title' => 'Official', 'authority' => 'Authority', 'url' => 'https://example.test', 'verified_at' => now()->toDateTimeString()])->assertRedirect();
        $source = $dataset->sources()->firstOrFail();
        $this->actingAs($editor)->put(route('admin.datasets.sources.update', [$dataset, $source]), ['title' => 'Updated', 'authority' => 'Authority', 'url' => 'https://example.test', 'verified_at' => now()->toDateTimeString(), 'is_active' => true])->assertRedirect();
        $this->actingAs($editor)->post(route('admin.datasets.releases.store', $dataset), ['dataset' => UploadedFile::fake()->createWithContent('draft.json', '{"version":"2026.08.31-draft"}')])->assertRedirect();
        foreach (['validate', 'publish', 'rollback', 'retire'] as $action) {
            $this->actingAs($editor)->post(route("admin.datasets.releases.$action", [$dataset, $release]))->assertForbidden();
        }
    }

    public function test_reviewer_can_review_but_cannot_mutate_registry_or_sources(): void
    {
        $dataset = $this->dataset();
        $release = $this->release($dataset);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer, 'is_active' => true]);
        $this->actingAs($reviewer)->get(route('admin.datasets.index'))->assertOk();
        foreach (['validate', 'publish', 'rollback', 'retire'] as $action) {
            $this->actingAs($reviewer)->post(route("admin.datasets.releases.$action", [$dataset, $release]))->assertRedirect();
        }
        $this->actingAs($reviewer)->post(route('admin.datasets.store'), ['key' => 'forbidden', 'title' => 'Forbidden', 'schema_version' => 1])->assertForbidden();
        $this->actingAs($reviewer)->post(route('admin.datasets.sources.store', $dataset), ['title' => 'Forbidden', 'authority' => 'Authority', 'url' => 'https://example.test', 'verified_at' => now()->toDateTimeString()])->assertForbidden();
        $this->actingAs($reviewer)->post(route('admin.datasets.releases.store', $dataset), ['dataset' => UploadedFile::fake()->createWithContent('draft.json', '{"version":"2026.08.31"}')])->assertForbidden();
    }

    public function test_commercial_is_denied_every_b01_surface_and_admin_roles_are_allowed(): void
    {
        $dataset = $this->dataset();
        $release = $this->release($dataset);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial, 'is_active' => true]);
        $this->actingAs($commercial)->get(route('admin.audit.index'))->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.datasets.store'), ['key' => 'forbidden', 'title' => 'Forbidden', 'schema_version' => 1])->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.datasets.sources.store', $dataset), [])->assertForbidden();
        $this->actingAs($commercial)->post(route('admin.datasets.releases.store', $dataset), [])->assertForbidden();
        foreach (['validate', 'publish', 'rollback', 'retire'] as $action) {
            $this->actingAs($commercial)->post(route("admin.datasets.releases.$action", [$dataset, $release]))->assertForbidden();
        }
        foreach ([OperatorRole::Admin, OperatorRole::SuperAdmin] as $role) {
            $operator = User::factory()->create(['role' => $role, 'is_active' => true]);
            $this->actingAs($operator)->get(route('admin.datasets.index'))->assertOk();
            $this->actingAs($operator)->get(route('admin.audit.index'))->assertOk();
            $this->actingAs($operator)->post(route('admin.datasets.store'), ['key' => "admin_{$role->value}", 'title' => 'Allowed', 'schema_version' => 1])->assertRedirect();
        }
    }

    private function dataset(): Dataset
    {
        return Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
    }

    private function release(Dataset $dataset): DatasetRelease
    {
        return $dataset->releases()->create(['version' => '2026.08.31', 'status' => 'draft']);
    }
}
