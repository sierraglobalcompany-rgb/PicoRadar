<?php

namespace App\Services;

use App\Models\Camera;

class CameraDuplicateDetector
{
    /** @return list<array{camera: Camera, distanceMeters: float}> */
    public function candidates(Camera $camera, float $meters = 25, int $limit = 25): array
    {
        return $this->scan($camera, $meters, $limit)['candidates'];
    }

    /**
     * Performs a portable, bounded geographic scan. `scanCapped` is derived
     * from the raw bounding-box query before Haversine filtering or result
     * limiting, so callers never infer completeness from a short result list.
     *
     * @return array{candidates: list<array{camera: Camera, distanceMeters: float}>, scanCapped: bool, boundingCandidateCountObserved: int, scanCap: int}
     */
    public function scan(Camera $camera, float $meters = 25, int $returnLimit = 25, int $candidateScanCap = 250): array
    {
        $latitude = (float) $camera->lat;
        $longitude = (float) $camera->lon;
        // Match the sphere radius used by haversine(). 111_320 m/degree
        // is larger than the spherical value (~111_195) and silently omits
        // true <=25m neighbours close to the bounding-box edge.
        $latitudeDelta = rad2deg($meters / 6_371_000);
        $longitudeDelta = $latitudeDelta / max(0.01, cos(deg2rad(
            min(90.0, abs($latitude) + $latitudeDelta)
        )));
        $scanCap = max(1, $candidateScanCap);
        $rawBoundingRows = Camera::query()
            ->with(['source', 'jurisdiction', 'geographicUnit'])
            ->where('jurisdiction_id', $camera->jurisdiction_id)
            ->whereKeyNot($camera->id)
            ->where('status', '!=', 'retired')
            ->whereBetween('lat', [$latitude - $latitudeDelta, $latitude + $latitudeDelta])
            ->whereBetween('lon', [$longitude - $longitudeDelta, $longitude + $longitudeDelta])
            ->orderBy('id')
            ->limit($scanCap + 1)
            ->get();
        $scanCapped = $rawBoundingRows->count() > $scanCap;
        $candidates = $rawBoundingRows->take($scanCap)
            ->map(function (Camera $candidate) use ($latitude, $longitude): array {
                return ['camera' => $candidate, 'distanceMeters' => $this->haversine($latitude, $longitude, (float) $candidate->lat, (float) $candidate->lon)];
            })
            ->filter(fn (array $candidate): bool => $candidate['distanceMeters'] <= $meters)
            ->sortBy('distanceMeters')
            ->take(max(1, $returnLimit))
            ->values()
            ->all();

        return ['candidates' => $candidates, 'scanCapped' => $scanCapped, 'boundingCandidateCountObserved' => $rawBoundingRows->count(), 'scanCap' => $scanCap];
    }

    /**
     * Returns a bounded, non-N² registry scan. A cap hit is exposed so callers
     * never present this operational signal as a complete global duplicate total.
     *
     * @return array{pairs: int, cappedSeeds: int}
     */
    public function boundedRegistryMetrics(float $meters = 25): array
    {
        $pairs = 0;
        $cappedSeeds = 0;
        Camera::query()->where('status', '!=', 'retired')->orderBy('id')->eachById(function (Camera $camera) use ($meters, &$pairs, &$cappedSeeds): void {
            $scan = $this->scan($camera, $meters, 250);
            if ($scan['scanCapped']) {
                $cappedSeeds++;
            }
            foreach ($scan['candidates'] as $candidate) {
                if ($camera->id < $candidate['camera']->id) {
                    $pairs++;
                }
            }
        });

        return ['pairs' => $pairs, 'cappedSeeds' => $cappedSeeds];
    }

    private function haversine(float $latA, float $lonA, float $latB, float $lonB): float
    {
        $a = sin(deg2rad(($latB - $latA) / 2)) ** 2 + cos(deg2rad($latA)) * cos(deg2rad($latB)) * sin(deg2rad(($lonB - $lonA) / 2)) ** 2;

        return 2 * 6_371_000 * asin(min(1, sqrt($a)));
    }
}
