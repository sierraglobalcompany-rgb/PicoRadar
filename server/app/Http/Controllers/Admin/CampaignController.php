<?php

namespace App\Http\Controllers\Admin;

use App\Enums\CampaignStatus;
use App\Enums\GeographicUnitLevel;
use App\Enums\SponsorStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\CampaignRequest;
use App\Models\Campaign;
use App\Models\GeographicUnit;
use App\Models\Sponsor;
use App\Services\CampaignAccess;
use App\Services\CampaignService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class CampaignController extends Controller
{
    public function index(Request $request, CampaignAccess $access): View
    {
        $access->authorizeView($request->user());
        $campaigns = Campaign::query()->with(['sponsor', 'geographicUnit']);
        if ($request->filled('status')) {
            $campaigns->where('status', $request->string('status')->toString());
        }

        return view('admin.campaigns.index', [
            'operator' => $request->user(),
            'campaigns' => $campaigns->orderBy('priority')->latest()->paginate(50)->withQueryString(),
        ]);
    }

    public function create(Request $request, CampaignAccess $access): View
    {
        $access->authorizeEdit($request->user());

        return view('admin.campaigns.form', $this->formData($request, new Campaign, route('admin.campaigns.store'), 'POST'));
    }

    public function store(CampaignRequest $request, CampaignService $service): RedirectResponse
    {
        $campaign = $service->create($request->safe()->except('image'), $request->file('image'), $request->user());

        return redirect()->route('admin.campaigns.show', $campaign)->with('status', 'Campana creada como borrador.');
    }

    public function show(Request $request, Campaign $campaign, CampaignAccess $access): View
    {
        $access->authorizeView($request->user());
        $campaign->load(['sponsor', 'geographicUnit']);

        return view('admin.campaigns.show', compact('campaign') + ['operator' => $request->user()]);
    }

    public function edit(Request $request, Campaign $campaign, CampaignAccess $access): View
    {
        $access->authorizeEdit($request->user());

        return view('admin.campaigns.form', $this->formData($request, $campaign, route('admin.campaigns.update', $campaign), 'PUT'));
    }

    public function update(CampaignRequest $request, Campaign $campaign, CampaignService $service): RedirectResponse
    {
        $service->update($campaign, $request->safe()->except('image'), $request->file('image'), $request->user());

        return redirect()->route('admin.campaigns.show', $campaign)->with('status', 'Campana actualizada.');
    }

    public function duplicate(Request $request, Campaign $campaign, CampaignService $service, CampaignAccess $access): RedirectResponse
    {
        $access->authorizeEdit($request->user());
        $copy = $service->duplicate($campaign, $request->user());

        return redirect()->route('admin.campaigns.edit', $copy)->with('status', 'Copia creada como borrador.');
    }

    public function preview(Request $request, Campaign $campaign, CampaignAccess $access): View
    {
        $access->authorizeView($request->user());
        $campaign->load(['sponsor', 'geographicUnit']);

        return view('admin.campaigns.preview', compact('campaign') + ['operator' => $request->user()]);
    }

    public function image(Request $request, Campaign $campaign, CampaignAccess $access): Response
    {
        $access->authorizeView($request->user());
        $disk = Storage::disk(config('campaigns.private_disk'));
        abort_unless($disk->exists($campaign->source_image_path), 404);

        return response($disk->get($campaign->source_image_path), 200, [
            'Cache-Control' => 'no-store, private',
            'Content-Type' => $campaign->image_mime,
            'Content-Disposition' => 'inline; filename="campaign-preview"',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function activate(Request $request, Campaign $campaign, CampaignService $service, CampaignAccess $access): RedirectResponse
    {
        $access->authorizePublish($request->user());
        $service->activate($campaign, $request->user());

        return redirect()->route('admin.campaigns.show', $campaign)->with('status', 'Campana activada y catalogo publicado.');
    }

    public function pause(Request $request, Campaign $campaign, CampaignService $service, CampaignAccess $access): RedirectResponse
    {
        $access->authorizePublish($request->user());
        $service->pause($campaign, $request->user());

        return redirect()->route('admin.campaigns.show', $campaign)->with('status', 'Campana pausada y catalogo actualizado.');
    }

    public function archive(Request $request, Campaign $campaign, CampaignService $service, CampaignAccess $access): RedirectResponse
    {
        $access->authorizePublish($request->user());
        $service->archive($campaign, $request->user());

        return redirect()->route('admin.campaigns.index')->with('status', 'Campana archivada.');
    }

    /** @return array<string, mixed> */
    private function formData(Request $request, Campaign $campaign, string $action, string $method): array
    {
        return [
            'operator' => $request->user(),
            'campaign' => $campaign,
            'action' => $action,
            'method' => $method,
            'sponsors' => Sponsor::query()->where('status', SponsorStatus::Active->value)->orderBy('name')->get(),
            'geographicUnits' => GeographicUnit::query()
                ->whereIn('level', [GeographicUnitLevel::Department->value, GeographicUnitLevel::Municipality->value])
                ->where('is_active', true)
                ->orderBy('name')
                ->get(),
            'statuses' => CampaignStatus::cases(),
        ];
    }
}
