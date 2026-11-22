<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\ServiceProvider;
use App\Models\User;
use App\Services\ServiceProviderCatalogService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ServiceProviderController extends Controller
{
    public function index(Request $request, ServiceProviderCatalogService $catalog): View
    {
        Gate::authorize('service_providers.view');
        $filters = $request->validate([
            'category' => ['nullable', Rule::in(ServiceProvider::CATEGORIES)],
            'status' => ['nullable', Rule::in(ServiceProvider::STATUSES)],
            'department_code' => ['nullable', 'regex:/^\d{2}$/'],
            'municipality_code' => ['nullable', 'regex:/^\d{5}$/'],
        ]);

        return view('admin.service-providers.index', [
            'providers' => $catalog->query($filters)->paginate(30)->withQueryString(),
            'departments' => $catalog->departments(),
            'municipalities' => $catalog->municipalities(),
            'categories' => ServiceProvider::CATEGORIES,
            'statuses' => ServiceProvider::STATUSES,
            'filters' => $filters,
        ]);
    }

    public function create(ServiceProviderCatalogService $catalog): View
    {
        Gate::authorize('service_providers.edit');

        return view('admin.service-providers.form', [
            'provider' => new ServiceProvider(['status' => 'draft']),
            ...$this->formOptions($catalog),
        ]);
    }

    public function store(Request $request, ServiceProviderCatalogService $catalog): RedirectResponse
    {
        $attributes = $this->validatedAttributes($request);
        $this->authorizeStatus($attributes['status']);
        $catalog->create($attributes, $this->actor($request));

        return to_route('admin.service-providers.index')->with('status', 'El proveedor quedó guardado en el catálogo.');
    }

    public function edit(ServiceProvider $serviceProvider, ServiceProviderCatalogService $catalog): View
    {
        Gate::authorize('service_providers.edit');

        return view('admin.service-providers.form', [
            'provider' => $serviceProvider,
            ...$this->formOptions($catalog),
        ]);
    }

    public function update(Request $request, ServiceProvider $serviceProvider, ServiceProviderCatalogService $catalog): RedirectResponse
    {
        $attributes = $this->validatedAttributes($request);
        $this->authorizeStatus($attributes['status']);
        $catalog->update($serviceProvider, $attributes, $this->actor($request));

        return to_route('admin.service-providers.index')->with('status', 'El proveedor quedó actualizado; el historial se conserva.');
    }

    /** @return array<string, mixed> */
    private function formOptions(ServiceProviderCatalogService $catalog): array
    {
        return [
            'departments' => $catalog->departments(),
            'municipalities' => $catalog->municipalities(),
            'categories' => ServiceProvider::CATEGORIES,
            'statuses' => ServiceProvider::STATUSES,
        ];
    }

    /** @return array<string, mixed> */
    private function validatedAttributes(Request $request): array
    {
        $attributes = $request->validate([
            'category' => ['required', Rule::in(ServiceProvider::CATEGORIES)],
            'department_code' => ['required', 'regex:/^\d{2}$/'],
            'municipality_code' => ['required', 'regex:/^\d{5}$/'],
            'name' => ['required', 'string', 'max:160'],
            'address' => ['nullable', 'string', 'max:240'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'source_url' => ['nullable', 'string', 'max:768', 'url', 'regex:/^https:\/\//i'],
            'verified_at' => ['nullable', 'date', 'before_or_equal:now', 'required_if:status,published'],
            'valid_until' => ['nullable', 'date', 'required_if:status,published'],
            'status' => ['required', Rule::in(ServiceProvider::STATUSES)],
            'contact_url' => ['nullable', 'string', 'max:768', function (string $attribute, mixed $value, \Closure $fail): void {
                if ($value === null || $value === '') {
                    return;
                }

                $scheme = strtolower((string) parse_url((string) $value, PHP_URL_SCHEME));
                $valid = $scheme === 'https'
                    ? filter_var($value, FILTER_VALIDATE_URL) !== false
                    : in_array($scheme, ['tel', 'mailto'], true);

                if (! $valid) {
                    $fail('El contacto debe usar HTTPS, teléfono o correo.');
                }
            }],
        ]);

        $hasLatitude = ($attributes['latitude'] ?? null) !== null;
        $hasLongitude = ($attributes['longitude'] ?? null) !== null;
        if ($hasLatitude !== $hasLongitude) {
            throw ValidationException::withMessages(['latitude' => 'Registra latitud y longitud juntas, o deja ambas vacías.']);
        }

        return $attributes;
    }

    private function authorizeStatus(string $status): void
    {
        Gate::authorize('service_providers.edit');

        if ($status === 'published') {
            Gate::authorize('service_providers.publish');
        }
    }

    private function actor(Request $request): User
    {
        $actor = $request->user();
        abort_unless($actor instanceof User, 403);

        return $actor;
    }
}
