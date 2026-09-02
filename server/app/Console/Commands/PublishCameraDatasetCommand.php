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
        if (! preg_match('/^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})T(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})(?<timezone>Z|[+-]\d{2}:\d{2})$/', $value, $matches)) {
            throw new DomainException('Camera dataset generated-at timestamp is invalid.');
        }

        $year = (int) $matches['year'];
        $month = (int) $matches['month'];
        $day = (int) $matches['day'];
        $hour = (int) $matches['hour'];
        $minute = (int) $matches['minute'];
        $second = (int) $matches['second'];
        $timezone = $matches['timezone'] === 'Z' ? '+00:00' : $matches['timezone'];
        $offsetHour = (int) substr($timezone, 1, 2);
        $offsetMinute = (int) substr($timezone, 4, 2);

        if (! $this->isValidDate($year, $month, $day) || $hour > 23 || $minute > 59 || $second > 59 || $offsetHour > 23 || $offsetMinute > 59) {
            throw new DomainException('Camera dataset generated-at timestamp is invalid.');
        }

        return CarbonImmutable::create($year, $month, $day, $hour, $minute, $second, $timezone)->utc();
    }

    private function asOf(): CarbonImmutable
    {
        $option = $this->option('as-of');
        if (! $option) {
            return CarbonImmutable::now('America/Bogota');
        }
        $value = (string) $option;
        if (! preg_match('/^(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})$/', $value, $matches)) {
            throw new DomainException('Camera dataset as-of date is invalid.');
        }

        $year = (int) $matches['year'];
        $month = (int) $matches['month'];
        $day = (int) $matches['day'];
        if (! $this->isValidDate($year, $month, $day)) {
            throw new DomainException('Camera dataset as-of date is invalid.');
        }

        return CarbonImmutable::create($year, $month, $day, 0, 0, 0, 'America/Bogota');
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

    private function isValidDate(int $year, int $month, int $day): bool
    {
        return $year > 0 && checkdate($month, $day, $year);
    }
}
