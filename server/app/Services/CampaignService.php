<?php

namespace App\Services;

use App\Enums\CampaignScope;
use App\Enums\CampaignStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\SponsorStatus;
use App\Models\Campaign;
use App\Models\GeographicUnit;
use App\Models\Sponsor;
use App\Models\User;
use Carbon\CarbonImmutable;
use DomainException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

class CampaignService
{
    private const CONTENT_FIELDS = [
        'sponsor_id', 'eyebrow', 'title', 'subtitle', 'cta_text', 'cta_url',
        'placement', 'priority', 'scope', 'geographic_unit_id', 'starts_at', 'ends_at',
    ];

    public function __construct(
        private readonly CampaignImageStore $images,
        private readonly CampaignCatalogPublisher $catalog,
        private readonly DatasetAuditLogger $audit,
    ) {}

    /** @param array<string, mixed> $data */
    public function create(array $data, UploadedFile $image, User $actor): Campaign
    {
        $attributes = $this->validatedAttributes($data);
        $publicId = 'cmp_'.strtolower((string) Str::ulid());
        $imageAttributes = $this->images->store($image, $publicId);

        try {
            return DB::transaction(function () use ($attributes, $imageAttributes, $publicId, $actor): Campaign {
                $campaign = Campaign::query()->create($attributes + $imageAttributes + [
                    'public_id' => $publicId,
                    'status' => CampaignStatus::Draft,
                    'content_revision' => 1,
                    'created_by_id' => $actor->id,
                    'updated_by_id' => $actor->id,
                ]);
                $this->audit->log($actor, 'campaign.created', $campaign, $this->metadata($campaign));

                return $campaign;
            });
        } catch (Throwable $exception) {
            Storage::disk(config('campaigns.private_disk'))->delete($imageAttributes['source_image_path']);
            throw $exception;
        }
    }

    /** @param array<string, mixed> $data */
    public function update(Campaign $campaign, array $data, ?UploadedFile $image, User $actor): Campaign
    {
        $currentData = Arr::only($campaign->getAttributes(), self::CONTENT_FIELDS);
        $attributes = $this->validatedAttributes(array_replace($currentData, $data));
        $previousSourcePath = $campaign->source_image_path;
        $imageAttributes = $image ? $this->images->store($image, $campaign->public_id) : [];

        try {
            return DB::transaction(function () use ($campaign, $attributes, $imageAttributes, $actor): Campaign {
                $current = Campaign::query()->lockForUpdate()->findOrFail($campaign->id);
                if (! in_array($current->status, [CampaignStatus::Draft, CampaignStatus::Paused], true)) {
                    throw new DomainException('Only draft or paused campaigns can be edited.');
                }
                $current->fill($attributes + $imageAttributes);
                if ($imageAttributes !== []) {
                    $current->public_image_path = null;
                }
                $current->content_revision++;
                $current->updated_by_id = $actor->id;
                $current->save();
                $this->audit->log($actor, 'campaign.updated', $current, $this->metadata($current));

                return $current->refresh();
            });
        } catch (Throwable $exception) {
            if ($imageAttributes !== [] && $imageAttributes['source_image_path'] !== $previousSourcePath) {
                Storage::disk(config('campaigns.private_disk'))->delete($imageAttributes['source_image_path']);
            }
            throw $exception;
        }
    }

    public function duplicate(Campaign $campaign, User $actor): Campaign
    {
        if ($campaign->status === CampaignStatus::Archived) {
            throw new DomainException('Archived campaigns cannot be duplicated.');
        }
        $publicId = 'cmp_'.strtolower((string) Str::ulid());
        $sourcePath = $this->images->duplicate($campaign->source_image_path, $publicId);

        try {
            return DB::transaction(function () use ($campaign, $actor, $publicId, $sourcePath): Campaign {
                $copy = Campaign::query()->create([
                    ...Arr::only($campaign->getAttributes(), self::CONTENT_FIELDS),
                    'public_id' => $publicId,
                    'status' => CampaignStatus::Draft,
                    'title' => mb_substr($campaign->title, 0, 112).' (copia)',
                    'source_image_path' => $sourcePath,
                    'image_sha256' => $campaign->image_sha256,
                    'image_mime' => $campaign->image_mime,
                    'image_width' => $campaign->image_width,
                    'image_height' => $campaign->image_height,
                    'image_bytes' => $campaign->image_bytes,
                    'content_revision' => 1,
                    'created_by_id' => $actor->id,
                    'updated_by_id' => $actor->id,
                ]);
                $this->audit->log($actor, 'campaign.duplicated', $copy, [
                    ...$this->metadata($copy),
                    'sourceCampaignId' => $campaign->public_id,
                ]);

                return $copy;
            });
        } catch (Throwable $exception) {
            Storage::disk(config('campaigns.private_disk'))->delete($sourcePath);
            throw $exception;
        }
    }

    public function activate(Campaign $campaign, User $actor): Campaign
    {
        if (! in_array($campaign->status, [CampaignStatus::Draft, CampaignStatus::Paused], true)) {
            throw new DomainException('Only draft or paused campaigns can be activated.');
        }
        if ($campaign->sponsor()->first()?->status !== SponsorStatus::Active) {
            throw new DomainException('The campaign sponsor must be active.');
        }
        if ($campaign->ends_at->isPast()) {
            throw new DomainException('Expired campaigns cannot be activated.');
        }
        $publicPath = $this->images->promote($campaign->source_image_path, $campaign->image_sha256, $campaign->image_mime);

        return DB::transaction(function () use ($campaign, $actor, $publicPath): Campaign {
            $current = Campaign::query()->lockForUpdate()->findOrFail($campaign->id);
            if (! in_array($current->status, [CampaignStatus::Draft, CampaignStatus::Paused], true)) {
                throw new DomainException('Campaign state changed before activation.');
            }
            $current->forceFill([
                'status' => CampaignStatus::Active,
                'public_image_path' => $publicPath,
                'activated_at' => now(),
                'activated_by_id' => $actor->id,
                'paused_at' => null,
                'paused_by_id' => null,
                'updated_by_id' => $actor->id,
            ])->save();
            $this->audit->log($actor, 'campaign.activated', $current, $this->metadata($current));
            $this->catalog->publish($actor);

            return $current->refresh();
        });
    }

