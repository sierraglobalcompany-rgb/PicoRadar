<?php

namespace App\Services;

use App\Models\CameraImportRun;
use DomainException;

/** Read-only, deterministic advisory comparison of two analyzed runs for one source. */
class CameraImportRunComparator
{
    private const FIELDS = ['jurisdiction', 'municipality', 'name', 'lat', 'lon', 'type', 'direction', 'bearing', 'corridor', 'speed_limit'];

    public function compare(CameraImportRun $previous, CameraImportRun $current): array
    {
        if ($previous->source_id !== $current->source_id) {
            throw new DomainException('Only runs from the same source can be compared.');
        }
        $left = $this->indexed($previous);
        $right = $this->indexed($current);
        $result = ['added' => [], 'removed' => [], 'changed' => [], 'unchanged' => [], 'conflicted' => [], 'missing_identity' => []];
        foreach (array_unique(array_merge(array_keys($left['rows']), array_keys($right['rows']))) as $identity) {
            $a = $left['rows'][$identity] ?? null;
            $b = $right['rows'][$identity] ?? null;
            if (isset($left['conflicts'][$identity]) || isset($right['conflicts'][$identity])) {
                $result['conflicted'][] = ['externalId' => $identity];
            } elseif (! $a) {
                $result['added'][] = ['externalId' => $identity];
            } elseif (! $b && $current->import_mode === 'snapshot') {
                $result['removed'][] = ['externalId' => $identity, 'advisory' => true];
            } elseif ($b) {
                $fields = $this->fields($a->normalized_payload, $b->normalized_payload);
                $fields === [] ? $result['unchanged'][] = ['externalId' => $identity] : $result['changed'][] = ['externalId' => $identity, 'fields' => $fields, 'distanceMeters' => $this->distance($a->normalized_payload, $b->normalized_payload), 'highRisk' => $this->highRisk($fields, $a->normalized_payload, $b->normalized_payload)];
            }
        }
        $result['missing_identity'] = array_merge($left['missing'], $right['missing']);
        $previousCount = count($left['rows']);
        $drop = $previousCount === 0 || $current->import_mode !== 'snapshot' ? 0 : count($result['removed']) / $previousCount * 100;
        $result['snapshotDropPercent'] = round($drop, 2);
        $result['suspiciousSnapshotDrop'] = $drop >= config('picoradar.camera_import_snapshot_drop_warning_percent', 30);
        $result['counts'] = array_map('count', array_intersect_key($result, array_flip(['added', 'removed', 'changed', 'unchanged', 'conflicted', 'missing_identity'])));

        return $result;
    }

    private function indexed(CameraImportRun $run): array
    {
        $rows = [];
        $conflicts = [];
        $missing = [];
        foreach ($run->items()->where('analysis_generation', $run->analysis_generation)->where('status', '!=', 'skipped')->orderBy('external_id')->orderBy('row_number')->cursor() as $item) {
            $identity = trim((string) $item->external_id);
            if ($identity === '') {
                $missing[] = ['runId' => $run->id, 'rowNumber' => $item->row_number];
            } elseif (isset($rows[$identity])) {
                $conflicts[$identity] = true;
            } else {
                $rows[$identity] = $item;
            }
        }

        return compact('rows', 'conflicts', 'missing');
    }

    private function fields(array $a, array $b): array
    {
        $changed = [];
        foreach (self::FIELDS as $field) {
            $key = match ($field) {
                'jurisdiction' => 'region_code', 'municipality' => 'municipality_code', default => $field
            };
            if ($this->canonical($a[$key] ?? null) !== $this->canonical($b[$key] ?? null)) {
                $changed[] = $field;
            }
        }

        return $changed;
    }

    private function canonical(mixed $value): mixed
    {
        return is_numeric($value) ? round((float) $value, 7) : (is_string($value) && trim($value) === '' ? null : $value);
    }

    private function distance(array $a, array $b): ?float
    {
        if ($this->canonical($a['lat'] ?? null) === $this->canonical($b['lat'] ?? null) && $this->canonical($a['lon'] ?? null) === $this->canonical($b['lon'] ?? null)) {
            return null;
        }
        $dLat = deg2rad((float) $b['lat'] - (float) $a['lat']);
        $dLon = deg2rad((float) $b['lon'] - (float) $a['lon']);
        $h = sin($dLat / 2) ** 2 + cos(deg2rad((float) $a['lat'])) * cos(deg2rad((float) $b['lat'])) * sin($dLon / 2) ** 2;

        return round(6371000 * 2 * atan2(sqrt($h), sqrt(1 - $h)), 2);
    }

    private function highRisk(array $fields, array $a, array $b): bool
    {
        return array_intersect($fields, ['jurisdiction', 'municipality', 'type']) !== [] || (($this->distance($a, $b) ?? 0) > config('picoradar.camera_import_high_risk_move_meters', 100));
    }
}
