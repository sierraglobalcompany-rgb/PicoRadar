<?php

namespace App\Console\Commands;

use App\Services\GeographyImporter;
use Illuminate\Console\Command;

class BootstrapGeographyCommand extends Command
{
    protected $signature = 'picoradar:geography:bootstrap {--dry-run : Validate fixtures and report without writing}';

    protected $description = 'Bootstrap canonical Colombia geography and PicoRadar jurisdictions from versioned fixtures.';

    public function handle(GeographyImporter $importer): int
    {
        $summary = $importer->bootstrap((bool) $this->option('dry-run'));
        foreach ($summary as $key => $value) {
            $this->line("$key: $value");
        }

        return self::SUCCESS;
    }
}