    public function pause(Campaign $campaign, User $actor): Campaign
    {
        return DB::transaction(function () use ($campaign, $actor): Campaign {
            $current = Campaign::query()->lockForUpdate()->findOrFail($campaign->id);
            if ($current->status !== CampaignStatus::Active) {
                throw new DomainException('Only active campaigns can be paused.');
            }
            $current->forceFill([
                'status' => CampaignStatus::Paused,
                'paused_at' => now(),
                'paused_by_id' => $actor->id,
                'updated_by_id' => $actor->id,
            ])->save();
            $this->audit->log($actor, 'campaign.paused', $current, $this->metadata($current));
            $this->catalog->publish($actor);

            return $current->refresh();
        });
    }

    public function archive(Campaign $campaign, User $actor): Campaign
    {
        return DB::transaction(function () use ($campaign, $actor): Campaign {
            $current = Campaign::query()->lockForUpdate()->findOrFail($campaign->id);
            if ($current->status === CampaignStatus::Archived) {
                return $current;
            }
            $wasActive = $current->status === CampaignStatus::Active;
            $current->forceFill([
                'status' => CampaignStatus::Archived,
                'archived_at' => now(),
                'archived_by_id' => $actor->id,
                'updated_by_id' => $actor->id,
            ])->save();
            $this->audit->log($actor, 'campaign.archived', $current, $this->metadata($current));
            if ($wasActive) {
                $this->catalog->publish($actor);
            }

            return $current->refresh();
        });
    }

    /** @param array<string, mixed> $data @return array<string, mixed> */
    private function validatedAttributes(array $data): array
    {
        $attributes = Arr::only($data, self::CONTENT_FIELDS);
        foreach (['sponsor_id', 'eyebrow', 'title', 'subtitle', 'cta_text', 'cta_url', 'placement', 'priority', 'scope', 'starts_at', 'ends_at'] as $required) {
            if (! array_key_exists($required, $attributes) || $attributes[$required] === '' || $attributes[$required] === null) {
                throw new DomainException("Campaign field {$required} is required.");
            }
        }
        $sponsor = Sponsor::query()->find($attributes['sponsor_id']);
        if (! $sponsor || $sponsor->status !== SponsorStatus::Active) {
            throw new DomainException('Campaign sponsor must exist and be active.');
        }
        if ($attributes['placement'] !== config('campaigns.placement')) {
            throw new DomainException('Campaign placement is not approved.');
        }
        $priority = filter_var($attributes['priority'], FILTER_VALIDATE_INT);
        if ($priority === false || $priority < 0 || $priority > 1000) {
            throw new DomainException('Campaign priority must be between 0 and 1000.');
        }
        foreach (['eyebrow' => 80, 'title' => 120, 'subtitle' => 240, 'cta_text' => 64] as $field => $max) {
            if (mb_strlen((string) $attributes[$field]) > $max) {
                throw new DomainException("Campaign field {$field} is too long.");
            }
        }
        $url = parse_url((string) $attributes['cta_url']);
        if (! is_array($url) || ($url['scheme'] ?? null) !== 'https' || empty($url['host']) || isset($url['user']) || isset($url['pass'])) {
            throw new DomainException('Campaign target must be a credential-free HTTPS URL.');
        }

        $scope = $attributes['scope'] instanceof CampaignScope
            ? $attributes['scope']
            : CampaignScope::tryFrom((string) $attributes['scope']);
        if (! $scope) {
            throw new DomainException('Campaign territory scope is invalid.');
        }
        $unitId = $attributes['geographic_unit_id'] ?? null;
        if ($scope === CampaignScope::National && $unitId !== null) {
            throw new DomainException('National campaigns cannot target one geographic unit.');
        }
        if ($scope !== CampaignScope::National) {
            $unit = GeographicUnit::query()->find($unitId);
            $expectedLevel = $scope === CampaignScope::Department
                ? GeographicUnitLevel::Department
                : GeographicUnitLevel::Municipality;
            if (! $unit || $unit->level !== $expectedLevel || ! $unit->is_active) {
                throw new DomainException('Campaign geographic unit does not match its scope.');
            }
        }

        try {
            $startsAt = CarbonImmutable::parse($attributes['starts_at']);
            $endsAt = CarbonImmutable::parse($attributes['ends_at']);
        } catch (Throwable) {
            throw new DomainException('Campaign validity dates are invalid.');
        }
        if ($endsAt <= $startsAt) {
            throw new DomainException('Campaign end must be after its start.');
        }

        return [
            ...$attributes,
            'priority' => $priority,
            'scope' => $scope,
            'geographic_unit_id' => $unitId,
            'starts_at' => $startsAt,
            'ends_at' => $endsAt,
        ];
    }

    /** @return array<string, mixed> */
    private function metadata(Campaign $campaign): array
    {
        return [
            'campaignId' => $campaign->public_id,
            'sponsorId' => $campaign->sponsor->public_id,
            'status' => $campaign->status->value,
            'revision' => $campaign->content_revision,
        ];
    }
}
