<?php

namespace Tests\Feature;

use App\Models\GeographicUnit;
use App\Services\GeographyImporter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class TripRoutePointImportTest extends TestCase
{
    use RefreshDatabase;

    public function test_route_points_are_imported_idempotently_without_changing_geography_identity(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $medellin = GeographicUnit::query()->where('code', '05001')->firstOrFail();
        $this->assertSame(['officialType' => 'MUNICIPIO'], $medellin->metadata);

        $exit = Artisan::call('picoradar:trips:route-points', ['--json' => true]);

        $this->assertSame(0, $exit);
        $this->assertSame(['points' => 3, 'updated' => 3, 'unchanged' => 0, 'errors' => 0], json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR));
        $medellin = $medellin->fresh();
        $this->assertSame('co-05001', $medellin->key);
        $this->assertSame('05001', $medellin->code);
        $this->assertSame('MUNICIPIO', $medellin->metadata['officialType']);
        $this->assertSame([
            'latitude' => 6.2697324,
            'longitude' => -75.6025597,
            'source' => 'nominatim_openstreetmap',
            'version' => 'trip_route_points_pilot_v1',
        ], $medellin->metadata['routePoint']);

        $secondExit = Artisan::call('picoradar:trips:route-points', ['--json' => true]);

        $this->assertSame(0, $secondExit);
        $this->assertSame(['points' => 3, 'updated' => 0, 'unchanged' => 3, 'errors' => 0], json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR));
    }

    public function test_route_point_dry_run_validates_without_writing(): void
    {
        app(GeographyImporter::class)->bootstrap();

        $exit = Artisan::call('picoradar:trips:route-points', ['--dry-run' => true, '--json' => true]);

        $this->assertSame(0, $exit);
        $this->assertSame(['points' => 3, 'updated' => 0, 'unchanged' => 0, 'errors' => 0], json_decode(Artisan::output(), true, 512, JSON_THROW_ON_ERROR));
        $this->assertArrayNotHasKey('routePoint', GeographicUnit::query()->where('code', '05001')->firstOrFail()->metadata);
    }

    public function test_route_point_fixture_fails_closed_for_unknown_geography(): void
    {
        app(GeographyImporter::class)->bootstrap();
        $fixture = json_decode((string) file_get_contents(database_path('data/trip_route_points_pilot_v1.json')), true, 512, JSON_THROW_ON_ERROR);
        $fixture['points'][0]['code'] = '99999';
        $path = tempnam(sys_get_temp_dir(), 'picoradar-route-points-');
        file_put_contents($path, json_encode($fixture, JSON_THROW_ON_ERROR));

        $exit = Artisan::call('picoradar:trips:route-points', ['file' => $path, '--json' => true]);

        $this->assertSame(1, $exit);
        $this->assertStringContainsString('unknown geography', Artisan::output());
        $this->assertArrayNotHasKey('routePoint', GeographicUnit::query()->where('code', '05001')->firstOrFail()->metadata);
    }
}
