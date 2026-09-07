<?php

namespace App\Services;

use App\Support\GeographicNameNormalizer;
use DateTimeImmutable;
use DateTimeZone;
use DomainException;
use GuzzleHttp\Exception\ConnectTimeoutException;
use GuzzleHttp\Exception\NetworkTimeoutException;
use GuzzleHttp\Exception\ResponseTimeoutException;
use GuzzleHttp\Psr7\Exception\TimeoutException;
use Illuminate\Cache\DatabaseStore;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use JsonException;
use Psr\Http\Message\ResponseInterface;
use Throwable;

final class TollGuruTripPreview
{
    private const MAX_MOBILE_RESPONSE_BYTES = 262144;

    // Shared transport contract with the Dart decoder.
    private const MAX_GEOMETRY_POINTS = 3000;

    private const ENDPOINT = 'https://apis.tollguru.com/toll/v2/origin-destination-waypoints/';

    private const LEDGER = 'trips:tollguru:budget:v1';

    private const LOCK = 'trips:tollguru:operation:v1';

    private const VEHICLES = ['car' => '2AxlesAuto', 'motorcycle' => '2AxlesMotorcycle'];

    public function preview(array $request): array
    {
        if (! isset(self::VEHICLES[$request['vehicleCategory'] ?? ''])) {
            throw new DomainException('unsupported_vehicle');
        }
        $settings = $this->settings();
        $lock = null;
        $reserved = null;
        $cache = null;
        try {
            $cache = Cache::store(config('trips.cache_store'));
            if (! $cache->getStore() instanceof DatabaseStore) {
                throw new DomainException('not_configured');
            }
            $lock = $cache->lock(self::LOCK, $settings['lock_seconds']);
            if (! $lock->get()) {
                throw new DomainException('quota');
            }
            $spent = $cache->get(self::LEDGER);
            if (! is_array($spent) || ($spent['budget_id'] ?? null) !== config('trips.budget_id')
                || ($spent['currency'] ?? null) !== config('trips.budget_currency') || ($spent['in_flight'] ?? null) !== false) {
                throw new DomainException('quota');
            }
            foreach (['requests' => 1, 'units' => $settings['units_per_request'], 'money_minor' => $settings['money_minor_per_request']] as $field => $increment) {
                if (! is_int($spent[$field] ?? null) || $spent[$field] < 0 || $spent[$field] > $settings['max_'.$field] - $increment) {
                    throw new DomainException('quota');
                }
                $spent[$field] += $increment;
            }
            // One atomic value under the shared lock. A crash/expired lease cannot reopen
            // concurrency: in_flight stays closed until explicit operator reconciliation.
            $spent['in_flight'] = true;
            if (! $cache->forever(self::LEDGER, $spent) || $cache->get(self::LEDGER) !== $spent) {
                throw new DomainException('quota');
            }
            $reserved = $spent;

            if (now()->utc()->toDateTimeImmutable() >= $settings['authorization_deadline']) {
                throw new DomainException('not_configured');
            }

            return $this->normalizeResponse($this->fetch($request, $settings), $request);
        } catch (DomainException $exception) {
            throw $exception;
        } catch (Throwable) {
            throw new DomainException('quota');
        } finally {
            if ($lock !== null) {
                try {
                    if ($reserved !== null && $lock->isOwnedByCurrentProcess()) {
                        // Never replace a missing or externally changed spent ledger.
                        if ($cache->get(self::LEDGER) !== $reserved) {
                            throw new DomainException('quota');
                        }
                        $reserved['in_flight'] = false;
                        if (! $cache->forever(self::LEDGER, $reserved)) {
                            throw new DomainException('quota');
                        }
                    }
                } catch (Throwable) {
                    throw new DomainException('quota');
                } finally {
                    try {
                        $lock->release();
                    } catch (Throwable) {
                        throw new DomainException('quota');
                    }
                }
            }
        }
    }

