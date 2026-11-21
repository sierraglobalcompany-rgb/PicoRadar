@extends('layouts.admin', ['title' => 'Reglas por ciudad | PicoRadar'])
@section('content')
<div class="flex flex-wrap items-center justify-between gap-3">
    <div>
        <p class="text-sm font-medium text-teal-700">Pico y placa</p>
        <h1 class="mt-1 text-3xl font-semibold">Reglas por ciudad</h1>
        <p class="mt-2 text-sm text-slate-600">Cobertura por jurisdicción y categoría. Release {{ $dataset?->current_version ?? 'sin publicar' }} · revisión {{ $dataset?->publication_revision ?? 0 }}</p>
    </div>
    <div class="flex gap-2">
        @can('datasets.edit')
            @if($filters['management'] !== 'inactive')
                <a class="rounded border border-slate-300 px-3 py-2" href="{{ route('admin.restrictions.import') }}">Importar</a>
                <a class="rounded bg-slate-900 px-3 py-2 text-white" href="{{ route('admin.restrictions.create') }}">Nuevo borrador</a>
            @endif
        @endcan
        <a class="rounded border border-slate-300 px-3 py-2" href="{{ route('admin.restrictions.history') }}">Historial</a>
    </div>
</div>

@if($errors->any())
    <div class="mt-4 rounded bg-red-50 p-3 text-red-800">{{ $errors->first() }}</div>
@endif

<form class="mt-6 grid gap-3 rounded-lg border border-slate-200 bg-white p-4 md:grid-cols-6" method="GET" action="{{ route('admin.restrictions.index') }}">
    <label class="text-sm font-medium">Buscar ciudad
        <input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="q" value="{{ $filters['q'] }}" placeholder="Nombre o identificador">
    </label>
    <label class="text-sm font-medium">Departamento
        <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="department">
            <option value="">Todos</option>
            @foreach($departments as $department)
                <option value="{{ $department->code }}" @selected($filters['department'] === $department->code)>{{ $department->name }}</option>
            @endforeach
        </select>
    </label>
    <label class="text-sm font-medium">Tipo de vehículo
        <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="vehicle_kind">
            <option value="">Todos</option>
            <option value="car" @selected($filters['vehicle_kind'] === 'car')>Carro</option>
            <option value="motorcycle" @selected($filters['vehicle_kind'] === 'motorcycle')>Moto</option>
            <option value="truck" @selected($filters['vehicle_kind'] === 'truck')>Camión</option>
            <option value="bus" @selected($filters['vehicle_kind'] === 'bus')>Bus</option>
            <option value="motocarro" @selected($filters['vehicle_kind'] === 'motocarro')>Motocarro</option>
        </select>
    </label>
    <label class="text-sm font-medium">Estado de cobertura
        <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="availability">
            <option value="" @selected($filters['availability'] === '')>Todos</option>
            <option value="attention" @selected($filters['availability'] === 'attention')>Requiere atención</option>
            <option value="verified" @selected($filters['availability'] === 'verified')>VERIFIED</option>
            <option value="partial" @selected($filters['availability'] === 'partial')>PARTIAL</option>
            <option value="unknown" @selected($filters['availability'] === 'unknown')>UNKNOWN</option>
            <option value="stale" @selected($filters['availability'] === 'stale')>STALE</option>
        </select>
    </label>
    <label class="text-sm font-medium">Estado de gestión
        <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="management">
            <option value="active" @selected($filters['management'] === 'active')>Activas</option>
            <option value="inactive" @selected($filters['management'] === 'inactive')>Inactivas · solo lectura</option>
            <option value="all" @selected($filters['management'] === 'all')>Todas</option>
        </select>
    </label>
    <div class="flex items-end gap-2">
        <button class="min-h-12 rounded-md bg-slate-900 px-4 font-medium text-white">Filtrar</button>
        <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-4" href="{{ route('admin.restrictions.index') }}">Limpiar</a>
    </div>
</form>

@can('datasets.view')
    <div class="mt-3 flex flex-wrap gap-x-4 gap-y-2 text-sm">
        <a class="text-teal-700 underline" href="{{ route('admin.restrictions.municipalities') }}">Matriz municipal</a>
        <a class="text-teal-700 underline" href="{{ route('admin.restrictions.coverage.export', ['scope' => 'editorial'] + $filters) }}">Exportar vista CSV</a>
        <a class="text-teal-700 underline" href="{{ route('admin.restrictions.coverage.export', ['scope' => 'municipalities']) }}">Matriz municipal CSV</a>
    </div>
@endcan

