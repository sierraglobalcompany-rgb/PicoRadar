<?php

namespace Tests\Feature;

use App\Enums\DatasetReleaseStatus;
use App\Enums\OperatorRole;
use App\Enums\RestrictionRuleVersionStatus;
use App\Models\Dataset;
use App\Models\DatasetRelease;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionPublication;
use App\Models\RestrictionPublicationItem;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class RestrictionCoverageExportTest extends TestCase
{
    use RefreshDatabase;

    private GeographicUnit $department;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
        Http::preventStrayRequests();
        $country = GeographicUnit::query()->create([
            'key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia',
            'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'c6-test',
        ]);
        $this->department = GeographicUnit::query()->create([
            'parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05',
            'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true,
            'source_system' => 'synthetic', 'source_version' => 'c6-test',
        ]);
    }

    public function test_editorial_export_streams_beyond_one_page_and_reuses_all_editor_filters(): void
    {
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        for ($index = 1; $index <= 56; $index++) {
            [$municipality, $jurisdiction] = $this->jurisdiction(
                sprintf('05%03d', $index),
                sprintf('export-city-%02d', $index),
                sprintf('Export city %02d', $index),
            );
            $coverage = $this->coverage('car', 'private', 'complete', ['https://example.test/source'], '2099-01-01T00:00:00Z');
            if ($index === 1) {
                $coverage['consultationEnabled'] = false;
            }
            $this->version($jurisdiction, 1, RestrictionRuleVersionStatus::Draft, [$coverage]);
        }

        foreach ([
            ['05090', 'Attention unknown', 'attention-unknown', 'complete', [], null],
            ['05091', 'Attention partial', 'attention-partial', 'partial', ['https://example.test/partial'], '2099-01-01T00:00:00Z'],
            ['05092', 'Attention stale', 'attention-stale', 'complete', ['https://example.test/stale'], '2000-01-01T00:00:00Z'],
        ] as [$code, $name, $key, $completeness, $sources, $staleAfter]) {
            [, $jurisdiction] = $this->jurisdiction($code, $key, $name);
            $this->version($jurisdiction, 1, RestrictionRuleVersionStatus::Draft, [
                $this->coverage('car', 'private', $completeness, $sources, $staleAfter),
            ]);
        }
        [, $inactive] = $this->jurisdiction('05093', 'inactive-city', 'Inactive city', enabled: false);
        $this->version($inactive, 1, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', 'private', 'complete', ['https://example.test/inactive'], '2099-01-01T00:00:00Z'),
        ]);

        $allResponse = $this->actingAs($reviewer)
            ->get(route('admin.restrictions.coverage.export', ['page' => 2]))
            ->assertOk()
            ->assertHeader('content-type', 'text/csv; charset=UTF-8');
        $allRows = $this->csvRows($allResponse->streamedContent());
        self::assertCount(59, $allRows, 'The export must include all 56 rows plus three attention rows, independent of page 2.');
        self::assertSame('editorial', $allRows[0]['scope']);
        self::assertSame('false', collect($allRows)->firstWhere('municipality_key', 'co-05001')['consultation_enabled']);

        $filteredResponse = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', [
            'q' => 'Attention',
            'department' => '05',
            'vehicle_kind' => 'car',
            'availability' => 'attention',
            'management' => 'active',
        ]));
        $filtered = $this->csvRows($filteredResponse->streamedContent());
        self::assertCount(3, $filtered);
        $attentionStates = array_column($filtered, 'coverage_evidence_state');
        sort($attentionStates);
        self::assertSame(['PARTIAL', 'STALE', 'UNKNOWN'], $attentionStates);

        $inactive = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', [
            'q' => 'Inactive', 'department' => '05', 'vehicle_kind' => 'car',
            'availability' => 'verified', 'management' => 'inactive',
        ]));
        self::assertCount(1, $this->csvRows($inactive->streamedContent()));

        $editorialUrl = route('admin.restrictions.coverage.export', [
            'scope' => 'editorial', 'q' => 'Attention', 'department' => '05',
            'vehicle_kind' => 'car', 'availability' => 'attention', 'management' => 'active',
        ]);
        $this->actingAs($reviewer)
            ->get(route('admin.restrictions.index', [
                'q' => 'Attention', 'department' => '05', 'vehicle_kind' => 'car',
                'availability' => 'attention', 'management' => 'active',
            ]))
            ->assertOk()
            ->assertSee('Exportar vista CSV')
            ->assertSee('Matriz municipal CSV')
            ->assertSee(e($editorialUrl), false);
    }

    public function test_municipality_matrix_keeps_unassigned_and_inactive_geography_and_actual_release_separate(): void
    {
        Dataset::query()->create([
            'key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 2, 'enabled' => true,
            'current_version' => 'c6-release-7', 'publication_revision' => 7,
        ]);
        $reviewer = User::factory()->create(['role' => OperatorRole::Reviewer]);
        [$unassigned] = $this->jurisdictionUnit('05001', 'unassigned-city', '  =HYPERLINK("https://example.test","x")');
        [$assigned, $inactive] = $this->jurisdiction('05002', 'inactive-jurisdiction', 'Inactive municipality', enabled: false);
        $draftJurisdiction = Jurisdiction::query()->create([
            'key' => 'inactive-draft-jurisdiction', 'name' => 'Draft jurisdiction', 'kind' => 'city',
            'primary_geographic_unit_id' => $assigned->id, 'enabled' => false, 'timezone' => 'America/Bogota',
        ]);
        $assigned->jurisdictions()->attach($draftJurisdiction->id);
        $this->version($draftJurisdiction, 1, RestrictionRuleVersionStatus::Draft, [
            $this->coverage('car', 'private', 'complete', ['https://example.test/draft'], '2099-01-01T00:00:00Z'),
        ]);

        $carCoverage = $this->coverage('car', "\t=SUM(1,1)", 'complete', ['https://example.test/source-one', 'https://example.test/source-two'], '2099-01-01T00:00:00Z');
        $carCoverage['rules'] = [
            ['sourceUrl' => 'https://example.test/source-rule-one', 'verifiedAt' => '2026-11-18T00:00:00Z', 'validUntil' => '2027-01-01T00:00:00Z'],
            ['sourceUrl' => 'https://example.test/source-rule-two', 'verifiedAt' => '2026-11-17T00:00:00Z', 'validUntil' => '2027-02-01T00:00:00Z'],
        ];
        $version = $this->version($inactive, 4, RestrictionRuleVersionStatus::Validated, [
            $carCoverage,
            $this->coverage('motorcycle', 'public_cargo', 'partial', ['https://example.test/source-three'], '2099-01-01T00:00:00Z'),
        ]);
        $release = DatasetRelease::query()->create([
            'dataset_id' => Dataset::query()->where('key', 'restrictions')->value('id'),
            'version' => 'c6-release-7',
            'status' => DatasetReleaseStatus::Draft,
            'sha256' => hash('sha256', 'synthetic-release'),
        ]);
        DB::table('dataset_releases')->where('id', $release->id)->update([
            'status' => DatasetReleaseStatus::Published->value,
            'asset_path' => 'datasets/restrictions/c6-release-7/restrictions.json',
            'published_at' => now(),
        ]);
        $publication = RestrictionPublication::query()->create([
            'dataset_release_id' => $release->id,
            'action' => 'publish',
            'base_publication_revision' => 6,
            'result_publication_revision' => 7,
            'actor_id' => $reviewer->id,
            'summary' => ['jurisdictionCount' => 1],
        ]);
        RestrictionPublicationItem::query()->create([
            'restriction_publication_id' => $publication->id,
            'jurisdiction_id' => $inactive->id,
            'restriction_rule_version_id' => $version->id,
            'action' => 'publish',
        ]);

        $response = $this->actingAs($reviewer)->get(route('admin.restrictions.coverage.export', [
            'scope' => 'municipalities',
            'management' => 'active',
        ]));
        $rows = $this->csvRows($response->streamedContent());
        self::assertCount(4, $rows, 'This synthetic fixture has two municipalities: one unknown row, two released categories and one draft row.');
        $noJurisdiction = collect($rows)->firstWhere('management_state', 'NO_JURISDICTION');
        self::assertSame('UNKNOWN', $noJurisdiction['coverage_evidence_state']);
        self::assertSame('NO_JURISDICTION', $noJurisdiction['missing_reason']);
        self::assertSame("'  =HYPERLINK(\"https://example.test\",\"x\")", $noJurisdiction['municipality_name']);

        $inactiveRows = collect($rows)->where('jurisdiction_key', 'inactive-jurisdiction')->values();
        self::assertCount(2, $inactiveRows);
        self::assertSame(['car', 'motorcycle'], $inactiveRows->pluck('vehicle_kind')->all());
        self::assertSame(["'\t=SUM(1,1)", 'public_cargo'], $inactiveRows->pluck('service_type')->all());
        self::assertSame(['INACTIVE', 'INACTIVE'], $inactiveRows->pluck('management_state')->all());
        self::assertSame(['4', '4'], $inactiveRows->pluck('editor_version')->all());
        self::assertSame(['c6-release-7', 'c6-release-7'], $inactiveRows->pluck('published_release')->all());
        self::assertSame(['PUBLISHED', 'PUBLISHED'], $inactiveRows->pluck('publication_state')->all());
        self::assertSame(4, count(json_decode($inactiveRows[0]['source_urls'], true, 512, JSON_THROW_ON_ERROR)));
        self::assertSame(3, count(json_decode($inactiveRows[0]['verified_at'], true, 512, JSON_THROW_ON_ERROR)));
        self::assertSame(2, count(json_decode($inactiveRows[0]['valid_until'], true, 512, JSON_THROW_ON_ERROR)));
        $draftRow = collect($rows)->firstWhere('jurisdiction_key', 'inactive-draft-jurisdiction');
        self::assertSame('1', $draftRow['editor_version']);
        self::assertSame('draft', $draftRow['editor_version_status']);
        self::assertSame('', $draftRow['published_release']);
        self::assertSame('UNKNOWN', $draftRow['publication_state']);
    }

    public function test_export_denies_roles_without_dataset_view_and_does_not_mutate_data_or_call_services(): void
    {
        $commercial = User::factory()->create(['role' => OperatorRole::Commercial]);
        $before = [
            'geographic_units' => DB::table('geographic_units')->count(),
            'jurisdictions' => DB::table('jurisdictions')->count(),
            'restriction_rule_versions' => DB::table('restriction_rule_versions')->count(),
            'restriction_publications' => DB::table('restriction_publications')->count(),
            'dataset_releases' => DB::table('dataset_releases')->count(),
        ];
        $mutations = [];
        DB::listen(function (QueryExecuted $query) use (&$mutations): void {
            if (preg_match('/^\s*(insert|update|delete|replace|alter|create|drop)\b/i', $query->sql) === 1) {
                $mutations[] = $query->sql;
            }
        });

        $this->actingAs($commercial)->get(route('admin.restrictions.coverage.export'))->assertForbidden();

        $after = [
            'geographic_units' => DB::table('geographic_units')->count(),
            'jurisdictions' => DB::table('jurisdictions')->count(),
            'restriction_rule_versions' => DB::table('restriction_rule_versions')->count(),
            'restriction_publications' => DB::table('restriction_publications')->count(),
            'dataset_releases' => DB::table('dataset_releases')->count(),
        ];
        self::assertSame($before, $after);
        self::assertSame([], $mutations, 'Export authorization and GET must not write database state.');
    }

    /** @return array{GeographicUnit, Jurisdiction} */
    private function jurisdiction(string $code, string $key, string $name, bool $enabled = true): array
    {
        [$unit, $jurisdiction] = $this->jurisdictionUnit($code, $key, $name, $enabled);
        $unit->jurisdictions()->attach($jurisdiction->id);

        return [$unit, $jurisdiction];
    }

    /** @return array{GeographicUnit, Jurisdiction} */
    private function jurisdictionUnit(string $code, string $key, string $name, bool $enabled = true): array
    {
        $unit = GeographicUnit::query()->create([
            'parent_id' => $this->department->id, 'key' => 'co-'.$code, 'level' => 'municipality',
            'code' => $code, 'name' => $name, 'normalized_name' => strtolower($name),
            'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'c6-test',
        ]);
        $jurisdiction = Jurisdiction::query()->create([
            'key' => $key, 'name' => $name, 'kind' => 'city', 'primary_geographic_unit_id' => $unit->id,
            'enabled' => $enabled, 'timezone' => 'America/Bogota',
        ]);

        return [$unit, $jurisdiction];
    }

    /** @param list<array<string, mixed>> $coverages */
    private function version(Jurisdiction $jurisdiction, int $number, RestrictionRuleVersionStatus $status, array $coverages): RestrictionRuleVersion
    {
        $payload = ['id' => $jurisdiction->key, 'name' => $jurisdiction->name, 'coverages' => $coverages];

        return RestrictionRuleVersion::query()->create([
            'jurisdiction_id' => $jurisdiction->id,
            'version' => $number,
            'status' => $status,
            'payload' => $payload,
            'payload_sha256' => hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR)),
            'base_publication_revision' => 0,
        ]);
    }

    /** @param list<string> $sources
     * @return array<string, mixed>
     */
    private function coverage(string $vehicleKind, string $serviceType, string $completeness, array $sources, ?string $staleAfter): array
    {
        return [
            'vehicleKind' => $vehicleKind,
            'serviceType' => $serviceType,
            'coverageCompleteness' => $completeness,
            'sourceUrls' => $sources,
            'verifiedAt' => $sources === [] ? null : '2026-11-19T00:00:00Z',
            'staleAfter' => $staleAfter,
            'rules' => [],
        ];
    }

    /** @return list<array<string, string>> */
    private function csvRows(string $csv): array
    {
        $stream = fopen('php://temp', 'w+b');
        self::assertNotFalse($stream);
        fwrite($stream, $csv);
        rewind($stream);
        $headers = fgetcsv($stream, null, ',', '"', '');
        self::assertIsArray($headers);
        $rows = [];
        while (($values = fgetcsv($stream, null, ',', '"', '')) !== false) {
            if (count($values) === count($headers)) {
                $rows[] = array_combine($headers, $values);
            }
        }
        fclose($stream);

        return $rows;
    }
}
