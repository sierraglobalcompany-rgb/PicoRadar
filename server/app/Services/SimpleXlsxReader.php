<?php

namespace App\Services;

use DomainException;
use ZipArchive;

class SimpleXlsxReader
{
    private const XMLNS = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

    /** @return list<array<string, string|null>> */
    public function rows(string $path): array
    {
        $zip = new ZipArchive;
        if ($zip->open($path) !== true) {
            throw new DomainException('ANSV XLSX source could not be opened.');
        }

        $sharedStrings = $this->sharedStrings($zip);
        $sheet = $zip->getFromName('xl/worksheets/sheet1.xml');
        if ($sheet === false) {
            $zip->close();
            throw new DomainException('ANSV XLSX source has no first worksheet.');
        }

        $xml = simplexml_load_string($sheet);
        if ($xml === false) {
            $zip->close();
            throw new DomainException('ANSV XLSX worksheet is not readable XML.');
        }
        $xml->registerXPathNamespace('x', self::XMLNS);
        $headers = [];
        $rows = [];

        foreach ($xml->children(self::XMLNS)->sheetData->children(self::XMLNS)->row as $row) {
            $cells = [];
            foreach ($row->children(self::XMLNS)->c as $cell) {
                $ref = (string) $cell->attributes()['r'];
                $index = $this->columnIndex($ref);
                $cells[$index] = $this->cellValue($cell, $sharedStrings);
            }
            if ($headers === []) {
                $headers = $cells;
                ksort($headers);
                $headers = array_values($headers);

                continue;
            }
            $mapped = [];
            foreach ($headers as $index => $header) {
                $mapped[$header] = $cells[$index] ?? null;
            }
            $rows[] = $mapped;
        }
        $zip->close();

        return $rows;
    }

    /** @return list<string> */
    public function headers(string $path): array
    {
        $rows = $this->rows($path);
        if ($rows === []) {
            return [];
        }

        return array_keys($rows[0]);
    }

    /** @return list<string> */
    private function sharedStrings(ZipArchive $zip): array
    {
        $raw = $zip->getFromName('xl/sharedStrings.xml');
        if ($raw === false) {
            return [];
        }
        $strings = [];
        preg_match_all('/<si\b[^>]*>(.*?)<\/si>/su', $raw, $items);
        foreach ($items[1] ?? [] as $item) {
            preg_match_all('/<t\b[^>]*>(.*?)<\/t>/su', $item, $matches);
            $strings[] = html_entity_decode(implode('', $matches[1] ?? []), ENT_QUOTES | ENT_XML1, 'UTF-8');
        }

        return $strings;
    }

    private function cellValue(\SimpleXMLElement $cell, array $sharedStrings): ?string
    {
        $children = $cell->children(self::XMLNS);
        $value = isset($children->v) ? (string) $children->v : null;
        if ($value === null) {
            return null;
        }
        if ((string) $cell->attributes()['t'] === 's') {
            return $sharedStrings[(int) $value] ?? null;
        }

        return $value;
    }

    private function columnIndex(string $cellRef): int
    {
        preg_match('/^([A-Z]+)/', $cellRef, $matches);
        $letters = $matches[1] ?? 'A';
        $index = 0;
        foreach (str_split($letters) as $letter) {
            $index = ($index * 26) + (ord($letter) - 64);
        }

        return $index - 1;
    }
}
