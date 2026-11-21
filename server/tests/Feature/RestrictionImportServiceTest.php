<?php

namespace Tests\Feature;

use App\Enums\OperatorRole;
use App\Enums\RestrictionImportStatus;
use App\Models\Dataset;
use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\RestrictionRuleVersion;
use App\Models\User;
use App\Services\RestrictionImportService;
use DomainException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use ZipArchive;

class RestrictionImportServiceTest extends TestCase
{
    use RefreshDatabase;

    private User $actor;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('local');
        $this->actor = User::factory()->create(['role' => OperatorRole::Editor]);
        Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $this->jurisdiction();
    }

    public function test_json_contract_is_analyzed_idempotently_and_confirmed_as_a_draft(): void
    {
        $json = json_encode(['schemaVersion' => 1, 'datasetKey' => 'restrictions', 'version' => 'synthetic-import', 'generatedAt' => '2026-09-20T12:00:00Z', 'jurisdictions' => [$this->payload()]], JSON_THROW_ON_ERROR);
        $path = $this->temporaryFile($json);
        $service = app(RestrictionImportService::class);

        $import = $service->analyze($path, 'synthetic.json', 'json', null, $this->actor);
        $same = $service->analyze($path, 'renamed.json', 'json', null, $this->actor);

        $this->assertTrue($import->is($same));
        $this->assertSame([1, 1, 0, 0], [$import->row_count, $import->valid_count, $import->invalid_count, $import->excluded_count]);
        Storage::disk('local')->assertExists($import->private_path);

        $versions = $service->confirm($import, $import->rows()->pluck('id')->all(), $this->actor);
        $this->assertCount(1, $versions);
        $this->assertSame($this->payload(), $versions[0]->payload);
        $this->assertSame(RestrictionImportStatus::Confirmed, $import->fresh()->status);
    }

    public function test_csv_and_xlsx_rows_use_the_same_real_contract_mapping(): void
    {
        $header = array_keys($this->flatRow());
        $csv = implode(',', $header)."\n".implode(',', array_map(fn (string $value): string => $this->csv($value), array_values($this->flatRow())))."\n";
        $service = app(RestrictionImportService::class);

        $csvImport = $service->analyze($this->temporaryFile($csv), 'synthetic.csv', 'csv', null, $this->actor);
        $xlsxImport = $service->analyze($this->xlsx($header, array_values($this->flatRow())), 'synthetic.xlsx', 'xlsx', 'Rules', $this->actor);

        $this->assertSame(1, $csvImport->valid_count);
        $this->assertSame(1, $xlsxImport->valid_count);
        $this->assertSame($csvImport->rows()->first()->normalized, $xlsxImport->rows()->first()->normalized);
    }

    public function test_invalid_or_excluded_rows_are_never_confirmed(): void
    {
        $excluded = $this->flatRow();
        $excluded['publish'] = 'no';
        $invalid = $this->flatRow();
        $invalid['source_url'] = 'http://unsafe.test/rules';
        $json = json_encode([$excluded, $invalid], JSON_THROW_ON_ERROR);
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile($json), 'rows.json', 'json', null, $this->actor);

        $this->assertSame([0, 1, 1], [$import->valid_count, $import->invalid_count, $import->excluded_count]);
        $this->expectException(DomainException::class);
        app(RestrictionImportService::class)->confirm($import, $import->rows()->pluck('id')->all(), $this->actor);
    }

    public function test_confirmation_is_atomic_when_two_rows_for_the_same_city_conflict(): void
    {
        $first = $this->flatRow();
        $second = $first;
        $second['rule_id'] = 'synthetic-rule-2';
        $second['effect'] = 'allow';
        $import = app(RestrictionImportService::class)->analyze($this->temporaryFile(json_encode([$first, $second], JSON_THROW_ON_ERROR)), 'conflict.json', 'json', null, $this->actor);

        $this->expectException(DomainException::class);
        try {
            app(RestrictionImportService::class)->confirm($import, $import->rows()->pluck('id')->all(), $this->actor);
        } finally {
            $this->assertSame(0, RestrictionRuleVersion::query()->count());
        }
    }

    /** @return array<string,string> */
    private function flatRow(): array
    {
        return [
            'jurisdiction_id' => 'co-test-synthetic', 'jurisdiction_name' => 'Ciudad sintética',
            'vehicle_kind' => 'car', 'service_type' => 'private', 'rule_id' => 'synthetic-rule-1',
            'priority' => '100', 'effect' => 'restrict', 'valid_from' => '2026-09-01T00:00:00-05:00',
            'valid_until' => '2026-12-31T23:59:59-05:00', 'weekdays' => '[1]', 'date_parity' => '',
            'digit_position' => 'lastNumeric', 'digits' => '[1,2]',
            'time_windows' => '[{"startMinute":360,"endMinute":1200}]', 'applies_on_holidays' => 'false',
            'source_url' => 'https://example.test/synthetic-rules', 'verified_at' => '2026-09-01T05:00:00Z',
            'stale_after' => '2027-01-15T05:00:00Z', 'publish' => 'yes',
        ];
    }

    /** @return array<string,mixed> */
    private function payload(): array
    {
        return [
            'id' => 'co-test-synthetic', 'name' => 'Ciudad sintética',
            'coverages' => [[
                'vehicleKind' => 'car', 'serviceType' => 'private', 'verifiedAt' => '2026-09-01T05:00:00Z',
                'staleAfter' => '2027-01-15T05:00:00Z', 'sourceUrls' => ['https://example.test/synthetic-rules'],
                'rules' => [[
                    'id' => 'synthetic-rule-1', 'priority' => 100, 'effect' => 'restrict',
                    'validFrom' => '2026-09-01T00:00:00-05:00', 'validUntil' => '2026-12-31T23:59:59-05:00',
                    'weekdays' => [1], 'digitPosition' => 'lastNumeric', 'digits' => [1, 2],
                    'timeWindows' => [['startMinute' => 360, 'endMinute' => 1200]],
                    'appliesOnHolidays' => false, 'sourceUrl' => 'https://example.test/synthetic-rules',
                    'verifiedAt' => '2026-09-01T05:00:00Z',
                ]],
            ]],
        ];
    }

    private function jurisdiction(): void
    {
        $country = GeographicUnit::query()->create(['key' => 'co', 'level' => 'country', 'code' => 'CO', 'name' => 'Colombia', 'normalized_name' => 'colombia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $department = GeographicUnit::query()->create(['parent_id' => $country->id, 'key' => 'co-05', 'level' => 'department', 'code' => '05', 'name' => 'Antioquia', 'normalized_name' => 'antioquia', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        $municipality = GeographicUnit::query()->create(['parent_id' => $department->id, 'key' => 'co-05001', 'level' => 'municipality', 'code' => '05001', 'name' => 'Ciudad sintética', 'normalized_name' => 'ciudad sintetica', 'is_active' => true, 'source_system' => 'synthetic', 'source_version' => 'v1']);
        Jurisdiction::query()->create(['key' => 'co-test-synthetic', 'name' => 'Ciudad sintética', 'kind' => 'city', 'primary_geographic_unit_id' => $municipality->id, 'enabled' => true, 'timezone' => 'America/Bogota']);
    }

    private function temporaryFile(string $contents): string
    {
        $path = tempnam(sys_get_temp_dir(), 'restriction-import-');
        file_put_contents($path, $contents);

        return $path;
    }

    private function csv(string $value): string
    {
        return '"'.str_replace('"', '""', $value).'"';
    }

    /** @param list<string> $header @param list<string> $row */
    private function xlsx(array $header, array $row): string
    {
        $path = tempnam(sys_get_temp_dir(), 'restriction-xlsx-');
        $zip = new ZipArchive;
        $zip->open($path, ZipArchive::OVERWRITE);
        $zip->addFromString('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
        $zip->addFromString('xl/workbook.xml', '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Rules" sheetId="1" r:id="rId1"/></sheets></workbook>');
        $zip->addFromString('xl/_rels/workbook.xml.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
        $rows = [$header, $row];
        $xmlRows = '';
        foreach ($rows as $rowIndex => $cells) {
            $xmlRows .= '<row r="'.($rowIndex + 1).'">';
            foreach ($cells as $column => $value) {
                $reference = $this->column($column + 1).($rowIndex + 1);
                $xmlRows .= '<c r="'.$reference.'" t="inlineStr"><is><t>'.htmlspecialchars($value, ENT_XML1).'</t></is></c>';
            }
            $xmlRows .= '</row>';
        }
        $zip->addFromString('xl/worksheets/sheet1.xml', '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'.$xmlRows.'</sheetData></worksheet>');
        $zip->close();

        return $path;
    }

    private function column(int $number): string
    {
        $result = '';
        while ($number > 0) {
            $number--;
            $result = chr(65 + ($number % 26)).$result;
            $number = intdiv($number, 26);
        }

        return $result;
    }
}
