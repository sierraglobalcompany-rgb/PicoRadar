<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class PartnerInquiryApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.url' => 'https://api.picoradar.test',
            'partner_inquiries.enabled' => true,
            'partner_inquiries.admin_inbox_enabled' => true,
            'partner_inquiries.privacy_version' => '2026-09-19',
            'partner_inquiries.privacy_url' => 'https://picoradar.test/privacidad/aliados',
            'partner_inquiries.allow_insecure_local' => false,
        ]);
    }

    public function test_route_is_public_rate_limited_and_fails_closed_when_configuration_is_incomplete(): void
    {
        $route = Route::getRoutes()->getByName('api.v1.partner-inquiries.store');

        $this->assertNotNull($route);
        $this->assertSame('api/v1/partner-inquiries', $route->uri());
        $this->assertContains('throttle:partner-inquiries', $route->gatherMiddleware());

        config(['partner_inquiries.admin_inbox_enabled' => false]);

        $this->postJson('/api/v1/partner-inquiries', $this->payload(), $this->headers())
            ->assertStatus(503)
            ->assertExactJson(['error' => ['code' => 'not_configured']]);
    }

    public function test_insecure_development_override_is_limited_to_local_hosts(): void
    {
        config([
            'app.url' => 'http://partners.example.test',
            'partner_inquiries.allow_insecure_local' => true,
        ]);

        $this->postJson('/api/v1/partner-inquiries', $this->payload(), $this->headers())
            ->assertStatus(503)
            ->assertExactJson(['error' => ['code' => 'not_configured']]);
    }

    public function test_valid_inquiry_is_stored_without_vehicle_location_or_document_data(): void
    {
        $response = $this->postJson(
            '/api/v1/partner-inquiries',
            $this->payload(),
            $this->headers('mobile-attempt-0001'),
        )->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        $publicId = $response->json('data.id');
        $this->assertIsString($publicId);
        $this->assertMatchesRegularExpression('/^pi_[a-f0-9]{24}$/', $publicId);

        $stored = DB::table('partner_inquiries')->sole();
        $this->assertSame($publicId, $stored->public_id);
        $this->assertSame('Taller Ejemplo SAS', $stored->business_name);
        $this->assertSame('Persona Ejemplo', $stored->contact_name);
        $this->assertSame('contacto@example.test', $stored->email);
        $this->assertSame('Medellin', $stored->city);
        $this->assertSame('workshop', $stored->category);
        $this->assertSame('2026-09-19', $stored->consent_version);
        $this->assertNotSame('mobile-attempt-0001', $stored->idempotency_hash);
        $this->assertNotEmpty($stored->request_fingerprint);

        $columns = array_keys((array) $stored);
        $this->assertNotContains('plate', $columns);
        $this->assertNotContains('latitude', $columns);
        $this->assertNotContains('longitude', $columns);
        $this->assertNotContains('attachment', $columns);
    }

    public function test_explicit_current_consent_and_allowed_fields_are_required(): void
    {
        $payload = $this->payload();
        $payload['consentAccepted'] = false;
        $payload['consentVersion'] = 'old-version';
        $payload['plate'] = 'ABC123';
        $payload['gps'] = ['latitude' => 6.2, 'longitude' => -75.5];
        $payload['attachments'] = ['document.jpg'];

        $this->postJson('/api/v1/partner-inquiries', $payload, $this->headers())
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'validation_failed');

        $this->assertDatabaseCount('partner_inquiries', 0);
    }

    public function test_repeated_idempotency_key_returns_the_original_inquiry_without_duplicate(): void
    {
        $headers = $this->headers('mobile-attempt-repeat');
        $first = $this->postJson('/api/v1/partner-inquiries', $this->payload(), $headers)
            ->assertCreated();
        $second = $this->postJson('/api/v1/partner-inquiries', $this->payload(), $headers)
            ->assertOk();

        $this->assertSame($first->json('data.id'), $second->json('data.id'));
        $this->assertDatabaseCount('partner_inquiries', 1);
    }

    public function test_reusing_an_idempotency_key_for_different_content_is_rejected(): void
    {
        $headers = $this->headers('mobile-attempt-conflict');
        $this->postJson('/api/v1/partner-inquiries', $this->payload(), $headers)
            ->assertCreated();

        $changed = $this->payload();
        $changed['city'] = 'Bogota';

        $this->postJson('/api/v1/partner-inquiries', $changed, $headers)
            ->assertStatus(409)
            ->assertExactJson(['error' => ['code' => 'idempotency_conflict']]);
        $this->assertDatabaseCount('partner_inquiries', 1);
    }

    public function test_endpoint_throttles_repeated_new_attempts(): void
    {
        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postJson(
                '/api/v1/partner-inquiries',
                $this->payload(email: "contacto{$attempt}@example.test"),
                $this->headers("mobile-throttle-{$attempt}"),
            )->assertCreated();
        }

        $this->postJson(
            '/api/v1/partner-inquiries',
            $this->payload(email: 'contacto6@example.test'),
            $this->headers('mobile-throttle-6'),
        )->assertStatus(429)
            ->assertJsonPath('error.code', 'rate_limited');
    }

    /** @return array<string, string> */
    private function headers(string $key = 'mobile-attempt-default'): array
    {
        return ['Idempotency-Key' => $key];
    }

    /** @return array<string, mixed> */
    private function payload(string $email = 'contacto@example.test'): array
    {
        return [
            'businessName' => 'Taller Ejemplo SAS',
            'contactName' => 'Persona Ejemplo',
            'email' => $email,
            'phone' => '+57 300 000 0000',
            'city' => 'Medellin',
            'category' => 'workshop',
            'message' => 'Quiero conocer el programa de aliados.',
            'consentAccepted' => true,
            'consentVersion' => '2026-09-19',
        ];
    }
}
