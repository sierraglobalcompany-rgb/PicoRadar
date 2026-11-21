<?php

namespace App\Support;

final class GeographicNameNormalizer
{
    public static function normalize(string $value): string
    {
        $normalized = mb_strtolower(trim($value));
        $normalized = strtr($normalized, [
            'á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ü' => 'u', 'ñ' => 'n',
        ]);
        $normalized = str_replace(',', '', $normalized);

        return trim((string) preg_replace('/\s+/u', ' ', $normalized));
    }
}
