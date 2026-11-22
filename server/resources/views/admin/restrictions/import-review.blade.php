@extends('layouts.admin', ['title' => 'Revisar importación | PicoRadar'])
@section('content')
@php
    $newCount = $import->rows->filter(fn ($row) => $row->state === 'valid' && ($row->normalized['onboarding']['status'] ?? null) === 'ALTA_PROPUESTA')->count();
    $existingCount = $import->rows->filter(fn ($row) => $row->state === 'valid' && ($row->normalized['onboarding']['status'] ?? null) === 'EXISTENTE')->count();
@endphp
<div class="flex items-center justify-between">
    <div>
        <h1 class="text-3xl font-semibold">{{ $import->original_name }}</h1>
        <p class="mt-2 text-sm text-slate-600">{{ $import->format }} · {{ $import->row_count }} filas · {{ $import->sheet ?? 'sin hoja' }}</p>
    </div>
    <a class="text-teal-700" href="{{ route('admin.restrictions.imports.report', $import) }}">Descargar reporte</a>
</div>
<div class="mt-2 grid gap-1 text-xs text-slate-600 sm:grid-cols-2">
    <p>SHA-256 del archivo: <span class="break-all font-mono">{{ $import->sha256 }}</span></p>
    <p>Válidas: {{ $import->valid_count }} · Inválidas: {{ $import->invalid_count }} · Excluidas: {{ $import->excluded_count }}</p>
    <p>Filas válidas con alta propuesta: {{ $newCount }} · Filas válidas de jurisdicciones existentes: {{ $existingCount }}</p>
