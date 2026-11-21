<?php

namespace App\Services;

use App\Enums\SponsorStatus;
use App\Models\Sponsor;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SponsorService
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    /** @param array<string, mixed> $data */
    public function create(array $data, User $actor): Sponsor
    {
        return DB::transaction(function () use ($data, $actor): Sponsor {
            $sponsor = Sponsor::query()->create($data + [
                'public_id' => 'sp_'.strtolower((string) Str::ulid()),
                'status' => SponsorStatus::Active,
                'created_by_id' => $actor->id,
                'updated_by_id' => $actor->id,
            ]);
            $this->audit->log($actor, 'sponsor.created', $sponsor, $this->metadata($sponsor));

            return $sponsor;
        });
    }

    /** @param array<string, mixed> $data */
    public function update(Sponsor $sponsor, array $data, User $actor): Sponsor
    {
        return DB::transaction(function () use ($sponsor, $data, $actor): Sponsor {
            $current = Sponsor::query()->lockForUpdate()->findOrFail($sponsor->id);
            if ($current->status === SponsorStatus::Archived) {
                throw new DomainException('Archived sponsors cannot be edited.');
            }
            $current->fill($data);
            $current->updated_by_id = $actor->id;
            $current->save();
            $this->audit->log($actor, 'sponsor.updated', $current, $this->metadata($current));

            return $current->refresh();
        });
    }

    public function archive(Sponsor $sponsor, User $actor): Sponsor
    {
        return DB::transaction(function () use ($sponsor, $actor): Sponsor {
            $current = Sponsor::query()->lockForUpdate()->findOrFail($sponsor->id);
            if ($current->status === SponsorStatus::Archived) {
                return $current;
            }
            if ($current->campaigns()->whereNot('status', 'archived')->exists()) {
                throw new DomainException('Archive or reassign sponsor campaigns first.');
            }
            $current->forceFill([
                'status' => SponsorStatus::Archived,
                'archived_at' => now(),
                'archived_by_id' => $actor->id,
                'updated_by_id' => $actor->id,
            ])->save();
            $this->audit->log($actor, 'sponsor.archived', $current, $this->metadata($current));

            return $current;
        });
    }

    /** @return array<string, mixed> */
    private function metadata(Sponsor $sponsor): array
    {
        return ['sponsorId' => $sponsor->public_id, 'status' => $sponsor->status->value];
    }
}
