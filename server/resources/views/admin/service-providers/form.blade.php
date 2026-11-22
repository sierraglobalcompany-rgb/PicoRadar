@extends('layouts.admin', ['title' => ($provider->exists ? 'Editar proveedor' : 'Agregar proveedor').' | PicoRadar'])

@section('content')
    <div class="max-w-3xl">
        <a class="text-sm font-medium text-teal-800 underline" href="{{ route('admin.service-providers.index') }}">← Directorio</a>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight">{{ $provider->exists ? 'Editar proveedor' : 'Agregar proveedor' }}</h1>
        <p class="mt-2 text-slate-600">La ficha publicada aparece en el directorio tras una revisión editorial. Patrocinio no concede señal oficial o acreditación.</p>
    </div>

    <form class="mt-6 max-w-3xl space-y-5 rounded-lg border border-slate-200 bg-white p-5" method="POST" action="{{ $provider->exists ? route('admin.service-providers.update', $provider) : route('admin.service-providers.store') }}">
        @csrf
        @if($provider->exists) @method('PUT') @endif

        @if($errors->any())
            <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-sm text-rose-900" role="alert"><p class="font-semibold">Revisa estos datos:</p><ul class="mt-1 list-inside list-disc">@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>
        @endif

        <div class="grid gap-4 sm:grid-cols-2">
            <label class="text-sm font-medium">Categoría
                <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="category" required>
                    <option value="">Selecciona una categoría</option>
                    @foreach($categories as $category)<option value="{{ $category }}" @selected(old('category', $provider->category) === $category)>{{ match($category) {'cda' => 'CDA', 'soat' => 'SOAT', 'workshop' => 'Taller', 'tow' => 'Grúa', default => 'Aliado'} }}</option>@endforeach
                </select>
            </label>
            <label class="text-sm font-medium">Estado editorial
                <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="status" required>
                    @foreach($statuses as $status)
                        @if($status !== 'published' || auth()->user()?->can('service_providers.publish'))
                            <option value="{{ $status }}" @selected(old('status', $provider->status) === $status)>{{ match($status) {'draft' => 'Borrador', 'published' => 'Publicado', default => 'Deshabilitado'} }}</option>
                        @endif
                    @endforeach
                </select>
            </label>
            <label class="text-sm font-medium">Departamento
                <select id="department-code" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="department_code" required>
                    <option value="">Selecciona un departamento</option>
                    @foreach($departments as $department)<option value="{{ $department->code }}" @selected(old('department_code', $provider->department_code) === $department->code)>{{ $department->name }} · {{ $department->code }}</option>@endforeach
                </select>
            </label>
            <label class="text-sm font-medium">Municipio · DIVIPOLA
                <select id="municipality-code" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="municipality_code" required>
                    <option value="">Selecciona un municipio</option>
                    @foreach($municipalities as $municipality)<option value="{{ $municipality->code }}" data-department="{{ $municipality->parent?->code }}" @selected(old('municipality_code', $provider->municipality_code) === $municipality->code)>{{ $municipality->name }} · {{ $municipality->code }}</option>@endforeach
                </select>
            </label>
            <label class="text-sm font-medium sm:col-span-2">Nombre del proveedor
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="name" maxlength="160" value="{{ old('name', $provider->name) }}" required>
            </label>
            <label class="text-sm font-medium sm:col-span-2">Dirección <span class="font-normal text-slate-500">(opcional)</span>
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="address" maxlength="1000" value="{{ old('address', $provider->address) }}">
            </label>
            <label class="text-sm font-medium">Latitud <span class="font-normal text-slate-500">(opcional)</span>
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="number" step="any" min="-90" max="90" name="latitude" value="{{ old('latitude', $provider->latitude) }}">
            </label>
            <label class="text-sm font-medium">Longitud <span class="font-normal text-slate-500">(opcional)</span>
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="number" step="any" min="-180" max="180" name="longitude" value="{{ old('longitude', $provider->longitude) }}">
            </label>
            <label class="text-sm font-medium sm:col-span-2">URL de la fuente <span class="font-normal text-slate-500">(HTTPS; necesaria para publicar)</span>
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="url" inputmode="url" name="source_url" value="{{ old('source_url', $provider->source_url) }}">
            </label>
            <label class="text-sm font-medium">Última revisión de la fuente
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="verified_at" value="{{ old('verified_at', $provider->verified_at?->format('Y-m-d\TH:i')) }}">
            </label>
            <label class="text-sm font-medium">Vigente hasta <span class="font-normal text-slate-500">(requerida para publicar)</span>
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="date" name="valid_until" value="{{ old('valid_until', $provider->valid_until?->format('Y-m-d')) }}">
            </label>
            <label class="text-sm font-medium sm:col-span-2">Contacto <span class="font-normal text-slate-500">(HTTPS, teléfono o correo)</span>
                <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="contact_url" value="{{ old('contact_url', $provider->contact_url) }}" placeholder="https://… · tel:+57… · mailto:…">
            </label>
        </div>

        <div class="flex flex-wrap gap-3 border-t border-slate-100 pt-4">
            <button class="min-h-12 rounded-md bg-teal-700 px-5 font-semibold text-white">Guardar ficha</button>
            <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-5" href="{{ route('admin.service-providers.index') }}">Cancelar</a>
        </div>
    </form>

    <script>
        (() => {
            const department = document.getElementById('department-code');
            const municipality = document.getElementById('municipality-code');
            const options = [...municipality.options];
            const filterMunicipalities = () => {
                for (const option of options) {
                    if (!option.value) continue;
                    option.hidden = department.value !== '' && option.dataset.department !== department.value;
                    if (option.hidden && option.selected) municipality.value = '';
                }
            };
            department.addEventListener('change', filterMunicipalities);
            filterMunicipalities();
        })();
    </script>
@endsection
