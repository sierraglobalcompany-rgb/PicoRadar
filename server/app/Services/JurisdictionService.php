<?php

namespace App\Services;

use App\Models\GeographicUnit;
use App\Models\Jurisdiction;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;

class JurisdictionService
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    /** @param array<string, mixed> $attributes @param list<int> $coverageIds */
    public function create(array $attributes, array $coverageIds, ?User $actor = null): Jurisdiction
    {
        return DB::transaction(function () use ($attributes, $coverageIds, $actor): Jurisdiction {
            $jurisdiction = Jurisdiction::query()->create($attributes);
            $this->setCoverage($jurisdiction, $coverageIds, $actor, 'jurisdiction.created');

            return $jurisdiction->refresh();
        });
    }

    /** @param array<string, mixed> $attributes */
    public function update(Jurisdiction $jurisdiction, array $attributes, ?User $actor = null): Jurisdiction
    {
        return DB::transaction(function () use ($jurisdiction, $attributes, $actor): Jurisdiction {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            $locked->update($attributes);
            $this->assertPrimaryCovered($locked);
            $this->audit->log($actor, 'jurisdiction.updated', $locked, ['jurisdictionKey' => $locked->key]);

            return $locked->refresh();
        });
    }

    public function attachCoverage(Jurisdiction $jurisdiction, GeographicUnit $unit, ?User $actor = null): void
    {
        DB::transaction(function () use ($jurisdiction, $unit, $actor): void {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            if ($locked->geographicUnits()->whereKey($unit->id)->exists()) {
                throw new DomainException('Coverage mapping already exists.');
            }
            $locked->geographicUnits()->attach($unit->id);
            $this->audit->log($actor, 'jurisdiction.coverage_attached', $locked, ['jurisdictionKey' => $locked->key, 'geographicUnitCode' => $unit->code]);
        });
    }

    public function detachCoverage(Jurisdiction $jurisdiction, GeographicUnit $unit, ?User $actor = null): void
    {
        DB::transaction(function () use ($jurisdiction, $unit, $actor): void {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            if ($locked->primary_geographic_unit_id === $unit->id) {
                throw new DomainException('The primary geographic unit cannot be detached.');
            }
            $locked->geographicUnits()->detach($unit->id);
            $this->assertPrimaryCovered($locked);
            $this->audit->log($actor, 'jurisdiction.coverage_detached', $locked, ['jurisdictionKey' => $locked->key, 'geographicUnitCode' => $unit->code]);
        });
    }

    /** @param list<int> $coverageIds */
    public function setCoverage(Jurisdiction $jurisdiction, array $coverageIds, ?User $actor = null, ?string $creationAction = null): void
    {
        $coverageIds = array_values(array_unique(array_map('intval', $coverageIds)));
        if (! in_array($jurisdiction->primary_geographic_unit_id, $coverageIds, true)) {
            throw new DomainException('Jurisdiction coverage must include the primary geographic unit.');
        }
        $actualCount = GeographicUnit::query()->whereIn('id', $coverageIds)->count();
        if ($actualCount !== count($coverageIds)) {
            throw new DomainException('Jurisdiction coverage references unknown geography.');
        }
        $existing = $jurisdiction->geographicUnits()->pluck('geographic_unit_id')->all();
        foreach (array_diff($coverageIds, $existing) as $unitId) {
            $jurisdiction->geographicUnits()->attach($unitId);
            $this->audit->log($actor, 'jurisdiction.coverage_attached', $jurisdiction, ['jurisdictionKey' => $jurisdiction->key, 'geographicUnitId' => $unitId]);
        }
        $this->assertPrimaryCovered($jurisdiction);
        if ($creationAction) {
            $this->audit->log($actor, $creationAction, $jurisdiction, ['jurisdictionKey' => $jurisdiction->key]);
        }
    }

    private function assertPrimaryCovered(Jurisdiction $jurisdiction): void
    {
        if (! $jurisdiction->geographicUnits()->whereKey($jurisdiction->primary_geographic_unit_id)->exists()) {
            throw new DomainException('Jurisdiction coverage must include the primary geographic unit.');
        }
    }
}
