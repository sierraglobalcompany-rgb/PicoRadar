<?php

namespace App\Services;

use App\Models\Camera;

class CameraDuplicateDetector
{
    /** @return list<array{camera: Camera, distanceMeters: float}> */
    public function candidates(Camera $camera, float $meters = 25, int $limit = 25): array
    {
        $latitude = (float) $camera->lat;
        $longitude = (float) $camera->lon;
        $latitudeDelta = $meters / 111_320;
        $longitudeDelta = $meters / (111_320 * max(0.01, cos(deg2rad($latitude))));

        return Camera::query()
            ->with(['source', 'jurisdiction', 'geographicUnit'])
            ->where('jurisdiction_id', $camera->jurisdiction_id)
            ->whereKeyNot($camera->id)
            ->where('status', '!=', 'retired')
            ->whereBetween('lat', [$latitude - $latitudeDelta, $latitude + $latitudeDelta])
            ->whereBetween('lon', [$longitude - $longitudeDelta, $longitude + $longitudeDelta])
            ->limit(250)
            ->get()
            ->map(function (Camera $candidate) use ($latitude, $longitude): array {
                return ['camera' => $candidate, 'distanceMeters' => $this->haversine($latitude, $longitude, (float) $candidate->lat, (float) $candidate->lon)];
            })
            ->filter(fn (array $candidate): bool => $candidate['distanceMeters'] <= $meters)
            ->sortBy('distanceMeters')->take($limit)->values()->all();
    }

    private function haversine(float $latA, float $lonA, float $latB, float $lonB): float
    {
        $a = sin(deg2rad(($latB - $latA) / 2)) ** 2 + cos(deg2rad($latA)) * cos(deg2rad($latB)) * sin(deg2rad(($lonB - $lonA) / 2)) ** 2;

        return 2 * 6_371_000 * asin(min(1, sqrt($a)));
    }
}
