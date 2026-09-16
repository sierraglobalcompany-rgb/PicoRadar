<?php

namespace Tests\Fixtures;

final class TaxCalendarPayload
{
    public static function valid(string $version = '2026.09.13-test'): array
    {
        return [
            'schemaVersion' => 1,
            'datasetKey' => 'tax_calendars',
            'version' => $version,
            'generatedAt' => '2026-09-13T12:00:00Z',
            'authorities' => [[
                'id' => 'bogota',
                'territoryCode' => '11',
                'territoryName' => 'Bogota D. C.',
                'name' => 'Fixture authority',
                'institutionalUrl' => 'https://hacienda.example.org/',
                'portalUrl' => 'https://portal.example.org/vehiculos',
                'sourceUrls' => ['https://hacienda.example.org/portal-oficial'],
                'reviewedAt' => '2026-09-12T10:00:00-05:00',
            ]],
            'calendars' => [[
                'id' => 'bogota-2026-vehicle-tax',
                'authorityId' => 'bogota',
                'year' => 2026,
                'obligationKind' => 'vehicle_tax',
                'status' => 'partial',
                'reviewedAt' => '2026-09-12T10:00:00-05:00',
                'reviewAfter' => '2026-10-01T00:00:00Z',
                'sourceUrls' => ['https://hacienda.example.org/resolucion-2026'],
                'events' => [[
                    'id' => 'ordinary',
                    'date' => '2026-10-30',
                    'label' => 'Fixture ordinary deadline',
                    'kind' => 'ordinary',
                    'condition' => null,
                    'status' => 'active',
                    'supersededBy' => null,
                    'sourceUrls' => ['https://hacienda.example.org/resolucion-2026'],
                ]],
            ]],
        ];
    }
}
