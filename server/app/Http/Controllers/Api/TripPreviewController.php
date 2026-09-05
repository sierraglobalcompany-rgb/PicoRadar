<?php

namespace App\Http\Controllers\Api;

use App\Enums\GeographicUnitLevel;
use App\Models\GeographicUnit;
use App\Services\TollGuruTripPreview;
use App\Support\GeographicNameNormalizer;
use DateTimeImmutable;
use DomainException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use JsonException;
use Throwable;

final class TripPreviewController
{
    public function __invoke(Request $request, TollGuruTripPreview $provider): JsonResponse
    {
        try {
            $input = $this->validate($request);
            $body = $provider->preview($input);

            return response()->json($body)->header('Cache-Control', 'no-store');
        } catch (DomainException $exception) {
            $code = $exception->getMessage();
            $status = match ($code) {
                'validation', 'departure_window', 'no_route', 'unsupported_vehicle' => 422,
                'not_configured' => 503,
                'quota' => 429,
                'timeout' => 504,
                default => 502,
            };
            if (! in_array($code, ['validation', 'departure_window', 'no_route', 'unsupported_vehicle', 'not_configured', 'quota', 'timeout', 'invalid_upstream', 'network'], true)) {
                $code = 'invalid_upstream';
            }
            $error = ['code' => $code];
            if ($code === 'departure_window') {
                $error['maxFutureDays'] = $this->maxFutureDays();
            }

            return response()->json(['error' => $error], $status)->header('Cache-Control', 'no-store');
        } catch (Throwable) {
            // Includes unavailable geography storage; never pass SQL/payloads to global logging.
            return response()->json(['error' => ['code' => 'not_configured']], 503)->header('Cache-Control', 'no-store');
        }
    }

    private function validate(Request $request): array
    {
        $raw = $request->getContent();
        if (! $request->isJson() || strlen($raw) > min(4096, (int) config('trips.max_request_bytes', 4096))) {
            throw new DomainException('validation');
        }
        try {
            $input = json_decode($raw, true, 12, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw new DomainException('validation');
        }
        $this->exactKeys($input, ['requestId', 'origin', 'destination', 'departureUtc', 'timeZone', 'vehicleCategory', 'paymentMethod', 'alternatives']);
        if (! is_string($input['requestId']) || ! preg_match('/\A[a-zA-Z0-9_-]{1,128}\z/', $input['requestId'])
            || $input['timeZone'] !== 'America/Bogota' || $input['paymentMethod'] !== 'cash'
            || ! in_array($input['vehicleCategory'], ['car', 'motorcycle', 'taxi'], true)
            || ! is_int($input['alternatives']) || $input['alternatives'] < 1 || $input['alternatives'] > 3) {
            throw new DomainException('validation');
        }
        if (! is_string($input['departureUtc']) || ! preg_match('/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z\z/', $input['departureUtc'])) {
            throw new DomainException('validation');
        }
        $format = str_contains($input['departureUtc'], '.') ? '!Y-m-d\TH:i:s.u\Z' : '!Y-m-d\TH:i:s\Z';
        $departure = DateTimeImmutable::createFromFormat($format, $input['departureUtc'], new \DateTimeZone('UTC'));
        $errors = DateTimeImmutable::getLastErrors();
        if ($departure === false || ($errors !== false && ($errors['warning_count'] || $errors['error_count']))) {
            throw new DomainException('validation');
        }
        $now = now()->utc();
        if ($departure < $now || $departure > $now->copy()->addDays($this->maxFutureDays())) {
            throw new DomainException('departure_window');
        }
        foreach (['origin', 'destination'] as $key) {
            $point = $input[$key];
            $this->exactKeys($point, ['code', 'municipality', 'department']);
            if (! is_string($point['code']) || ! preg_match('/\A\d{5}\z/', $point['code'])
                || ! is_string($point['municipality']) || strlen($point['municipality']) > 160
                || ! is_string($point['department']) || strlen($point['department']) > 160) {
                throw new DomainException('validation');
            }
            $matches = GeographicUnit::query()->where('code', $point['code'])->where('level', GeographicUnitLevel::Municipality)
                ->where('is_active', true)->with('parent.parent')->limit(2)->get();
            $unit = $matches->count() === 1 ? $matches->first() : null;
            $department = $unit?->parent;
            $country = $department?->parent;
            if (! $unit || ! $department?->is_active || $department->level !== GeographicUnitLevel::Department
                || ! $country?->is_active || $country->level !== GeographicUnitLevel::Country || $country->code !== 'CO'
                || GeographicNameNormalizer::normalize($point['municipality']) !== $unit->normalized_name
                || GeographicNameNormalizer::normalize($point['department']) !== $department->normalized_name) {
                throw new DomainException('validation');
            }
            $input[$key] = ['code' => $unit->code, 'municipality' => $unit->name, 'department' => $department->name];
        }
        if ($input['origin']['code'] === $input['destination']['code']) {
            throw new DomainException('validation');
        }

        return $input;
    }

    private function maxFutureDays(): int
    {
        return max(1, min(30, (int) config('trips.max_future_days', 30)));
    }

    private function exactKeys(mixed $value, array $keys): void
    {
        if (! is_array($value) || count($value) !== count($keys) || array_diff($keys, array_keys($value))) {
            throw new DomainException('validation');
        }
    }
}
