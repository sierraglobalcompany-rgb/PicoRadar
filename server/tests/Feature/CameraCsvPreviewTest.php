<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Enums\CameraStatus;
use App\Models\Camera;
use App\Models\CameraSource;
use App\Models\Jurisdiction;
use App\Services\CameraCsvPreviewService;
use App\Services\CameraRegistryService;
use App\Services\GeographyImporter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CameraCsvPreviewTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        app(GeographyImporter::class)->bootstrap();
    }

    public function test_new_valid_row_is_only_previewed_and_never_created(): void
    {
        [$source, $jurisdiction, $unit] = $this->domain();
        $before = Camera::count();
        $review = $this->review([$this->row(2, $unit->code)]);
        self::assertSame('create_ready', $review['rows'][0]['status']);
        self::assertSame(0, $review['missing_advisory']);
        self::assertSame($before, Camera::count());
    }

    public function test_unverified_source_is_blocked_fail_closed(): void
    {
        [$source, $jurisdiction, $unit] = $this->domain();
        $source->update(['verified_at' => null]);
        $review = $this->review([$this->row(2, $unit->code)]);
        self::assertSame('blocked', $review['rows'][0]['status']);
    }

    public function test_existing_active_camera_cannot_be_updated(): void
    {
        [$source, $jurisdiction, $unit] = $this->domain();
        $camera = app(CameraRegistryService::class)->create([
            'source_id' => $source->id, 'jurisdiction_id' => $jurisdiction->id,
            'geographic_unit_id' => $unit->id, 'external_id' => 'EX-1',
            'lat' => 4.711, 'lon' => -74.0721, 'type' => 'other',
        ]);
        $camera->forceFill(['status' => CameraStatus::InReview])->save();
        $review = $this->review([$this->row(2, $unit->code)]);
        self::assertSame('blocked', $review['rows'][0]['status']);
        self::assertSame(CameraStatus::InReview, $camera->fresh()->status);
    }

    public function test_duplicate_external_ids_inside_csv_are_not_safe(): void
    {
        [$source, $jurisdiction, $unit] = $this->domain();
        $review = $this->review([$this->row(2, $unit->code), $this->row(3, $unit->code)]);
        self::assertSame(2, $review['counts']['duplicate']);
    }

    public function test_nearby_distinct_csv_records_are_blocked(): void
    {
        [$source, $jurisdiction, $unit] = $this->domain();
        $a = $this->row(2, $unit->code);
        $b = $this->row(3, $unit->code);
        $b['values']['external_id'] = 'EX-2';
        $review = $this->review([$a, $b]);
        self::assertSame(2, $review['counts']['blocked']);
    }

    public function test_external_ids_that_differ_only_by_letter_case_are_duplicate(): void
    {
        [$source, $jurisdiction, $unit] = $this->domain();
        $first = $this->row(2, $unit->code);
        $second = $this->row(3, $unit->code);
        $second['values']['external_id'] = 'ex-1';
        $second['values']['lat'] = '4.7500000';
        $second['values']['lon'] = '-74.0500000';
        $review = $this->review([$first, $second]);
        self::assertSame(2, $review['counts']['duplicate']);
        self::assertSame(0, $review['counts']['create_ready']);
    }

    private function domain(): array
    {
        $jurisdiction = Jurisdiction::query()->where('enabled', true)->with('geographicUnits')->firstOrFail();
        $unit = $jurisdiction->geographicUnits->first();
        $source = CameraSource::factory()->create();
        app()->instance('b04.csv.test.source', $source);
        app()->instance('b04.csv.test.jurisdiction', $jurisdiction);

        return [$source, $jurisdiction, $unit];
    }

    private function review(array $rows): array
    {
        return app(CameraCsvPreviewService::class)->preview(
            ['rows' => $rows], app('b04.csv.test.source'),
            app('b04.csv.test.jurisdiction'), 'delta'
        );
    }

    private function row(int $record, string $code): array
    {
        return ['record' => $record, 'errors' => [], 'values' => [
            'external_id' => 'EX-1', 'municipality_code' => $code,
            'lat' => '4.7110000', 'lon' => '-74.0721000', 'type' => 'other',
        ]];
    }
}
