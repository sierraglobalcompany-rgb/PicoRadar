<?php

namespace App\Console\Commands;

use App\Services\ManifestPublisher;
use Illuminate\Console\Command;

class RegenerateDatasetManifestCommand extends Command
{
    protected $signature = 'picoradar:datasets:manifest';

    protected $description = 'Regenerate the static PicoRadar dataset manifest from published releases.';

    public function handle(ManifestPublisher $publisher): int
    {
        $publisher->regenerate();
        $this->components->info('Dataset manifest regenerated.');

        return self::SUCCESS;
    }
}
