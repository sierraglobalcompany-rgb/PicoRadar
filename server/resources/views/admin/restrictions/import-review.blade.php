@extends('layouts.admin', ['title' => 'Revisar importación | PicoRadar'])
@section('content')
<div class="flex items-center justify-between"><div><h1 class="text-3xl font-semibold">{{ $import->original_name }}</h1><p class="mt-2 text-sm text-slate-600">{{ $import->format }} · {{ $import->row_count }} filas · {{ $import->sheet ?? 'sin hoja' }}</p></div><a class="text-teal-700" href="{{ route('admin.restrictions.imports.report', $import) }}">Descargar reporte</a></div>
<div class="mt-2 grid gap-1 text-xs text-slate-600 sm:grid-cols-2">
    <p>SHA-256 del archivo: <span class="break-all font-mono">{{ $import->sha256 }}</span></p>
    <p>Válidas: {{ $import->valid_count }} · Inválidas: {{ $import->invalid_count }} · Excluidas: {{ $import->excluded_count }}</p>
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
                    $payload = $normalized['payload'] ?? [];
                    $coverages = $payload['coverages'] ?? (isset($normalized['coverage']) ? [$normalized['coverage']] : []);
                    $primaryUnit = $row->jurisdiction?->primaryGeographicUnit;
                    $department = $primaryUnit?->parent;
                    $municipalityCodes = $payload['municipalityCodes'] ?? [];
                    if ($municipalityCodes === [] && $primaryUnit?->code) {
                        $municipalityCodes = [(string) $primaryUnit->code];
                    }
                @endphp
                <tr class="border-b align-top">
                    <td class="p-2">@if($row->publishable)<input type="checkbox" name="rows[]" value="{{ $row->id }}" checked aria-label="Incluir fila {{ $row->row_number }}">@endif</td>
                    <td class="p-2">{{ $row->row_number }}</td>
                    <td class="p-2">
                        <div class="font-medium">{{ $row->jurisdiction?->name ?? ($payload['name'] ?? '—') }}</div>
                        <div class="break-all text-xs text-slate-600">{{ $row->jurisdiction?->key ?? ($payload['id'] ?? 'Jurisdicción no confirmada') }}</div>
                        <div class="text-xs text-slate-600">Departamento: {{ $department?->name ?? 'No determinado' }}</div>
                        <div class="break-all text-xs text-slate-600">DIVIPOLA: {{ is_array($municipalityCodes) && $municipalityCodes !== [] ? implode(', ', $municipalityCodes) : 'No disponible' }}</div>
                    </td>
                    <td class="p-2">
                        @forelse($coverages as $coverage)
                            <div class="mb-2 last:mb-0">
                                <div>{{ $coverage['vehicleKind'] ?? 'No confirmado' }} · {{ $coverage['serviceType'] ?? 'No confirmado' }}</div>
                                @if(isset($coverage['coverageCompleteness']))<div class="text-xs text-slate-600">Cobertura declarada: {{ $coverage['coverageCompleteness'] }}</div>@endif
                            </div>
                        @empty
                            <span class="text-slate-600">Modalidad no disponible</span>
                        @endforelse
                    </td>
                    <td class="max-w-xl break-all p-2">
                        @forelse($coverages as $coverage)
                            @php
                                $rules = $coverage['rules'] ?? [];
                                if (isset($normalized['rule']) && is_array($normalized['rule'])) {
                                    $rules[] = $normalized['rule'];
                                }
                                $sources = array_values(array_unique(array_filter(array_merge($coverage['sourceUrls'] ?? [], array_column($rules, 'sourceUrl')))));
                                $verifiedAt = array_values(array_unique(array_filter(array_merge([$coverage['verifiedAt'] ?? null], array_column($rules, 'verifiedAt')))));
                            @endphp
                            <div class="mb-3 last:mb-0">
                                <div class="font-medium">{{ $sources !== [] ? implode(' · ', $sources) : 'Fuente no confirmada' }}</div>
                                <div class="text-xs text-slate-600">Verificada: {{ $verifiedAt !== [] ? implode(' · ', $verifiedAt) : 'Sin fecha' }} · Revisar hasta: {{ $coverage['staleAfter'] ?? 'Sin fecha' }}</div>
                            </div>
                        @empty
                            <span class="text-slate-600">Procedencia no disponible; fila no publicable</span>
                        @endforelse
                    </td>
                    <td class="p-2">
                        <div>{{ $row->state }}</div>
                        <div class="text-red-700">{{ implode(' · ', $row->errors ?? []) }}</div>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </div>
    <button class="mt-4 rounded bg-slate-900 px-4 py-2 text-white">Crear borradores seleccionados</button>
</form>
@endsection
