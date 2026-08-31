<?php

namespace App\Console\Commands;

use App\Services\AnsvRichCameraImporter;
use App\Services\GeographyImporter;
use App\Services\SimpleXlsxReader;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

class ImportAnsvRichCamerasCommand extends Command
{
    protected $signature = 'picoradar:ansv:cameras:import {xlsx : Path to official ANSV XLSX export} {--snapshot-sha=} {--fetched-at=} {--dry-run} {--json}';

    protected $description = 'Import the official rich ANSV camera export into the B03 camera registry.';

    public function handle(SimpleXlsxReader $reader, AnsvRichCameraImporter $importer, GeographyImporter $geography): int
    {
        $path = (string) $this->argument('xlsx');
        if (! is_file($path)) {
            $this->error('ANSV XLSX file not found.');

            return self::FAILURE;
        }
        $snapshotSha = (string) ($this->option('snapshot-sha') ?: hash_file('sha256', $path));
        $fetchedAt = CarbonImmutable::parse((string) ($this->option('fetched-at') ?: now()->toAtomString()));
        $geography->bootstrap();
        $result = $importer->importRows($reader->rows($path), strtolower($snapshotSha), $fetchedAt, (bool) $this->option('dry-run'));
        if ($this->option('json')) {
            $this->line(json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        } else {
            $this->components->info("ANSV camera rows: {$result['rowCount']}");
            $this->components->info("Active public candidates: {$result['activeCandidateCount']}");
            $this->components->info("RAW_37_PARSED_AS_37_KMH={$result['raw37ParsedAs37Kmh']}");
        }

        return self::SUCCESS;
    }
}
