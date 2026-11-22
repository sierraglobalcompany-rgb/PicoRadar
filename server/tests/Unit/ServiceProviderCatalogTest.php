<?php

namespace Tests\Unit;

use App\Models\ServiceProvider;
use App\Models\GeographicUnit;
use PHPUnit\Framework\TestCase;
use Illuminate\Support\Carbon;

class ServiceProviderCatalogTest extends TestCase
{
    public function test_source_evidence_must_be_https_reviewed_and_not_expired(): void
    {
        $asOf = Carbon::parse('2026-11-22 12:00:00', 'America/Bogota');
        $provider = new ServiceProvider([
            'source_url' => 'https://authority.example/providers/1',
            'verified_at' => Carbon::parse('2026-11-22 11:00:00', 'America/Bogota'),
            'valid_until' => '2026-11-23',
        ]);

        $this->assertTrue($provider->hasCurrentSourceEvidence($asOf));

        $provider->valid_until = null;
        $this->assertFalse($provider->hasCurrentSourceEvidence($asOf));
        $provider->valid_until = '2026-11-23';

        $provider->source_url = 'http://authority.example/providers/1';
        $this->assertFalse($provider->hasCurrentSourceEvidence($asOf));

        $provider->source_url = 'https://authority.example/providers/1';
        $provider->valid_until = '2026-11-21';
        $this->assertFalse($provider->hasCurrentSourceEvidence($asOf));
    }

    public function test_missing_or_future_source_review_never_counts_as_current(): void
    {
        $asOf = Carbon::parse('2026-11-22 12:00:00', 'America/Bogota');
        $provider = new ServiceProvider(['source_url' => 'https://authority.example/providers/1']);

        $this->assertFalse($provider->hasCurrentSourceEvidence($asOf));

        $provider->verified_at = Carbon::parse('2026-11-22 13:00:00', 'America/Bogota');
        $this->assertFalse($provider->hasCurrentSourceEvidence($asOf));
    }

    public function test_valid_until_uses_the_colombian_calendar_date_even_when_as_of_is_utc(): void
    {
        $provider = new ServiceProvider([
            'source_url' => 'https://authority.example/providers/1',
            'verified_at' => Carbon::parse('2026-11-21 23:00:00', 'America/Bogota'),
            'valid_until' => '2026-11-21',
        ]);
        $asOf = Carbon::parse('2026-11-22T04:30:00Z');

        $this->assertTrue($provider->hasCurrentSourceEvidence($asOf));
    }

    public function test_only_published_records_with_current_source_evidence_are_projected(): void
    {
        $asOf = Carbon::parse('2026-11-22 12:00:00', 'America/Bogota');
        $provider = new ServiceProvider([
            'category' => 'cda',
            'department_code' => '05',
            'municipality_code' => '05001',
            'name' => 'Centro sintético',
            'latitude' => '6.2518400',
            'longitude' => '-75.5635900',
            'source_url' => 'https://authority.example/providers/1',
            'verified_at' => Carbon::parse('2026-11-22 11:00:00', 'America/Bogota'),
            'valid_until' => '2026-11-23',
            'status' => 'draft',
        ]);
        $provider->setAttribute('id', 41);
        $provider->setRelation('department', new GeographicUnit(['name' => 'Departamento sintético']));
        $provider->setRelation('municipality', new GeographicUnit(['name' => 'Municipio sintético']));

        $this->assertNull($provider->toPublishedDatasetRecord($asOf));

        $provider->status = 'published';
        $record = $provider->toPublishedDatasetRecord($asOf);

        $this->assertNotNull($record);
        $this->assertSame('sp-41', $record['id']);
        $this->assertSame('Departamento sintético', $record['department']);
        $this->assertSame('Municipio sintético', $record['municipality']);
        $this->assertSame(6.25184, $record['latitude']);
        $this->assertSame(-75.56359, $record['longitude']);
        $this->assertSame('05001', $record['municipalityCode']);
        $this->assertSame('https://authority.example/providers/1', $record['sourceUrl']);
        $this->assertArrayNotHasKey('officialStatus', $record);
        $this->assertArrayNotHasKey('sponsorStatus', $record);

        $provider->valid_until = '2026-11-21';
        $this->assertNull($provider->toPublishedDatasetRecord($asOf));
    }
}
