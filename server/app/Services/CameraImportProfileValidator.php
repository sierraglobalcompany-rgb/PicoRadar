<?php

namespace App\Services;

use DomainException;

class CameraImportProfileValidator
{
    private const TARGETS = ['region_code', 'municipality_code', 'municipality_name', 'external_id', 'name', 'lat', 'lon', 'type', 'direction', 'bearing', 'corridor', 'speed_limit', 'notes'];

    public function read(string $key): array
    {
        if (! preg_match('/^[a-z0-9_]+$/', $key)) {
            throw new DomainException('Invalid import profile key.');
        } $path = database_path("data/camera_import_profiles/{$key}.json");
        if (! is_file($path)) {
            throw new DomainException('Unknown import profile.');
        } $data = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        if (($data['schemaVersion'] ?? null) !== 1 || ($data['key'] ?? null) !== $key || ! in_array($data['format'] ?? null, ['csv', 'ndjson', 'geojson'], true) || ! is_array($data['requiredColumns'] ?? null) || ! is_array($data['columnMappings'] ?? null) || ! is_array($data['typeAliases'] ?? null) || ! is_array($data['defaults'] ?? null)) {
            throw new DomainException('Invalid import profile schema.');
        }
        foreach ($data['requiredColumns'] as $column) {
            if (! is_string($column) || trim($column) === '') {
                throw new DomainException('Invalid required profile column.');
            }
        }
        $targets = [];
        foreach ($data['columnMappings'] as $column => $target) {
            if (! is_string($column) || ! is_string($target) || ! in_array($target, self::TARGETS, true) || in_array($target, $targets, true)) {
                throw new DomainException('Invalid or duplicate profile column mapping.');
            }
            $targets[] = $target;
        }
        foreach ($data['typeAliases'] as $alias => $type) {
            if (! is_string($alias) || ! in_array($type, ['speed', 'red_light', 'combined', 'other'], true)) {
                throw new DomainException('Invalid profile type alias.');
            }
        }
        foreach ($data['defaults'] as $target => $value) {
            if (! in_array($target, self::TARGETS, true) || is_array($value) || is_object($value)) {
                throw new DomainException('Invalid profile default.');
            }
        }

        return $data;
    }

    public function hash(string $key): string
    {
        $this->read($key);

        return hash_file('sha256', database_path("data/camera_import_profiles/{$key}.json"));
    }
}
