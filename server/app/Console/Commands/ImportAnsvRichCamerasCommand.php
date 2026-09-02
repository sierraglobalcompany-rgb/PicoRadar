<?php

namespace App\Console\Commands;

use App\Services\AnsvRichCameraImporter;
use App\Services\GeographyImporter;
use App\Services\SimpleXlsxReader;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

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
        try {
            $snapshotSha = $this->snapshotSha($path, $this->option('snapshot-sha'));
            $fetchedAt = $this->fetchedAt($this->option('fetched-at'));
            $officialGridRows = $this->officialGridRows($this->option('official-grid-json'));
            $rows = $reader->rows($path);
            $dryRun = (bool) $this->option('dry-run');
            if ($dryRun) {
                $geography->bootstrap(dryRun: true);
                $result = $importer->importRows($rows, $snapshotSha, $fetchedAt, true, $officialGridRows);
            } else {
                $result = DB::transaction(function () use ($geography, $importer, $rows, $snapshotSha, $fetchedAt, $officialGridRows): array {
                    $geography->bootstrap();

                    return $importer->importRows($rows, $snapshotSha, $fetchedAt, false, $officialGridRows);
                });
            }
        } catch (Throwable $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }

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

    private function snapshotSha(string $path, mixed $option): string
    {
        $actualSha = strtolower((string) hash_file('sha256', $path));
        $providedSha = trim((string) $option);
        if ($providedSha === '') {
            return $actualSha;
        }
        if (! preg_match('/^[a-f0-9]{64}$/i', $providedSha)) {
            throw new DomainException('ANSV source snapshot SHA-256 is invalid.');
        }
        if (strtolower($providedSha) !== $actualSha) {
            throw new DomainException('ANSV source snapshot SHA-256 does not match the XLSX bytes.');
        }

        return $actualSha;
    }

    private function fetchedAt(mixed $option): CarbonImmutable
    {
        try {
            $fetchedAt = CarbonImmutable::parse((string) ($option ?: now()->toAtomString()));
        } catch (Throwable) {
            throw new DomainException('ANSV fetched-at timestamp is invalid.');
        }
        if ($fetchedAt->isAfter(CarbonImmutable::now()->addDay())) {
            throw new DomainException('ANSV fetched-at timestamp cannot be more than one day in the future.');
        }

        return $fetchedAt;
    }

    /** @return list<array<string,mixed>>|null */
    private function officialGridRows(mixed $option): ?array
    {
        $path = trim((string) $option);
        if ($path === '') {
            return null;
        }
        if (! is_file($path)) {
            throw new DomainException('Official ANSV grid JSON file not found.');
        }
        $decoded = json_decode((string) file_get_contents($path), true);
        if (! is_array($decoded) || ! is_array($decoded['results'] ?? null)) {
            throw new DomainException('Official ANSV grid JSON shape is invalid.');
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
