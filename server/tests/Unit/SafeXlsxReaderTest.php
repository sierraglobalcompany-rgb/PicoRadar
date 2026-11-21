<?php

namespace Tests\Unit;

use App\Services\SafeXlsxReader;
use DomainException;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;
use ZipArchive;

class SafeXlsxReaderTest extends TestCase
{
    public function test_it_reads_cached_values_without_evaluating_formulas(): void
    {
        $path = $this->xlsx([
            'xl/sharedStrings.xml' => $this->sharedStrings(['jurisdiction_id', 'co-test', 'priority']),
            'xl/worksheets/sheet1.xml' => $this->worksheet(
                '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>2</v></c></row>'.
                '<row r="2"><c r="A2" t="s"><v>1</v></c><c r="B2"><f>1+99</f><v>100</v></c></row>',
            ),
        ]);

        $workbook = (new SafeXlsxReader)->read($path);

        $this->assertSame(['Rules'], $workbook['sheets']);
        $this->assertSame([
            ['jurisdiction_id', 'priority'],
            ['co-test', '100'],
        ], $workbook['rows']['Rules']);
    }

    #[DataProvider('unsafeWorkbookProvider')]
    public function test_it_rejects_unsafe_workbook_features(array $extra, string $message): void
    {
        $path = $this->xlsx($extra);

        $this->expectException(DomainException::class);
        $this->expectExceptionMessage($message);

        (new SafeXlsxReader)->read($path);
    }

    public static function unsafeWorkbookProvider(): array
    {
        return [
            'macro' => [['xl/vbaProject.bin' => 'not-a-macro'], 'Macros are not permitted'],
            'external relationship' => [[
                'xl/_rels/workbook.xml.rels' => '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId9" Type="x" Target="https://example.test/data" TargetMode="External"/></Relationships>',
            ], 'External workbook relationships are not permitted'],
            'doctype' => [[
                'xl/worksheets/sheet1.xml' => '<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>',
            ], 'DTD and entity declarations are not permitted'],
        ];
    }

    /** @param array<string,string> $overrides */
    private function xlsx(array $overrides): string
    {
        $path = tempnam(sys_get_temp_dir(), 'restriction-xlsx-');
        $zip = new ZipArchive;
        $zip->open($path, ZipArchive::OVERWRITE);
        $entries = [
            '[Content_Types].xml' => '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
            'xl/workbook.xml' => '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Rules" sheetId="1" r:id="rId1"/></sheets></workbook>',
            'xl/_rels/workbook.xml.rels' => '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
            'xl/worksheets/sheet1.xml' => $this->worksheet('<row r="1"><c r="A1" t="inlineStr"><is><t>empty</t></is></c></row>'),
        ];
        foreach (array_replace($entries, $overrides) as $name => $contents) {
            $zip->addFromString($name, $contents);
        }
        $zip->close();

        return $path;
    }

    private function worksheet(string $rows): string
    {
        return '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'.$rows.'</sheetData></worksheet>';
    }

    /** @param list<string> $values */
    private function sharedStrings(array $values): string
    {
        return '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'.implode('', array_map(fn (string $value): string => '<si><t>'.$value.'</t></si>', $values)).'</sst>';
    }
}