<div class="mt-6 overflow-x-auto rounded-lg border border-slate-200 bg-white">
    <table class="w-full border-collapse text-left text-sm">
        <thead>
            <tr class="border-b border-slate-200 bg-slate-50">
                @can('datasets.review')<th class="p-3">Vista previa</th>@endcan
                <th class="p-3">Jurisdicción</th>
                <th class="p-3">Departamento</th>
                <th class="p-3">Cobertura / categoría</th>
                <th class="p-3">Disponibilidad</th>
                <th class="p-3">Estado editorial</th>
                <th class="p-3">Estado de gestión</th>
                <th class="p-3">Fuente y vigencia</th>
                <th class="p-3">Acciones</th>
            </tr>
        </thead>
        <tbody>
            @forelse($jurisdictions as $row)
                @php($jurisdiction = $row['jurisdiction'])
                @php($latest = $row['version'])
                @php($isInactive = ! $jurisdiction->enabled)
                <tr class="border-b border-slate-200 align-top">
                    @can('datasets.review')
                        <td class="p-3">
                            @if(! $isInactive && $latest?->status->value === 'validated')
                                <input type="checkbox" form="restriction-preview-form" name="versions[]" value="{{ $latest->id }}" aria-label="Previsualizar {{ $jurisdiction->name }}">
                            @endif
                        </td>
                    @endcan
                    <td class="p-3 font-medium">
                        {{ $jurisdiction->name }}
                        <div class="text-xs font-normal text-slate-500">{{ $jurisdiction->key }}</div>
                    </td>
                    <td class="p-3">{{ $jurisdiction->primaryGeographicUnit?->parent?->name ?? '—' }}</td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['coverages'] as $coverage)
                                <li>{{ $coverage['category'] }}</li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['coverages'] as $coverage)
                                <li>
                                    <span class="font-semibold">{{ $coverage['availability'] }}</span>
                                    @if($coverage['availability'] === 'UNKNOWN')
                                        <div class="text-xs text-slate-600">No verificada</div>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        @if($latest)
                            <span>{{ ucfirst($latest->status->value) }}</span>
                            <div class="text-xs text-slate-600">Versión {{ $latest->version }}</div>
                        @else
                            <span>Sin borrador</span>
                        @endif
                    </td>
                    <td class="p-3">
                        @if($isInactive)
                            <span class="inline-flex rounded-full bg-slate-100 px-2 py-1 font-medium text-slate-700">Inactiva</span>
                            <div class="mt-1 text-xs text-slate-600">Solo lectura</div>
                        @else
                            <span class="inline-flex rounded-full bg-emerald-50 px-2 py-1 font-medium text-emerald-800">Activa</span>
                        @endif
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['coverages'] as $coverage)
                                <li class="space-y-1">
                                    @if($coverage['source_urls'] !== [])
                                        <div>Fuente: @foreach($coverage['source_urls'] as $source){{ $source }}@if(! $loop->last) · @endif @endforeach</div>
                                    @else
                                        <div>Fuente: No registrada</div>
                                    @endif
                                    @if($coverage['verified_at'] !== [])
                                        <div>Verificada: @foreach($coverage['verified_at'] as $verifiedAt){{ $verifiedAt }}@if(! $loop->last) · @endif @endforeach</div>
                                    @else
                                        <div>No verificada</div>
                                    @endif
                                    @if($coverage['valid_until'] !== [])
                                        <div>Válida hasta: @foreach($coverage['valid_until'] as $validUntil){{ $validUntil }}@if(! $loop->last) · @endif @endforeach</div>
                                    @elseif($coverage['has_unbounded_rule'])
                                        <div>Sin fecha límite registrada</div>
                                    @endif
                                    @if($coverage['stale_after'])
                                        <div>Revisión de fuente: {{ $coverage['stale_after'] }}</div>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <div class="flex flex-col items-start gap-2">
                            @if($isInactive)
                                <span class="text-sm text-slate-600">Solo lectura</span>
                            @elseif($latest)
                                @can('datasets.edit')
                                    <a class="text-teal-700 underline" href="{{ route('admin.restrictions.edit', $latest) }}">Editar</a>
                                @endcan
                                @if($latest->status->value === 'draft')
                                    @can('datasets.review')
                                        <form method="POST" action="{{ route('admin.restrictions.validate', $latest) }}">
                                            @csrf
                                            <button class="text-teal-700 underline">Validar</button>
                                        </form>
                                    @endcan
                                @elseif($latest->status->value === 'validated')
                                    @can('datasets.review')
                                        <a class="text-teal-700 underline" href="{{ route('admin.restrictions.publish.preview', ['versions' => [$latest->id]]) }}">Previsualizar publicación</a>
                                    @endcan
                                @endif
                            @else
                                @can('datasets.edit')
                                    <a class="text-teal-700 underline" href="{{ route('admin.restrictions.create') }}">Crear borrador</a>
                                @endcan
                            @endif
                        </div>
                    </td>
                </tr>
            @empty
                <tr>
                    @can('datasets.review')
                        <td class="p-5 text-center text-slate-600" colspan="9">No hay ciudades que coincidan con los filtros.</td>
                    @else
                        <td class="p-5 text-center text-slate-600" colspan="8">No hay ciudades que coincidan con los filtros.</td>
                    @endcan
                </tr>
            @endforelse
        </tbody>
    </table>
</div>

@can('datasets.review')
    @if($filters['management'] !== 'inactive')
        <form id="restriction-preview-form" class="mt-4" method="GET" action="{{ route('admin.restrictions.publish.preview') }}">
            <button class="min-h-12 rounded-md bg-slate-900 px-4 text-white">Revisar selección</button>
        </form>
    @endif
@endcan

<div class="mt-5">{{ $jurisdictions->links() }}</div>
@endsection
