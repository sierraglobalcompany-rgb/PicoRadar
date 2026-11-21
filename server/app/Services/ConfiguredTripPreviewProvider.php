<?php

namespace App\Services;

use App\Contracts\TripPreviewProvider;
use DomainException;

final class ConfiguredTripPreviewProvider implements TripPreviewProvider
{
    public function __construct(
        private readonly TollGuruTripPreview $tollGuru,
        private readonly PrivateOsrmTripPreview $privateOsrm,
    ) {}

    public function preview(array $request): array
    {
        return match (config('trips.provider', 'tollguru')) {
            'tollguru' => $this->tollGuru->preview($request),
            'private_osrm' => $this->privateOsrm->preview($request),
            default => throw new DomainException('not_configured'),
        };
    }
}
