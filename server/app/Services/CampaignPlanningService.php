<?php

namespace App\Services;

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\SponsorStatus;
use App\Models\Campaign;
use App\Models\GeographicUnit;
use Carbon\CarbonImmutable;

/** Read-only projections for the campaign planning screen. */
class CampaignPlanningService
{
    /** @return array<string, bool|string|null> */
    public function project(
        Campaign $campaign,
        CarbonImmutable $at,
        ?GeographicUnit $department,
        ?GeographicUnit $municipality,
        string $placement,
    ): array
    {
        $operationalStatus = $campaign->operationalStatus($at);
        $sponsorActive = $campaign->sponsor?->status === SponsorStatus::Active;
        $serverReason = match (true) {
            $campaign->status !== CampaignStatus::Active => $campaign->status->value,
            ! $sponsorActive => 'sponsor_inactive',
            $campaign->placement !== $placement => 'other_placement',
            $campaign->ends_at->getTimestamp() <= $at->getTimestamp() => 'expired',
            default => null,
        };
        $serverCandidate = $serverReason === null;

        $mobileReason = match (true) {
            ! $serverCandidate => 'not_in_server_candidate',
            $campaign->starts_at->getTimestamp() > $at->getTimestamp() => 'scheduled',
            $campaign->scope === CampaignScope::Municipality && $municipality === null => 'municipality_required',
            $campaign->scope === CampaignScope::Department && $department === null && $municipality === null => 'municipality_required',
            ! $this->matchesTerritory($campaign, $department, $municipality) => 'outside_territory',
            default => null,
        };
        $mobileEligible = $mobileReason === null;
        $imageReadyMetadata = $campaign->public_image_path !== null
            && preg_match('/^[a-f0-9]{64}$/i', (string) $campaign->image_sha256) === 1
            && str_starts_with((string) $campaign->image_mime, 'image/');

        $target = parse_url((string) $campaign->cta_url);
        $targetUrlSafe = is_array($target)
            && ($target['scheme'] ?? null) === 'https'
            && ! empty($target['host'])
            && ! array_key_exists('user', $target)
            && ! array_key_exists('pass', $target);

        return [
            'operational_status' => $operationalStatus,
            'server_candidate' => $serverCandidate,
            'server_reason' => $serverReason,
            'mobile_eligible' => $mobileEligible,
            'mobile_reason' => $mobileReason,
            'image_metadata_ready' => $imageReadyMetadata,
            'target_url_safe' => $targetUrlSafe,
        ];
    }

    /** @param iterable<Campaign> $candidates */
    public function overlapCount(Campaign $campaign, iterable $candidates): int
    {
        if ($campaign->status === CampaignStatus::Archived) {
            return 0;
        }
        $count = 0;
        foreach ($candidates as $candidate) {
            if ($candidate->is($campaign) || $candidate->status === CampaignStatus::Archived || $candidate->placement !== $campaign->placement) {
                continue;
            }
            if ($campaign->starts_at->getTimestamp() >= $candidate->ends_at->getTimestamp()
                || $candidate->starts_at->getTimestamp() >= $campaign->ends_at->getTimestamp()) {
                continue;
            }
            if ($this->territoriesOverlap($campaign, $candidate)) {
                $count++;
            }
        }

        return $count;
    }

    private function matchesTerritory(Campaign $campaign, ?GeographicUnit $department, ?GeographicUnit $municipality): bool
    {
        return match ($campaign->scope) {
            CampaignScope::National => true,
            CampaignScope::Department => $this->sameUnit($campaign->geographicUnit, $municipality?->parent ?? $department),
            CampaignScope::Municipality => $municipality !== null && $this->sameUnit($campaign->geographicUnit, $municipality),
        };
    }

    private function territoriesOverlap(Campaign $left, Campaign $right): bool
    {
        if ($left->scope === CampaignScope::National || $right->scope === CampaignScope::National) {
            return true;
        }

        if ($left->scope === CampaignScope::Department && $right->scope === CampaignScope::Department) {
            return $this->sameUnit($left->geographicUnit, $right->geographicUnit);
        }
        if ($left->scope === CampaignScope::Municipality && $right->scope === CampaignScope::Municipality) {
            return $this->sameUnit($left->geographicUnit, $right->geographicUnit);
        }

        $department = $left->scope === CampaignScope::Department ? $left : $right;
        $municipal = $left->scope === CampaignScope::Municipality ? $left : $right;

        return $this->sameUnit($department->geographicUnit, $municipal->geographicUnit?->parent);
    }

    private function sameUnit(?GeographicUnit $left, ?GeographicUnit $right): bool
    {
        return $left !== null && $right !== null
            && ($left->code === $right->code || $left->key === $right->key);
    }
}
