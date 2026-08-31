<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
}
