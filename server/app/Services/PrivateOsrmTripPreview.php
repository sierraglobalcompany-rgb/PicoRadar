<?php

namespace App\Services;

use App\Contracts\TripPreviewProvider;
use DomainException;
use GuzzleHttp\Exception\ConnectTimeoutException;
use GuzzleHttp\Exception\NetworkTimeoutException;
use GuzzleHttp\Exception\ResponseTimeoutException;
use GuzzleHttp\Psr7\Exception\TimeoutException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use JsonException;
use Throwable;

final class PrivateOsrmTripPreview implements TripPreviewProvider
{
    private const MAX_MOBILE_RESPONSE_BYTES = 262144;

    private const MAX_GEOMETRY_POINTS = 3000;

    public function preview(array $request): array
    {
        if (($request['vehicleCategory'] ?? null) !== 'car') {
            throw new DomainException('unsupported_vehicle');
        }
        $settings = $this->settings();
        $origin = $this->routePoint($request['origin'] ?? null);
        $destination = $this->routePoint($request['destination'] ?? null);
        if ($origin === null || $destination === null) {
            throw new DomainException('not_configured');
        }

        return $this->normalizeResponse($this->fetch($origin, $destination, $request, $settings), $request, $settings);
    }

    private function settings(): array
    {
        if (config('trips.enabled') !== true || config('trips.private_osrm.enabled') !== true
            || config('trips.private_osrm.access_authorized') !== true || config('trips.private_osrm.source_authorized') !== true) {
            throw new DomainException('not_configured');
        }
        $baseUrl = config('trips.private_osrm.base_url');
        $profile = config('trips.private_osrm.profile', 'driving');
        $attribution = config('trips.private_osrm.attribution');
        if (! is_string($baseUrl) || trim($baseUrl) === '' || ! is_string($profile) || $profile !== 'driving'
            || ! is_string($attribution) || trim($attribution) === '' || strlen($attribution) > 160) {
            throw new DomainException('not_configured');
        }
        $parts = parse_url(trim($baseUrl));
        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        $host = strtolower((string) ($parts['host'] ?? ''));
        if (! in_array($scheme, ['http', 'https'], true) || $host === ''
            || ($scheme === 'http' && ! in_array($host, ['127.0.0.1', 'localhost', '::1'], true))) {
            throw new DomainException('not_configured');
        }

        return [
            'base_url' => rtrim(trim($baseUrl), '/'),
            'profile' => $profile,
            'attribution' => $attribution,
            'timeout_seconds' => $this->positiveInt('trips.private_osrm.timeout_seconds', 20),
            'connect_timeout_seconds' => $this->positiveInt('trips.private_osrm.connect_timeout_seconds', 5),
            'max_response_bytes' => min(self::MAX_MOBILE_RESPONSE_BYTES, $this->positiveInt('trips.private_osrm.max_response_bytes', self::MAX_MOBILE_RESPONSE_BYTES)),
        ];
    }

    private function fetch(array $origin, array $destination, array $request, array $settings): string
    {
        $path = sprintf(
            '/route/v1/%s/%s,%s;%s,%s',
            $settings['profile'],
            $this->decimal($origin['longitude']),
            $this->decimal($origin['latitude']),
            $this->decimal($destination['longitude']),
            $this->decimal($destination['latitude']),
        );
        try {
            $response = Http::acceptJson()
                ->connectTimeout($settings['connect_timeout_seconds'])
                ->timeout($settings['timeout_seconds'])
                ->withOptions(['allow_redirects' => false, 'verify' => true])
                ->get($settings['base_url'].$path, [
                    'overview' => 'full',
                    'geometries' => 'geojson',
                    'steps' => 'false',
                    'alternatives' => $request['alternatives'] > 1 ? 'true' : 'false',
                ]);
            if (! $response->successful()) {
                throw new DomainException(match ($response->status()) {
                    408, 504 => 'timeout',
                    default => 'invalid_upstream',
                });
            }
            $contentType = (string) $response->header('Content-Type');
            if ($contentType !== '' && ! preg_match('~\Aapplication/(?:[a-z0-9.+-]+\+)?json(?:\s*;|\z)~i', $contentType)) {
                throw new DomainException('invalid_upstream');
            }
            $body = $response->body();
            if (strlen($body) > $settings['max_response_bytes']) {
                throw new DomainException('invalid_upstream');
            }

            return $body;
        } catch (ConnectionException $exception) {
            $previous = $exception->getPrevious();
            $timeout = $previous instanceof ConnectTimeoutException || $previous instanceof NetworkTimeoutException || $previous instanceof ResponseTimeoutException;
            throw new DomainException($timeout ? 'timeout' : 'network');
        } catch (ConnectTimeoutException|NetworkTimeoutException|ResponseTimeoutException|TimeoutException) {
            throw new DomainException('timeout');
        } catch (DomainException $exception) {
            throw $exception;
        } catch (Throwable) {
            throw new DomainException('invalid_upstream');
        }
    }

