<?php

namespace App\Console\Commands;

use App\Services\CameraImportHealthReporter;
use Illuminate\Console\Command;

class CameraImportHealthCommand extends Command
{
    protected $signature = 'picoradar:cameras:imports:health {--json}';

    public function handle(CameraImportHealthReporter $reporter): int
    {
        $this->line(json_encode($reporter->report(), JSON_THROW_ON_ERROR));

        return self::SUCCESS;
    }
}
