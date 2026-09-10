<?php

namespace Tests\Unit;

use App\Services\TollGuruTripPreview;
use DomainException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class TollGuruTripPreviewTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(now()->setDate(2026, 9, 5)->setTime(12, 0)->utc());
        config(['trips.max_response_bytes' => 262144, 'trips.max_routes' => 3, 'trips.max_tolls' => 200]);
    }

    public function test_complete_cash_breakdown_reconciles_exact_minor_units_without_fuel(): void
    {
        $plan = $this->normalize(self::providerFixture());

        $this->assertSame('trip-test-001', $plan['requestId']);
        $this->assertSame('TollGuru', $plan['provider']);
        $this->assertNotEmpty($plan['attribution']);
        $this->assertSame(6.2442, $plan['origin']['latitude']);
        $this->assertSame(-75.374, $plan['destination']['longitude']);
        $route = $plan['routes'][0];
        $this->assertSame(42000, $route['distanceMeters']);
        $this->assertSame(3600, $route['durationSeconds']);
        $this->assertSame('static', $route['timeBasis']);
        $this->assertSame('complete', $route['tolls']['coverage']);
        $this->assertSame(1800030, $route['tolls']['totalMinor']);
        $this->assertNull($route['tolls']['subtotalMinor']);
        $this->assertSame(0, $route['tolls']['missingRates']);
        $this->assertSame(2, $route['tolls']['stationCount']);
        $this->assertSame(2, $route['tolls']['payableCount']);
        $this->assertSame([800010, 1000020], array_column($route['tolls']['charges'], 'amountMinor'));
        $this->assertSame([null, null], array_column($route['tolls']['charges'], 'effectiveAt'));
        $this->assertSame([null, null], array_column($route['tolls']['charges'], 'sourceUrl'));
        $this->assertArrayNotHasKey('polyline', $route);
        $this->assertSame([
            'type' => 'LineString',
            'coordinates' => [
                [-75.5812, 6.2442],
                [-75.48, 6.2],
                [-75.374, 6.1533],
            ],
        ], $route['geometry']);
        $this->assertStringNotContainsString('upstream-private-marker', json_encode($plan, JSON_THROW_ON_ERROR));
    }

    public function test_normalized_payload_matches_the_mobile_boundary_fixture(): void
    {
        $fixture = file_get_contents(dirname(base_path()).'/mobile/test/fixtures/trip/tollguru_normalized_plan.json');
        $this->assertNotFalse($fixture);

        $this->assertSame(
            json_decode($fixture, true, 512, JSON_THROW_ON_ERROR),
            $this->normalize(self::providerFixture()),
        );
    }

    public function test_three_routes_at_3000_vertices_fit_the_mobile_transport_budget(): void
    {
        $body = self::providerFixtureWithRoutes(3000);
        $providerPayload = json_encode($body, JSON_THROW_ON_ERROR);
        $this->assertLessThanOrEqual(262144, strlen($providerPayload));

        $plan = app(TollGuruTripPreview::class)->normalizeResponse($providerPayload, self::tripRequest());
        $normalizedPayload = json_encode($plan, JSON_THROW_ON_ERROR);

        $this->assertCount(3, $plan['routes']);
        foreach ($plan['routes'] as $route) {
            $this->assertCount(3000, $route['geometry']['coordinates']);
        }
        $this->assertGreaterThan(150000, strlen($normalizedPayload));
        $this->assertLessThanOrEqual(262144, strlen($normalizedPayload));
    }

    public function test_route_above_3000_vertices_is_rejected(): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['polyline'] = self::colombianPolyline(3001);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('invalid_upstream');
        $this->normalize($body);
    }

    public function test_expanded_response_above_mobile_byte_limit_is_rejected(): void
    {
        $body = self::providerFixtureWithRoutes(3000);
        $tolls = [];
        for ($index = 0; $index < 200; $index++) {
            $tolls[] = [
                'id' => $index + 1,
                'name' => str_pad("Test station {$index}", 150, 'x'),
                'cashCost' => 1,
                'currency' => 'COP',
                'arrival' => ['distance' => $index + 1, 'time' => '2026-09-06T04:45:00Z'],
            ];
        }
        foreach ($body['routes'] as &$route) {
            $route['tolls'] = $tolls;
            $route['costs']['cash'] = 200;
        }
        unset($route);
        $providerPayload = json_encode($body, JSON_THROW_ON_ERROR);
        $this->assertLessThanOrEqual(262144, strlen($providerPayload));

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('invalid_upstream');
        app(TollGuruTripPreview::class)->normalizeResponse($providerPayload, self::tripRequest());
    }

    public function test_missing_cash_rate_keeps_route_with_subtotal_and_no_total(): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['tolls'][1]['cashCost'] = null;
        $tolls = $this->normalize($body)['routes'][0]['tolls'];

        $this->assertSame('partial', $tolls['coverage']);
        $this->assertNull($tolls['totalMinor']);
        $this->assertSame(800010, $tolls['subtotalMinor']);
        $this->assertSame(1, $tolls['missingRates']);
        $this->assertSame(2, $tolls['stationCount']);
        $this->assertNull($tolls['payableCount']);
    }

    public function test_mismatched_aggregate_never_becomes_a_complete_total(): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['costs']['cash'] = 19000;
        $tolls = $this->normalize($body)['routes'][0]['tolls'];

        $this->assertSame('unknown', $tolls['coverage']);
        $this->assertNull($tolls['totalMinor']);
        $this->assertNull($tolls['subtotalMinor']);
        $this->assertSame(0, $tolls['missingRates']);
    }

    #[DataProvider('emptyTollEvidence')]
    public function test_empty_list_requires_explicit_evidence_for_zero(?bool $hasTolls, mixed $cash, string $coverage, ?int $total): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['tolls'] = [];
        $body['routes'][0]['summary']['hasTolls'] = $hasTolls;
        $body['routes'][0]['costs']['cash'] = $cash;
        $tolls = $this->normalize($body)['routes'][0]['tolls'];

        $this->assertSame($coverage, $tolls['coverage']);
        $this->assertSame($total, $tolls['totalMinor']);
        $this->assertNull($tolls['subtotalMinor']);
        $this->assertSame($coverage === 'no_charge_confirmed' ? 0 : null, $tolls['stationCount']);
        $this->assertSame($coverage === 'no_charge_confirmed' ? 0 : null, $tolls['payableCount']);
    }

    public static function emptyTollEvidence(): array
    {
        return [
            'absent evidence' => [null, null, 'unknown', null],
            'zero aggregate alone' => [null, 0, 'unknown', null],
            'total without stations' => [true, 18000.30, 'unknown', null],
            'explicit no tolls and zero' => [false, 0, 'no_charge_confirmed', 0],
            'contradictory no tolls' => [false, 100, 'unknown', null],
        ];
    }

    public function test_repeated_station_visits_remain_ordered_individual_charges(): void
    {
        $body = self::providerFixture();
        $first = $body['routes'][0]['tolls'][0];
        $repeat = $first;
        $repeat['arrival']['distance'] = 30000;
        $body['routes'][0]['tolls'] = [$repeat, $first];
        $body['routes'][0]['costs']['cash'] = 16000.20;
        $tolls = $this->normalize($body)['routes'][0]['tolls'];

        $this->assertCount(2, $tolls['charges']);
        $this->assertSame(['Test station A', 'Test station A'], array_column($tolls['charges'], 'name'));
        $this->assertSame(1600020, $tolls['totalMinor']);
    }

    public function test_stations_are_sorted_by_travel_distance_not_price_or_name(): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['tolls'] = array_reverse($body['routes'][0]['tolls']);
        $tolls = $this->normalize($body)['routes'][0]['tolls'];

        $this->assertSame(['Test station A', 'Test station B'], array_column($tolls['charges'], 'name'));
    }

    public function test_distinct_routes_sort_by_duration_and_identity_follows_geometry(): void
    {
        $body = self::providerFixture();
        $other = $body['routes'][0];
        $other['polyline'] = 'gqbe@n}hlMvtE_vTjaJ_wQ';
        $other['summary']['duration']['value'] = 3000;
        $other['summary']['distance']['value'] = 45000;
        $body['routes'][] = $other;
        $plan = $this->normalize($body);

        $this->assertSame([3000, 3600], array_column($plan['routes'], 'durationSeconds'));
        $this->assertNotSame($plan['routes'][0]['id'], $plan['routes'][1]['id']);
        $body['routes'] = array_reverse($body['routes']);
        $body['routes'][0]['summary']['name'] = 'Renamed upstream route';
        $this->assertSame(array_column($plan['routes'], 'id'), array_column($this->normalize($body)['routes'], 'id'));
        $body['routes'][] = $body['routes'][0];
        $this->assertCount(2, $this->normalize($body)['routes']);
    }

    public function test_requested_alternative_limit_does_not_create_extra_upstream_calls_or_routes(): void
    {
        $body = self::providerFixture();
        $body['routes'][] = $body['routes'][0];
        $body['routes'][1]['polyline'] = 'gqbe@n}hlMvtE_vTjaJ_wQ';
        $request = self::tripRequest();
        $request['alternatives'] = 1;

        $this->assertCount(1, $this->normalize($body, $request)['routes']);
    }

    #[DataProvider('invalidProviderFields')]
    public function test_invalid_upstream_fields_fail_with_only_safe_code(string $path, mixed $value): void
    {
        $body = self::providerFixture();
        data_set($body, $path, $value);
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('invalid_upstream');
        $this->normalize($body);
    }

    public static function invalidProviderFields(): array
    {
        return [
            'foreign country' => ['summary.countries', ['USA']],
            'wrong municipality' => ['summary.route.1.address', 'Rionegro, Santander, Colombia'],
            'substring homonym' => ['summary.route.1.address', 'Nuevo Rionegro, Antioquia, Colombia'],
            'missing municipality proof' => ['summary.route.1.address', 'Colombia'],
            'foreign endpoint' => ['summary.route.0.location.lat', 39.9],
            'string coordinate' => ['summary.route.0.location.lat', '6.2442'],
            'reversed longitude' => ['summary.route.0.location.lng', 75.5812],
            'wrong vehicle' => ['summary.vehicleType', '2AxlesMotorcycle'],
            'geometry detached from endpoints' => ['routes.0.polyline', '_p~iF~ps|U_ulLnnqC_mqNvxq`@'],
            'invalid geometry' => ['routes.0.polyline', '?????'],
            'missing geometry' => ['routes.0.polyline', null],
            'string distance' => ['routes.0.summary.distance.value', '42000'],
            'zero distance' => ['routes.0.summary.distance.value', 0],
            'fractional duration' => ['routes.0.summary.duration.value', 1.5],
            'negative duration' => ['routes.0.summary.duration.value', -1],
            'unbounded duration' => ['routes.0.summary.duration.value', PHP_INT_MAX],
            'invalid route collection' => ['routes', ['arbitrary' => []]],
        ];
    }

    #[DataProvider('invalidTollFields')]
    public function test_invalid_toll_fields_degrade_tolls_without_discarding_the_route(string $path, mixed $value): void
    {
        $body = self::providerFixture();
        data_set($body, $path, $value);
        $route = $this->normalize($body)['routes'][0];

        $this->assertSame(42000, $route['distanceMeters']);
        $this->assertSame(3600, $route['durationSeconds']);
        $this->assertContains($route['tolls']['coverage'], ['unknown', 'partial']);
        $this->assertNull($route['tolls']['totalMinor']);
        $this->assertNull($route['tolls']['payableCount']);
    }

    public static function invalidTollFields(): array
    {
        return [
            'negative cash' => ['routes.0.tolls.0.cashCost', -1],
            'boolean cash' => ['routes.0.tolls.0.cashCost', true],
            'unbounded cash' => ['routes.0.tolls.0.cashCost', PHP_INT_MAX],
            'subcent cash' => ['routes.0.tolls.0.cashCost', 0.001],
            'localized cash string' => ['routes.0.tolls.0.cashCost', '8.000,10'],
            'foreign station currency' => ['routes.0.tolls.0.currency', 'USD'],
            'missing currency' => ['routes.0.tolls.0.currency', null],
            'station beyond route' => ['routes.0.tolls.0.arrival.distance', 999999],
            'oversized station label' => ['routes.0.tolls.0.name', str_repeat('x', 10000)],
            'missing toll list' => ['routes.0.tolls', null],
            'malformed toll list' => ['routes.0.tolls', ['arbitrary' => 'value']],
        ];
    }

    public function test_global_currency_mismatch_keeps_route_with_unknown_tolls(): void
    {
        $body = self::providerFixture();
        $body['summary']['currency'] = 'USD';
        $route = $this->normalize($body)['routes'][0];

        $this->assertSame(42000, $route['distanceMeters']);
        $this->assertSame(3600, $route['durationSeconds']);
        $this->assertSame('unknown', $route['tolls']['coverage']);
        $this->assertSame('COP', $route['tolls']['currency']);
        $this->assertNull($route['tolls']['totalMinor']);
        $this->assertNull($route['tolls']['subtotalMinor']);
        $this->assertNull($route['tolls']['payableCount']);
    }

    public function test_zero_rate_station_is_passed_but_is_not_a_payable_charge(): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['tolls'][0]['cashCost'] = 0;
        $body['routes'][0]['costs']['cash'] = 10000.20;
        $tolls = $this->normalize($body)['routes'][0]['tolls'];

        $this->assertSame(2, $tolls['stationCount']);
        $this->assertSame(1, $tolls['payableCount']);
        $this->assertSame(1000020, $tolls['totalMinor']);
    }

    #[DataProvider('invalidJson')]
    public function test_malformed_or_oversized_json_is_rejected(string $body): void
    {
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('invalid_upstream');
        app(TollGuruTripPreview::class)->normalizeResponse($body, self::tripRequest());
    }

    public static function invalidJson(): array
    {
        return [
            'truncated' => ['{"status":"OK"'],
            'scalar' => ['true'],
            'array' => ['[]'],
            'oversize' => [str_repeat(' ', 262145)],
            'too deep' => [str_repeat('[', 100).str_repeat(']', 100)],
        ];
    }

    public function test_toll_collection_is_bounded(): void
    {
        $body = self::providerFixture();
        $body['routes'][0]['tolls'] = array_fill(0, 201, $body['routes'][0]['tolls'][0]);
        $route = $this->normalize($body)['routes'][0];
        $this->assertSame(42000, $route['distanceMeters']);
        $this->assertSame('unknown', $route['tolls']['coverage']);
        $this->assertNull($route['tolls']['totalMinor']);
        $this->assertNull($route['tolls']['stationCount']);
        $this->assertNull($route['tolls']['payableCount']);
        $this->assertSame([], $route['tolls']['charges']);
    }

    public function test_empty_routes_returns_no_route(): void
    {
        $body = self::providerFixture();
        $body['routes'] = [];
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('no_route');
        $this->normalize($body);
    }

    #[DataProvider('bogotaDirections')]
    public function test_canonical_bogota_comma_sequence_resolves_in_both_directions(bool $reverse): void
    {
        [$request, $body] = self::bogotaFixture($reverse);
        $plan = $this->normalize($body, $request);
        $endpoint = $reverse ? 'origin' : 'destination';

        $this->assertSame('11001', $request[$endpoint]['code']);
        $this->assertSame($request[$endpoint]['municipality'].', '.$request[$endpoint]['department'], $plan[$endpoint]['label']);
        $this->assertSame(4.711, $plan[$endpoint]['latitude']);
        $this->assertSame(420000, $plan['routes'][0]['distanceMeters']);
    }

    public static function bogotaDirections(): array
    {
        return ['Bogota destination' => [false], 'Bogota origin' => [true]];
    }

    #[DataProvider('bogotaWrongAddresses')]
    public function test_canonical_bogota_rejects_homonyms_wrong_department_and_broken_sequence(string $address): void
    {
        [$request, $body] = self::bogotaFixture(false);
        $body['summary']['route'][1]['address'] = $address;
        $this->expectException(DomainException::class);
        $this->expectExceptionMessage('invalid_upstream');
        $this->normalize($body, $request);
    }

    public static function bogotaWrongAddresses(): array
    {
        return [
            'municipality substring' => ['Nuevo Bogota, D.C., Bogota, D.C., Colombia'],
            'wrong department' => ['Bogota, D.C., Santander, Colombia'],
            'department substring' => ['Bogota, D.C., Nuevo Bogota, D.C., Colombia'],
            'noncontiguous name' => ['Bogota, Centro, D.C., Bogota, D.C., Colombia'],
        ];
    }

    // Names come from the committed catalog; coordinates/road metrics remain synthetic.
    public static function bogotaFixture(bool $reverse): array
    {
        $catalog = json_decode(file_get_contents(base_path('database/data/colombia_divipola_mgn_2025.json')), true, 512, JSON_THROW_ON_ERROR);
        $municipality = collect($catalog['municipalities'])->firstWhere('code', '11001');
        $department = collect($catalog['departments'])->firstWhere('code', '11');
        $request = self::tripRequest();
        $request['destination'] = ['code' => $municipality['code'], 'municipality' => $municipality['name'], 'department' => $department['name']];
        $body = self::providerFixture();
        $body['summary']['route'][1] = [
            'location' => ['lat' => 4.711, 'lng' => -74.0721],
            'address' => 'Calle 26, '.$municipality['name'].', '.$department['name'].', Colombia',
        ];
        $body['routes'][0]['summary']['distance']['value'] = 420000;
        $body['routes'][0]['summary']['duration']['value'] = 28800;
        $body['routes'][0]['polyline'] = 'gqbe@n}hlMnmjH{veH';
        if ($reverse) {
            [$request['origin'], $request['destination']] = [$request['destination'], $request['origin']];
            $body['summary']['route'] = array_reverse($body['summary']['route']);
            $body['routes'][0]['polyline'] = 'wbw[rebcMomjHzveH';
        }

        return [$request, $body];
    }

    private function normalize(array $body, ?array $request = null): array
    {
        return app(TollGuruTripPreview::class)->normalizeResponse(json_encode($body, JSON_THROW_ON_ERROR), $request ?? self::tripRequest());
    }

    private static function providerFixtureWithRoutes(int $vertices): array
    {
        $body = self::providerFixture();
        $template = $body['routes'][0];
        $body['routes'] = [];
        for ($variant = 0; $variant < 3; $variant++) {
            $route = $template;
            $route['summary']['name'] = 'Synthetic route '.($variant + 1);
            $route['summary']['duration']['value'] += $variant * 600;
            $route['polyline'] = self::colombianPolyline($vertices, $variant);
            $body['routes'][] = $route;
        }

        return $body;
    }

    private static function colombianPolyline(int $vertices, int $variant = 0): string
    {
        $encoded = '';
        $previous = [0, 0];
        for ($index = 0; $index < $vertices; $index++) {
            $ratio = $index / ($vertices - 1);
            $point = [
                (int) round(624420 + ((615330 - 624420) * $ratio)),
                (int) round(-7558120 + ((-7537400 + 7558120) * $ratio)),
            ];
            if ($index > 0 && $index < $vertices - 1) {
                $point[0] += $variant;
            }
            foreach ([0, 1] as $axis) {
                $delta = $point[$axis] - $previous[$axis];
                $value = $delta < 0 ? ~($delta << 1) : $delta << 1;
                while ($value >= 0x20) {
                    $encoded .= chr((0x20 | ($value & 0x1F)) + 63);
                    $value >>= 5;
                }
                $encoded .= chr($value + 63);
            }
            $previous = $point;
        }

        return $encoded;
    }

    public static function tripRequest(): array
    {
        return [
            'requestId' => 'trip-test-001',
            'origin' => ['code' => '05001', 'municipality' => "MEDELL\u{00cd}N", 'department' => 'ANTIOQUIA'],
            'destination' => ['code' => '05615', 'municipality' => 'RIONEGRO', 'department' => 'ANTIOQUIA'],
            'departureUtc' => '2026-09-06T04:30:00Z',
            'timeZone' => 'America/Bogota',
            'vehicleCategory' => 'car',
            'paymentMethod' => 'cash',
            'alternatives' => 3,
        ];
    }

    // Synthetic Colombia values in the public MapUp example schema, not live route/tariff evidence.
    // https://github.com/mapup/tollguru-tolltally-api-payload-examples/blob/main/responses/01-Origin-Destination-Cost-Tradeoff/01-address-as-string.json
    public static function providerFixture(): array
    {
        return [
            'status' => 'OK',
            'summary' => [
                'route' => [
                    ['location' => ['lat' => 6.2442, 'lng' => -75.5812], 'address' => "Medell\u{00ed}n, Antioquia, Colombia"],
                    ['location' => ['lat' => 6.1533, 'lng' => -75.374], 'address' => 'Rionegro, Antioquia, Colombia'],
                ],
                'countries' => ['COL'],
                'currency' => 'COP',
                'vehicleType' => '2AxlesAuto',
                'source' => 'HERE',
                'departure_time' => '2026-09-06T04:30:00Z',
                'share' => ['uuid' => 'upstream-private-marker'],
            ],
            'routes' => [[
                'summary' => ['name' => 'Synthetic route', 'hasTolls' => true, 'distance' => ['value' => 42000], 'duration' => ['value' => 3600]],
                'polyline' => 'gqbe@n}hlMfsGowRzbHouS',
                'costs' => ['cash' => 18000.30, 'fuel' => 50000, 'tag' => 10000],
                'tolls' => [
                    ['id' => 1, 'name' => 'Test station A', 'cashCost' => 8000.10, 'currency' => 'COP', 'arrival' => ['distance' => 10000, 'time' => '2026-09-06T04:45:00Z']],
                    ['id' => 2, 'name' => 'Test station B', 'cashCost' => 10000.20, 'currency' => 'COP', 'arrival' => ['distance' => 20000, 'time' => '2026-09-06T05:00:00Z']],
                ],
            ]],
        ];
    }
}