    private function settings(): array
    {
        $confirmedFree = config('trips.confirmed_free');
        $authorizationDeadline = $this->authorizationDeadline(config('trips.authorization_expires_at'));
        if (config('trips.enabled') !== true || config('trips.access_authorized') !== true || config('trips.license_authorized') !== true
            || ! is_bool($confirmedFree) || $authorizationDeadline === null
            || now()->utc()->toDateTimeImmutable() >= $authorizationDeadline
            || ! is_string(config('trips.api_key')) || trim(config('trips.api_key')) === ''
            || ! is_string(config('trips.budget_id')) || ! preg_match('/\A[a-zA-Z0-9_-]{1,80}\z/', config('trips.budget_id'))
            || ! in_array(config('trips.budget_currency'), ['USD', 'COP'], true)
            || config('cache.stores.'.config('trips.cache_store').'.driver') !== 'database') {
            throw new DomainException('not_configured');
        }
        $settings = [];
        foreach (['max_requests' => 1000000, 'max_units' => 1000000000, 'units_per_request' => 1000000,
            'timeout_seconds' => 20, 'connect_timeout_seconds' => 5, 'lock_seconds' => 120] as $name => $max) {
            $value = config('trips.'.$name);
            if ((! is_int($value) && (! is_string($value) || ! ctype_digit($value))) || $value < 1 || $value > $max) {
                throw new DomainException('not_configured');
            }
            $settings[$name] = (int) $value;
        }
        foreach (['max_money_minor' => 1000000000000, 'money_minor_per_request' => 1000000000] as $name => $max) {
            $value = config('trips.'.$name);
            $minimum = $confirmedFree ? 0 : 1;
            if ((! is_int($value) && (! is_string($value) || ! ctype_digit($value))) || $value < $minimum || $value > $max
                || ($confirmedFree && (int) $value !== 0)) {
                throw new DomainException('not_configured');
            }
            $settings[$name] = (int) $value;
        }
        if ($settings['lock_seconds'] < $settings['timeout_seconds'] + 10 || $settings['connect_timeout_seconds'] > $settings['timeout_seconds']) {
            throw new DomainException('not_configured');
        }
        $settings['authorization_deadline'] = $authorizationDeadline;

        return $settings;
    }

    private function authorizationDeadline(mixed $value): ?DateTimeImmutable
    {
        if (! is_string($value)) {
            return null;
        }
        $deadline = DateTimeImmutable::createFromFormat('!Y-m-d\TH:i:s\Z', $value, new DateTimeZone('UTC'));
        $errors = DateTimeImmutable::getLastErrors();
        if ($deadline === false || ($errors !== false && ($errors['warning_count'] > 0 || $errors['error_count'] > 0))
            || $deadline->format('Y-m-d\TH:i:s\Z') !== $value) {
            return null;
        }

        return $deadline;
    }

