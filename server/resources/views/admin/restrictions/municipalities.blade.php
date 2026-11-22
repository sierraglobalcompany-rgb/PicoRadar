@extends('layouts.admin', ['title' => 'Matriz municipal | PicoRadar'])
@section('content')
<div class="flex flex-wrap items-start justify-between gap-3">
    <div>
        <p class="text-sm font-medium text-teal-700">Pico y placa · cobertura</p>
        <h1 class="mt-1 text-3xl font-semibold">Matriz municipal</h1>
        <p class="mt-2 max-w-3xl text-sm text-slate-600">La cobertura nacional actual viene del asset verificado al que apunta el dataset. El editor más reciente se muestra por separado. UNKNOWN no equivale a autorización para circular.</p>
        <p class="mt-2 text-sm font-medium text-slate-700">Release nacional actual: {{ $currentRelease?->version ?? 'Sin release actual verificable' }}</p>
    </div>
    <div class="flex flex-wrap gap-2">
        <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-4 text-teal-800 underline" href="{{ route('admin.restrictions.index') }}">Reglas por ciudad</a>
        <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-4 text-teal-800 underline" href="{{ route('admin.restrictions.coverage.export', ['scope' => 'municipalities']) }}">Descargar CSV</a>
    </div>
</div>

<form class="mt-6 grid gap-3 rounded-lg border border-slate-200 bg-white p-4 md:grid-cols-5" method="GET" action="{{ route('admin.restrictions.municipalities') }}">
    <label class="text-sm font-medium" for="municipality-q">Buscar municipio o jurisdicción
        <input id="municipality-q" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" name="q" value="{{ $filters['q'] }}" placeholder="Nombre, código o identificador">
    </label>
    <label class="text-sm font-medium" for="municipality-department">Departamento
        <select id="municipality-department" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="department">
            <option value="">Todos</option>
            @foreach($departments as $department)
                <option value="{{ $department->code }}" @selected($filters['department'] === $department->code)>{{ $department->name }}</option>
            @endforeach
        </select>
    </label>
    <label class="text-sm font-medium" for="municipality-management">Gestión
        <select id="municipality-management" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="management">
            <option value="all" @selected($filters['management'] === 'all')>Todas</option>
            <option value="active" @selected($filters['management'] === 'active')>Activas</option>
            <option value="inactive" @selected($filters['management'] === 'inactive')>Inactivas</option>
            <option value="unassigned" @selected($filters['management'] === 'unassigned')>Sin jurisdicción</option>
        </select>
    </label>
    <label class="text-sm font-medium" for="municipality-evidence">Evidencia
        <select id="municipality-evidence" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="availability">
            <option value="all" @selected($filters['availability'] === 'all')>Todos los estados</option>
            <option value="verified" @selected($filters['availability'] === 'verified')>VERIFIED</option>
            <option value="partial" @selected($filters['availability'] === 'partial')>PARTIAL</option>
            <option value="stale" @selected($filters['availability'] === 'stale')>STALE</option>
            <option value="unknown" @selected($filters['availability'] === 'unknown')>UNKNOWN</option>
        </select>
    </label>
    <div class="flex items-end gap-2">
        <button class="min-h-12 rounded-md bg-slate-900 px-4 font-medium text-white">Filtrar</button>
        <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-4" href="{{ route('admin.restrictions.municipalities') }}">Limpiar</a>
    </div>
</form>

