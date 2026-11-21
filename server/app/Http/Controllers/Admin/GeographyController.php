<?php

namespace App\Http\Controllers\Admin;

use App\Enums\GeographicUnitLevel;
use App\Http\Controllers\Controller;
use App\Models\GeographicUnit;
use App\Support\GeographicNameNormalizer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class GeographyController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('geography.view');
        $query = GeographicUnit::query()->with('parent')->orderBy('code');
        if ($search = trim((string) $request->query('q'))) {
            $normalized = GeographicNameNormalizer::normalize($search);
            $query->where(function ($builder) use ($normalized, $search): void {
                $builder->where('normalized_name', 'like', "%$normalized%")
                    ->orWhere('code', 'like', "%$search%");
            });
        }
        if ($level = $request->query('level')) {
            $query->where('level', $level);
        }
        if ($department = $request->integer('department')) {
            $query->where('parent_id', $department);
        }

        return view('admin.geography.index', [
            'operator' => $request->user(),
            'units' => $query->paginate(50)->withQueryString(),
            'departments' => GeographicUnit::query()->where('level', GeographicUnitLevel::Department)->orderBy('name')->get(),
            'levels' => GeographicUnitLevel::cases(),
        ]);
    }
}
