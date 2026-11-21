<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\SponsorRequest;
use App\Models\Sponsor;
use App\Services\CampaignAccess;
use App\Services\SponsorService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class SponsorController extends Controller
{
    public function index(Request $request, CampaignAccess $access): View
    {
        $access->authorizeView($request->user());

        return view('admin.sponsors.index', [
            'operator' => $request->user(),
            'sponsors' => Sponsor::query()->withCount('campaigns')->latest()->paginate(50),
        ]);
    }

    public function create(Request $request, CampaignAccess $access): View
    {
        $access->authorizeEdit($request->user());

        return view('admin.sponsors.form', [
            'operator' => $request->user(),
            'sponsor' => new Sponsor,
            'action' => route('admin.sponsors.store'),
            'method' => 'POST',
        ]);
    }

    public function store(SponsorRequest $request, SponsorService $service): RedirectResponse
    {
        $sponsor = $service->create($request->validated(), $request->user());

        return redirect()->route('admin.sponsors.show', $sponsor)->with('status', 'Patrocinador creado.');
    }

    public function show(Request $request, Sponsor $sponsor, CampaignAccess $access): View
    {
        $access->authorizeView($request->user());
        $sponsor->load(['campaigns' => fn ($query) => $query->latest()]);

        return view('admin.sponsors.show', compact('sponsor') + ['operator' => $request->user()]);
    }

    public function edit(Request $request, Sponsor $sponsor, CampaignAccess $access): View
    {
        $access->authorizeEdit($request->user());

        return view('admin.sponsors.form', [
            'operator' => $request->user(),
            'sponsor' => $sponsor,
            'action' => route('admin.sponsors.update', $sponsor),
            'method' => 'PUT',
        ]);
    }

    public function update(SponsorRequest $request, Sponsor $sponsor, SponsorService $service): RedirectResponse
    {
        $service->update($sponsor, $request->validated(), $request->user());

        return redirect()->route('admin.sponsors.show', $sponsor)->with('status', 'Patrocinador actualizado.');
    }

    public function archive(Request $request, Sponsor $sponsor, SponsorService $service, CampaignAccess $access): RedirectResponse
    {
        $access->authorizeEdit($request->user());
        $service->archive($sponsor, $request->user());

        return redirect()->route('admin.sponsors.index')->with('status', 'Patrocinador archivado.');
    }
}
