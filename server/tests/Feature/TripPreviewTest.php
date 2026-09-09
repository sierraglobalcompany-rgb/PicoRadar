<?php

namespace Tests\Feature;

use App\Enums\GeographicUnitLevel;
use App\Models\GeographicUnit;
use App\Services\TollGuruTripPreview;
use App\Support\GeographicNameNormalizer;
use GuzzleHttp\Exception\ConnectTimeoutException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Factory;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;
use Tests\Unit\TollGuruTripPreviewTest;

class TripPreviewTest extends TestCase
{
    use RefreshDatabase;

    private const ENDPOINT = 'https://apis.tollguru.com/toll/v2/origin-destination-waypoints/';

    private const LEDGER = 'trips:tollguru:budget:v1';

    private const LOCK = 'trips:tollguru:operation:v1';

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(now()->setDate(2026, 9, 5)->setTime(12, 0)->utc());
        $this->fakeProvider([self::ENDPOINT => fn () => Http::response(TollGuruTripPreviewTest::providerFixture())]);
        config([
            'trips.enabled' => false,
            'trips.api_key' => 'synthetic-test-key-not-a-credential',
            'trips.access_authorized' => true,
            'trips.license_authorized' => true,
            'trips.confirmed_free' => false,
            'trips.authorization_expires_at' => '2026-09-06T12:00:00Z',
            'trips.cache_store' => 'database',
            'trips.budget_id' => 'test-authorization-001',
            'trips.budget_currency' => 'USD',
            'trips.max_requests' => 2,
            'trips.max_units' => 42,
            'trips.max_money_minor' => 600,
            'trips.units_per_request' => 21,
            'trips.money_minor_per_request' => 300,
            'trips.timeout_seconds' => 10,
            'trips.connect_timeout_seconds' => 3,
            'trips.lock_seconds' => 30,
            'trips.max_request_bytes' => 4096,
            'trips.max_response_bytes' => 262144,
            'trips.max_routes' => 3,
            'trips.max_tolls' => 200,
            'trips.max_future_days' => 30,
        ]);
        $country = $this->unit('CO', 'Colombia', GeographicUnitLevel::Country);
        $department = $this->unit('05', 'ANTIOQUIA', GeographicUnitLevel::Department, $country->id);
        $this->unit('05001', "MEDELL\u{00cd}N", GeographicUnitLevel::Municipality, $department->id);
        $this->unit('05615', 'RIONEGRO', GeographicUnitLevel::Municipality, $department->id);
        Cache::store('database')->forever(self::LEDGER, $this->ledger());
    }

    public function test_disabled_bridge_returns_not_configured_even_with_key_present(): void
    {
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
    }

    public function test_date_only_request_uses_explicit_local_noon_reference_without_user_hour(): void
    {
        config(['trips.enabled' => true]);
        $request = $this->request();
        $request['departureMode'] = 'date_only';
        $request['departureDate'] = '2026-09-06';
        $request['departureUtc'] = null;

        $this->postJson('/api/v1/trips/preview', $request)
            ->assertOk()
            ->assertJsonPath('routes.0.timeBasis', 'static');

        Http::assertSent(function (Request $sent): bool {
            $this->assertSame('2026-09-06T17:00:00Z', $sent['departure_time']);

            return true;
        });
        Http::assertSentCount(1);
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
    }

    public function test_now_request_accepts_and_preserves_the_single_recent_capture(): void
    {
        config(['trips.enabled' => true]);
        $request = $this->request();
        $request['departureMode'] = 'now';
        $request['departureDate'] = '2026-09-05';
        $request['departureUtc'] = '2026-09-05T11:59:59Z';

        $this->postJson('/api/v1/trips/preview', $request)->assertOk();

        Http::assertSent(fn (Request $sent): bool => $sent['departure_time'] === '2026-09-05T11:59:59Z');
        Http::assertSentCount(1);
    }

    public function test_production_route_is_registered_and_throttled_without_account(): void
    {
        $route = Route::getRoutes()->getByName('api.v1.trips.preview');
        $this->assertNotNull($route);
        $this->assertSame('api/v1/trips/preview', $route->uri());
        $this->assertContains('throttle:trips-preview', $route->gatherMiddleware());
        for ($i = 0; $i < 6; $i++) {
            $this->postJson('/api/v1/trips/preview', $this->request())->assertStatus(503);
        }
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        Http::assertNothingSent();
    }

    public function test_enabled_bridge_works_without_account_and_sends_only_documented_allowlist(): void
    {
        config(['trips.enabled' => true]);
        $response = $this->postJson('/api/v1/trips/preview', $this->request());

        $response->assertOk()->assertJsonPath('requestId', 'trip-test-001')
            ->assertJsonPath('routes.0.geometry.type', 'LineString')
            ->assertJsonPath('routes.0.geometry.coordinates.0', [-75.5812, 6.2442])
            ->assertJsonPath('routes.0.geometry.coordinates.2', [-75.374, 6.1533])
            ->assertJsonPath('routes.0.tolls.totalMinor', 1800030)
            ->assertJsonPath('routes.0.tolls.stationCount', 2)
            ->assertJsonPath('routes.0.tolls.payableCount', 2);
        Http::assertSentCount(1);
        Http::assertSent(function (Request $request): bool {
            $this->assertSame(self::ENDPOINT, $request->url());
            $this->assertSame('POST', $request->method());
            $this->assertSame([
                'from' => ['address' => "MEDELL\u{00cd}N, ANTIOQUIA, Colombia"],
                'to' => ['address' => 'RIONEGRO, ANTIOQUIA, Colombia'],
                'vehicle' => ['type' => '2AxlesAuto'],
                'serviceProvider' => 'here',
                'departure_time' => '2026-09-06T04:30:00Z',
                'units' => ['currency' => 'COP'],
                'allowFerry' => false,
            ], $request->data());

            return true;
        });
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
    }

    public function test_unknown_trip_provider_fails_closed_without_spending_or_http(): void
    {
        config(['trips.enabled' => true, 'trips.provider' => 'unknown-provider']);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);

        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public function test_private_osrm_provider_requires_authorized_versioned_route_points_without_spending(): void
    {
        config([
            'trips.enabled' => true,
            'trips.provider' => 'private_osrm',
            'trips.private_osrm.enabled' => true,
            'trips.private_osrm.access_authorized' => true,
            'trips.private_osrm.source_authorized' => true,
            'trips.private_osrm.base_url' => 'https://osrm.test',
        ]);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);

        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public function test_private_osrm_provider_returns_geometry_without_claiming_toll_totals_or_spending_tollguru_budget(): void
    {
        config([
            'trips.enabled' => true,
            'trips.provider' => 'private_osrm',
            'trips.private_osrm.enabled' => true,
            'trips.private_osrm.access_authorized' => true,
            'trips.private_osrm.source_authorized' => true,
            'trips.private_osrm.base_url' => 'https://osrm.test',
            'trips.private_osrm.attribution' => 'OSRM; OpenStreetMap contributors',
        ]);
        $this->routePoint('05001', 6.2442, -75.5812);
        $this->routePoint('05615', 6.1533, -75.3740);
        $coordinates = [
            [-75.5812, 6.2442],
            [-75.48, 6.2],
            [-75.374, 6.1533],
        ];
        $this->fakeProvider(['https://osrm.test/route/v1/driving/*' => Http::response([
            'code' => 'Ok',
            'routes' => [[
                'distance' => 42000.4,
                'duration' => 3600.2,
                'geometry' => [
                    'type' => 'LineString',
                    'coordinates' => $coordinates,
                ],
            ]],
            'waypoints' => [
                ['name' => 'Medellin', 'location' => [-75.5812, 6.2442]],
                ['name' => 'Rionegro', 'location' => [-75.374, 6.1533]],
            ],
        ], 200, ['Content-Type' => 'application/json'])]);

        $response = $this->postJson('/api/v1/trips/preview', $this->request());

        $response
            ->assertOk()
            ->assertJsonPath('provider', 'Private OSRM')
            ->assertJsonPath('attribution', 'OSRM; OpenStreetMap contributors')
            ->assertJsonPath('origin.latitude', 6.2442)
            ->assertJsonPath('destination.longitude', -75.374)
            ->assertJsonPath('routes.0.distanceMeters', 42000)
            ->assertJsonPath('routes.0.durationSeconds', 3600)
            ->assertJsonPath('routes.0.geometry.encoding', 'polyline6')
            ->assertJsonPath('routes.0.geometry.pointCount', 3)
            ->assertJsonPath('routes.0.tolls.coverage', 'unknown')
            ->assertJsonPath('routes.0.tolls.totalMinor', null)
            ->assertJsonPath('routes.0.tolls.stationCount', null);
        $this->assertSame($this->polyline6($coordinates), $response->json('routes.0.geometry.coordinates'));

        Http::assertSent(function (Request $request): bool {
            $this->assertSame('GET', $request->method());
            $this->assertStringStartsWith('https://osrm.test/route/v1/driving/-75.5812,6.2442;-75.374,6.1533', $request->url());
            $query = [];
            parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);
            $this->assertSame('full', $query['overview'] ?? null);
            $this->assertSame('polyline6', $query['geometries'] ?? null);
            $this->assertSame('false', $query['steps'] ?? null);
            $this->assertSame('true', $query['alternatives'] ?? null);

            return true;
        });
        Http::assertSentCount(1);
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public function test_private_osrm_preserves_full_geometry_with_compact_mobile_transport(): void
    {
        config([
            'trips.enabled' => true,
            'trips.provider' => 'private_osrm',
            'trips.private_osrm.enabled' => true,
            'trips.private_osrm.access_authorized' => true,
            'trips.private_osrm.source_authorized' => true,
            'trips.private_osrm.base_url' => 'https://osrm.test',
            'trips.private_osrm.attribution' => 'OSRM; OpenStreetMap contributors',
        ]);
        $this->routePoint('05001', 6.2442, -75.5812);
        $this->routePoint('05615', 6.1533, -75.3740);
        $coordinates = $this->osrmLineCoordinates(12001, [-75.5812, 6.2442], [-75.374, 6.1533]);
        $encoded = $this->polyline6($coordinates);
        $providerBody = json_encode([
            'code' => 'Ok',
            'routes' => [[
                'distance' => 42000.4,
                'duration' => 3600.2,
                'geometry' => $encoded,
            ]],
        ], JSON_THROW_ON_ERROR);
        $this->fakeProvider(['https://osrm.test/route/v1/driving/*' => Http::response($providerBody, 200, ['Content-Type' => 'application/json'])]);

        $response = $this->postJson('/api/v1/trips/preview', $this->request());

        $response->assertOk()
            ->assertJsonPath('routes.0.geometry.encoding', 'polyline6')
            ->assertJsonPath('routes.0.geometry.pointCount', 12001)
            ->assertJsonPath('routes.0.geometry.coordinates', $encoded);
        $this->assertLessThanOrEqual(524288, strlen($response->getContent()));
        Http::assertSent(function (Request $request): bool {
            $query = [];
            parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

            return ($query['overview'] ?? null) === 'full' && ($query['geometries'] ?? null) === 'polyline6';
        });
    }

    public function test_confirmed_free_trial_allows_zero_money_and_reserves_non_money_quota(): void
    {
        $this->enableConfirmedFreeTrial();

        $this->postJson('/api/v1/trips/preview', $this->request())->assertOk();

        Http::assertSentCount(1);
        $this->assertSame($this->ledger(1, 21, 0), Cache::store('database')->get(self::LEDGER));
    }

    public function test_zero_money_trial_requires_explicit_confirmed_free_authorization(): void
    {
        config([
            'trips.enabled' => true,
            'trips.max_money_minor' => 0,
            'trips.money_minor_per_request' => 0,
        ]);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    #[DataProvider('missingConfirmedFreeAuthorization')]
    public function test_confirmed_free_trial_keeps_non_money_authorization_gates_closed(string $key, mixed $value): void
    {
        $this->enableConfirmedFreeTrial();
        config(['trips.'.$key => $value]);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public static function missingConfirmedFreeAuthorization(): array
    {
        return [
            'owner access not authorized' => ['access_authorized', false],
            'provider key missing' => ['api_key', null],
            'provider license not authorized' => ['license_authorized', false],
            'free-cost evidence not boolean' => ['confirmed_free', 'true'],
            'authorization deadline missing' => ['authorization_expires_at', null],
            'request allowance missing' => ['max_requests', 0],
            'unit allowance missing' => ['max_units', 0],
            'unit reservation missing' => ['units_per_request', 0],
            'timeout missing' => ['timeout_seconds', 0],
        ];
    }

    public function test_expired_authorization_blocks_confirmed_free_trial_without_spending(): void
    {
        $this->enableConfirmedFreeTrial();
        config(['trips.authorization_expires_at' => '2026-09-05T12:00:00Z']);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    #[DataProvider('exhaustedConfirmedFreeLedgers')]
    public function test_confirmed_free_trial_still_enforces_request_and_unit_caps(int $requests, int $units): void
    {
        $this->enableConfirmedFreeTrial();
        $ledger = $this->ledger($requests, $units, 0);
        Cache::store('database')->forever(self::LEDGER, $ledger);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        Http::assertNothingSent();
        $this->assertSame($ledger, Cache::store('database')->get(self::LEDGER));
    }

    public static function exhaustedConfirmedFreeLedgers(): array
    {
        return [
            'requests exhausted' => [2, 0],
            'units exhausted' => [0, 22],
        ];
    }

    public function test_confirmed_free_trial_rejects_corrupt_ledger_without_resetting_it(): void
    {
        $this->enableConfirmedFreeTrial();
        $ledger = $this->ledger();
        $ledger['requests'] = '0';
        Cache::store('database')->forever(self::LEDGER, $ledger);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        Http::assertNothingSent();
        $this->assertSame($ledger, Cache::store('database')->get(self::LEDGER));
    }

    public function test_unknown_cost_mode_rejects_zero_money_budget(): void
    {
        config([
            'trips.enabled' => true,
            'trips.confirmed_free' => false,
            'trips.max_money_minor' => 0,
            'trips.money_minor_per_request' => 0,
        ]);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public function test_confirmed_free_trial_rejects_positive_money_budget_and_reservation(): void
    {
        $this->enableConfirmedFreeTrial();
        config([
            'trips.max_money_minor' => 100,
            'trips.money_minor_per_request' => 1,
        ]);

        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    #[DataProvider('closedConfiguration')]
    public function test_missing_authorization_or_invalid_caps_prevent_all_upstream_calls(string $key, mixed $value): void
    {
        config(['trips.enabled' => true, 'trips.'.$key => $value]);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(503)->assertExactJson(['error' => ['code' => 'not_configured']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public static function closedConfiguration(): array
    {
        return [
            'no key' => ['api_key', null],
            'no account permission' => ['access_authorized', false],
            'no license permission' => ['license_authorized', false],
            'no budget identity' => ['budget_id', ''],
            'zero requests' => ['max_requests', 0],
            'negative units' => ['max_units', -1],
            'no money cap' => ['max_money_minor', null],
            'no unit reservation' => ['units_per_request', 0],
            'no money reservation' => ['money_minor_per_request', 0],
            'fractional money' => ['money_minor_per_request', 0.5],
            'overflow reservation' => ['money_minor_per_request', PHP_INT_MAX],
            'memory only cache' => ['cache_store', 'array'],
            'fallback can lose ledger' => ['cache_store', 'failover'],
            'lock expires during HTTP' => ['lock_seconds', 1],
        ];
    }

    #[DataProvider('invalidRequests')]
    public function test_strict_request_validation_rejects_untrusted_or_private_fields_before_spending(string $path, mixed $value): void
    {
        config(['trips.enabled' => true]);
        $request = $this->request();
        data_set($request, $path, $value);
        $this->postJson('/api/v1/trips/preview', $request)
            ->assertStatus(422)->assertExactJson(['error' => ['code' => 'validation']]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public static function invalidRequests(): array
    {
        return [
            'plate' => ['plate', 'TEST123'],
            'vehicle ID' => ['vehicleId', 'local-private-id'],
            'arbitrary URL' => ['url', 'https://example.invalid/'],
            'nested coordinates' => ['origin.latitude', 6.2],
            'unknown municipality code' => ['origin.code', '99999'],
            'code must be string' => ['origin.code', 5001],
            'label does not match code' => ['origin.municipality', 'RIONEGRO'],
            'wrong department' => ['origin.department', 'SANTANDER'],
            'department is not municipality' => ['origin.code', '05'],
            'empty identity' => ['requestId', ''],
            'unbounded identity' => ['requestId', str_repeat('a', 129)],
            'wrong zone' => ['timeZone', 'America/New_York'],
            'missing UTC suffix' => ['departureUtc', '2026-09-06T04:30:00'],
            'invalid calendar date' => ['departureUtc', '2026-09-31T04:30:00Z'],
            'noncash' => ['paymentMethod', 'tag'],
            'unverified physical category' => ['vehicleCategory', 'truck'],
            'zero alternatives' => ['alternatives', 0],
            'too many alternatives' => ['alternatives', 4],
            'string alternatives' => ['alternatives', '2'],
            'boolean alternatives' => ['alternatives', true],
        ];
    }

    public function test_same_municipality_is_rejected_without_distinct_points(): void
    {
        config(['trips.enabled' => true]);
        $request = $this->request();
        $request['destination'] = $request['origin'];
        $this->postJson('/api/v1/trips/preview', $request)
            ->assertStatus(422)->assertExactJson(['error' => ['code' => 'validation']]);
        Http::assertNothingSent();
    }

    public function test_inactive_catalog_municipality_is_rejected(): void
    {
        config(['trips.enabled' => true]);
        GeographicUnit::query()->where('code', '05615')->update(['is_active' => false]);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(422)->assertExactJson(['error' => ['code' => 'validation']]);
        Http::assertNothingSent();
    }

    public function test_taxi_mapping_fails_closed_without_sending_car_request(): void
    {
        config(['trips.enabled' => true]);
        $request = $this->request();
        $request['vehicleCategory'] = 'taxi';
        $this->postJson('/api/v1/trips/preview', $request)
            ->assertStatus(422)->assertExactJson(['error' => ['code' => 'unsupported_vehicle']]);
        Http::assertNothingSent();
    }

    public function test_motorcycle_uses_its_documented_type_and_never_infers_free_tolls(): void
    {
        config(['trips.enabled' => true]);
        $request = $this->request();
        $request['vehicleCategory'] = 'motorcycle';
        $body = TollGuruTripPreviewTest::providerFixture();
        $body['summary']['vehicleType'] = '2AxlesMotorcycle';
        $body['routes'][0]['tolls'] = [];
        $body['routes'][0]['costs']['cash'] = null;
        $this->fakeProvider([self::ENDPOINT => Http::response($body)]);
        $this->postJson('/api/v1/trips/preview', $request)
            ->assertOk()->assertJsonPath('routes.0.tolls.coverage', 'unknown')
            ->assertJsonPath('routes.0.tolls.totalMinor', null);
        Http::assertSent(fn (Request $sent): bool => $sent['vehicle']['type'] === '2AxlesMotorcycle');
        Http::assertSentCount(1);
    }

    #[DataProvider('invalidBodies')]
    public function test_request_body_is_bounded_and_requires_json_object(string $body): void
    {
        config(['trips.enabled' => true]);
        $this->call('POST', '/api/v1/trips/preview', [], [], [], ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], $body)
            ->assertStatus(422)->assertExactJson(['error' => ['code' => 'validation']]);
        Http::assertNothingSent();
    }

    public static function invalidBodies(): array
    {
        return ['truncated' => ['{"requestId":'], 'scalar' => ['true'], 'array' => ['[]'], 'too big' => [str_repeat(' ', 4097)]];
    }

    public function test_missing_spent_ledger_is_never_reinitialized(): void
    {
        config(['trips.enabled' => true]);
        Cache::store('database')->forget(self::LEDGER);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        $this->assertNull(Cache::store('database')->get(self::LEDGER));
        Http::assertNothingSent();
    }

    #[DataProvider('invalidLedgers')]
    public function test_corrupt_or_mismatched_ledger_is_not_reset_or_spent(string $field, mixed $value): void
    {
        config(['trips.enabled' => true]);
        $ledger = $this->ledger();
        $ledger[$field] = $value;
        Cache::store('database')->forever(self::LEDGER, $ledger);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        $this->assertSame($ledger, Cache::store('database')->get(self::LEDGER));
        Http::assertNothingSent();
    }

    public static function invalidLedgers(): array
    {
        return [
            'old authorization' => ['budget_id', 'old-authorization'],
            'wrong currency' => ['currency', 'COP'],
            'missing units' => ['units', null],
            'negative money' => ['money_minor', -1],
            'string counter' => ['requests', '0'],
            'overflow money' => ['money_minor', PHP_INT_MAX],
            'abandoned operation' => ['in_flight', true],
            'missing operation state' => ['in_flight', null],
        ];
    }

    #[DataProvider('exhaustedLedgers')]
    public function test_each_global_cap_blocks_without_partially_reserving_other_counters(int $requests, int $units, int $money): void
    {
        config(['trips.enabled' => true]);
        $ledger = $this->ledger($requests, $units, $money);
        Cache::store('database')->forever(self::LEDGER, $ledger);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        $this->assertSame($ledger, Cache::store('database')->get(self::LEDGER));
        Http::assertNothingSent();
    }

    public static function exhaustedLedgers(): array
    {
        return ['request cap' => [2, 0, 0], 'unit cap' => [0, 22, 0], 'money cap' => [0, 0, 301]];
    }

    public function test_global_cap_is_shared_across_ips_requests_and_service_instances(): void
    {
        config(['trips.enabled' => true]);
        foreach (['192.0.2.1', '192.0.2.2'] as $index => $ip) {
            $request = $this->request();
            $request['requestId'] = 'test-request-'.$index;
            $this->withServerVariables(['REMOTE_ADDR' => $ip])->postJson('/api/v1/trips/preview', $request)->assertOk();
        }
        $this->withServerVariables(['REMOTE_ADDR' => '192.0.2.3'])->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        Http::assertSentCount(2);
        $this->assertSame($this->ledger(2, 42, 600), Cache::store('database')->get(self::LEDGER));
    }

    public function test_single_operation_lock_blocks_all_requests_without_spending(): void
    {
        config(['trips.enabled' => true]);
        $lock = Cache::store('database')->lock(self::LOCK, 30);
        $this->assertTrue($lock->get());
        try {
            $this->postJson('/api/v1/trips/preview', $this->request())
                ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
            Http::assertNothingSent();
            $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
        } finally {
            $lock->release();
        }
    }

    public function test_reservation_and_operation_lock_are_in_place_before_http_and_lock_is_released_afterward(): void
    {
        config(['trips.enabled' => true]);
        $this->fakeProvider(function (): mixed {
            $this->assertSame([...$this->ledger(1, 21, 300), 'in_flight' => true], Cache::store('database')->get(self::LEDGER));
            $contender = Cache::store('database')->lock(self::LOCK, 30);
            $this->assertFalse($contender->get());

            return Http::response(TollGuruTripPreviewTest::providerFixture());
        });
        $this->postJson('/api/v1/trips/preview', $this->request())->assertOk();
        $lock = Cache::store('database')->lock(self::LOCK, 30);
        $this->assertTrue($lock->get());
        $lock->release();
    }

    #[DataProvider('upstreamErrors')]
    public function test_upstream_failures_are_sanitized_not_retried_and_never_refunded(int $upstream, int $status, string $code): void
    {
        config(['trips.enabled' => true]);
        Log::spy();
        $this->fakeProvider([self::ENDPOINT => Http::response('private-route TEST123 synthetic-test-key-not-a-credential', $upstream)]);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus($status)->assertExactJson(['error' => ['code' => $code]]);
        Http::assertSentCount(1);
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
        Log::shouldNotHaveReceived('error');
        Log::shouldNotHaveReceived('warning');
        $lock = Cache::store('database')->lock(self::LOCK, 30);
        $this->assertTrue($lock->get());
        $lock->release();
    }

    public static function upstreamErrors(): array
    {
        return ['unauthorized' => [401, 503, 'not_configured'], 'forbidden' => [403, 503, 'not_configured'], 'limited' => [429, 429, 'quota'], 'server failure' => [500, 502, 'invalid_upstream'], 'redirect' => [302, 502, 'invalid_upstream']];
    }

    public function test_network_failure_is_sanitized_and_keeps_conservative_reservation(): void
    {
        config(['trips.enabled' => true]);
        $this->fakeProvider(function (): never {
            throw new ConnectionException('private route and synthetic-test-key-not-a-credential');
        });
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(502)->assertExactJson(['error' => ['code' => 'network']]);
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
    }

    public function test_only_budget_metadata_is_retained_in_durable_cache(): void
    {
        config(['trips.enabled' => true]);
        $this->postJson('/api/v1/trips/preview', $this->request())->assertOk();
        $values = DB::table('cache')->pluck('value')->implode(' ');
        foreach (['trip-test-001', 'gqbe@', 'Test station', 'MEDELL', 'RIONEGRO', 'synthetic-test-key', 'upstream-private-marker'] as $privateValue) {
            $this->assertStringNotContainsString($privateValue, $values);
        }
    }

    public function test_expired_lock_cannot_admit_a_second_operation_while_first_is_active(): void
    {
        config(['trips.enabled' => true]);
        $this->fakeProvider(function (): mixed {
            $this->travel(31)->seconds();
            try {
                app(TollGuruTripPreview::class)->preview($this->request());
                $this->fail('An active operation must survive expiration of the cache lock.');
            } catch (\DomainException $exception) {
                $this->assertSame('quota', $exception->getMessage());
            }

            return Http::response(TollGuruTripPreviewTest::providerFixture());
        });
        $this->postJson('/api/v1/trips/preview', $this->request())->assertOk();
        Http::assertSentCount(1);
        $this->assertTrue(Cache::store('database')->get(self::LEDGER)['in_flight']);
    }

    public function test_ledger_evicted_during_http_is_never_restored_from_stale_memory(): void
    {
        config(['trips.enabled' => true]);
        $this->fakeProvider(function (): mixed {
            Cache::store('database')->forget(self::LEDGER);

            return Http::response(TollGuruTripPreviewTest::providerFixture());
        });
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        $this->assertNull(Cache::store('database')->get(self::LEDGER));
        Http::assertSentCount(1);
    }

    public function test_unavailable_cache_never_falls_back_to_unmetered_http(): void
    {
        config(['trips.enabled' => true]);
        Cache::shouldReceive('store')->andThrow(new \RuntimeException('private storage details'));
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(429)->assertExactJson(['error' => ['code' => 'quota']]);
        Http::assertNothingSent();
    }

    public function test_transport_timeout_uses_typed_cause_without_exposing_exception_text(): void
    {
        config(['trips.enabled' => true]);
        $this->fakeProvider(function (): never {
            $cause = new ConnectTimeoutException('private-route', new \GuzzleHttp\Psr7\Request('POST', self::ENDPOINT));
            throw new ConnectionException('private timeout details', 0, $cause);
        });
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(504)->assertExactJson(['error' => ['code' => 'timeout']]);
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
    }

    public function test_transport_disables_redirects_and_bounds_streamed_response_without_content_length(): void
    {
        config(['trips.enabled' => true]);
        $this->fakeProvider(function ($request, $options): mixed {
            $this->assertFalse($options['allow_redirects']);
            $this->assertTrue($options['verify']);
            $this->assertTrue($options['stream']);
            $this->assertLessThanOrEqual(10, $options['timeout']);
            $this->assertLessThanOrEqual(3, $options['connect_timeout']);

            return Http::response(str_repeat(' ', 262145), 200, ['Content-Type' => 'application/json']);
        });
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(502)->assertExactJson(['error' => ['code' => 'invalid_upstream']]);
        Http::assertSentCount(1);
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
    }

    public function test_provider_echoed_secret_is_not_released_as_a_route_label(): void
    {
        config(['trips.enabled' => true]);
        $body = TollGuruTripPreviewTest::providerFixture();
        $body['routes'][0]['summary']['name'] = 'synthetic-test-key-not-a-credential';
        $this->fakeProvider([self::ENDPOINT => Http::response($body)]);
        $this->postJson('/api/v1/trips/preview', $this->request())
            ->assertStatus(502)->assertExactJson(['error' => ['code' => 'invalid_upstream']]);
    }

    #[DataProvider('bogotaDirections')]
    public function test_catalog_bogota_endpoint_passes_controller_and_adapter_in_both_directions(bool $reverse): void
    {
        config(['trips.enabled' => true]);
        [$request, $body] = TollGuruTripPreviewTest::bogotaFixture($reverse);
        $endpoint = $reverse ? 'origin' : 'destination';
        $country = GeographicUnit::query()->where('code', 'CO')->firstOrFail();
        $department = $this->unit('11', $request[$endpoint]['department'], GeographicUnitLevel::Department, $country->id);
        $this->unit('11001', $request[$endpoint]['municipality'], GeographicUnitLevel::Municipality, $department->id);
        $this->fakeProvider([self::ENDPOINT => Http::response($body)]);

        $this->postJson('/api/v1/trips/preview', $request)->assertOk()
            ->assertJsonPath($endpoint.'.latitude', 4.711)
            ->assertJsonPath('routes.0.distanceMeters', 420000);
        $field = $reverse ? 'from' : 'to';
        $address = $request[$endpoint]['municipality'].', '.$request[$endpoint]['department'].', Colombia';
        Http::assertSent(fn (Request $sent): bool => $sent[$field]['address'] === $address);
        Http::assertSentCount(1);
    }

    public static function bogotaDirections(): array
    {
        return ['Bogota destination' => [false], 'Bogota origin' => [true]];
    }

    #[DataProvider('bogotaWrongAddresses')]
    public function test_catalog_bogota_rejects_provider_homonym_or_wrong_department(bool $reverse, string $address): void
    {
        config(['trips.enabled' => true]);
        [$request, $body] = TollGuruTripPreviewTest::bogotaFixture($reverse);
        $endpoint = $reverse ? 'origin' : 'destination';
        $country = GeographicUnit::query()->where('code', 'CO')->firstOrFail();
        $department = $this->unit('11', $request[$endpoint]['department'], GeographicUnitLevel::Department, $country->id);
        $this->unit('11001', $request[$endpoint]['municipality'], GeographicUnitLevel::Municipality, $department->id);
        $body['summary']['route'][$reverse ? 0 : 1]['address'] = $address;
        $this->fakeProvider([self::ENDPOINT => Http::response($body)]);

        $this->postJson('/api/v1/trips/preview', $request)->assertStatus(502)
            ->assertExactJson(['error' => ['code' => 'invalid_upstream']]);
        Http::assertSentCount(1);
        $this->assertSame($this->ledger(1, 21, 300), Cache::store('database')->get(self::LEDGER));
    }

    public static function bogotaWrongAddresses(): array
    {
        return [
            'destination wrong department' => [false, 'Bogota, D.C., Santander, Colombia'],
            'origin homonym' => [true, 'Nuevo Bogota, D.C., Bogota, D.C., Colombia'],
        ];
    }

    #[DataProvider('departureWindows')]
    public function test_departure_window_reports_only_actual_bounded_days_without_spending(string $departure, int $configuredDays, int $expectedDays): void
    {
        config(['trips.enabled' => true, 'trips.max_future_days' => $configuredDays]);
        $this->travelTo(now()->setTime(12, 0, 30));
        $request = $this->request();
        $request['departureUtc'] = $departure;

        $this->postJson('/api/v1/trips/preview', $request)->assertStatus(422)
            ->assertExactJson(['error' => ['code' => 'departure_window', 'maxFutureDays' => $expectedDays]]);
        Http::assertNothingSent();
        $this->assertSame($this->ledger(), Cache::store('database')->get(self::LEDGER));
    }

    public static function departureWindows(): array
    {
        return [
            'restored past date' => ['2026-09-04T12:00:30Z', 30, 30],
            'current minute already started' => ['2026-09-05T12:00:00Z', 30, 30],
            'one microsecond before now' => ['2026-09-05T12:00:29.999999Z', 30, 30],
            'day thirty one' => ['2026-10-06T12:00:30Z', 30, 30],
            'one microsecond beyond upper bound' => ['2026-10-05T12:00:30.000001Z', 30, 30],
            'configured seven day window' => ['2026-09-12T12:00:31Z', 7, 7],
            'configured one day window' => ['2026-09-06T12:00:31Z', 1, 1],
            'lower clamp' => ['2026-09-06T12:00:31Z', 0, 1],
            'upper clamp' => ['2026-10-05T12:00:31Z', 99, 30],
        ];
    }

    #[DataProvider('allowedDepartureBoundaries')]
    public function test_departure_window_accepts_exact_boundaries_without_changing_departure(string $departure, int $days): void
    {
        config(['trips.enabled' => true, 'trips.max_future_days' => $days]);
        $this->travelTo(now()->setTime(12, 0, 30));
        $request = $this->request();
        $request['departureUtc'] = $departure;

        $this->postJson('/api/v1/trips/preview', $request)->assertOk();
        Http::assertSent(fn (Request $sent): bool => $sent['departure_time'] === $departure);
        Http::assertSentCount(1);
    }

    public static function allowedDepartureBoundaries(): array
    {
        return [
            'now' => ['2026-09-05T12:00:30Z', 30],
            'thirty days' => ['2026-10-05T12:00:30Z', 30],
            'seven days' => ['2026-09-12T12:00:30Z', 7],
            'one day' => ['2026-09-06T12:00:30Z', 1],
        ];
    }

    private function request(): array
    {
        return TollGuruTripPreviewTest::tripRequest();
    }

    private function fakeProvider(array|\Closure $callback): void
    {
        Http::swap(new Factory);
        Http::preventStrayRequests();
        Http::fake($callback);
    }

    private function ledger(int $requests = 0, int $units = 0, int $money = 0): array
    {
        return ['budget_id' => 'test-authorization-001', 'currency' => 'USD', 'requests' => $requests, 'units' => $units, 'money_minor' => $money, 'in_flight' => false];
    }

    private function enableConfirmedFreeTrial(): void
    {
        config([
            'trips.enabled' => true,
            'trips.confirmed_free' => true,
            'trips.max_money_minor' => 0,
            'trips.money_minor_per_request' => 0,
        ]);
    }

    private function unit(string $code, string $name, GeographicUnitLevel $level, ?int $parent = null): GeographicUnit
    {
        return GeographicUnit::query()->create([
            'key' => 'co-'.strtolower($code), 'code' => $code, 'name' => $name,
            'normalized_name' => GeographicNameNormalizer::normalize($name),
            'level' => $level, 'parent_id' => $parent, 'is_active' => true,
            'source_system' => 'test', 'source_version' => 'v1',
        ]);
    }

    private function routePoint(string $code, float $latitude, float $longitude): void
    {
        $unit = GeographicUnit::query()->where('code', $code)->firstOrFail();
        $unit->metadata = [
            'routePoint' => [
                'latitude' => $latitude,
                'longitude' => $longitude,
                'source' => 'test-routing-points',
                'version' => 'v1',
            ],
        ];
        $unit->save();
    }

    private function osrmLineCoordinates(int $count, array $start, array $end): array
    {
        $coordinates = [];
        for ($index = 0; $index < $count; $index++) {
            $ratio = $count === 1 ? 0 : $index / ($count - 1);
            $coordinates[] = [
                round($start[0] + (($end[0] - $start[0]) * $ratio), 8),
                round($start[1] + (($end[1] - $start[1]) * $ratio), 8),
            ];
        }

        return $coordinates;
    }

    private function polyline6(array $coordinates): string
    {
        $encoded = '';
        $previousLat = 0;
        $previousLng = 0;
        foreach ($coordinates as $point) {
            $lat = (int) round($point[1] * 1000000);
            $lng = (int) round($point[0] * 1000000);
            foreach ([$lat - $previousLat, $lng - $previousLng] as $delta) {
                $value = $delta < 0 ? ~($delta << 1) : $delta << 1;
                while ($value >= 0x20) {
                    $encoded .= chr((0x20 | ($value & 0x1F)) + 63);
                    $value >>= 5;
                }
                $encoded .= chr($value + 63);
            }
            $previousLat = $lat;
            $previousLng = $lng;
        }

        return $encoded;
    }
}
