<?php

namespace App\Http\Controllers\Admin;

use App\Enums\RestrictionImportStatus;
use App\Enums\RestrictionRuleVersionStatus;
use App\Http\Controllers\Controller;
use App\Models\Jurisdiction;
use App\Models\RestrictionImport;
use App\Models\RestrictionPublication;
use App\Models\RestrictionRuleVersion;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class DashboardController extends Controller
{
    public function __invoke(Request $request): View
    {
        $contentStats = null;
        $recentJurisdictions = collect();
        if (Gate::allows('datasets.view')) {
            $contentStats = [
                'activeJurisdictions' => Jurisdiction::query()->where('enabled', true)->count(),
                'drafts' => RestrictionRuleVersion::query()->where('status', RestrictionRuleVersionStatus::Draft)->count(),
                'validated' => RestrictionRuleVersion::query()->where('status', RestrictionRuleVersionStatus::Validated)->count(),
                'pendingImports' => RestrictionImport::query()->where('status', RestrictionImportStatus::Analyzed)->count(),
                'publications' => RestrictionPublication::query()->count(),
            ];
            $recentJurisdictions = Jurisdiction::query()
                ->withCount('restrictionRuleVersions')
                ->latest('updated_at')
                ->limit(5)
                ->get();
        }

        return view('admin.dashboard', [
            'operator' => $request->user(),
            'contentStats' => $contentStats,
            'recentJurisdictions' => $recentJurisdictions,
        ]);
    }
}
