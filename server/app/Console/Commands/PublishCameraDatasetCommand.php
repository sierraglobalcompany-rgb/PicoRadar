<?php

namespace App\Console\Commands;

use App\Services\CameraMobileDatasetPublisher;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

class PublishCameraDatasetCommand extends Command
{
    protected $signature = 'picoradar:cameras:publish-mobile-dataset {--output-dir=} {--dataset-version=2026.08.31-ansv} {--generated-at=2026-08-31T15:44:00Z} {--as-of=2026-08-31} {--json}';

    protected $description = 'Publish the compact mobile camera dataset from accepted active camera records.';

    public function handle(CameraMobileDatasetPublisher $publisher): int
    {
        $outputDirectory = $this->option('output-dir') ?: dirname(base_path()).DIRECTORY_SEPARATOR.'mobile'.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR.'datasets'.DIRECTORY_SEPARATOR.'cameras';
        $result = $publisher->publish(
            (string) $outputDirectory,
            (string) $this->option('dataset-version'),
            CarbonImmutable::parse((string) $this->option('generated-at')),
            CarbonImmutable::parse((string) $this->option('as-of')),
        );

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
}
