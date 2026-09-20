<?php

if ($argc !== 2) {
    fwrite(STDERR, "Usage: php create_admin_content_browser_fixtures.php <output-directory>\n");
    exit(2);
}

$directory = $argv[1];
if (! is_dir($directory) && ! mkdir($directory, 0755, true) && ! is_dir($directory)) {
    throw new RuntimeException('Fixture output directory could not be created.');
}

$row = [
    'jurisdiction_id' => 'co-ant-medellin',
    'jurisdiction_name' => 'Medellín',
    'vehicle_kind' => 'car',
    'service_type' => 'private',
    'rule_id' => 'b07-browser-medellin-monday',
    'priority' => '100',
    'effect' => 'restrict',
    'valid_from' => '2026-09-01T00:00:00-05:00',
    'valid_until' => '2026-12-31T23:59:59-05:00',
    'weekdays' => '[1]',
    'date_parity' => '',
    'digit_position' => 'lastNumeric',
    'digits' => '[1,2]',
    'time_windows' => '[{"startMinute":360,"endMinute":1200}]',
    'applies_on_holidays' => 'false',
    'source_url' => 'https://example.test/b07-browser-rules',
    'verified_at' => '2026-09-20T12:00:00Z',
    'stale_after' => '2027-01-15T05:00:00Z',
    'publish' => 'yes',
];

$csvPath = $directory.DIRECTORY_SEPARATOR.'b07-rules.csv';
$stream = fopen($csvPath, 'wb');
fputcsv($stream, array_keys($row), ',', '"', '');
fputcsv($stream, array_values($row), ',', '"', '');
fclose($stream);

$jsonPath = $directory.DIRECTORY_SEPARATOR.'b07-rules.json';
file_put_contents($jsonPath, json_encode([$row], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR));

$xlsxPath = $directory.DIRECTORY_SEPARATOR.'b07-rules.xlsx';
$zip = new ZipArchive;
if ($zip->open($xlsxPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
    throw new RuntimeException('XLSX fixture could not be created.');
}
$zip->addFromString('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
$zip->addFromString('xl/workbook.xml', '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Rules" sheetId="1" r:id="rId1"/></sheets></workbook>');
$zip->addFromString('xl/_rels/workbook.xml.rels', '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
$xmlRows = '';
foreach ([array_keys($row), array_values($row)] as $rowIndex => $cells) {
    $xmlRows .= '<row r="'.($rowIndex + 1).'">';
    foreach ($cells as $columnIndex => $value) {
        $number = $columnIndex + 1;
        $column = '';
        while ($number > 0) {
            $number--;
            $column = chr(65 + ($number % 26)).$column;
            $number = intdiv($number, 26);
        }
        $xmlRows .= '<c r="'.$column.($rowIndex + 1).'" t="inlineStr"><is><t>'.htmlspecialchars((string) $value, ENT_XML1).'</t></is></c>';
    }
    $xmlRows .= '</row>';
}
$zip->addFromString('xl/worksheets/sheet1.xml', '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'.$xmlRows.'</sheetData></worksheet>');
$zip->close();

echo json_encode([
    'csv' => $csvPath,
    'json' => $jsonPath,
    'xlsx' => $xlsxPath,
], JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR).PHP_EOL;
