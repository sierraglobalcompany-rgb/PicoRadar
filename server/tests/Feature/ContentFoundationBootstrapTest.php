<?php

namespace Tests\Feature;

use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Tests\TestCase;

class ContentFoundationBootstrapTest extends TestCase
{
    use RefreshDatabase;

    public function test_content_bootstrap_prepares_geography_and_the_restrictions_dataset_idempotently(): void
    {
        $this->assertSame(0, Artisan::call('picoradar:content:bootstrap'));
        $counts = [
            GeographicUnit::query()->count(),
            Jurisdiction::query()->count(),
            Dataset::query()->count(),
        ];

        $this->assertSame(0, Artisan::call('picoradar:content:bootstrap'));

        $this->assertSame([1138, 73, 1], $counts);
        $this->assertSame($counts, [
            GeographicUnit::query()->count(),
            Jurisdiction::query()->count(),
            Dataset::query()->count(),
        ]);
        $this->assertDatabaseHas('datasets', [
            'key' => 'restrictions',
            'title' => 'Pico y placa por ciudad',
            'schema_version' => 1,
            'enabled' => true,
            'publication_revision' => 0,
        ]);
    }
}
