<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ServiceProviderImport;
use App\Models\User;
use App\Services\ServiceProviderBulkImportService;
use DomainException;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class ServiceProviderImportController extends Controller
{
    public function create(): View
    {
        Gate::authorize('service_providers.edit');

        return view('admin.service-providers.import');
    }

    public function analyze(Request $request, ServiceProviderBulkImportService $service): RedirectResponse
    {
        Gate::authorize('service_providers.edit');
        $file = $request->validate([
            'file' => ['required', 'file', 'max:'.(int) config('datasets.max_upload_kb')],
        ])['file'];
        $format = strtolower($file->getClientOriginalExtension());
        if (! in_array($format, ['csv', 'xlsx'], true)) {
            throw ValidationException::withMessages(['file' => 'Selecciona un archivo CSV o XLSX.']);
        }

        try {
            $import = $service->analyze($file->getPathname(), $file->getClientOriginalName(), $format, $this->actor($request));
        } catch (DomainException $error) {
            throw ValidationException::withMessages(['file' => $error->getMessage()]);
        }

        return to_route('admin.service-providers.imports.review', $import)
            ->with('status', 'Análisis listo. No se modificó ninguna ficha de proveedor.');
    }

    public function review(ServiceProviderImport $serviceProviderImport): View
    {
        Gate::authorize('service_providers.edit');

        return view('admin.service-providers.import-review', [
            'import' => $serviceProviderImport,
            'rows' => $serviceProviderImport->rows()->orderBy('row_number')->paginate(100)->withQueryString(),
        ]);
    }

    public function confirm(Request $request, ServiceProviderImport $serviceProviderImport, ServiceProviderBulkImportService $service): RedirectResponse
    {
        Gate::authorize('service_providers.edit');
        $rowIds = $request->validate([
            'row_ids' => ['required', 'array', 'min:1'],
            'row_ids.*' => ['required', 'integer', 'min:1'],
        ])['row_ids'];

        try {
            $summary = $service->confirm($serviceProviderImport, $rowIds, $this->actor($request));
        } catch (DomainException $error) {
            throw ValidationException::withMessages(['row_ids' => $error->getMessage()]);
        }

        return to_route('admin.service-providers.imports.review', $serviceProviderImport)
            ->with('status', "Confirmado: {$summary['created']} nuevos, {$summary['updated']} borradores actualizados y {$summary['unchanged']} sin cambios.");
    }

    private function actor(Request $request): User
    {
        $actor = $request->user();
        abort_unless($actor instanceof User, 403);

        return $actor;
    }
}