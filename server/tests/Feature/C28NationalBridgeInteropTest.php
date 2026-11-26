<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use App\Services\RestrictionPublicationService;
use App\Services\RestrictionRuleVersionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class C28NationalBridgeInteropTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        try {
            parent::tearDown();
        } finally {
            Carbon::setTestNow();
        }
    }

    /**
     * Runs the normal editorial approval and publication flow with fake disks.
     *
     * To export the exact published bytes for the opt-in Dart test, set the
     * process-only PICORADAR_C28_BRIDGE_EXPORT_DIR to a new direct child of
     * D:\\codex\\_REPORTES\\PicoRadar\\C29-V3-20261124. No files are written
     * when the variable is absent; existing directories/files are rejected.
     */
    public function test_c28_off_release_exports_exact_bytes_for_dart_bridge(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-11-23T12:00:00Z'));
        config([
            'cache.default' => 'array',
            'campaigns.public_catalog_enabled' => false,
            'app_accounts.transactional_email_enabled' => false,
            'app_accounts.marketing_send_enabled' => false,
            'datasets.draft_disk' => 'local',
            'datasets.published_disk' => 'public',
            'datasets.public_base_url' => '/storage',
            'datasets.min_app_version' => '1.0.0',
        ]);
        $draftDisk = (string) config('datasets.draft_disk');
        $publishedDisk = (string) config('datasets.published_disk');
        foreach (array_unique([$draftDisk, $publishedDisk]) as $disk) {
            Storage::fake($disk);
        }
        $this->withoutVite();

        $sourceUrl = 'https://example.test/c28-synthetic-restrictions';
        $dataset = Dataset::query()->create([
            'key' => 'restrictions',
            'title' => 'Restrictions',
            'schema_version' => 2,
            'enabled' => true,
        ]);
        $dataset->sources()->create([
            'title' => 'C28 synthetic source',
            'authority' => 'C28 synthetic authority',
            'url' => $sourceUrl,
            'verified_at' => now(),
            'is_active' => true,
        ]);

        $author = User::factory()->create([
            'role' => OperatorRole::Editor,
            'is_active' => true,
        ]);
        $reviewer = User::factory()->create([
            'role' => OperatorRole::Admin,
            'is_active' => true,
        ]);

        $country = GeographicUnit::query()->create([
            'key' => 'c28-synthetic-country',
            'level' => 'country',
            'code' => 'CO',
            'name' => 'C28 Synthetic Country',
            'normalized_name' => 'c28 synthetic country',
            'is_active' => true,
            'source_system' => 'C28 synthetic fixture',
            'source_version' => 'C28-V2',
        ]);
        $department = GeographicUnit::query()->create([
            'parent_id' => $country->id,
            'key' => 'c28-synthetic-department',
            'level' => 'department',
            'code' => '99',
            'name' => 'C28 Synthetic Department',
            'normalized_name' => 'c28 synthetic department',
            'is_active' => true,
            'source_system' => 'C28 synthetic fixture',
            'source_version' => 'C28-V2',
        ]);
        $unit = GeographicUnit::query()->create([
            'parent_id' => $department->id,
            'key' => 'c28-synthetic-municipality-99999',
            'level' => 'municipality',
            'code' => '99999',
            'name' => 'C28 Synthetic Municipality',
            'normalized_name' => 'c28 synthetic municipality',
            'is_active' => true,
            'source_system' => 'C28 synthetic fixture',
            'source_version' => 'C28-V2',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => 'co-c28-synthetic-99999',
            'name' => 'C28 Synthetic Municipality',
            'kind' => 'city',
            'primary_geographic_unit_id' => $unit->id,
            'enabled' => true,
            'timezone' => 'America/Bogota',
        ]);

        $payload = [
            'schemaVersion' => 2,
            'id' => 'co-c28-synthetic-99999',
            'name' => 'C28 Synthetic Municipality',
            'coverages' => [[
                'vehicleKind' => 'car',
                'serviceType' => 'private',
                'coverageCompleteness' => 'partial',
                'consultationEnabled' => true,
                'verifiedAt' => '2026-11-20T12:00:00Z',
                'staleAfter' => '2026-12-20T00:00:00Z',
                'sourceUrls' => [$sourceUrl],
                'rules' => [[
                    'id' => 'C28_SYNTHETIC_RESTRICTION_RULE',
                    'priority' => 100,
                    'effect' => 'restrict',
                    'validFrom' => '2026-11-01T00:00:00-05:00',
                    'validUntil' => '2026-12-31T23:59:59-05:00',
                    'weekdays' => [1],
                    'digitPosition' => 'lastNumeric',
                    'digits' => [1, 2],
                    'timeWindows' => [[
                        'startMinute' => 300,
                        'endMinute' => 1200,
                    ]],
                    'appliesOnHolidays' => false,
                    'sourceUrl' => $sourceUrl,
                    'verifiedAt' => '2026-11-20T12:00:00Z',
                ]],
            ]],
        ];

        $versions = app(RestrictionRuleVersionService::class);
        $publication = app(RestrictionPublicationService::class);
        $initialDraft = $versions->createDraft($jurisdiction, $payload, $author);
        $initialVersion = $versions->validate($initialDraft, $author);
        $publication->approveMaterialChange(
            $initialVersion,
            0,
            $reviewer,
            'C28 synthetic baseline approval for interoperability.',
            $sourceUrl,
        );
        $publication->publish([$initialVersion->id], 0, $author);

        $jurisdiction->geographicUnits()->attach($unit->id);
        $offPayload = $initialVersion->payload;
        $offPayload['municipalityCodes'] = ['99999'];
        $offPayload['consultationEnabled'] = false;
        foreach ($offPayload['coverages'] as &$coverage) {
            $coverage['consultationEnabled'] = false;
        }
        unset($coverage);

        $offDraft = $versions->createDraft($jurisdiction, $offPayload, $author);
        $offVersion = $versions->validate($offDraft, $author);
        $jurisdiction->update(['enabled' => false]);
        $publication->approveMaterialChange(
            $offVersion,
            1,
            $reviewer,
            'C28 synthetic jurisdiction OFF approval for interoperability.',
            $sourceUrl,
        );
        $release = $publication->publish([$offVersion->id], 1, $author);

        $this->assertSame(DatasetReleaseStatus::Published, $release->status);
        $this->assertNull($release->content_encoding);
        $disk = Storage::disk($publishedDisk);
        $this->assertTrue($disk->exists($release->asset_path));
        $payloadBytes = $disk->get($release->asset_path);
        $manifestPath = (string) config('datasets.manifest_path');
        $this->assertSame('manifest/v1/manifest.json', $manifestPath);
        $this->assertTrue($disk->exists($manifestPath));
        $manifestBytes = $disk->get($manifestPath);

        $payloadSha256 = hash('sha256', $payloadBytes);
        $this->assertSame($release->sha256, $payloadSha256);
        $publishedPayload = json_decode($payloadBytes, true, 512, JSON_THROW_ON_ERROR);
        $manifest = json_decode($manifestBytes, true, 512, JSON_THROW_ON_ERROR);
        $manifestEntry = $manifest['datasets']['restrictions'] ?? null;
        $this->assertIsArray($manifestEntry);
        $this->assertSame('restrictions', $publishedPayload['datasetKey']);
        $this->assertSame(2, $publishedPayload['schemaVersion']);
        $this->assertSame($release->version, $publishedPayload['version']);
        $this->assertSame($release->version, $manifestEntry['version']);
        $this->assertSame($payloadSha256, $manifestEntry['sha256']);
        $this->assertSame(
            $dataset->refresh()->publication_revision,
            $manifestEntry['publicationRevision'],
        );
        $this->assertArrayNotHasKey('contentEncoding', $manifestEntry);
        $this->assertCount(1, $publishedPayload['jurisdictions']);
        $publishedJurisdiction = $publishedPayload['jurisdictions'][0];
        $this->assertSame('co-c28-synthetic-99999', $publishedJurisdiction['id']);
        $this->assertSame(['99999'], $publishedJurisdiction['municipalityCodes']);
        $this->assertFalse($publishedJurisdiction['consultationEnabled']);
        $this->assertCount(1, $publishedJurisdiction['coverages']);
        $publishedCoverage = $publishedJurisdiction['coverages'][0];
        $this->assertSame('partial', $publishedCoverage['coverageCompleteness']);
        $this->assertFalse($publishedCoverage['consultationEnabled']);
        $this->assertNotEmpty($publishedCoverage['rules']);

        $exportDirectory = getenv('PICORADAR_C28_BRIDGE_EXPORT_DIR');
        if (is_string($exportDirectory) && trim($exportDirectory) !== '') {
            $allowedRoot = realpath('D:\\codex\\_REPORTES\\PicoRadar\\C29-V3-20261124');
            $exportParentPath = dirname($exportDirectory);
            $exportParent = realpath($exportParentPath);
            $this->assertNotFalse($allowedRoot, 'The C29 QA report root must already exist.');
            $this->assertSame(
                strtolower((string) $allowedRoot),
                strtolower((string) $exportParent),
                'Export must be a new direct child of the C29 QA report root.',
            );
            $this->assertSame(
                strtolower((string) $allowedRoot),
                strtolower($exportParentPath),
                'Export parent must be the canonical C29 root without traversal.',
            );
            $this->assertFalse(is_link((string) $allowedRoot));
            $this->assertFalse(is_link($exportParentPath));
            $this->assertMatchesRegularExpression('/^bridge-[0-9a-f-]{36}$/i', basename($exportDirectory));
            $this->assertFalse(is_link($exportDirectory));
            $this->assertFalse(file_exists($exportDirectory), 'Export directory must be new.');
            $this->assertTrue(mkdir($exportDirectory, 0700));

            $payloadPath = $exportDirectory.DIRECTORY_SEPARATOR.'restrictions.json';
            $manifestExportPath = $exportDirectory.DIRECTORY_SEPARATOR.'manifest.json';
            $this->assertFalse(file_exists($payloadPath));
            $this->assertFalse(file_exists($manifestExportPath));
            $this->assertSame(strlen($payloadBytes), file_put_contents($payloadPath, $payloadBytes, LOCK_EX));
            $this->assertSame(strlen($manifestBytes), file_put_contents($manifestExportPath, $manifestBytes, LOCK_EX));
            $this->assertSame($payloadSha256, hash_file('sha256', $payloadPath));
            $this->assertSame(hash('sha256', $manifestBytes), hash_file('sha256', $manifestExportPath));
        }
    }
}
