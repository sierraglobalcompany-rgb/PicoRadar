<?php

namespace App\Console\Commands;

use App\Services\AnsvRichCameraImporter;
use App\Services\GeographyImporter;
use App\Services\SimpleXlsxReader;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

class ImportAnsvRichCamerasCommand extends Command
{
    protected $signature = 'picoradar:ansv:cameras:import {xlsx : Path to official ANSV XLSX export} {--snapshot-sha=} {--fetched-at=} {--official-grid-json= : Path to official ANSV map/data/sast.json for reconciliation} {--dry-run} {--json}';

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
        $officialGridRows = $this->officialGridRows((string) $this->option('official-grid-json'));
        $geography->bootstrap();
        $result = $importer->importRows($reader->rows($path), strtolower($snapshotSha), $fetchedAt, (bool) $this->option('dry-run'), $officialGridRows);
        $result['RAW_DATE_37_STORED_AS_1900_DATE'] = $result['rawDate37StoredAs1900Date'] ?? null;
        $result['RAW_37_PARSED_AS_37_KMH'] = $result['raw37ParsedAs37Kmh'] ?? null;
        if ($this->option('json')) {
            $this->line(json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        } else {
            $this->components->info("ANSV camera rows: {$result['rowCount']}");
            $this->components->info("Active public candidates: {$result['activeCandidateCount']}");
            $this->components->info("RAW_37_PARSED_AS_37_KMH={$result['raw37ParsedAs37Kmh']}");
            $this->components->info("RAW_DATE_37_STORED_AS_1900_DATE={$result['rawDate37StoredAs1900Date']}");
        }

        return self::SUCCESS;
    }

    /** @return list<array<string,mixed>>|null */
    private function officialGridRows(string $path): ?array
    {
        if ($path === '') {
            return null;
        }
        if (! is_file($path)) {
            $this->error('Official ANSV grid JSON file not found.');

            return null;
        }
        $decoded = json_decode((string) file_get_contents($path), true);
        if (! is_array($decoded) || ! is_array($decoded['results'] ?? null)) {
            $this->error('Official ANSV grid JSON shape is invalid.');

            return null;
        }
        $rows = [];
        foreach ($decoded['results'] as $department) {
            if (! is_array($department) || ! is_array($department['ubicaciones'] ?? null)) {
                continue;
            }
            foreach ($department['ubicaciones'] as $location) {
                if (is_array($location)) {
                    $rows[] = $location;
                }
            }
        }

        return $rows;
    }
}
