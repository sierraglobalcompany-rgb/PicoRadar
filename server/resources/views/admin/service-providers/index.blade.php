@extends('layouts.admin', ['title' => 'Directorio de servicios | PicoRadar'])

@section('content')
    <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
            <p class="text-sm font-semibold text-teal-700">Catálogo editorial</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight">Directorio de servicios</h1>
            <p class="mt-2 max-w-2xl text-slate-600">Administra CDA, canales SOAT, talleres, grúas y aliados por municipio. La aprobación es editorial: no certifica acreditación ni publica una versión OTA.</p>
        </div>
        @can('service_providers.publish')
            <a class="inline-flex min-h-12 items-center rounded-md border border-teal-700 px-4 py-2 font-medium text-teal-900" href="{{ route('admin.service-providers.publication') }}">Revisar publicación OTA del dataset</a>
        @endcan
        @can('service_providers.edit')
            <a class="inline-flex min-h-12 items-center rounded-md bg-slate-900 px-4 py-2 font-medium text-white" href="{{ route('admin.service-providers.create') }}">Agregar proveedor</a>
        @endcan
    </div>

    <form class="mt-6 grid gap-3 rounded-lg border border-slate-200 bg-white p-4 sm:grid-cols-2 lg:grid-cols-5" method="GET" action="{{ route('admin.service-providers.index') }}" aria-label="Filtrar directorio">
        <label class="text-sm font-medium">Categoría
            <select class="mt-1 min-h-11 w-full rounded-md border border-slate-300 px-3" name="category">
                <option value="">Todas</option>
                @foreach($categories as $category)<option value="{{ $category }}" @selected(($filters['category'] ?? '') === $category)>{{ match($category) {'cda' => 'CDA', 'soat' => 'SOAT', 'workshop' => 'Taller', 'tow' => 'Grúa', default => 'Aliado'} }}</option>@endforeach
            </select>
        </label>
        <label class="text-sm font-medium">Departamento
            <select class="mt-1 min-h-11 w-full rounded-md border border-slate-300 px-3" name="department_code">
                <option value="">Todos</option>
                @foreach($departments as $department)<option value="{{ $department->code }}" @selected(($filters['department_code'] ?? '') === $department->code)>{{ $department->name }}</option>@endforeach
            </select>
        </label>
        <label class="text-sm font-medium">Municipio · DIVIPOLA
            <select class="mt-1 min-h-11 w-full rounded-md border border-slate-300 px-3" name="municipality_code">
                <option value="">Todos</option>
                @foreach($municipalities as $municipality)<option value="{{ $municipality->code }}" @selected(($filters['municipality_code'] ?? '') === $municipality->code)>{{ $municipality->name }} · {{ $municipality->code }}</option>@endforeach
            </select>
        </label>
        <label class="text-sm font-medium">Estado
            <select class="mt-1 min-h-11 w-full rounded-md border border-slate-300 px-3" name="status">
                <option value="">Todos</option>
                @foreach($statuses as $status)<option value="{{ $status }}" @selected(($filters['status'] ?? '') === $status)>{{ match($status) {'draft' => 'Borrador', 'published' => 'Aprobado editorialmente', default => 'Deshabilitado'} }}</option>@endforeach
            </select>
        </label>
        <div class="flex items-end gap-2">
            <button class="min-h-11 rounded-md bg-teal-700 px-4 font-medium text-white">Filtrar</button>
            <a class="inline-flex min-h-11 items-center rounded-md border border-slate-300 px-4" href="{{ route('admin.service-providers.index') }}">Limpiar</a>
        </div>
    </form>

    <div class="mt-5 overflow-x-auto rounded-lg border border-slate-200 bg-white">
        <table class="w-full min-w-[760px] text-left text-sm">
            <thead class="bg-slate-100 text-slate-700"><tr><th class="p-3">Proveedor</th><th class="p-3">Categoría</th><th class="p-3">Municipio</th><th class="p-3">Estado</th><th class="p-3">Fuente revisada</th><th class="p-3"><span class="sr-only">Acciones</span></th></tr></thead>
            <tbody>
                @forelse($providers as $provider)
                    <tr class="border-t border-slate-100">
                        <td class="p-3"><span class="font-medium">{{ $provider->name }}</span>@if($provider->address)<span class="mt-1 block text-slate-500">{{ $provider->address }}</span>@endif</td>
                        <td class="p-3">{{ match($provider->category) {'cda' => 'CDA', 'soat' => 'SOAT', 'workshop' => 'Taller', 'tow' => 'Grúa', default => 'Aliado'} }}</td>
                        <td class="p-3">{{ $provider->municipality?->name ?? $provider->municipality_code }} · {{ $provider->department?->name ?? $provider->department_code }}</td>
                        <td class="p-3">{{ match($provider->status) {'draft' => 'Borrador', 'published' => 'Aprobado editorialmente', default => 'Deshabilitado'} }}</td>
                        <td class="p-3">@if($provider->hasCurrentSourceEvidence())<a class="text-teal-800 underline" href="{{ $provider->source_url }}" target="_blank" rel="noopener noreferrer">Revisada · {{ $provider->verified_at?->format('Y-m-d') }}</a>@else<span class="text-slate-500">Sin confirmar</span>@endif</td>
                        <td class="p-3">@can('service_providers.edit')<a class="font-medium text-teal-800 underline" href="{{ route('admin.service-providers.edit', $provider) }}">Editar</a>@endcan</td>
                    </tr>
                @empty
                    <tr><td class="p-5 text-slate-600" colspan="6">No hay proveedores para estos filtros. No se agregan datos automáticamente.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="mt-4">{{ $providers->links() }}</div>
@endsection
