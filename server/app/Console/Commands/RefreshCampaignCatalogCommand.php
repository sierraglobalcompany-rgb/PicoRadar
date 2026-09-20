<?php

namespace App\Console\Commands;

use App\Models\CampaignCatalogRelease;
use App\Services\CampaignCatalogPublisher;
use Illuminate\Console\Command;

class RefreshCampaignCatalogCommand extends Command
{
    protected $signature = 'campaigns:refresh-catalog';

    protected $description = 'Refresh the public campaign catalog before its signed validity expires';

    public function handle(CampaignCatalogPublisher $publisher): int
    {
        $latest = CampaignCatalogRelease::query()->latest('version')->first();
        $refreshBefore = now()->addSeconds(config('campaigns.catalog_refresh_before_seconds'));

        if ($latest?->expires_at?->isAfter($refreshBefore)) {
            $this->components->info('SKIPPED_FRESH');

            return self::SUCCESS;
        }

        $release = $publisher->publish(null);
        $this->components->info("PUBLISHED {$release->version}");

        return self::SUCCESS;
    }
}
