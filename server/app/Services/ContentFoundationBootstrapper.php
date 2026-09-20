<?php

namespace App\Services;

use App\Models\Dataset;
use Illuminate\Support\Facades\DB;

class ContentFoundationBootstrapper
{
    public function __construct(private readonly GeographyImporter $geography) {}

    /** @return array<string, int> */
    public function bootstrap(): array
    {
        return DB::transaction(function (): array {
            $summary = $this->geography->bootstrap();
            Dataset::query()->firstOrCreate(
                ['key' => 'restrictions'],
                [
                    'title' => 'Pico y placa por ciudad',
                    'schema_version' => 1,
                    'enabled' => true,
                    'publication_revision' => 0,
                ],
            );

            return $summary + ['datasets' => Dataset::query()->count()];
        });
    }
}