    private function fetch(array $request, array $settings): string
    {
        // Official MapUp examples: request-bodies/01-Origin-Destination-Cost-Tradeoff/
        // 01,03,04,05,06a,15 at https://github.com/mapup/tollguru-tolltally-api-payload-examples
        // Public schema evidence only (2026-09-05), not Colombia license/tariff validation.
        $address = fn (array $point): string => $point['municipality'].', '.$point['department'].', Colombia';
        $max = min(self::MAX_MOBILE_RESPONSE_BYTES, (int) config('trips.max_response_bytes', self::MAX_MOBILE_RESPONSE_BYTES));
        $stream = null;
        try {
            $response = Http::acceptJson()->asJson()->withHeaders(['x-api-key' => config('trips.api_key')])
                ->connectTimeout($settings['connect_timeout_seconds'])->timeout($settings['timeout_seconds'])
                ->withOptions([
                    'allow_redirects' => false, 'verify' => true, 'stream' => true,
                    'read_timeout' => $settings['timeout_seconds'],
                    'on_headers' => function (ResponseInterface $response) use ($max): void {
                        $length = $response->getHeaderLine('Content-Length');
                        if ($length !== '' && (! ctype_digit($length) || (float) $length > $max)) {
                            throw new DomainException('invalid_upstream');
                        }
                    },
                    'progress' => function ($total, $downloaded) use ($max): void {
                        if ($total > $max || $downloaded > $max) {
                            throw new DomainException('invalid_upstream');
                        }
                    },
                ])->post(self::ENDPOINT, [
                    'from' => ['address' => $address($request['origin'])], 'to' => ['address' => $address($request['destination'])],
                    'vehicle' => ['type' => self::VEHICLES[$request['vehicleCategory']]], 'serviceProvider' => 'here',
                    'departure_time' => $this->providerDepartureTime($request), 'units' => ['currency' => 'COP'], 'allowFerry' => false,
                ]);
            $stream = $response->toPsrResponse()->getBody();
            if (! $response->successful()) {
                throw new DomainException(match ($response->status()) {
                    401, 403 => 'not_configured', 429 => 'quota', 408, 504 => 'timeout', default => 'invalid_upstream',
                });
            }
            if (! preg_match('~\Aapplication/(?:[a-z0-9.+-]+\+)?json(?:\s*;|\z)~i', $response->header('Content-Type'))) {
                throw new DomainException('invalid_upstream');
            }
            $body = '';
            $deadline = microtime(true) + $settings['timeout_seconds'];
            while (! $stream->eof()) {
                if (microtime(true) > $deadline) {
                    throw new DomainException('timeout');
                }
                $chunk = $stream->read(min(8192, $max + 1 - strlen($body)));
                $body .= $chunk;
                if (strlen($body) > $max || ($chunk === '' && ! $stream->eof())) {
                    throw new DomainException('invalid_upstream');
                }
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
        } finally {
            $stream?->close();
        }
    }

    private function providerDepartureTime(array $request): string
    {
        if (($request['departureMode'] ?? 'specified') !== 'date_only') {
            return $request['departureUtc'];
        }
        $date = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $request['departureDate'].' 12:00:00', new DateTimeZone('America/Bogota'));
        if ($date === false) {
            throw new DomainException('validation');
        }

        return $date->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d\TH:i:s\Z');
    }

    public function normalizeResponse(string $body, array $request): array
    {
        if (strlen($body) > min(self::MAX_MOBILE_RESPONSE_BYTES, (int) config('trips.max_response_bytes', self::MAX_MOBILE_RESPONSE_BYTES))) {
            throw new DomainException('invalid_upstream');
        }
        try {
            $data = json_decode($body, true, 32, JSON_THROW_ON_ERROR | JSON_BIGINT_AS_STRING);
        } catch (JsonException) {
            throw new DomainException('invalid_upstream');
        }
        $summary = is_array($data) ? ($data['summary'] ?? null) : null;
        if (! is_array($summary) || ($data['status'] ?? null) !== 'OK'
            || ($summary['countries'] ?? null) !== ['COL']
            || ($summary['vehicleType'] ?? null) !== (self::VEHICLES[$request['vehicleCategory']] ?? null)
            || ! is_array($summary['route'] ?? null) || count($summary['route']) !== 2 || ! array_is_list($summary['route'])) {
            throw new DomainException('invalid_upstream');
        }
        $origin = $this->resolvedPoint($summary['route'][0], $request['origin']);
        $destination = $this->resolvedPoint($summary['route'][1], $request['destination']);
        if (! is_array($data['routes'] ?? null) || ! array_is_list($data['routes']) || count($data['routes']) > 10) {
            throw new DomainException('invalid_upstream');
        }
        if ($data['routes'] === []) {
            throw new DomainException('no_route');
        }
        $routes = [];
        foreach ($data['routes'] as $route) {
            $meta = is_array($route) ? ($route['summary'] ?? []) : [];
            $distance = $meta['distance']['value'] ?? null;
            $duration = $meta['duration']['value'] ?? null;
            if (! is_int($distance) || $distance < 1 || $distance > 10000000
                || ! is_int($duration) || $duration < 1 || $duration > 604800 || ! $this->label($meta['name'] ?? null)) {
                throw new DomainException('invalid_upstream');
            }
            $points = $this->geometry($route['polyline'] ?? null);
            foreach ([[$points[0], $origin], [$points[array_key_last($points)], $destination]] as [$point, $endpoint]) {
                if (abs($point[0] - $endpoint['latitude']) > 0.01 || abs($point[1] - $endpoint['longitude']) > 0.01) {
                    throw new DomainException('invalid_upstream');
                }
            }
            $id = hash('sha256', json_encode($points, JSON_THROW_ON_ERROR));
            $routes[$id] ??= ['id' => $id, 'summary' => $meta['name'], 'distanceMeters' => $distance, 'durationSeconds' => $duration,
                // The documented duration field alone does not prove predicted traffic.
                'timeBasis' => 'static',
                // GeoJSON positions are [longitude, latitude].
                'geometry' => ['type' => 'LineString', 'coordinates' => array_map(fn (array $point): array => [$point[1], $point[0]], $points)],
                'tolls' => $this->tolls($route, $request, ($summary['currency'] ?? null) === 'COP')];
        }
        $routes = array_values($routes);
        usort($routes, fn (array $a, array $b): int => [$a['durationSeconds'], $a['id']] <=> [$b['durationSeconds'], $b['id']]);

        $plan = ['requestId' => $request['requestId'], 'generatedAtUtc' => now()->utc()->format('Y-m-d\TH:i:s\Z'),
            'provider' => 'TollGuru', 'attribution' => 'TollGuru / MapUp; routing: HERE', 'origin' => $origin, 'destination' => $destination,
            'routes' => array_slice($routes, 0, min(3, $request['alternatives']))];
        try {
            if (strlen(json_encode($plan, JSON_THROW_ON_ERROR)) > self::MAX_MOBILE_RESPONSE_BYTES) {
                throw new DomainException('invalid_upstream');
            }
        } catch (JsonException) {
            throw new DomainException('invalid_upstream');
        }

        return $plan;
    }

