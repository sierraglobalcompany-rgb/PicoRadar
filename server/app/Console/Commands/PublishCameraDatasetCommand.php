<?php

namespace App\Console\Commands;

use App\Services\CameraMobileDatasetPublisher;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Console\Command;
use Throwable;

class PublishCameraDatasetCommand extends Command
{
    protected $signature = 'picoradar:cameras:publish-mobile-dataset {--output-dir=} {--dataset-version=} {--generated-at=} {--as-of=} {--import-id=} {--latest-approved} {--json}';

    protected $description = 'Publish the compact mobile camera dataset from accepted active camera records.';

    public function handle(CameraMobileDatasetPublisher $publisher): int
    {
        try {
            $importId = $this->importId();
            $latestApproved = (bool) $this->option('latest-approved');
            if (($importId === null) === ! $latestApproved) {
                throw new DomainException('Select exactly one approved ANSV import source.');
            }
            $outputDirectory = $this->option('output-dir') ?: dirname(base_path()).DIRECTORY_SEPARATOR.'mobile'.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR.'datasets'.DIRECTORY_SEPARATOR.'cameras';
            $result = $publisher->publish(
                (string) $outputDirectory,
                $this->option('dataset-version') ? (string) $this->option('dataset-version') : null,
                $this->generatedAt(),
                $this->asOf(),
                $importId,
                $latestApproved,
            );
        } catch (Throwable $throwable) {
            if ($this->option('json')) {
                $this->line(json_encode([
                    'schema' => 'picoradar.camera-dataset-publication.v1',
                    'status' => 'failed',
                    'error' => $throwable->getMessage(),
                ], JSON_THROW_ON_ERROR));
            } else {
                $this->components->error($throwable->getMessage());
            }

            return self::FAILURE;
        }

        if ($this->option('json')) {
            $this->line(json_encode($result, JSON_THROW_ON_ERROR));

            return self::SUCCESS;
        }

        $this->components->info("Published {$result['recordCount']} operating cameras.");
        $this->table(['metric', 'value'], [
            ['version', $result['version']],
            ['records', $result['recordCount']],
            ['speed known', $result['speedKnownCount']],
            ['speed coverage', $result['speedCoverage']],
            ['asset sha256', $result['assetSha256']],
        ]);

        return self::SUCCESS;
    }

    private function generatedAt(): CarbonImmutable
    {
        $option = $this->option('generated-at');
        if (! $option) {
            return CarbonImmutable::now('America/Bogota')->utc();
        }
        $value = (string) $option;
        if (! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$/', $value)) {
            throw new DomainException('Camera dataset generated-at timestamp is invalid.');
        }

        return CarbonImmutable::parse($value)->utc();
    }

    private function asOf(): CarbonImmutable
    {
        $option = $this->option('as-of');
        if (! $option) {
            return CarbonImmutable::now('America/Bogota');
        }
        $value = (string) $option;
        if (! preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
            throw new DomainException('Camera dataset as-of date is invalid.');
        }

        return CarbonImmutable::createFromFormat('!Y-m-d', $value, 'America/Bogota');
    }

    private function importId(): ?int
    {
        $option = $this->option('import-id');
        if ($option === null || $option === '') {
            return null;
        }
        $value = (string) $option;
        if (! ctype_digit($value) || (int) $value < 1) {
            throw new DomainException('Camera dataset import-id must be a positive integer.');
        }

        return (int) $value;
    }
}
