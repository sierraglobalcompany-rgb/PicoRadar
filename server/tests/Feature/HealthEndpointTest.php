<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class HealthEndpointTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_returns_the_stable_public_contract(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertExactJson([
                'status' => 'ok',
                'service' => 'picoradar-control-plane',
                'apiVersion' => 'v1',
            ]);
    }

    public function test_api_errors_use_the_safe_error_contract(): void
    {
        $this->getJson('/api/v1/not-a-real-endpoint')
            ->assertNotFound()
            ->assertExactJson([
                'error' => [
                    'code' => 'not_found',
                    'message' => 'The requested API resource was not found.',
                ],
            ]);
    }

    public function test_health_does_not_expose_application_configuration(): void
    {
        config([
            'app.key' => 'base64:not-for-response',
            'database.connections.mysql.host' => 'internal-db.example.test',
        ]);

        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertDontSee('not-for-response')
            ->assertDontSee('internal-db.example.test');
    }

    public function test_health_limiter_returns_the_api_error_contract(): void
    {
        for ($attempt = 0; $attempt < 60; $attempt++) {
            $this->getJson('/api/v1/health')->assertOk();
        }

        $this->getJson('/api/v1/health')
            ->assertTooManyRequests()
            ->assertJsonPath('error.code', 'rate_limited');
    }
}
