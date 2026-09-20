<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Http\Controllers\Admin\RestrictionRuleController;
use App\Models\Dataset;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Tests\TestCase;

class RestrictionRuleControllerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    public function test_rule_index_reuses_dataset_view_permission(): void
    {
        Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $viewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);

        $this->actingAs($viewer);
        $view = app(RestrictionRuleController::class)->index($this->request($viewer));
        $this->assertSame('admin.restrictions.index', $view->name());
        $this->assertSame(0, $view->getData()['jurisdictions']->count());

        $this->actingAs($commercial);
        $this->expectException(AuthorizationException::class);
        app(RestrictionRuleController::class)->index($this->request($commercial));
    }

    public function test_csv_template_reuses_dataset_edit_permission_and_has_real_contract_headers(): void
    {
        $editor = User::factory()->create(['role' => OperatorRole::Editor]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);

        $this->actingAs($editor);
        $response = app(RestrictionRuleController::class)->template();
        $this->assertSame('text/csv; charset=UTF-8', $response->headers->get('content-type'));
        $this->assertStringContainsString('jurisdiction_id', $response->getContent());
        $this->assertStringContainsString('time_windows', $response->getContent());
        $this->assertStringContainsString('stale_after', $response->getContent());

        $this->actingAs($reviewer);
        $this->expectException(AuthorizationException::class);
        app(RestrictionRuleController::class)->template();
    }

    private function request(User $user): Request
    {
        $request = Request::create('/_b07/restrictions');
        $request->setUserResolver(fn (): User => $user);

        return $request;
    }
}
