@extends('layouts.admin', ['title' => 'Revisión de importación | PicoRadar'])

@section('content')
    <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
            <a class="text-sm font-medium text-teal-800 underline" href="{{ route('admin.service-providers.index') }}">← Directorio</a>
            <h1 class="mt-3 text-3xl font-semibold tracking-tight">Revisar importación</h1>
            <p class="mt-2 text-sm text-slate-600">SHA-256: <span class="font-mono">{{ $import->sha256 }}</span> · vence {{ $import->expires_at?->format('Y-m-d H:i') }} · estado {{ $import->status }}</p>
            <p class="mt-2 text-sm text-slate-600">Revisa cada fila y selecciona solo cambios válidos. Todo lo confirmado queda en draft. No se activa, anuncia ni publica nada.</p>
        </div>
        <a class="inline-flex min-h-11 items-center rounded-md border border-slate-300 px-4" href="{{ route('admin.service-providers.import') }}">Nuevo análisis</a>
    </div>

    @if($counts = data_get($import->report, 'counts', []))
        <dl class="mt-5 flex flex-wrap gap-3">
            @foreach($counts as $label => $count)
                <div class="rounded-md border border-slate-200 bg-white px-3 py-2 text-sm"><dt class="inline font-medium">{{ $label }}</dt><dd class="ml-2 inline">{{ $count }}</dd></div>
            @endforeach
        </dl>
    @endif

    @if($import->status === 'analyzed' && $import->expires_at?->isAfter(now()))
        <form class="mt-5" method="POST" action="{{ route('admin.service-providers.imports.confirm', $import) }}">
            @csrf
            @error('row_ids')<p class="mb-3 rounded-md bg-red-50 p-3 text-sm text-red-800">{{ $message }}</p>@enderror
            <div class="overflow-x-auto rounded-lg border border-slate-200 bg-white">
                <table class="w-full min-w-[900px] text-left text-sm">
                    <thead class="bg-slate-50 text-slate-700"><tr><th class="p-3">Confirmar</th><th class="p-3">Fila / estado</th><th class="p-3">Proveedor</th><th class="p-3">DIVIPOLA</th><th class="p-3">Fuente y vigencia</th><th class="p-3">Observaciones</th></tr></thead>
                    <tbody>
                    @forelse($rows as $row)
                        @php($data = $row->normalized['attributes'] ?? [])
                        <tr class="border-t border-slate-200 align-top">
                            <td class="p-3">
                                @if($row->publishable && in_array($row->status, ['NUEVA', 'SIN_CAMBIOS', 'EXISTENTE_CON_CAMBIOS'], true))
                                    <input class="h-5 w-5" type="checkbox" name="row_ids[]" value="{{ $row->id }}" aria-label="Seleccionar fila {{ $row->row_number }}: {{ $data['name'] ?? 'sin nombre' }}">
                                @else
                                    <span class="text-slate-500">—</span>
                                @endif
                            </td>
                            <td class="p-3"><div>{{ $row->row_number }}</div><strong>{{ $row->status }}</strong></td>
                            <td class="p-3"><div class="font-medium">{{ $data['name'] ?? ($row->raw['name'] ?? '—') }}</div><div class="text-slate-600">{{ $data['category'] ?? ($row->raw['category'] ?? '') }}</div></td>
                            <td class="p-3">{{ $data['department_code'] ?? '' }} / {{ $data['municipality_code'] ?? '' }}</td>
                            <td class="p-3"><div class="break-all">{{ $data['source_url'] ?? ($row->raw['source_url'] ?? '') }}</div><div>{{ $data['verified_at'] ?? '' }} · {{ $data['valid_until'] ?? '' }}</div></td>
                            <td class="p-3">@forelse($row->errors ?? [] as $error)<div class="text-red-700">{{ $error }}</div>@empty<span class="text-slate-500">Sin observaciones</span>@endforelse</td>
                        </tr>
                    @empty
                        <tr><td class="p-4 text-slate-600" colspan="6">No hay filas para revisar.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
            <div class="mt-4 flex flex-wrap items-center gap-3">
                <button class="inline-flex min-h-12 items-center rounded-md bg-slate-900 px-5 font-medium text-white" type="submit">Confirmar selección como borradores</button>
                <span class="text-sm text-slate-600">La confirmación vuelve a comprobar territorio, duplicados, fuente y estado del proveedor.</span>
            </div>
        </form>
    @elseif($import->status === 'confirmed')
        <p class="mt-5 rounded-md border border-emerald-300 bg-emerald-50 p-4 text-emerald-900">Este lote ya fue confirmado; los reintentos no vuelven a escribir sus fichas.</p>
    @else
        <p class="mt-5 rounded-md border border-amber-300 bg-amber-50 p-4 text-amber-950">El staging venció. Analiza el archivo de nuevo antes de confirmar.</p>
    @endif

    <div class="mt-4">{{ $rows->links() }}</div>
@endsection