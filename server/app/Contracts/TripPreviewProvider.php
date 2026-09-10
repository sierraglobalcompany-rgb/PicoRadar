<?php

namespace App\Contracts;

interface TripPreviewProvider
{
    public function preview(array $request): array;
}
