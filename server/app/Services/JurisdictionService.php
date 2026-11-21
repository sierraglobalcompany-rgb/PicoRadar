<?php

namespace App\Services;

use App\Enums\GeographicUnitLevel;
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
            $this->assertMunicipalityId((int) ($attributes['primary_geographic_unit_id'] ?? 0));
            $jurisdiction = Jurisdiction::query()->create($attributes);
            $this->syncCoverage($jurisdiction, $coverageIds, $actor, $jurisdiction->primary_geographic_unit_id);
            $this->audit->log($actor, 'jurisdiction.created', $jurisdiction, ['jurisdictionKey' => $jurisdiction->key]);

            return $jurisdiction->refresh();
        });
    }

    /** @param array<string, mixed> $attributes */
    public function update(Jurisdiction $jurisdiction, array $attributes, ?User $actor = null): Jurisdiction
    {
        return DB::transaction(function () use ($jurisdiction, $attributes, $actor): Jurisdiction {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            $primaryId = (int) ($attributes['primary_geographic_unit_id'] ?? $locked->primary_geographic_unit_id);
            $coverageIds = $locked->geographicUnits()->pluck('geographic_unit_id')->all();
            if (! in_array($primaryId, $coverageIds, true)) {
                $coverageIds[] = $primaryId;
            }

            return $this->syncLocked($locked, $attributes, $coverageIds, $actor);
        });
    }

    public function attachCoverage(Jurisdiction $jurisdiction, GeographicUnit $unit, ?User $actor = null): void
    {
        DB::transaction(function () use ($jurisdiction, $unit, $actor): void {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            $this->assertMunicipality($unit);
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
            if ($locked->geographicUnits()->detach($unit->id) !== 1) {
                throw new DomainException('Coverage mapping does not exist.');
            }
            $this->assertPrimaryCovered($locked);
            $this->audit->log($actor, 'jurisdiction.coverage_detached', $locked, ['jurisdictionKey' => $locked->key, 'geographicUnitCode' => $unit->code]);
        });
    }

    /** @param list<int> $coverageIds */
    public function setCoverage(Jurisdiction $jurisdiction, array $coverageIds, ?User $actor = null): void
    {
        DB::transaction(function () use ($jurisdiction, $coverageIds, $actor): void {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);
            $this->syncCoverage($locked, $coverageIds, $actor, $locked->primary_geographic_unit_id);
        });
    }

    /** @param array<string, mixed> $attributes @param list<int> $coverageIds */
    public function syncFromCanonicalMapping(Jurisdiction $jurisdiction, array $attributes, array $coverageIds, ?User $actor = null): Jurisdiction
    {
        return DB::transaction(function () use ($jurisdiction, $attributes, $coverageIds, $actor): Jurisdiction {
            $locked = Jurisdiction::query()->lockForUpdate()->findOrFail($jurisdiction->id);

            return $this->syncLocked($locked, $attributes, $coverageIds, $actor);
        });
    }

    /** @param array<string, mixed> $attributes @param list<int> $coverageIds */
    private function syncLocked(Jurisdiction $jurisdiction, array $attributes, array $coverageIds, ?User $actor): Jurisdiction
    {
        $primaryId = (int) ($attributes['primary_geographic_unit_id'] ?? $jurisdiction->primary_geographic_unit_id);
        $this->assertMunicipalityId($primaryId);
        $coverageIds = $this->validatedCoverageIds($coverageIds, $primaryId);
        $existing = array_map('intval', $jurisdiction->geographicUnits()->pluck('geographic_unit_id')->all());
        $this->attachMappings($jurisdiction, array_values(array_diff($coverageIds, $existing)), $actor);

        $jurisdiction->fill($attributes);
        if ($jurisdiction->isDirty()) {
            $jurisdiction->save();
            $this->audit->log($actor, 'jurisdiction.updated', $jurisdiction, ['jurisdictionKey' => $jurisdiction->key]);
        }
        $this->detachMappings($jurisdiction, array_values(array_diff($existing, $coverageIds)), $actor);
        $this->assertPrimaryCovered($jurisdiction);

        return $jurisdiction->refresh();
    }

    /** @param list<int> $coverageIds */
    private function syncCoverage(Jurisdiction $jurisdiction, array $coverageIds, ?User $actor, int $primaryId): void
    {
        $coverageIds = $this->validatedCoverageIds($coverageIds, $primaryId);
        $existing = array_map('intval', $jurisdiction->geographicUnits()->pluck('geographic_unit_id')->all());
        $toAttach = array_values(array_diff($coverageIds, $existing));
        $toDetach = array_values(array_diff($existing, $coverageIds));
        $this->attachMappings($jurisdiction, $toAttach, $actor);
        $this->detachMappings($jurisdiction, $toDetach, $actor);
        if ($jurisdiction->primary_geographic_unit_id === $primaryId) {
            $this->assertPrimaryCovered($jurisdiction);
        }
    }

    /** @param list<int> $coverageIds @return list<int> */
    private function validatedCoverageIds(array $coverageIds, int $primaryId): array
    {
        $coverageIds = array_values(array_unique(array_map('intval', $coverageIds)));
        if (! in_array($primaryId, $coverageIds, true)) {
            throw new DomainException('Jurisdiction coverage must include the primary geographic unit.');
        }
        $units = GeographicUnit::query()->whereIn('id', $coverageIds)->get()->keyBy('id');
        if ($units->count() !== count($coverageIds)) {
            throw new DomainException('Jurisdiction coverage references unknown geography.');
        }
        foreach ($units as $unit) {
            $this->assertMunicipality($unit);
        }

        return $coverageIds;
    }

    private function assertMunicipalityId(int $id): void
    {
        $unit = GeographicUnit::query()->find($id);
        if (! $unit) {
            throw new DomainException('Jurisdiction primary geography is unknown.');
        }
        $this->assertMunicipality($unit);
    }

    private function assertMunicipality(GeographicUnit $unit): void
    {
        if ($unit->level !== GeographicUnitLevel::Municipality) {
            throw new DomainException('Jurisdiction coverage must contain municipalities only.');
        }
    }

    /** @param list<int> $unitIds */
    private function attachMappings(Jurisdiction $jurisdiction, array $unitIds, ?User $actor): void
    {
        foreach ($unitIds as $unitId) {
            $jurisdiction->geographicUnits()->attach($unitId);
            $this->audit->log($actor, 'jurisdiction.coverage_attached', $jurisdiction, ['jurisdictionKey' => $jurisdiction->key, 'geographicUnitId' => $unitId]);
        }
    }

    /** @param list<int> $unitIds */
    private function detachMappings(Jurisdiction $jurisdiction, array $unitIds, ?User $actor): void
    {
        foreach ($unitIds as $unitId) {
            if ($jurisdiction->geographicUnits()->detach($unitId) === 1) {
                $this->audit->log($actor, 'jurisdiction.coverage_detached', $jurisdiction, ['jurisdictionKey' => $jurisdiction->key, 'geographicUnitId' => $unitId]);
            }
        }
    }

    private function assertPrimaryCovered(Jurisdiction $jurisdiction): void
    {
        if (! $jurisdiction->geographicUnits()->whereKey($jurisdiction->primary_geographic_unit_id)->exists()) {
            throw new DomainException('Jurisdiction coverage must include the primary geographic unit.');
        }
    }
}
