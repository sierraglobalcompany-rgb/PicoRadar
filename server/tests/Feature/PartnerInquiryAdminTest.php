<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PartnerInquiryAdminTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        config([
            'partner_inquiries.enabled' => true,
            'partner_inquiries.admin_inbox_enabled' => true,
            'partner_inquiries.privacy_version' => '2026-09-19',
            'partner_inquiries.privacy_url' => 'https://picoradar.test/privacidad/aliados',
            'partner_inquiries.retention_days' => 180,
        ]);
    }

    public function test_inbox_requires_an_authenticated_authorized_operator(): void
    {
        $this->get('/admin/partner-inquiries')->assertRedirect('/login');

        $viewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        $this->actingAs($viewer)->get('/admin/partner-inquiries')->assertForbidden();

        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $this->actingAs($commercial)->get('/admin/partner-inquiries')->assertOk();
        $this->actingAs($commercial)->get('/admin/partner-inquiries/audit')->assertOk();
    }

    public function test_admin_can_review_inbox_and_change_status_with_non_pii_audit_metadata(): void
    {
        $operator = User::factory()->create(['role' => OperatorRole::Admin]);
        $id = $this->insertInquiry('pi_aaaaaaaaaaaaaaaaaaaaaaaa');

        $this->actingAs($operator)
            ->get('/admin/partner-inquiries')
            ->assertOk()
            ->assertSee('Taller Ejemplo SAS')
            ->assertSee('pending');

        $this->actingAs($operator)
            ->put("/admin/partner-inquiries/{$id}/status", ['status' => 'approved'])
            ->assertRedirect();

        $this->assertDatabaseHas('partner_inquiries', ['id' => $id, 'status' => 'approved']);
        $audit = DB::table('audit_logs')->where('action', 'partner_inquiry.status_changed')->sole();
        $metadata = json_decode($audit->metadata, true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame([
            'from' => 'pending',
            'publicId' => 'pi_aaaaaaaaaaaaaaaaaaaaaaaa',
            'to' => 'approved',
        ], $metadata);
        $this->assertStringNotContainsString('contacto@example.test', $audit->metadata);
        $this->assertStringNotContainsString('+57', $audit->metadata);
        $this->assertStringNotContainsString('Persona Ejemplo', $audit->metadata);

        $this->actingAs($operator)
            ->get('/admin/partner-inquiries/audit')
            ->assertOk()
            ->assertSee('partner_inquiry.status_changed')
            ->assertDontSee('contacto@example.test');
    }

    public function test_purge_removes_only_unapproved_inquiries_older_than_180_days(): void
    {
        $this->travelTo(now()->setDate(2026, 9, 19)->setTime(12, 0)->utc());
        $oldPending = $this->insertInquiry('pi_bbbbbbbbbbbbbbbbbbbbbbbb', 'pending', now()->subDays(181));
        $boundaryPending = $this->insertInquiry('pi_cccccccccccccccccccccccc', 'pending', now()->subDays(180));
        $oldApproved = $this->insertInquiry('pi_dddddddddddddddddddddddd', 'approved', now()->subDays(365));

        $this->artisan('partner-inquiries:purge')->assertSuccessful();

        $this->assertDatabaseMissing('partner_inquiries', ['id' => $oldPending]);
        $this->assertDatabaseHas('partner_inquiries', ['id' => $boundaryPending]);
        $this->assertDatabaseHas('partner_inquiries', ['id' => $oldApproved]);
    }

    private function insertInquiry(
        string $publicId,
        string $status = 'pending',
        ?\DateTimeInterface $createdAt = null,
    ): int {
        return DB::table('partner_inquiries')->insertGetId([
            'public_id' => $publicId,
            'idempotency_hash' => hash('sha256', $publicId),
            'request_fingerprint' => hash('sha256', $publicId.'-payload'),
            'business_name' => 'Taller Ejemplo SAS',
            'contact_name' => 'Persona Ejemplo',
            'email' => 'contacto@example.test',
            'phone' => '+57 300 000 0000',
            'city' => 'Medellin',
            'category' => 'workshop',
            'message' => null,
            'consent_version' => '2026-09-19',
            'consented_at' => now(),
            'status' => $status,
            'created_at' => $createdAt ?? now(),
            'updated_at' => $createdAt ?? now(),
        ]);
    }
}
