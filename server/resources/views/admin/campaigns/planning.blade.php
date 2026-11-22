@extends('layouts.admin')

@section('content')
<div class="space-y-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
            <h1 class="text-3xl font-semibold">Planificación de campañas</h1>
            <p class="mt-1 text-sm text-slate-600">Agenda y simulación de lectura para {{ $operator->name }}. Esta pantalla no cambia campañas ni publica catálogos.</p>
        </div>
        <a class="rounded border bg-white px-4 py-2 underline" href="{{ route('admin.campaigns.index') }}">Volver a campañas</a>
    </div>

    @if ($errors->any())
        <div class="rounded border border-red-300 bg-red-50 p-4 text-sm text-red-900" role="alert">
            <p class="font-semibold">Revisa los filtros:</p>
            <ul class="mt-2 list-inside list-disc">@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
        </div>
    @endif

    <section class="rounded border bg-white p-4" aria-labelledby="delivery-state">
        <h2 id="delivery-state" class="text-lg font-semibold">{{ $deliveryState }}</h2>
        @if ($deliveryState === 'PUBLICIDAD OFF / SOLO SIMULACIÓN')
            <p class="mt-1 text-sm text-slate-700">Al menos una de las dos banderas de difusión está apagada. Los resultados siguientes son solo diagnóstico.</p>
        @else
            <p class="mt-1 text-sm text-slate-700">Las banderas están encendidas, pero esta vista no comprueba el asset, release ni recepción del cliente; no acredita impresiones reales.</p>
        @endif
        <p class="mt-1 text-sm text-slate-600">Las imágenes no se leen desde almacenamiento. Se muestra únicamente si sus metadatos están presentes. El modelo de campaña no registra una fuente de vigencia independiente. Campañas e imágenes requieren aprobación legal/comercial y activación explícita por los flujos existentes; aquí no se activan.</p>
    </section>

    <form method="GET" action="{{ route('admin.campaigns.planning') }}" class="grid gap-4 rounded border bg-white p-4 md:grid-cols-3 xl:grid-cols-5">
        <label class="text-sm">Desde (Bogotá, incluido)
            <input class="mt-1 w-full rounded border p-2" type="date" name="from" value="{{ $filters['from'] }}" required>
        </label>
        <label class="text-sm">Hasta (Bogotá, excluido)
            <input class="mt-1 w-full rounded border p-2" type="date" name="until" value="{{ $filters['until'] }}" required>
        </label>
        <label class="text-sm">Ubicación
            <select class="mt-1 w-full rounded border p-2" name="placement" required>
                <option value="home_c11" @selected($filters['placement'] === 'home_c11')>Inicio · home_c11</option>
            </select>
        </label>
        <label class="text-sm">Estado de agenda
            <select class="mt-1 w-full rounded border p-2" name="status">
                <option value="">Todos</option>
                @foreach ($statuses as $status)
                    <option value="{{ $status->value }}" @selected(($filters['status'] ?? '') === $status->value)>{{ $status->value }}</option>
                @endforeach
            </select>
        </label>
        <label class="text-sm">Patrocinador existente
            <select class="mt-1 w-full rounded border p-2" name="sponsor_id">
                <option value="">Todos</option>
                @foreach ($sponsors as $sponsor)
                    <option value="{{ $sponsor->id }}" @selected((string) ($filters['sponsor_id'] ?? '') === (string) $sponsor->id)>{{ $sponsor->name }} · {{ $sponsor->status->value }}</option>
                @endforeach
            </select>
        </label>
        <label class="text-sm">Departamento
            <select class="mt-1 w-full rounded border p-2" name="department_id">
                <option value="">Todos</option>
                @foreach ($departments as $department)
                    <option value="{{ $department->id }}" @selected((string) ($filters['department_id'] ?? '') === (string) $department->id)>{{ $department->code }} · {{ $department->name }}</option>
                @endforeach
            </select>
        </label>
        <label class="text-sm">Municipio para territorio
            <select class="mt-1 w-full rounded border p-2" name="municipality_id">
                <option value="">Sin municipio (nacionales y departamento)</option>
                @foreach ($municipalities as $municipality)
                    <option value="{{ $municipality->id }}" @selected((string) ($filters['municipality_id'] ?? '') === (string) $municipality->id)>{{ $municipality->code }} · {{ $municipality->name }}</option>
                @endforeach
            </select>
        </label>
        <label class="text-sm">Instante T (hora de Bogotá)
            <input class="mt-1 w-full rounded border p-2" type="datetime-local" name="simulation_at" value="{{ $filters['simulation_at'] }}" required>
        </label>
        <label class="text-sm">Filas por página
            <select class="mt-1 w-full rounded border p-2" name="per_page">
                <option value="25" @selected((int) $filters['per_page'] === 25)>25</option>
                <option value="50" @selected((int) $filters['per_page'] === 50)>50</option>
            </select>
        </label>
        <div class="flex items-end"><button class="rounded bg-slate-900 px-4 py-2 text-white" type="submit">Aplicar filtros</button></div>
        <p class="text-sm text-slate-600 md:col-span-3 xl:col-span-5">Rango máximo: 90 días; T debe quedar dentro de [desde, hasta). La agenda aplica los filtros de estado y territorio. La simulación compara los registros del rango y añade candidatas activas al catálogo con ends_at &gt; T, aunque empiecen después del rango (y patrocinador, si se eligió).</p>
    </form>

    <section class="space-y-3" aria-labelledby="simulation-heading">
        <div>
            <h2 id="simulation-heading" class="text-xl font-semibold">Simulación en T · {{ $simulationAt->setTimezone('America/Bogota')->format('Y-m-d H:i') }}</h2>
            <p class="text-sm text-slate-600">Etapa del servidor y elegibilidad teórica del cliente se muestran por separado. Una futura puede ser candidata al catálogo sin ser visible todavía. El orden esperado es prioridad y luego public_id.</p>
        </div>
        <div class="overflow-x-auto rounded border bg-white">
            <table class="w-full text-left text-sm">
                <thead class="bg-slate-50"><tr><th class="p-3">Campaña / patrocinador</th><th class="p-3">Servidor en T</th><th class="p-3">Móvil en T</th><th class="p-3">Preparación declarada</th></tr></thead>
                <tbody>
                @forelse ($simulation as $row)
                    @php
                        $campaign = $row['campaign'];
                        $projection = $row['projection'];
                        $serverLabels = ['draft' => 'BORRADOR', 'paused' => 'PAUSADA', 'archived' => 'ARCHIVADA', 'sponsor_inactive' => 'PATROCINADOR INACTIVO', 'other_placement' => 'OTRA UBICACIÓN', 'expired' => 'VENCIDA'];
                        $mobileLabels = ['not_in_server_candidate' => 'NO ES CANDIDATA DEL SERVIDOR', 'scheduled' => 'PROGRAMADA · AÚN NO VISIBLE', 'municipality_required' => 'SELECCIONA MUNICIPIO', 'outside_territory' => 'FUERA DEL TERRITORIO'];
                    @endphp
                    <tr class="border-t align-top" data-simulation-campaign="{{ $campaign->public_id }}" data-server-candidate="{{ $projection['server_candidate'] ? 'true' : 'false' }}" data-mobile-reason="{{ $projection['mobile_reason'] ?? '' }}">
                        <td class="p-3"><a class="font-medium underline" href="{{ route('admin.campaigns.show', $campaign) }}">{{ $campaign->title }}</a><div>{{ $campaign->sponsor->name }}</div><div class="text-slate-600">Prioridad {{ $campaign->priority }} · {{ $campaign->public_id }}</div><div class="text-slate-600">{{ $campaign->scope->value }}@if($campaign->geographicUnit) · {{ $campaign->geographicUnit->name }}@endif</div></td>
                        <td class="p-3">@if($projection['server_candidate'])<strong>EN_CATÁLOGO_CANDIDATO</strong><div class="text-slate-600">Estado operativo en T: {{ $projection['operational_status'] }}.</div><div class="text-slate-600">active + patrocinador activo + ubicación + ends_at &gt; T; puede iniciar después de T.</div>@else<strong>{{ $serverLabels[$projection['server_reason']] ?? 'NO ELEGIBLE' }}</strong>@endif</td>
                        <td class="p-3">@if($projection['mobile_eligible'])<strong>ELEGIBLE EN MÓVIL EN TEORÍA</strong><div class="text-slate-600">Cumple tiempo y alcance territorial según el contexto seleccionado; no acredita recepción o impresión.</div>@else<strong>{{ $mobileLabels[$projection['mobile_reason']] ?? 'NO VISIBLE EN T' }}</strong>@endif</td>
                        <td class="p-3">Imagen: {{ $projection['image_metadata_ready'] ? 'metadatos presentes; archivo no verificado' : 'no preparada: metadatos incompletos' }}<br>URL CTA: {{ $projection['target_url_safe'] ? 'HTTPS válida por formato' : 'inválida o no HTTPS' }}</td>
                    </tr>
                @empty
                    <tr><td class="p-6 text-slate-600" colspan="4">No hay campañas en esta ubicación y ventana.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
    </section>

    <section class="space-y-3" aria-labelledby="agenda-heading">
        <div>
            <h2 id="agenda-heading" class="text-xl font-semibold">Agenda planificada · {{ $campaigns->total() }} campañas</h2>
            <p class="text-sm text-slate-600">Período [{{ $localFrom->format('Y-m-d') }}, {{ $localUntil->format('Y-m-d') }}) en America/Bogota. Coincidencia de calendario cuenta campañas no archivadas con el mismo placement y territorio superpuesto; no indica límite ni agotamiento de espacios.</p>
        </div>
        <div class="overflow-x-auto rounded border bg-white">
            <table class="w-full text-left text-sm">
                <thead class="bg-slate-50"><tr><th class="p-3">Prioridad / orden</th><th class="p-3">Campaña</th><th class="p-3">Territorio / ubicación</th><th class="p-3">Período (Bogotá)</th><th class="p-3">Estado / concurrencia</th><th class="p-3">Acciones existentes</th></tr></thead>
                <tbody>
                @forelse ($campaigns as $campaign)
                    @php
                        $scopeLabel = $campaign->scope->value;
                        $territoryLabel = $campaign->geographicUnit?->name ?? 'Nacional';
                    @endphp
                    <tr class="border-t align-top" data-campaign="{{ $campaign->public_id }}" data-overlap-count="{{ $overlapCounts[$campaign->id] ?? 0 }}">
                        <td class="p-3">{{ $campaign->priority }}<div class="text-slate-600">orden de catálogo</div></td>
                        <td class="p-3"><a class="font-medium underline" href="{{ route('admin.campaigns.show', $campaign) }}">{{ $campaign->title }}</a><div>{{ $campaign->sponsor->name }}</div><div class="text-slate-600">{{ $campaign->public_id }}</div></td>
                        <td class="p-3">{{ $scopeLabel }} · {{ $territoryLabel }}<div class="text-slate-600">{{ $campaign->placement }}</div></td>
                        <td class="p-3">{{ $campaign->starts_at->setTimezone('America/Bogota')->format('Y-m-d H:i') }}<br>{{ $campaign->ends_at->setTimezone('America/Bogota')->format('Y-m-d H:i') }}</td>
                        <td class="p-3">{{ $campaign->status->value }}<div class="mt-1">{{ $overlapCounts[$campaign->id] ?? 0 }} campañas con ventana y territorio coincidentes</div></td>
                        <td class="p-3"><a class="underline" href="{{ route('admin.campaigns.show', $campaign) }}">Ver</a>@can('campaigns.edit')<span aria-hidden="true"> · </span><a class="underline" href="{{ route('admin.campaigns.edit', $campaign) }}">Editar</a>@endcan</td>
                    </tr>
                @empty
                    <tr><td class="p-6 text-slate-600" colspan="6">No hay campañas para estos filtros.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
        <div>{{ $campaigns->links() }}</div>
    </section>
</div>
@endsection
