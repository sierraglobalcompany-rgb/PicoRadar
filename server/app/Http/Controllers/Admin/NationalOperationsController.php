<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\NationalDatasetIntegrityService;
use App\Services\NationalOperationsReadService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

final class NationalOperationsController extends Controller
{
    public function index(
        Request $request,
        NationalOperationsReadService $service,
        NationalDatasetIntegrityService $integrityService,
    ): View
    {
        Gate::authorize('datasets.view');
        Gate::authorize('jurisdictions.view');

        $validated = $request->validate([
            'department' => ['nullable', 'regex:/^\d{2}$/D'],
            'q' => ['nullable', 'string', 'max:100'],
            'state' => ['nullable', 'in:sin_asignar,off,borrador,validado,publicacion_no_confirmada,vencido,sin_evidencia'],
            'per_page' => ['nullable', 'integer', 'in:25,50'],
            'page' => ['nullable', 'integer', 'min:1'],
            'verify_assets' => ['nullable', 'in:1'],
        ]);

        $integrityVerification = $request->query('verify_assets') === '1'
            ? $integrityService->verify()
            : null;

        return view('admin.operations.national', $service->dashboard($validated) + [
            'operator' => $request->user(),
            'integrityVerification' => $integrityVerification,
        ]);
    }
}
