<?php

namespace App\Console\Commands;

use App\Enums\GeographicUnitLevel;
use App\Models\GeographicUnit;
use DomainException;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

class ImportTripRoutePointsCommand extends Command
{
    protected $signature = 'picoradar:trips:route-points {file? : Path to route-point JSON fixture} {--dry-run} {--json}';

    protected $description = 'Import pilot Viaje route points into geographic unit metadata.';

    public function handle(): int
    {
        $path = (string) ($this->argument('file') ?: database_path('data/trip_route_points_pilot_v1.json'));
        if (! is_file($path)) {
            $this->error('Trip route-point fixture not found.');

            return self::FAILURE;
        }

        try {
            $data = $this->validatedData($path);
            $result = $this->option('dry-run')
                ? $this->dryRun($data)
                : DB::transaction(fn (): array => $this->import($data));
        } catch (Throwable $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }

        if ($this->option('json')) {
            $this->line(json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        } else {
            foreach ($result as $key => $value) {
                $this->components->info("$key: $value");
            }
        }

        return self::SUCCESS;
    }

    /** @return array{version:string, points:list<array<string,mixed>>} */
    private function validatedData(string $path): array
    {
        try {
            $decoded = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        } catch (Throwable) {
            throw new DomainException('Trip route-point fixture JSON is invalid.');
        }
        $points = $decoded['points'] ?? null;
        if (($decoded['schemaVersion'] ?? null) !== 1 || ! is_string($decoded['version'] ?? null)
            || trim($decoded['version']) === '' || ! is_array($points) || ! array_is_list($points) || $points === []) {
            throw new DomainException('Trip route-point fixture shape is invalid.');
        }

        $seen = [];
        foreach ($points as $point) {
            if (! is_array($point) || ! is_string($point['code'] ?? null) || ! preg_match('/^\d{5}$/', $point['code'])
                || isset($seen[$point['code']]) || ! $this->colombiaPoint($point['latitude'] ?? null, $point['longitude'] ?? null)
                || ! is_string($point['source'] ?? null) || trim($point['source']) === '' || strlen($point['source']) > 120
                || ! is_string($point['version'] ?? null) || trim($point['version']) === '' || strlen($point['version']) > 64) {
                throw new DomainException('Trip route-point record is invalid.');
            }
            $seen[$point['code']] = true;
        }

        return ['version' => $decoded['version'], 'points' => $points];
    }

    /** @param array{version:string, points:list<array<string,mixed>>} $data @return array<string,int> */
    private function dryRun(array $data): array
    {
        $this->units($data['points']);

        return ['points' => count($data['points']), 'updated' => 0, 'unchanged' => 0, 'errors' => 0];
    }

    /** @param array{version:string, points:list<array<string,mixed>>} $data @return array<string,int> */
    private function import(array $data): array
    {
        $units = $this->units($data['points']);
        $updated = 0;
        $unchanged = 0;
        foreach ($data['points'] as $point) {
            $unit = $units[$point['code']];
            $metadata = is_array($unit->metadata) ? $unit->metadata : [];
            $nextRoutePoint = [
                'latitude' => (float) $point['latitude'],
                'longitude' => (float) $point['longitude'],
                'source' => $point['source'],
                'version' => $point['version'],
            ];
            if (($metadata['routePoint'] ?? null) === $nextRoutePoint) {
                $unchanged++;

                continue;
            }
            $metadata['routePoint'] = $nextRoutePoint;
            $unit->metadata = $metadata;
            $unit->save();
            $updated++;
        }

        return ['points' => count($data['points']), 'updated' => $updated, 'unchanged' => $unchanged, 'errors' => 0];
    }

    /** @param list<array<string,mixed>> $points @return array<string,GeographicUnit> */
    private function units(array $points): array
    {
        $codes = array_column($points, 'code');
        $units = GeographicUnit::query()
            ->whereIn('code', $codes)
            ->where('level', GeographicUnitLevel::Municipality)
            ->where('is_active', true)
            ->get()
            ->keyBy('code');
        if ($units->count() !== count($codes)) {
            throw new DomainException('Trip route-point fixture references unknown geography.');
        }

        return $units->all();
    }

    private function colombiaPoint(mixed $lat, mixed $lng): bool
    {
        return (is_float($lat) || is_int($lat)) && (is_float($lng) || is_int($lng)) && is_finite((float) $lat) && is_finite((float) $lng)
            && $lat >= -4.3 && $lat <= 13.6 && $lng >= -82 && $lng <= -66.8;
    }
}
