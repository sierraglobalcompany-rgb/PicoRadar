<?php

namespace App\Console\Commands;

use App\Services\CameraImportIntegrityAuditor;
use Illuminate\Console\Command;

class CameraImportIntegrityCommand extends Command
{
    protected $signature = 'picoradar:cameras:imports:integrity {--json} {--fail-on-error}';

    public function handle(CameraImportIntegrityAuditor $auditor): int
    {
        $result = $auditor->audit();
        $this->line(json_encode($result, JSON_THROW_ON_ERROR));

        return $result['errorCount'] > 0 && $this->option('fail-on-error') ? self::FAILURE : self::SUCCESS;
    }
}
