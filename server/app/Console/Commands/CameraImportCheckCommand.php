<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

/** Read-only preflight: it never creates a run, writes storage, or emits an audit record. */
class CameraImportCheckCommand extends Command
{
    protected $signature = 'picoradar:cameras:import:check {file} {--json}';

    public function handle(): int
    {
        $path = (string) $this->argument('file');
        $format = strtolower(pathinfo($path, PATHINFO_EXTENSION));
        $valid = is_file($path) && in_array($format, ['csv', 'ndjson', 'jsonl', 'geojson'], true);
        $result = ['schema' => 'picoradar.camera-import-check.v1', 'valid' => $valid, 'format' => $format, 'sha256' => $valid ? hash_file('sha256', $path) : null];
        $this->line(json_encode($result, JSON_THROW_ON_ERROR));

        return $valid ? self::SUCCESS : self::FAILURE;
    }
}
