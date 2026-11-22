@extends('layouts.admin', ['title' => 'Prioridad editorial nacional | PicoRadar'])

@section('content')
    <div class="flex flex-wrap items-start justify-between gap-4">
        <div class="max-w-3xl">
            <p class="text-sm font-semibold text-teal-700">Operación nacional · solo lectura</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight">Prioridad editorial por municipio</h1>
            <p class="mt-3 text-slate-600">Esta cola indica el siguiente trabajo editorial usando DIVIPOLA, jurisdicciones y versiones registradas. No certifica cobertura legal ni permiso para circular; ausencia de reglas significa SIN EVIDENCIA, no permitido.</p>
        </div>
        <nav class="flex flex-wrap gap-2" aria-label="Herramientas de restricciones">
            <a class="min-h-12 rounded-md border border-slate-300 px-4 py-3 font-medium" href="{{ route('admin.restrictions.municipalities') }}">Matriz municipal</a>
            <a class="min-h-12 rounded-md border border-slate-300 px-4 py-3 font-medium" href="{{ route('admin.restrictions.coverage.export') }}">CSV existente</a>
            @can('datasets.edit')
                <a class="min-h-12 rounded-md bg-slate-900 px-4 py-3 font-medium text-white" href="{{ route('admin.restrictions.import') }}">Analizar importación</a>
            @endcan
            @can('jurisdictions.edit')
                <a class="min-h-12 rounded-md border border-slate-300 px-4 py-3 font-medium" href="{{ route('admin.jurisdictions.index') }}">Jurisdicciones</a>
            @endcan
        </nav>
    </div>

    <section class="mt-6 rounded-lg border border-slate-200 bg-white p-4" aria-labelledby="release-state-title">
        <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
                <h2 id="release-state-title" class="font-semibold">Release global de restricciones</h2>
                <p class="mt-1 text-sm text-slate-700">{{ $release['status'] }} · versión {{ $release['version'] ?? 'sin versión actual' }}</p>
                <p class="mt-1 text-xs text-slate-500">Asset: {{ $release['asset_state'] }}. La pantalla no declara publicada ninguna ciudad o modalidad individual.</p>
            </div>
            @if($release['expires_at'])
                <p class="text-sm text-slate-600">Vigencia registrada hasta {{ $release['expires_at'] }}</p>
            @endif
        </div>
    </section>

    <section class="mt-4 rounded-lg border border-slate-200 bg-white p-4" aria-labelledby="national-integrity-title">
        <div class="flex flex-wrap items-start justify-between gap-3">
            <div>
                <h2 id="national-integrity-title" class="font-semibold">Integridad técnica de datos nacionales</h2>
                @if($integrityVerification)
                    <p class="mt-1 text-sm text-slate-600">Comprobado en esta solicitud · {{ $integrityVerification['checked_at']->setTimezone('America/Bogota')->format('Y-m-d H:i:s') }} Bogotá.</p>
                @else
                    <p class="mt-1 text-sm text-slate-600">NO_VERIFICADO · La lectura de assets se ejecuta solo cuando se solicita.</p>
                @endif
                <p class="mt-1 text-xs text-slate-600">Una comprobación técnica no acredita legalidad, entrega OTA ni datos del dispositivo.</p>
            </div>
            <a class="inline-flex min-h-11 items-center rounded border border-slate-300 px-4 py-2 font-medium" href="{{ route('admin.operations.national', ['verify_assets' => '1']) }}">Verificar integridad técnica ahora</a>
        </div>
        @if($integrityVerification)
            <div class="mt-4 overflow-x-auto">
                <table class="w-full min-w-[720px] text-left text-sm">
                    <thead class="bg-slate-50 text-slate-700">
                        <tr>
                            <th class="p-2">Dataset</th>
                            <th class="p-2">Versión apuntada</th>
                            <th class="p-2">Expira</th>
                            <th class="p-2">Estado</th>
                            <th class="p-2">Resultado</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($integrityVerification['rows'] as $integrityRow)
                            <tr class="border-t border-slate-200 align-top">
                                <td class="p-2">
                                    <span>{{ $integrityRow['label'] }}</span>
                                    @can('datasets.view')
                                        @if($integrityRow['dataset_id'])
                                            <a class="ml-2 text-teal-800 underline" href="{{ route('admin.datasets.show', $integrityRow['dataset_id']) }}">Ver registro</a>
                                        @endif
                                    @endcan
                                </td>
                                <td class="p-2">{{ $integrityRow['version'] ?? 'sin versión' }}</td>
                                <td class="p-2">{{ $integrityRow['expires_at']?->setTimezone('America/Bogota')->format('Y-m-d H:i:s') ?? 'sin fecha registrada' }}</td>
                                <td class="p-2 font-semibold">{{ $integrityRow['status'] }}</td>
                                <td class="p-2">{{ $integrityRow['reason'] }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </section>

    <section class="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4" aria-label="Conteos del universo filtrado">
        @foreach([
            ['Municipios DIVIPOLA activos', $metrics['active_municipalities'], 'Municipios del universo tras los filtros'],
            ['Municipios con jurisdicción', $metrics['associated_municipalities'], 'Municipios distintos; no suma relaciones N:N'],
            ['Jurisdicciones OFF', $metrics['off_jurisdictions'], 'Registros de jurisdicción'],
            ['Jurisdicciones sin borrador', $metrics['jurisdictions_without_draft'], 'Registros de jurisdicción'],
            ['Versiones DRAFT', $metrics['draft_versions'], 'Registros de versión'],
            ['Versiones VALIDATED', $metrics['validated_versions'], 'Registros; no implica publicación'],
            ['Propuestas pendientes', $metrics['pending_proposal_rows'], 'Filas ALTA_PROPUESTA en imports analizados'],
        ] as [$label, $value, $note])
            <article class="rounded-lg border border-slate-200 bg-white p-4">
                <p class="text-2xl font-semibold text-slate-950">{{ number_format($value) }}</p>
                <h2 class="mt-1 text-sm font-medium text-slate-800">{{ $label }}</h2>
                <p class="mt-1 text-xs text-slate-500">{{ $note }}</p>
            </article>
        @endforeach
    </section>
    <p class="mt-2 text-xs text-slate-500">Los conteos corresponden al universo visible después de departamento, búsqueda y estado. Municipios = unidades DIVIPOLA activas; jurisdicciones y versiones = registros; propuestas = filas de importación.</p>

    <form class="mt-6 grid gap-3 rounded-lg border border-slate-200 bg-white p-4 sm:grid-cols-2 lg:grid-cols-5" method="GET" action="{{ route('admin.operations.national') }}" aria-label="Filtrar cola editorial">
        <label class="text-sm font-medium text-slate-700">Departamento DIVIPOLA
            <select class="mt-1 min-h-11 w-full rounded border-slate-300" name="department">
                <option value="">Todos</option>
                @foreach($departments as $department)
                    <option value="{{ $department->code }}" @selected($filters['department'] === (string) $department->code)>{{ $department->code }} · {{ $department->name }}</option>
                @endforeach
            </select>
        </label>
        <label class="text-sm font-medium text-slate-700">Municipio o DIVIPOLA
            <input class="mt-1 min-h-11 w-full rounded border-slate-300" type="search" name="q" value="{{ $filters['q'] }}" maxlength="100" placeholder="Nombre o código de 5 dígitos">
        </label>
        <label class="text-sm font-medium text-slate-700">Gestión editorial
            <select class="mt-1 min-h-11 w-full rounded border-slate-300" name="state">
                <option value="">Todos los estados</option>
                @foreach(['sin_asignar' => 'Sin asignar', 'off' => 'Deshabilitado', 'borrador' => 'Borrador', 'validado' => 'Validado', 'publicacion_no_confirmada' => 'Publicación no comprobada', 'vencido' => 'Vencido', 'sin_evidencia' => 'Sin evidencia'] as $value => $label)
                    <option value="{{ $value }}" @selected($filters['state'] === $value)>{{ $label }}</option>
                @endforeach
            </select>
        </label>
        <label class="text-sm font-medium text-slate-700">Filas por página
            <select class="mt-1 min-h-11 w-full rounded border-slate-300" name="per_page">
                @foreach([25, 50] as $size)
                    <option value="{{ $size }}" @selected($filters['per_page'] === $size)>{{ $size }}</option>
                @endforeach
            </select>
        </label>
        <div class="flex items-end gap-2">
            <button class="min-h-11 rounded bg-slate-900 px-4 font-medium text-white" type="submit">Aplicar filtros</button>
            <a class="min-h-11 rounded border px-4 py-3 text-sm" href="{{ route('admin.operations.national') }}">Limpiar</a>
        </div>
    </form>

    <div class="mt-4 flex flex-wrap items-center justify-between gap-2">
        <h2 class="text-xl font-semibold">Cola editorial</h2>
        <p class="text-sm text-slate-600">{{ $rows->total() }} municipios · máximo 50 por página · corte {{ $generated_at->setTimezone('America/Bogota')->format('Y-m-d H:i') }} Bogotá</p>
    </div>
    <div class="mt-3 overflow-x-auto rounded-lg border border-slate-200 bg-white">
        <table class="w-full min-w-[1050px] text-left text-sm">
            <thead class="bg-slate-50 text-slate-700">
                <tr>
                    <th class="p-3">Municipio / DIVIPOLA</th>
                    <th class="p-3">Gestión editorial</th>
                    <th class="p-3">Jurisdicción</th>
                    <th class="p-3">Fuente / revisión</th>
                    <th class="p-3">Distribución</th>
                    <th class="p-3">Siguiente tarea</th>
                </tr>
            </thead>
            <tbody>
                @forelse($rows as $row)
                    <tr class="border-t align-top">
                        <td class="p-3">
                            <p class="font-semibold text-slate-950">{{ $row['municipality_name'] }}</p>
                            <p class="text-xs text-slate-600">{{ $row['municipality_code'] }} · {{ $row['department_code'] }} {{ $row['department_name'] }}</p>
                        </td>
                        <td class="p-3">
                            <span class="inline-flex rounded border border-slate-300 px-2 py-1 font-semibold">{{ $row['state_label'] }}</span>
                            <p class="mt-2 max-w-xs text-slate-700">{{ $row['reason'] }}</p>
                            @if($row['pending_proposal_count'] > 0)
                                <p class="mt-1 text-xs font-medium text-indigo-800">{{ $row['pending_proposal_count'] }} propuesta(s) pendiente(s)</p>
                            @endif
                        </td>
                        <td class="p-3">
                            @forelse($row['jurisdictions'] as $jurisdiction)
                                <div class="mb-2 last:mb-0">
                                    <p class="font-medium">{{ $jurisdiction['name'] }}</p>
                                    <p class="text-xs text-slate-600">{{ $jurisdiction['key'] }} · {{ $jurisdiction['enabled'] ? 'habilitada' : 'OFF' }} · editorial {{ strtoupper($jurisdiction['version_status'] ?? 'sin versión') }}</p>
                                </div>
                            @empty
                                <span class="text-slate-600">Sin jurisdicción asociada</span>
                            @endforelse
                        </td>
                        <td class="p-3">
                            @if($row['latest_source_url'])
                                <p class="max-w-xs break-all text-xs">{{ $row['latest_source_url'] }}</p>
                                <p class="mt-1 text-xs text-slate-600">Verificada en {{ $row['source_checked_at'] ?? 'fecha desconocida' }}</p>
                                <p class="text-xs text-slate-600">Revisar antes de {{ $row['stale_after'] ?? 'fecha desconocida' }}</p>
                            @else
                                <span class="font-medium text-amber-900">SIN EVIDENCIA VERIFICABLE</span>
                            @endif
                        </td>
                        <td class="p-3">
                            <p class="font-semibold text-amber-900">{{ $row['publication_note'] }}</p>
                            <p class="mt-1 text-xs text-slate-600">VALIDATED y el historial editorial no prueban qué contiene el asset vigente para este municipio.</p>
                        </td>
                        <td class="p-3">
                            @if(in_array($row['next_action_label'], ['Analizar importación territorial', 'Revisar borrador y fuente'], true))
                                @can('datasets.edit')
                                    <a class="font-semibold text-teal-800 underline" href="{{ $row['next_action_url'] }}">{{ $row['next_action_label'] }}</a>
                                @else
                                    <a class="font-semibold text-teal-800 underline" href="{{ $row['matrix_url'] }}">Abrir matriz para revisión</a>
                                @endcan
                            @else
                                <a class="font-semibold text-teal-800 underline" href="{{ $row['next_action_url'] }}">{{ $row['next_action_label'] }}</a>
                            @endif
                            <p class="mt-2"><a class="text-slate-700 underline" href="{{ $row['matrix_url'] }}">Abrir matriz existente</a></p>
                            @if($row['jurisdiction_count'] === 0)
                                @can('jurisdictions.edit')
                                    <p class="mt-2"><a class="text-slate-700 underline" href="{{ route('admin.jurisdictions.create') }}">Crear/asignar jurisdicción</a></p>
                                @endcan
                            @endif
                        </td>
                    </tr>
                @empty
                    <tr><td class="p-6 text-slate-600" colspan="6">No hay municipios que coincidan con estos filtros. Ninguna fila equivale a permiso para circular.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
    <div class="mt-4">{{ $rows->links() }}</div>
@endsection
