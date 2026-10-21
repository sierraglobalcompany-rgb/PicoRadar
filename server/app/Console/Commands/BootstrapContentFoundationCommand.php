<?php

namespace App\Console\Commands;

use App\Services\ContentFoundationBootstrapper;
use Illuminate\Console\Command;

class BootstrapContentFoundationCommand extends Command
{
    protected $signature = 'picoradar:content:bootstrap';

    protected $description = 'Prepare canonical geography, jurisdictions and required content datasets.';

    public function handle(ContentFoundationBootstrapper $bootstrapper): int
    {
        foreach ($bootstrapper->bootstrap() as $key => $value) {
            $this->line("$key: $value");
        }

        return self::SUCCESS;
    }
}