    private function resolvedPoint(mixed $point, array $requested): array
    {
        $address = is_array($point) ? ($point['address'] ?? null) : null;
        $lat = $point['location']['lat'] ?? null;
        $lng = $point['location']['lng'] ?? null;
        if (! $this->label($address, 512) || ! $this->colombiaPoint($lat, $lng)) {
            throw new DomainException('invalid_upstream');
        }
        // Canonical names may contain commas (BOGOTA, D.C.). Match the complete
        // ordered component sequence; municipality/department must not share a match.
        $parts = array_map(GeographicNameNormalizer::normalize(...), explode(',', $address));
        $expected = array_map(GeographicNameNormalizer::normalize(...), explode(',', $requested['municipality'].','.$requested['department'].',Colombia'));
        $matches = false;
        for ($start = 0; $start <= count($parts) - count($expected); $start++) {
            if (array_slice($parts, $start, count($expected)) === $expected) {
                $matches = true;
                break;
            }
        }
        if (! $matches) {
            throw new DomainException('invalid_upstream');
        }

        return ['label' => $requested['municipality'].', '.$requested['department'], 'latitude' => (float) $lat, 'longitude' => (float) $lng];
    }

    private function colombiaPoint(mixed $lat, mixed $lng): bool
    {
        return (is_float($lat) || is_int($lat)) && (is_float($lng) || is_int($lng)) && is_finite((float) $lat) && is_finite((float) $lng)
            && $lat >= -4.3 && $lat <= 13.6 && $lng >= -82 && $lng <= -66.8;
    }

    private function geometry(mixed $encoded): array
    {
        if (! is_string($encoded) || strlen($encoded) < 4 || strlen($encoded) > 200000) {
            throw new DomainException('invalid_upstream');
        }
        $points = [];
        $position = [0, 0];
        $offset = 0;
        while ($offset < strlen($encoded)) {
            foreach ([0, 1] as $axis) {
                $value = 0;
                $shift = 0;
                do {
                    if ($offset >= strlen($encoded) || $shift > 30) {
                        throw new DomainException('invalid_upstream');
                    }
                    $byte = ord($encoded[$offset++]) - 63;
                    if ($byte < 0 || $byte > 63) {
                        throw new DomainException('invalid_upstream');
                    }
                    $value |= ($byte & 31) << $shift;
                    $shift += 5;
                } while ($byte >= 32);
                $position[$axis] += ($value & 1) ? ~($value >> 1) : ($value >> 1);
            }
            $point = [$position[0] / 100000, $position[1] / 100000];
            if (! $this->colombiaPoint(...$point) || count($points) >= self::MAX_GEOMETRY_POINTS) {
                throw new DomainException('invalid_upstream');
            }
            $points[] = $point;
        }
        if (count($points) < 2 || $points[0] === $points[array_key_last($points)]) {
            throw new DomainException('invalid_upstream');
        }

        return $points;
    }

