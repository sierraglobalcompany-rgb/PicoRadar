<?php

namespace App\Http\Controllers\Admin;

use App\Enums\CampaignStatus;
use App\Enums\CampaignScope;
use App\Enums\GeographicUnitLevel;
use App\Enums\SponsorStatus;
use App\Http\Controllers\Controller;
use App\Models\Campaign;
use App\Models\GeographicUnit;
use App\Models\Sponsor;
use App\Services\CampaignAccess;
use App\Services\CampaignPlanningService;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class CampaignPlanningController extends Controller
{
    private const TIMEZONE = 'America/Bogota';

    public function index(Request $request, CampaignAccess $access, CampaignPlanningService $planning): View
    {
        $access->authorizeView($request->user());
        $today = CarbonImmutable::now(self::TIMEZONE)->startOfDay();
        $filters = array_replace([
            'from' => $today->format('Y-m-d'),
            'until' => $today->addDays(30)->format('Y-m-d'),
            'placement' => (string) config('campaigns.placement'),
            'status' => null,
            'sponsor_id' => null,
            'department_id' => null,
            'municipality_id' => null,
            'simulation_at' => CarbonImmutable::now(self::TIMEZONE)->format('Y-m-d\\TH:i'),
            'per_page' => '25',
        ], $request->query());

        $validator = Validator::make($filters, [
            'from' => ['required', 'date_format:Y-m-d'],
            'until' => ['required', 'date_format:Y-m-d'],
            'placement' => ['required', Rule::in([(string) config('campaigns.placement')])],
            'status' => ['nullable', Rule::enum(CampaignStatus::class)],
            'sponsor_id' => ['nullable', 'integer', 'exists:sponsors,id'],
            'department_id' => [
                'nullable', 'integer',
                Rule::exists('geographic_units', 'id')->where('level', GeographicUnitLevel::Department->value)->where('is_active', true),
            ],
            'municipality_id' => [
                'nullable', 'integer',
                Rule::exists('geographic_units', 'id')->where('level', GeographicUnitLevel::Municipality->value)->where('is_active', true),
            ],
            'simulation_at' => ['required', 'date_format:Y-m-d\\TH:i'],
            'per_page' => ['required', Rule::in(['25', '50', 25, 50])],
        ]);
        $validator->after(function ($validator) use ($filters): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }
            $from = CarbonImmutable::createFromFormat('!Y-m-d', (string) $filters['from'], self::TIMEZONE);
            $until = CarbonImmutable::createFromFormat('!Y-m-d', (string) $filters['until'], self::TIMEZONE);
            $simulationAt = CarbonImmutable::createFromFormat('Y-m-d\\TH:i', (string) $filters['simulation_at'], self::TIMEZONE);

            if ($until->getTimestamp() <= $from->getTimestamp()) {
                $validator->errors()->add('until', 'La fecha final es exclusiva y debe ser posterior a la inicial.');

                return;
            }
            if (($until->getTimestamp() - $from->getTimestamp()) > 90 * 86400) {
                $validator->errors()->add('until', 'El intervalo de consulta no puede superar 90 días.');
            }
            if ($simulationAt->getTimestamp() < $from->getTimestamp() || $simulationAt->getTimestamp() >= $until->getTimestamp()) {
                $validator->errors()->add('simulation_at', 'El instante T debe estar dentro del intervalo [desde, hasta).');
            }

            if (! empty($filters['department_id']) && ! empty($filters['municipality_id'])) {
                $belongs = GeographicUnit::query()
                    ->whereKey((int) $filters['municipality_id'])
                    ->where('parent_id', (int) $filters['department_id'])
                    ->exists();
                if (! $belongs) {
                    $validator->errors()->add('municipality_id', 'El municipio debe pertenecer al departamento seleccionado.');
                }
            }
        });
        $filters = $validator->validate();

        $from = CarbonImmutable::createFromFormat('!Y-m-d', $filters['from'], self::TIMEZONE)->setTimezone(config('app.timezone'));
        $until = CarbonImmutable::createFromFormat('!Y-m-d', $filters['until'], self::TIMEZONE)->setTimezone(config('app.timezone'));
        $at = CarbonImmutable::createFromFormat('Y-m-d\\TH:i', $filters['simulation_at'], self::TIMEZONE)->setTimezone(config('app.timezone'));
        $department = isset($filters['department_id']) ? GeographicUnit::query()->find((int) $filters['department_id']) : null;
        $municipality = isset($filters['municipality_id']) ? GeographicUnit::query()->with('parent')->find((int) $filters['municipality_id']) : null;
        $territoryDepartment = $municipality?->parent ?? $department;

        $agendaQuery = $this->campaignsInWindow($from, $until, $department, $municipality, $filters, true);
        $campaigns = (clone $agendaQuery)
            ->with(['sponsor', 'geographicUnit.parent'])
            ->orderBy('priority')
            ->orderBy('public_id')
            ->paginate((int) $filters['per_page'])
            ->withQueryString();

        $simulationCampaigns = Campaign::query()
            ->where('placement', $filters['placement'])
            ->where(function (Builder $query) use ($from, $until, $at): void {
                $query->where(function (Builder $window) use ($from, $until): void {
                    $window->where('starts_at', '<', $until)
                        ->where('ends_at', '>', $from);
                })->orWhere(function (Builder $candidate) use ($at): void {
                    $candidate->where('status', CampaignStatus::Active->value)
                        ->where('ends_at', '>', $at)
                        ->whereHas('sponsor', fn (Builder $sponsor) => $sponsor->where('status', SponsorStatus::Active->value));
                });
            })
            ->when(! empty($filters['sponsor_id']), fn (Builder $query) => $query->where('sponsor_id', (int) $filters['sponsor_id']))
            ->with(['sponsor', 'geographicUnit.parent'])
            ->orderBy('priority')
            ->orderBy('public_id')
            ->get();
        $simulation = $simulationCampaigns->map(fn (Campaign $campaign): array => [
            'campaign' => $campaign,
            'projection' => $planning->project($campaign, $at, $territoryDepartment, $municipality, (string) $filters['placement']),
        ]);

        $overlapFilters = $filters;
        $overlapFilters['sponsor_id'] = null;
        $overlapCandidates = $this->campaignsInWindow($from, $until, null, null, $overlapFilters, false)
            ->with(['geographicUnit.parent'])
            ->get();
        $overlapCounts = $campaigns->getCollection()->mapWithKeys(fn (Campaign $campaign): array => [
            $campaign->id => $planning->overlapCount($campaign, $overlapCandidates),
        ]);

        $departmentId = $department?->id;
        $departments = GeographicUnit::query()
            ->where('level', GeographicUnitLevel::Department->value)
            ->where('is_active', true)->orderBy('name')->get(['id', 'code', 'name']);
        $municipalities = GeographicUnit::query()
            ->where('level', GeographicUnitLevel::Municipality->value)
            ->where('is_active', true)
            ->when($departmentId, fn (Builder $query) => $query->where('parent_id', $departmentId))
            ->orderBy('name')->get(['id', 'parent_id', 'code', 'name']);

        return view('admin.campaigns.planning', [
            'operator' => $request->user(),
            'campaigns' => $campaigns,
            'simulation' => $simulation,
            'overlapCounts' => $overlapCounts,
            'filters' => $filters,
            'departments' => $departments,
            'municipalities' => $municipalities,
            'sponsors' => Sponsor::query()->orderBy('name')->get(['id', 'name', 'status']),
            'statuses' => CampaignStatus::cases(),
            'simulationAt' => $at,
            'localFrom' => $from->setTimezone(self::TIMEZONE),
            'localUntil' => $until->setTimezone(self::TIMEZONE),
            'deliveryState' => config('campaigns.public_catalog_enabled') !== true || config('datasets.features.ads') !== true
                ? 'PUBLICIDAD OFF / SOLO SIMULACIÓN'
                : 'DIFUSIÓN NO CERTIFICADA',
        ]);
    }

    /** @param array<string, mixed> $filters */
    private function campaignsInWindow(
        CarbonImmutable $from,
        CarbonImmutable $until,
        ?GeographicUnit $department,
        ?GeographicUnit $municipality,
        array $filters,
        bool $includeStatus,
    ): Builder {
        $query = Campaign::query()
            ->where('placement', $filters['placement'])
            ->where('starts_at', '<', $until)
            ->where('ends_at', '>', $from);

        if ($includeStatus && ! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }
        if (! empty($filters['sponsor_id'])) {
            $query->where('sponsor_id', (int) $filters['sponsor_id']);
        }
        if ($municipality) {
            $query->where(function (Builder $territory) use ($municipality): void {
                $territory->where('scope', CampaignScope::National->value)
                    ->orWhere(fn (Builder $query) => $query->where('scope', CampaignScope::Department->value)->where('geographic_unit_id', $municipality->parent_id))
                    ->orWhere(fn (Builder $query) => $query->where('scope', CampaignScope::Municipality->value)->where('geographic_unit_id', $municipality->id));
            });
        } elseif ($department) {
            $query->where(function (Builder $territory) use ($department): void {
                $territory->where('scope', CampaignScope::National->value)
                    ->orWhere(fn (Builder $query) => $query->where('scope', CampaignScope::Department->value)->where('geographic_unit_id', $department->id))
                    ->orWhere(fn (Builder $query) => $query->where('scope', CampaignScope::Municipality->value)
                        ->whereHas('geographicUnit', fn (Builder $unit) => $unit->where('parent_id', $department->id)));
            });
        }

        return $query;
    }
}
