<?php

namespace App\Services;

use DomainException;
use SimpleXMLElement;
use ZipArchive;

final class SafeXlsxReader
{
    private const MAX_ENTRIES = 256;

    private const MAX_UNCOMPRESSED_BYTES = 33_554_432;

    private const MAX_ENTRY_BYTES = 8_388_608;

    private const MAX_SHEETS = 32;

    private const MAX_ROWS = 10_000;

    private const MAX_COLUMNS = 128;

    /** @return array{sheets:list<string>,rows:array<string,list<list<string>>>} */
    public function read(string $path): array
    {
        $zip = new ZipArchive;
        if ($zip->open($path, ZipArchive::RDONLY) !== true) {
            throw new DomainException('The XLSX file is not a readable ZIP archive.');
        }

        try {
            $this->assertArchiveIsSafe($zip);
            $workbook = $this->xml($this->entry($zip, 'xl/workbook.xml'));
            $relationships = $this->relationships($this->xml($this->entry($zip, 'xl/_rels/workbook.xml.rels')));
            $sharedStrings = $zip->locateName('xl/sharedStrings.xml') === false
                ? []
                : $this->sharedStrings($this->xml($this->entry($zip, 'xl/sharedStrings.xml')));
            $sheets = [];
            $rows = [];
            $workbookNamespaces = $workbook->getNamespaces(true);
            foreach ($workbook->xpath('//*[local-name()="sheets"]/*[local-name()="sheet"]') ?: [] as $sheet) {
                $relationAttributes = $sheet->attributes($workbookNamespaces['r'] ?? 'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
                $name = trim((string) $sheet->attributes()['name']);
                $relationId = (string) $relationAttributes['id'];
                $target = $relationships[$relationId] ?? throw new DomainException('A worksheet relationship is missing.');
                $sheetPath = $this->worksheetPath($target);
                $sheets[] = $name;
                $rows[$name] = $this->worksheet($this->xml($this->entry($zip, $sheetPath)), $sharedStrings);
            }
            if ($sheets === [] || count($sheets) > self::MAX_SHEETS) {
                throw new DomainException('The workbook has an invalid number of worksheets.');
            }

            return ['sheets' => $sheets, 'rows' => $rows];
        } finally {
            $zip->close();
        }
    }

    private function assertArchiveIsSafe(ZipArchive $zip): void
    {
        if ($zip->numFiles < 1 || $zip->numFiles > self::MAX_ENTRIES) {
            throw new DomainException('The XLSX archive contains too many entries.');
        }
        $total = 0;
        for ($index = 0; $index < $zip->numFiles; $index++) {
            $stat = $zip->statIndex($index);
            if (! is_array($stat)) {
                throw new DomainException('The XLSX archive contains an unreadable entry.');
            }
            $name = str_replace('\\', '/', (string) $stat['name']);
            if (str_starts_with($name, '/') || preg_match('#(?:^|/)\.\.(?:/|$)#', $name)) {
                throw new DomainException('The XLSX archive contains an unsafe path.');
            }
            if (preg_match('#(?:vbaProject\.bin|xl/externalLinks/|xl/connections\.xml|xl/queryTables/)#i', $name)) {
                throw new DomainException('Macros are not permitted in XLSX imports.');
            }
            $size = (int) ($stat['size'] ?? 0);
            if ($size > self::MAX_ENTRY_BYTES) {
                throw new DomainException('An XLSX entry exceeds the size limit.');
            }
            $total += $size;
            if ($total > self::MAX_UNCOMPRESSED_BYTES) {
                throw new DomainException('The XLSX uncompressed size limit was exceeded.');
            }
        }
    }

    /** @return array<string,string> */
    private function relationships(SimpleXMLElement $xml): array
    {
        $relationships = [];
        foreach ($xml->xpath('//*[local-name()="Relationship"]') ?: [] as $relationship) {
            if (strcasecmp((string) $relationship['TargetMode'], 'External') === 0) {
                throw new DomainException('External workbook relationships are not permitted.');
            }
            $relationships[(string) $relationship['Id']] = (string) $relationship['Target'];
        }

        return $relationships;
    }

    private function worksheetPath(string $target): string
    {
        $target = str_replace('\\', '/', $target);
        $target = str_starts_with($target, '/') ? ltrim($target, '/') : 'xl/'.ltrim($target, '/');
        if (! preg_match('#^xl/worksheets/[A-Za-z0-9_.-]+\.xml$#', $target)) {
            throw new DomainException('The workbook contains an unsafe worksheet target.');
        }

        return $target;
    }

    /** @return list<string> */
    private function sharedStrings(SimpleXMLElement $xml): array
    {
        $values = [];
        foreach ($xml->xpath('//*[local-name()="si"]') ?: [] as $item) {
            $values[] = $this->richText($item);
            if (count($values) > 100_000) {
                throw new DomainException('The XLSX shared string limit was exceeded.');
            }
        }

        return $values;
    }

    /** @param list<string> $sharedStrings @return list<list<string>> */
    private function worksheet(SimpleXMLElement $xml, array $sharedStrings): array
    {
        $rows = [];
        foreach ($xml->xpath('//*[local-name()="sheetData"]/*[local-name()="row"]') ?: [] as $row) {
            if (count($rows) >= self::MAX_ROWS) {
                throw new DomainException('The XLSX row limit was exceeded.');
            }
            $values = [];
            foreach ($row->xpath('./*[local-name()="c"]') ?: [] as $cell) {
                $column = $this->columnNumber((string) $cell['r']);
                if ($column > self::MAX_COLUMNS) {
                    throw new DomainException('The XLSX column limit was exceeded.');
                }
                while (count($values) < $column - 1) {
                    $values[] = '';
                }
                $type = (string) $cell['t'];
                $valueNode = ($cell->xpath('./*[local-name()="v"]') ?: [null])[0];
                $inlineNode = ($cell->xpath('./*[local-name()="is"]') ?: [null])[0];
                $value = match ($type) {
                    's' => $sharedStrings[(int) $valueNode] ?? '',
                    'inlineStr' => $inlineNode instanceof SimpleXMLElement ? $this->richText($inlineNode) : '',
                    'b' => (string) $valueNode === '1' ? 'true' : 'false',
                    default => (string) $valueNode,
                };
                $values[] = $value;
            }
            $rows[] = $values;
        }

        return $rows;
    }

    private function richText(SimpleXMLElement $node): string
    {
        $text = '';
        foreach ($node->xpath('.//*[local-name()="t"]') ?: [] as $textNode) {
            $text .= (string) $textNode;
        }

        return $text;
    }

    private function columnNumber(string $reference): int
    {
        if (! preg_match('/^([A-Z]+)\d+$/i', $reference, $matches)) {
            throw new DomainException('The XLSX cell reference is invalid.');
        }
        $number = 0;
        foreach (str_split(strtoupper($matches[1])) as $letter) {
            $number = ($number * 26) + ord($letter) - 64;
        }

        return $number;
    }

    private function entry(ZipArchive $zip, string $name): string
    {
        $contents = $zip->getFromName($name);
        if (! is_string($contents)) {
            throw new DomainException("The XLSX entry $name is missing.");
        }

        return $contents;
    }

    private function xml(string $contents): SimpleXMLElement
    {
        if (preg_match('/<!DOCTYPE|<!ENTITY/i', $contents)) {
            throw new DomainException('DTD and entity declarations are not permitted in XLSX imports.');
        }
        $previous = libxml_use_internal_errors(true);
        try {
            $xml = simplexml_load_string($contents, SimpleXMLElement::class, LIBXML_NONET | LIBXML_NOBLANKS);
            if (! $xml instanceof SimpleXMLElement) {
                throw new DomainException('The XLSX file contains malformed XML.');
            }

            return $xml;
        } finally {
            libxml_clear_errors();
            libxml_use_internal_errors($previous);
        }
    }
}