    private function normalizeResponse(string $body, array $request, array $settings): array
    {
        try {
            $data = json_decode($body, true, 32, JSON_THROW_ON_ERROR | JSON_BIGINT_AS_STRING);
        } catch (JsonException) {
            throw new DomainException('invalid_upstream');
        }
        if (! is_array($data) || ($data['code'] ?? null) !== 'Ok' || ! is_array($data['routes'] ?? null) || ! array_is_list($data['routes'])) {
            throw new DomainException('invalid_upstream');
        }
        if ($data['routes'] === []) {
            throw new DomainException('no_route');
        }
        if (count($data['routes']) > 10) {
            throw new DomainException('invalid_upstream');
        }
        $origin = $this->resolvedPoint($request['origin']);
        $destination = $this->resolvedPoint($request['destination']);
        $routes = [];
        foreach ($data['routes'] as $route) {
            $distance = is_array($route) ? ($route['distance'] ?? null) : null;
            $duration = is_array($route) ? ($route['duration'] ?? null) : null;
            if ((! is_int($distance) && ! is_float($distance)) || ! is_finite((float) $distance) || $distance < 1 || $distance > 10000000
                || (! is_int($duration) && ! is_float($duration)) || ! is_finite((float) $duration) || $duration < 1 || $duration > 604800) {
                throw new DomainException('invalid_upstream');
            }
            $coordinates = $this->geometry($route['geometry']['coordinates'] ?? null);
            foreach ([[$coordinates[0], $origin], [$coordinates[array_key_last($coordinates)], $destination]] as [$point, $endpoint]) {
                if (abs($point[1] - $endpoint['latitude']) > 0.05 || abs($point[0] - $endpoint['longitude']) > 0.05) {
                    throw new DomainException('invalid_upstream');
                }
            }
            $id = hash('sha256', json_encode($coordinates, JSON_THROW_ON_ERROR));
            $routes[$id] ??= [
                'id' => $id,
                'summary' => 'Ruta por carretera',
                'distanceMeters' => (int) round($distance),
                'durationSeconds' => (int) round($duration),
                'timeBasis' => 'static',
                'geometry' => ['type' => 'LineString', 'coordinates' => $coordinates],
                'tolls' => [
                    'coverage' => 'unknown',
                    'currency' => 'COP',
                    'totalMinor' => null,
                    'subtotalMinor' => null,
                    'paymentMethod' => 'cash',
                    'vehicleCategory' => $request['vehicleCategory'],
                    'charges' => [],
                    'missingRates' => 0,
                    'stationCount' => null,
                    'payableCount' => null,
                ],
            ];
        }
        $routes = array_values($routes);
        usort($routes, fn (array $a, array $b): int => [$a['durationSeconds'], $a['id']] <=> [$b['durationSeconds'], $b['id']]);

        $plan = [
            'requestId' => $request['requestId'],
            'generatedAtUtc' => now()->utc()->format('Y-m-d\TH:i:s\Z'),
            'provider' => 'Private OSRM',
            'attribution' => $settings['attribution'],
            'origin' => $origin,
            'destination' => $destination,
            'routes' => array_slice($routes, 0, min(3, $request['alternatives'])),
        ];
        try {
            if (strlen(json_encode($plan, JSON_THROW_ON_ERROR)) > self::MAX_MOBILE_RESPONSE_BYTES) {
                throw new DomainException('invalid_upstream');
            }
        } catch (JsonException) {
            throw new DomainException('invalid_upstream');
        }

        return $plan;
    }

    private function routePoint(mixed $point): ?array
    {
        if (! is_array($point) || ! is_array($point['routePoint'] ?? null)) {
            return null;
        }
        $routePoint = $point['routePoint'];
        if (! $this->colombiaPoint($routePoint['latitude'] ?? null, $routePoint['longitude'] ?? null)) {
            return null;
        }

        return ['latitude' => (float) $routePoint['latitude'], 'longitude' => (float) $routePoint['longitude']];
    }

    private function resolvedPoint(array $point): array
    {
        $routePoint = $this->routePoint($point);
        if ($routePoint === null) {
            throw new DomainException('not_configured');
        }

        return [
            'label' => $point['municipality'].', '.$point['department'],
            'latitude' => $routePoint['latitude'],
            'longitude' => $routePoint['longitude'],
        ];
    }

    private function geometry(mixed $coordinates): array
    {
        if (! is_array($coordinates) || ! array_is_list($coordinates) || count($coordinates) < 2 || count($coordinates) > self::MAX_GEOMETRY_POINTS) {
            throw new DomainException('invalid_upstream');
        }
        $points = [];
        foreach ($coordinates as $point) {
            if (! is_array($point) || count($point) !== 2 || ! $this->colombiaPoint($point[1] ?? null, $point[0] ?? null)) {
                throw new DomainException('invalid_upstream');
            }
            $points[] = [(float) $point[0], (float) $point[1]];
        }
        if ($points[0] === $points[array_key_last($points)]) {
            throw new DomainException('invalid_upstream');
        }

        return $points;
    }

    private function colombiaPoint(mixed $lat, mixed $lng): bool
    {
        return (is_float($lat) || is_int($lat)) && (is_float($lng) || is_int($lng)) && is_finite((float) $lat) && is_finite((float) $lng)
            && $lat >= -4.3 && $lat <= 13.6 && $lng >= -82 && $lng <= -66.8;
    }

    private function positiveInt(string $key, int $max): int
    {
        $value = config($key);
        if ((! is_int($value) && (! is_string($value) || ! ctype_digit($value))) || $value < 1 || $value > $max) {
            throw new DomainException('not_configured');
        }

        return (int) $value;
    }

    private function decimal(float $value): string
    {
        return rtrim(rtrim(sprintf('%.6F', $value), '0'), '.');
    }
}
