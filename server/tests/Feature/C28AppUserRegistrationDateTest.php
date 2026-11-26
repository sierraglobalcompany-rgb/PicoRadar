<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Models\AppUser;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Tests\TestCase;

class C28AppUserRegistrationDateTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        config([
            'app_accounts.enabled' => true,
            'app_accounts.privacy_url' => 'https://picoradar.test/privacidad',
            'app_accounts.privacy_version' => '2026-11-17',
            'app_accounts.transactional_email_enabled' => true,
            'app_accounts.marketing_send_enabled' => false,
        ]);
        Mail::fake();
    }

    public function test_registration_date_is_shown_in_bogota_without_mutating_utc_storage(): void
    {
        $this->assertSame('UTC', config('app.timezone'));

        $admin = User::factory()->create([
            'role' => OperatorRole::SuperAdmin,
            'is_active' => true,
        ]);

        $accounts = [
            [
                'name' => 'C28 Fecha Bogotá 0030 UTC',
                'email' => 'c28-registration-0030@example.test',
                'created_at' => '2026-11-24 00:30:00',
                'expected_date' => '2026-11-23',
            ],
            [
                'name' => 'C28 Fecha Bogotá 0600 UTC',
                'email' => 'c28-registration-0600@example.test',
                'created_at' => '2026-11-24 06:00:00',
                'expected_date' => '2026-11-24',
            ],
        ];

        foreach ($accounts as &$account) {
            $timestamp = Carbon::parse($account['created_at'], 'UTC');
            $user = AppUser::query()->create([
                'public_id' => (string) Str::uuid(),
                'name' => $account['name'],
                'email' => $account['email'],
                'phone' => null,
                'municipality' => null,
                'categories' => ['car'],
                'privacy_version' => '2026-11-17',
                'privacy_accepted_at' => Carbon::parse('2026-11-24 00:00:00', 'UTC'),
                'privacy_purpose' => 'optional_account',
                'marketing_consent' => false,
                'email_verified_at' => Carbon::parse('2026-11-24 00:00:00', 'UTC'),
            ]);
            $user->forceFill([
                'created_at' => $timestamp,
                'updated_at' => $timestamp,
            ])->save();
            $account['id'] = $user->id;
        }
        unset($account);

        $response = $this->actingAs($admin)->get(route('admin.app-users.index'));
        $response->assertOk();

        $document = new \DOMDocument;
        $previous = libxml_use_internal_errors(true);
        $document->loadHTML($response->getContent());
        libxml_clear_errors();
        libxml_use_internal_errors($previous);
        $xpath = new \DOMXPath($document);

        foreach ($accounts as $account) {
            $rows = $xpath->query('//tr[.//span[normalize-space(.) = "'.$account['name'].'"]]');
            $this->assertSame(1, $rows->length, 'Expected one table row for '.$account['name'].'.');

            $cells = $xpath->query('./td', $rows->item(0));
            $dateAndMarketing = preg_replace('/\s+/u', ' ', trim($cells->item($cells->length - 1)->textContent));
            $this->assertSame($account['expected_date'].' · Sin opt-in', $dateAndMarketing);

            $this->assertSame(
                $account['created_at'],
                DB::table('app_users')->where('id', $account['id'])->value('created_at'),
            );
            $this->assertSame(
                $account['created_at'],
                DB::table('app_users')->where('id', $account['id'])->value('updated_at'),
            );
        }

        $this->assertStringContainsString('Alta (Bogotá) / marketing', $response->getContent());
    }
}
