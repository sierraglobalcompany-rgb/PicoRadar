<?php

namespace App\Console\Commands;

use App\Services\CameraMobileDatasetPublisher;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

class PublishCameraDatasetCommand extends Command
{
    protected $signature = 'picoradar:cameras:publish-mobile-dataset {--output-dir=} {--dataset-version=} {--generated-at=} {--as-of=} {--import-id=} {--latest-approved} {--json}';

    protected $description = 'Publish the compact mobile camera dataset from accepted active camera records.';

    public function handle(CameraMobileDatasetPublisher $publisher): int
    {
        $outputDirectory = $this->option('output-dir') ?: dirname(base_path()).DIRECTORY_SEPARATOR.'mobile'.DIRECTORY_SEPARATOR.'assets'.DIRECTORY_SEPARATOR.'datasets'.DIRECTORY_SEPARATOR.'cameras';
        $generatedAt = $this->option('generated-at')
            ? CarbonImmutable::parse((string) $this->option('generated-at'))->utc()
            : CarbonImmutable::now('America/Bogota')->utc();
        $asOf = $this->option('as-of')
            ? CarbonImmutable::parse((string) $this->option('as-of'), 'America/Bogota')
            : CarbonImmutable::now('America/Bogota');
        $result = $publisher->publish(
            (string) $outputDirectory,
            $this->option('dataset-version') ? (string) $this->option('dataset-version') : null,
            $generatedAt,
            $asOf,
            $this->option('import-id') ? (int) $this->option('import-id') : null,
            (bool) $this->option('latest-approved'),
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
