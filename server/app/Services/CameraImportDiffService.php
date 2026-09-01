<?php

namespace App\Services;

use App\Models\Camera;

/** Compares only fields B04 may propose; lifecycle, verification, and notes remain B03-owned. */
class CameraImportDiffService
{
    public function differs(Camera $camera, array $payload, int $jurisdictionId, int $municipalityId): bool
    {
        return [
            $camera->external_id, $camera->jurisdiction_id, $camera->geographic_unit_id, $camera->name, round((float) $camera->lat, 7), round((float) $camera->lon, 7), $camera->type->value, $camera->direction, $camera->bearing, $camera->corridor, $camera->speed_limit,
        ] !== [
            $payload['external_id'], $jurisdictionId, $municipalityId, $payload['name'], round((float) $payload['lat'], 7), round((float) $payload['lon'], 7), $payload['type'], $payload['direction'], $payload['bearing'], $payload['corridor'], $payload['speed_limit'],
        ];
    }
}
