<?php

declare(strict_types=1);

namespace Tests\Unit;

use App\Services\CameraCsvParser;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

final class CameraCsvParserTest extends TestCase
{
    public function test_bom_multiline_comma_and_municipal_leading_zeros(): void
    {
        $csv = "\xEF\xBB\xBFexternal_id,municipality_code,lat,lon,type,name,notes\r\n".
            "A,05001,6.2518,-75.5636,speed,\"Prueba, sintética\",\"Línea 1\nLínea 2\"\r\n".
            "B,05001,6.2571,-75.5781,other,,\r\n";
        $parsed = $this->parseCsv($csv);
        self::assertSame(2, $parsed['valid_count']);
        self::assertSame(0, $parsed['invalid_count']);
        self::assertSame('05001', $parsed['rows'][0]['values']['municipality_code']);
        self::assertSame('6.2518000', $parsed['rows'][0]['values']['lat']);
        self::assertSame('Prueba, sintética', $parsed['rows'][0]['values']['name']);
        self::assertSame("Línea 1\nLínea 2", $parsed['rows'][0]['values']['notes']);
        self::assertArrayNotHasKey('name', $parsed['rows'][1]['values']);
    }

    public function test_header_only_or_blank_rows_are_rejected(): void
    {
        foreach ([
            "external_id,municipality_code,lat,lon,type\n",
            "external_id,municipality_code,lat,lon,type\n\n\n",
        ] as $emptyCsv) {
            $this->expectInvalid($emptyCsv);
        }
    }

    public function test_row_error_reporting_and_valid_types(): void
    {
        $data = $this->parseCsv("external_id,municipality_code,lat,lon,type,bearing,speed_limit\n".
            "A,05001,NaN,-75,speed,40,50\n".
            "B,05001,6,-75,laser,40,50\n".
            "C,05001,6,-75,speed,360,0\n".
            "D,05001,6,-75,speed,20,60\n");
        self::assertSame(1, $data['valid_count']);
        self::assertSame(3, $data['invalid_count']);
        self::assertSame(20, $data['rows'][3]['values']['bearing']);
        self::assertSame(60, $data['rows'][3]['values']['speed_limit']);
    }

    public function test_invalid_row_width_does_not_shift_columns(): void
    {
        $data = $this->parseCsv("external_id,municipality_code,lat,lon,type\nA,05001,6,-75\n");
        self::assertSame(1, $data['invalid_count']);
        self::assertSame([], $data['rows'][0]['values']);
    }

    public function test_unknown_duplicate_missing_and_lifecycle_columns_rejected(): void
    {
        foreach ([
            "external_id,municipality_code,lat,lon,type,type\n",
            "external_id,municipality_code,lat,lon,type,status\n",
            "external_id,lat,lon,type\n",
            "external_id,municipality_code,lat,lon,type,camera_id\n",
        ] as $csv) {
            $this->expectInvalid($csv);
        }
    }

    public function test_malformed_quotes_and_line_endings_rejected(): void
    {
        foreach ([
            "external_id,municipality_code,lat,lon,type\n\"A,05001,6,-75,speed\n",
            "external_id,municipality_code,lat,lon,type\nA\"B,05001,6,-75,speed\n",
            "external_id,municipality_code,lat,lon,type\n\"A\"X,05001,6,-75,speed\n",
            "external_id,municipality_code,lat,lon,type\nA,05001,6,-75,speed\rB,05001,6,-75,speed\n",
        ] as $csv) {
            $this->expectInvalid($csv);
        }
    }

    public function test_bad_utf8_and_control_characters_rejected(): void
    {
        $this->expectInvalid("external_id,municipality_code,lat,lon,type\nA,05001,6,-75,speed\x00\n");
        $this->expectInvalid("external_id,municipality_code,lat,lon,type\nA,05001,6,-75,speed\xFF\n");
    }

    public function test_maximum_rows_and_file_bytes_enforced(): void
    {
        $csv = "external_id,municipality_code,lat,lon,type\n";
        for ($i = 0; $i < 2001; $i++) {
            $csv .= "A-{$i},05001,6,-75,other\n";
        }
        $this->expectInvalid($csv);
        $this->expectInvalid(str_repeat('x', CameraCsvParser::MAX_BYTES + 1));
    }

    public function test_bytes_input_matches_file_input_without_reading_it_twice(): void
    {
        $csv = "external_id,municipality_code,lat,lon,type\n".
            "QA-001,05001,6.2518,-75.5636,other\n";
        $fromBytes = (new CameraCsvParser)->parseBytes($csv);
        self::assertSame($this->parseCsv($csv), $fromBytes);
        self::assertSame(1, $fromBytes['valid_count']);
    }

    public function test_external_id_with_tab_or_newline_is_rejected(): void
    {
        foreach (['QA'.chr(9).'01', 'QA'.chr(10).'01', 'QA'.chr(13).'01'] as $id) {
            $csv = "external_id,municipality_code,lat,lon,type\n".
                '"'.$id.'",05001,6,-75,other'."\n";
            $data = (new CameraCsvParser)->parseBytes($csv);
            self::assertSame(1, $data['invalid_count']);
        }
    }

    public function test_identifiers_with_leading_or_trailing_control_characters_are_invalid(): void
    {
        foreach (["\tQA", "QA\t", "\nQA", "QA\r\n"] as $id) {
            $csv = "external_id,municipality_code,lat,lon,type\n".
                '"'.$id.'",05001,6,-75,other'."\n";
            $analysis = (new CameraCsvParser)->parseBytes($csv);
            self::assertSame(1, $analysis['invalid_count']);
        }
    }

    public function test_external_identity_does_not_silently_normalize_spaces_or_invisible_unicode(): void
    {
        foreach ([
            ' QA-001', 'QA-001 ', "QA\u{200B}-001",
            "\u{202E}QA-001", "QA-001\u{2066}",
        ] as $identity) {
            $csv = "external_id,municipality_code,lat,lon,type\n".
                $identity.",05001,6,-75,other\n";
            $analysis = (new CameraCsvParser)->parseBytes($csv);
            self::assertSame(1, $analysis['invalid_count']);
        }
    }

    public function test_formula_escapes_for_output_only(): void
    {
        foreach (['=SUM(1,2)', '+cmd', '-cmd', '@cmd', " \t=cmd", "\u{200B}=cmd"] as $s) {
            self::assertSame("'".$s, CameraCsvParser::spreadsheetSafe($s));
        }
        self::assertSame('Normal', CameraCsvParser::spreadsheetSafe('Normal'));
    }

    private function expectInvalid(string $csv): void
    {
        try {
            $this->parseCsv($csv);
            self::fail('Expected invalid CSV to fail.');
        } catch (InvalidArgumentException) {
            self::addToAssertionCount(1);
        }
    }

    private function parseCsv(string $csv): array
    {
        $tmp = tempnam(sys_get_temp_dir(), 'picoradar-csv-');
        if ($tmp === false) {
            throw new \RuntimeException('Cannot create CSV test file.');
        }
        try {
            file_put_contents($tmp, $csv);

            return (new CameraCsvParser)->parse($tmp);
        } finally {
            unlink($tmp);
        }
    }
}