</div>
@if($errors->any())<div class="mt-4 rounded bg-red-50 p-3 text-red-800">{{ $errors->first() }}</div>@endif
<form class="mt-6" method="POST" action="{{ route('admin.restrictions.imports.confirm', $import) }}">@csrf
    <div class="overflow-x-auto">
        <table class="w-full text-left text-sm">
            <thead><tr class="border-b"><th class="p-2">Usar</th><th class="p-2">Fila</th><th class="p-2">Departamento / municipio</th><th class="p-2">Vehículo / servicio</th><th class="p-2">Fuente / vigencia</th><th class="p-2">Estado / detalle</th></tr></thead>
            <tbody>
            @foreach($import->rows as $row)
                @php
                    $normalized = $row->normalized ?? [];
                    $onboarding = $normalized['onboarding'] ?? [];
                    $payload = $normalized['payload'] ?? [];
                    $coverages = $payload['coverages'] ?? (isset($normalized['coverage']) ? [$normalized['coverage']] : []);
                    $primaryUnit = $row->jurisdiction?->primaryGeographicUnit;
                    $department = $primaryUnit?->parent;
                    $municipalityCodes = $payload['municipalityCodes'] ?? [];
                    if (! is_array($municipalityCodes) || $municipalityCodes === []) {
                        $code = $onboarding['municipality_code'] ?? $primaryUnit?->code;
                        $municipalityCodes = $code ? [(string) $code] : [];
                    }
                    $status = $onboarding['status'] ?? null;
                    $canSelect = $row->state === 'valid' && $row->publishable && ($status !== 'ALTA_PROPUESTA' || $canCreateJurisdictions);
                @endphp
                <tr class="border-b align-top">
                    <td class="p-2">
                        @if($canSelect && $import->status->value === 'analyzed')
                            <input type="checkbox" name="rows[]" value="{{ $row->id }}" checked aria-label="Incluir fila {{ $row->row_number }}">
                        @endif
                    </td>
                    <td class="p-2">{{ $row->row_number }}</td>
                    <td class="p-2">
                        <div class="font-medium">{{ $onboarding['municipality_name'] ?? $row->jurisdiction?->name ?? ($status === 'REQUIERE_ASIGNACION_MANUAL' ? 'Territorio pendiente de asignación' : ($payload['name'] ?? 'Municipio sin confirmar')) }}</div>
                        <div class="text-xs text-slate-600">Departamento: {{ $onboarding['department_name'] ?? $department?->name ?? 'No determinado' }}</div>
                        <div class="break-all text-xs text-slate-600">DIVIPOLA: {{ $municipalityCodes !== [] ? implode(', ', $municipalityCodes) : 'No disponible' }} · Depto: {{ $onboarding['department_code'] ?? '—' }}</div>
                        <div class="mt-1 text-xs font-medium {{ $status === 'ALTA_PROPUESTA' ? 'text-amber-700' : 'text-slate-700' }}">
                            @switch($status)
                                @case('ALTA_PROPUESTA') Alta propuesta · {{ $onboarding['proposed_key'] ?? 'clave pendiente' }} @break
                                @case('EXISTENTE') Jurisdicción existente · {{ $row->jurisdiction?->key ?? $onboarding['proposed_key'] ?? '' }} @break
                                @case('REQUIERE_ASIGNACION_MANUAL') Requiere asignación manual @break
                                @default Jurisdicción sin resolver
                            @endswitch
                        </div>
                        @if($status === 'REQUIERE_ASIGNACION_MANUAL' && !empty($onboarding['candidate_jurisdictions']))
                            <div class="mt-1 text-xs text-amber-800">
                                No se eligió una jurisdicción automáticamente. Para continuar, asigne en el archivo un <code>jurisdiction_id</code> de esta lista y analícelo de nuevo:
                                @foreach($onboarding['candidate_jurisdictions'] as $candidate)
                                    <div>{{ $candidate['key'] }} · {{ $candidate['name'] }}</div>
                                @endforeach
                            </div>
                        @endif
                    </td>
                    <td class="p-2">
                        @forelse($coverages as $coverage)
                            <div class="mb-2 last:mb-0">
                                <div>{{ $coverage['vehicleKind'] ?? 'No confirmado' }} · {{ $coverage['serviceType'] ?? 'No confirmado' }}</div>
                                @if(isset($coverage['coverageCompleteness']))<div class="text-xs text-slate-600">Cobertura declarada: {{ $coverage['coverageCompleteness'] }}</div>@endif
                                <div class="text-xs text-slate-600">Consulta de modalidad: {{ array_key_exists('consultationEnabled', $coverage) ? ($coverage['consultationEnabled'] ? 'habilitada' : 'deshabilitada') : 'no indicada; conserva el valor vigente o usa ON por compatibilidad histórica' }}</div>
                            </div>
                        @empty
                            @if(isset($normalized['rule']) || isset($onboarding['vehicle_kind']))
                                <div>{{ $normalized['coverage']['vehicleKind'] ?? $onboarding['vehicle_kind'] ?? 'No confirmado' }} · {{ $normalized['coverage']['serviceType'] ?? $onboarding['service_type'] ?? 'No confirmado' }}</div>
                            @else
                                <span class="text-slate-600">Modalidad no disponible</span>
                            @endif
                        @endforelse
                    </td>
                    <td class="max-w-xl break-all p-2">
                        @forelse($coverages as $coverage)
                            @php
                                $rules = is_array($coverage['rules'] ?? null) ? $coverage['rules'] : [];
                                if (isset($normalized['rule']) && is_array($normalized['rule'])) {
                                    $rules[] = $normalized['rule'];
                                }
                                $sources = is_array($coverage['sourceUrls'] ?? null) ? $coverage['sourceUrls'] : [];
                                $verifiedAt = array_filter([$coverage['verifiedAt'] ?? null]);
                                foreach ($rules as $rule) {
                                    if (is_array($rule)) {
                                        $sources[] = $rule['sourceUrl'] ?? null;
                                        $verifiedAt[] = $rule['verifiedAt'] ?? null;
                                    }
                                }
                                $sources = array_values(array_unique(array_filter($sources)));
                                $verifiedAt = array_values(array_unique(array_filter($verifiedAt)));
                            @endphp
                            <div class="mb-3 last:mb-0">
                                <div class="font-medium">{{ $sources !== [] ? implode(' · ', $sources) : 'Fuente no confirmada' }}</div>
                                <div class="text-xs text-slate-600">Verificada: {{ $verifiedAt !== [] ? implode(' · ', $verifiedAt) : 'Sin fecha' }} · Revisar hasta: {{ $coverage['staleAfter'] ?? 'Sin fecha' }}</div>
                            </div>
                        @empty
                            @if(isset($normalized['rule']))
                                <div class="font-medium">{{ $normalized['rule']['sourceUrl'] ?? 'Fuente no confirmada' }}</div>
                                <div class="text-xs text-slate-600">Verificada: {{ $normalized['rule']['verifiedAt'] ?? 'Sin fecha' }} · Revisar hasta: {{ $normalized['coverage']['staleAfter'] ?? 'Sin fecha' }}</div>
                            @elseif(isset($onboarding['source']))
                                <div class="font-medium">{{ !empty($onboarding['source']['urls']) ? implode(' · ', $onboarding['source']['urls']) : 'Fuente no confirmada' }}</div>
                                <div class="text-xs text-slate-600">Verificada: {{ !empty($onboarding['source']['verified_at']) ? implode(' · ', $onboarding['source']['verified_at']) : 'Sin fecha' }} · Revisar hasta: {{ !empty($onboarding['validity']['stale_after']) ? implode(' · ', $onboarding['validity']['stale_after']) : 'Sin fecha' }}</div>
                            @else
                                <span class="text-slate-600">Procedencia no disponible; fila no publicable</span>
                            @endif
                        @endforelse
                    </td>
                    <td class="p-2">
                        <div>{{ $row->state }} · {{ $row->publishable ? 'publicable como borrador' : 'no publicable' }}</div>
                        <div class="text-red-700">{{ implode(' · ', $row->errors ?? []) }}</div>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </div>
    @if($import->status->value === 'analyzed')
        <button class="mt-4 rounded bg-slate-900 px-4 py-2 text-white">Crear borradores seleccionados</button>
        <p class="mt-2 text-xs text-slate-600">La confirmación solo crea borradores. No publica normas ni habilita consultas.</p>
    @else
        <p class="mt-4 text-sm text-slate-700">Esta importación ya fue confirmada; la revisión es de solo lectura.</p>
    @endif
</form>
@endsection