<p class="mt-4 text-sm text-slate-600">{{ $municipalities->total() }} municipios · máximo 50 por página</p>
<div class="mt-3 overflow-x-auto rounded-lg border border-slate-200 bg-white">
    <table class="w-full border-collapse text-left text-sm">
        <thead>
            <tr class="border-b border-slate-200 bg-slate-50">
                <th scope="col" class="p-3">Código DIVIPOLA</th>
                <th scope="col" class="p-3">Municipio</th>
                <th scope="col" class="p-3">Departamento</th>
                <th scope="col" class="p-3">Jurisdicción</th>
                <th scope="col" class="p-3">Gestión</th>
                <th scope="col" class="p-3">Cobertura nacional actual</th>
                <th scope="col" class="p-3">Release nacional actual</th>
                <th scope="col" class="p-3">Editor más reciente</th>
                <th scope="col" class="p-3">Acciones</th>
            </tr>
        </thead>
        <tbody>
            @forelse($municipalities as $row)
                @php($municipality = $row['municipality'])
                <tr class="border-b border-slate-200 align-top">
                    <td class="p-3 font-mono">{{ $municipality->code }}</td>
                    <td class="p-3 font-medium">{{ $municipality->name }}<div class="text-xs font-normal text-slate-500">{{ $municipality->key }}</div></td>
                    <td class="p-3">{{ $municipality->parent?->name ?? '—' }}</td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['entries'] as $entry)
                                <li>
                                    @if($entry['jurisdiction'])
                                        <div class="font-medium">{{ $entry['jurisdiction']->name }}</div>
                                        <div class="text-xs text-slate-500">{{ $entry['jurisdiction']->key }}</div>
                                    @else
                                        <div class="font-medium">Sin jurisdicción asignada</div>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['entries'] as $entry)
                                <li>
                                    @if($entry['management_state'] === 'ACTIVE')
                                        <span class="inline-flex rounded-full bg-emerald-50 px-2 py-1 font-medium text-emerald-800">ACTIVE · Activa</span>
                                    @elseif($entry['management_state'] === 'INACTIVE')
                                        <span class="inline-flex rounded-full bg-slate-100 px-2 py-1 font-medium text-slate-700">INACTIVE · Inactiva</span>
                                        <div class="mt-1 text-xs text-slate-600">Solo lectura</div>
                                    @else
                                        <span class="inline-flex rounded-full bg-slate-100 px-2 py-1 font-medium text-slate-700">NO_JURISDICTION · Sin jurisdicción</span>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['entries'] as $entry)
                                <li class="space-y-1">
                                    @foreach($entry['coverages'] as $coverage)
                                        @php($evidenceClass = match($coverage['availability']) {'VERIFIED' => 'bg-emerald-50 text-emerald-800', 'PARTIAL' => 'bg-amber-50 text-amber-900', 'STALE' => 'bg-rose-50 text-rose-800', default => 'bg-slate-100 text-slate-800'})
                                        <div class="font-medium">{{ $coverage['category'] }}</div>
                                        <div><span class="inline-flex rounded-full px-2 py-1 font-semibold {{ $evidenceClass }}">{{ $coverage['availability'] }}</span></div>
                                        <div class="text-xs text-slate-600">Consulta de modalidad: {{ $coverage['consultation_enabled'] ? 'habilitada' : 'deshabilitada' }}</div>
                                        @if($coverage['availability'] === 'UNKNOWN')<div class="text-xs text-slate-600">{{ $coverage['missing_reason'] }}</div>@endif
                                    @endforeach
                                    @if($entry['jurisdiction'])
                                        <div class="text-xs text-slate-600">Fuente editorial: {{ $entry['source_editor_version'] === 'NO_IDENTIFICADA' ? 'NO_IDENTIFICADA' : 'v'.$entry['source_editor_version'] }}</div>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['entries'] as $entry)
                                <li>
                                    @if($entry['published_release'])
                                        <span class="font-medium">{{ $entry['published_release']->version }}</span>
                                        <div class="text-xs text-slate-600">Publicado · asset verificado</div>
                                    @else
                                        <span class="text-slate-600">Sin release actual verificable</span>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['entries'] as $entry)
                                <li>
                                    @if($entry['version'])
                                        <div class="font-medium">Editor: v{{ $entry['version']->version }} · {{ $entry['version']->status->value }}</div>
                                        <ul class="mt-1 space-y-1 text-xs text-slate-600">
                                            @foreach($entry['editor_coverages'] as $coverage)
                                                <li>{{ $coverage['category'] }} · editor: {{ $coverage['availability'] }}</li>
                                            @endforeach
                                        </ul>
                                    @else
                                        <span class="text-slate-600">Sin versión editorial</span>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                    <td class="p-3">
                        <ul class="space-y-3">
                            @foreach($row['entries'] as $entry)
                                <li class="flex flex-col items-start gap-1">
                                    @if($entry['management_state'] === 'ACTIVE' && $entry['jurisdiction'] && $entry['version'])
                                        @if($entry['version']->status->value === 'draft' && auth()->user()->can('datasets.edit'))
                                            <a class="text-teal-700 underline" href="{{ route('admin.restrictions.edit', $entry['version']) }}">Editar borrador</a>
                                        @else
                                            <a class="text-teal-700 underline" href="{{ route('admin.restrictions.edit', $entry['version']) }}">Ver versión</a>
                                        @endif
                                        @if($entry['version']->status->value === 'validated')
                                            @can('datasets.review')
                                                <a class="text-teal-700 underline" href="{{ route('admin.restrictions.publish.preview', ['versions' => [$entry['version']->id]]) }}">Revisar publicación</a>
                                            @endcan
                                        @endif
                                    @elseif($entry['management_state'] === 'NO_JURISDICTION')
                                        @can('jurisdictions.edit')
                                            <a class="text-sm text-teal-700 underline" href="{{ route('admin.jurisdictions.create', ['primary_geographic_unit_id' => $municipality->id]) }}">Preparar jurisdicción</a>
                                        @else
                                            <span class="text-sm text-slate-600">Requiere asignación revisada</span>
                                        @endcan
                                    @else
                                        <span class="text-sm text-slate-600">Solo lectura</span>
                                    @endif
                                </li>
                            @endforeach
                        </ul>
                    </td>
                </tr>
            @empty
                <tr><td class="p-5 text-center text-slate-600" colspan="9">No hay municipios que coincidan con los filtros.</td></tr>
            @endforelse
        </tbody>
    </table>
</div>
<div class="mt-5">{{ $municipalities->links() }}</div>
@endsection