    private function tolls(array $route, array $request, bool $copContext): array
    {
        $result = ['coverage' => 'unknown', 'currency' => 'COP', 'totalMinor' => null, 'subtotalMinor' => null,
            'paymentMethod' => 'cash', 'vehicleCategory' => $request['vehicleCategory'], 'charges' => [],
            'missingRates' => 0, 'stationCount' => null, 'payableCount' => null];
        $rows = $route['tolls'] ?? null;
        if (! is_array($rows) || ! array_is_list($rows) || count($rows) > min(200, (int) config('trips.max_tolls', 200))) {
            return $result;
        }
        $total = $copContext ? $this->money($route['costs']['cash'] ?? null) : null;
        if ($rows === []) {
            if (($route['summary']['hasTolls'] ?? null) === false && $total === 0) {
                $result = array_replace($result, ['coverage' => 'no_charge_confirmed', 'totalMinor' => 0, 'stationCount' => 0, 'payableCount' => 0]);
            }

            return $result;
        }
        $result['stationCount'] = count($rows);
        $charges = [];
        foreach ($rows as $index => $row) {
            $distance = is_array($row) ? ($row['arrival']['distance'] ?? null) : null;
            if (! is_array($row) || ! $this->label($row['name'] ?? null) || (! is_int($distance) && ! is_float($distance))
                || ! is_finite((float) $distance) || $distance < 0 || $distance > $route['summary']['distance']['value']) {
                // An unverifiable row cannot supply an ordered station count or breakdown.
                return array_replace($result, ['stationCount' => null, 'missingRates' => count($rows)]);
            }
            $amount = $copContext && ($row['currency'] ?? null) === 'COP' ? $this->money($row['cashCost'] ?? null) : null;
            $charges[] = ['distance' => $distance, 'index' => $index, 'charge' => [
                'name' => $row['name'], 'amountMinor' => $amount, 'sourceUrl' => null, 'effectiveAt' => null,
            ]];
        }
        usort($charges, fn (array $a, array $b): int => [$a['distance'], $a['index']] <=> [$b['distance'], $b['index']]);
        $result['charges'] = array_column($charges, 'charge');
        $amounts = array_column($result['charges'], 'amountMinor');
        $known = array_filter($amounts, fn ($amount): bool => $amount !== null);
        $result['missingRates'] = count($amounts) - count($known);
        $subtotal = array_sum($known);
        if ($known !== [] && $result['missingRates'] > 0) {
            $result['subtotalMinor'] = $subtotal;
            $result['coverage'] = 'partial';
        }
        if ($result['missingRates'] === 0) {
            $result['payableCount'] = count(array_filter($known, fn (int $amount): bool => $amount > 0));
            if ($total !== null && $total === $subtotal && ($route['summary']['hasTolls'] ?? null) === true) {
                $result['coverage'] = 'complete';
                $result['totalMinor'] = $total;
            }
        }

        return $result;
    }

    private function money(mixed $value): ?int
    {
        // Decimal text is converted digit-by-digit; no multiplication of binary floats.
        if ((! is_int($value) && ! is_float($value) && ! is_string($value)) || (is_float($value) && ! is_finite($value))) {
            return null;
        }
        $text = is_float($value) ? json_encode($value, JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR) : (string) $value;
        if (! preg_match('/\A(0|[1-9]\d{0,8})(?:\.(\d{1,2}))?\z/', $text, $parts)) {
            return null;
        }

        return (int) $parts[1] * 100 + (int) str_pad($parts[2] ?? '', 2, '0');
    }

    private function label(mixed $value, int $max = 160): bool
    {
        $secret = config('trips.api_key');

        return is_string($value) && trim($value) !== '' && strlen($value) <= $max && ! preg_match('/[\x00-\x1f\x7f<>]/', $value)
            && (! is_string($secret) || $secret === '' || ! str_contains($value, $secret));
    }
}
