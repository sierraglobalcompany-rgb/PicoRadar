@extends('layouts.admin', ['title' => 'Borrador de reglas | PicoRadar'])

@php
    $formatDate = static fn ($value) => filled($value) ? \Carbon\CarbonImmutable::parse($value)->format('Y-m-d\TH:i') : '';
    $formatWindows = static function ($windows): string {
        if (! is_array($windows)) return '';
        return collect($windows)->map(static function ($window): string {
            $start = (int) ($window['startMinute'] ?? 0);
            $end = (int) ($window['endMinute'] ?? 0);
            return sprintf('%02d:%02d-%02d:%02d', intdiv($start, 60), $start % 60, intdiv($end, 60), $end % 60);
        })->implode("\n");
    };
    $payloadCoverages = collect($version?->payload['coverages'] ?? [])->map(static function ($coverage) use ($formatDate, $formatWindows): array {
        return [
            'vehicle_kind' => $coverage['vehicleKind'] ?? 'car',
            'service_type' => $coverage['serviceType'] ?? 'private',
            'verified_at' => $formatDate($coverage['verifiedAt'] ?? null),
            'stale_after' => $formatDate($coverage['staleAfter'] ?? null),
            'source_urls' => implode("\n", $coverage['sourceUrls'] ?? []),
            'confirmed_no_rules' => empty($coverage['rules']),
            'rules' => collect($coverage['rules'] ?? [])->map(static fn ($rule): array => [
                'id' => $rule['id'] ?? '',
                'priority' => $rule['priority'] ?? 1000,
                'effect' => $rule['effect'] ?? 'restrict',
                'valid_from' => $formatDate($rule['validFrom'] ?? null),
                'valid_until' => $formatDate($rule['validUntil'] ?? null),
                'weekdays' => implode(',', $rule['weekdays'] ?? []),
                'date_parity' => $rule['dateParity'] ?? '',
                'digit_position' => $rule['digitPosition'] ?? 'lastNumeric',
                'digits' => implode(',', $rule['digits'] ?? []),
                'time_windows' => $formatWindows($rule['timeWindows'] ?? []),
                'applies_on_holidays' => (bool) ($rule['appliesOnHolidays'] ?? false),
                'source_url' => $rule['sourceUrl'] ?? '',
                'verified_at' => $formatDate($rule['verifiedAt'] ?? null),
                'registration_origins' => implode(',', $rule['registrationOrigins'] ?? []),
            ])->all(),
        ];
    })->all();
    $defaultRule = [
        'id' => '', 'priority' => 1000, 'effect' => 'restrict', 'valid_from' => '', 'valid_until' => '',
        'weekdays' => '1,2,3,4,5', 'date_parity' => '', 'digit_position' => 'lastNumeric', 'digits' => '',
        'time_windows' => '06:00-20:00', 'applies_on_holidays' => false, 'source_url' => '',
        'verified_at' => '', 'registration_origins' => '',
    ];
    $defaultCoverage = [
        'vehicle_kind' => 'car', 'service_type' => 'private', 'verified_at' => '', 'stale_after' => '',
        'source_urls' => '', 'confirmed_no_rules' => false, 'rules' => [$defaultRule],
    ];
    $coverages = old('coverages', $payloadCoverages ?: [$defaultCoverage]);
@endphp

@section('content')
<div class="flex flex-wrap items-start justify-between gap-3">
    <div>
        <p class="text-sm font-medium text-teal-700">Pico y placa</p>
        <h1 class="mt-1 text-3xl font-semibold">{{ $version ? 'Borrador '.$version->jurisdiction->name.' v'.$version->version : 'Nuevo borrador de ciudad' }}</h1>
        <p class="mt-2 max-w-3xl text-sm text-slate-600">Define coberturas y reglas con la fuente oficial. Guardar no publica: otra persona debe validar y seleccionar la ciudad para publicación.</p>
    </div>
    <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-4 font-medium" href="{{ route('admin.restrictions.index') }}">Volver</a>
</div>

@if(!$version || ($editable ?? false))
<form class="mt-6 space-y-5" method="POST" action="{{ $version ? route('admin.restrictions.update', $version) : route('admin.restrictions.store') }}" id="restriction-form">
    @csrf
    @if($version) @method('PUT') @else
        <label class="block max-w-xl text-sm font-medium">Ciudad
            <select class="mt-1 block min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="jurisdiction_id" required>
                @foreach($jurisdictions as $jurisdiction)
                    <option value="{{ $jurisdiction->id }}" @selected((string) old('jurisdiction_id') === (string) $jurisdiction->id)>{{ $jurisdiction->name }} · {{ $jurisdiction->key }}</option>
                @endforeach
            </select>
        </label>
    @endif

    <div class="space-y-5" id="coverage-list">
        @foreach($coverages as $coverageIndex => $coverage)
            <section class="coverage-card rounded-lg border border-slate-200 bg-white p-5" data-coverage-index="{{ $coverageIndex }}">
                <div class="flex flex-wrap items-center justify-between gap-3">
                    <div><p class="text-xs font-semibold uppercase text-teal-700">Cobertura</p><h2 class="text-xl font-semibold">Vehículo y servicio</h2></div>
                    <button class="remove-coverage min-h-12 rounded-md border border-red-200 px-3 text-sm font-medium text-red-700" type="button">Quitar cobertura</button>
                </div>
                <div class="mt-4 grid gap-4 md:grid-cols-2">
                    <label class="text-sm font-medium">Tipo de vehículo
                        <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[{{ $coverageIndex }}][vehicle_kind]" required><option value="car" @selected(($coverage['vehicle_kind'] ?? '') === 'car')>Carro</option><option value="motorcycle" @selected(($coverage['vehicle_kind'] ?? '') === 'motorcycle')>Moto</option></select>
                    </label>
                    <label class="text-sm font-medium">Servicio
                        <select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[{{ $coverageIndex }}][service_type]" required><option value="private" @selected(($coverage['service_type'] ?? '') === 'private')>Particular</option><option value="taxi" @selected(($coverage['service_type'] ?? '') === 'taxi')>Taxi</option></select>
                    </label>
                    <label class="text-sm font-medium">Fecha real de revisión<input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="coverages[{{ $coverageIndex }}][verified_at]" value="{{ $coverage['verified_at'] ?? '' }}" required></label>
                    <label class="text-sm font-medium">Revisar nuevamente antes de<input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="coverages[{{ $coverageIndex }}][stale_after]" value="{{ $coverage['stale_after'] ?? '' }}" required></label>
                </div>
                <label class="mt-4 block text-sm font-medium">Fuentes HTTPS de la cobertura <span class="font-normal text-slate-500">(una por línea)</span><textarea class="mt-1 min-h-24 w-full rounded-md border border-slate-300 p-3" name="coverages[{{ $coverageIndex }}][source_urls]" required>{{ $coverage['source_urls'] ?? '' }}</textarea></label>
                <div class="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-slate-200 pt-5">
                    <div><p class="text-xs font-semibold uppercase text-teal-700">Reglas</p><p class="text-sm text-slate-600">Cada regla tiene vigencia, horario, placa aplicable y fuente propia.</p></div>
                    <button class="add-rule min-h-12 rounded-md border border-slate-300 px-4 text-sm font-medium" type="button">Agregar regla</button>
                </div>
                <div class="rule-list mt-4 space-y-4">
                    @foreach(($coverage['rules'] ?? []) as $ruleIndex => $rule)
                        @include('admin.restrictions.partials.rule-fields', ['coverageIndex' => $coverageIndex, 'ruleIndex' => $ruleIndex, 'rule' => $rule])
                    @endforeach
                </div>
                <label class="mt-4 flex min-h-12 items-center gap-3 rounded-md bg-amber-50 px-3 text-sm text-amber-950"><input type="checkbox" name="coverages[{{ $coverageIndex }}][confirmed_no_rules]" value="1" @checked(!empty($coverage['confirmed_no_rules']))>Confirmo que la fuente revisada no publica restricciones para esta cobertura.</label>
            </section>
        @endforeach
    </div>
    <div class="flex flex-wrap items-center gap-3"><button class="min-h-12 rounded-md border border-slate-300 px-4 font-medium" id="add-coverage" type="button">Agregar cobertura</button><button class="min-h-12 rounded-md bg-slate-900 px-5 font-semibold text-white" type="submit">Guardar borrador</button></div>
</form>

<template id="rule-template">@include('admin.restrictions.partials.rule-fields', ['coverageIndex' => '__COVERAGE__', 'ruleIndex' => '__RULE__', 'rule' => $defaultRule])</template>
<template id="coverage-template">
    <section class="coverage-card rounded-lg border border-slate-200 bg-white p-5" data-coverage-index="__COVERAGE__">
        <div class="flex flex-wrap items-center justify-between gap-3"><div><p class="text-xs font-semibold uppercase text-teal-700">Cobertura</p><h2 class="text-xl font-semibold">Vehículo y servicio</h2></div><button class="remove-coverage min-h-12 rounded-md border border-red-200 px-3 text-sm font-medium text-red-700" type="button">Quitar cobertura</button></div>
        <div class="mt-4 grid gap-4 md:grid-cols-2">
            <label class="text-sm font-medium">Tipo de vehículo<select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[__COVERAGE__][vehicle_kind]" required><option value="car">Carro</option><option value="motorcycle">Moto</option></select></label>
            <label class="text-sm font-medium">Servicio<select class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="coverages[__COVERAGE__][service_type]" required><option value="private">Particular</option><option value="taxi">Taxi</option></select></label>
            <label class="text-sm font-medium">Fecha real de revisión<input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="coverages[__COVERAGE__][verified_at]" required></label>
            <label class="text-sm font-medium">Revisar nuevamente antes de<input class="mt-1 min-h-12 w-full rounded-md border border-slate-300 px-3" type="datetime-local" name="coverages[__COVERAGE__][stale_after]" required></label>
        </div>
        <label class="mt-4 block text-sm font-medium">Fuentes HTTPS de la cobertura <span class="font-normal text-slate-500">(una por línea)</span><textarea class="mt-1 min-h-24 w-full rounded-md border border-slate-300 p-3" name="coverages[__COVERAGE__][source_urls]" required></textarea></label>
        <div class="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-slate-200 pt-5"><div><p class="text-xs font-semibold uppercase text-teal-700">Reglas</p><p class="text-sm text-slate-600">Cada regla tiene vigencia, horario, placa aplicable y fuente propia.</p></div><button class="add-rule min-h-12 rounded-md border border-slate-300 px-4 text-sm font-medium" type="button">Agregar regla</button></div>
        <div class="rule-list mt-4 space-y-4"></div>
        <label class="mt-4 flex min-h-12 items-center gap-3 rounded-md bg-amber-50 px-3 text-sm text-amber-950"><input type="checkbox" name="coverages[__COVERAGE__][confirmed_no_rules]" value="1">Confirmo que la fuente revisada no publica restricciones para esta cobertura.</label>
    </section>
</template>
<script>
document.addEventListener('DOMContentLoaded', () => {
    const coverageList = document.getElementById('coverage-list');
    const coverageTemplate = document.getElementById('coverage-template').innerHTML;
    const ruleTemplate = document.getElementById('rule-template').innerHTML;
    let nextCoverage = Math.max(-1, ...Array.from(coverageList.querySelectorAll('.coverage-card')).map((card) => Number(card.dataset.coverageIndex))) + 1;
    function addRule(card) {
        const coverage = card.dataset.coverageIndex;
        const list = card.querySelector('.rule-list');
        const rule = Math.max(-1, ...Array.from(list.querySelectorAll('.rule-card')).map((item) => Number(item.dataset.ruleIndex))) + 1;
        list.insertAdjacentHTML('beforeend', ruleTemplate.replaceAll('__COVERAGE__', coverage).replaceAll('__RULE__', rule));
    }
    document.getElementById('add-coverage').addEventListener('click', () => {
        const index = nextCoverage++;
        coverageList.insertAdjacentHTML('beforeend', coverageTemplate.replaceAll('__COVERAGE__', index));
        addRule(coverageList.lastElementChild);
    });
    coverageList.addEventListener('click', (event) => {
        if (event.target.closest('.add-rule')) addRule(event.target.closest('.coverage-card'));
        const removeRule = event.target.closest('.remove-rule');
        if (removeRule) removeRule.closest('.rule-card').remove();
        const removeCoverage = event.target.closest('.remove-coverage');
        if (removeCoverage && coverageList.querySelectorAll('.coverage-card').length > 1) removeCoverage.closest('.coverage-card').remove();
    });
});
</script>
@else
<div class="mt-6 rounded-lg border border-slate-200 bg-white p-5"><p class="font-medium">Esta versión no se puede editar.</p><p class="mt-1 text-sm text-slate-600">Duplica la versión para crear un nuevo borrador sin alterar el historial.</p><details class="mt-4"><summary class="cursor-pointer font-medium">Ver contrato técnico publicado</summary><pre class="mt-3 max-h-[36rem] overflow-auto rounded bg-slate-950 p-3 text-xs text-slate-100">{{ json_encode($version->payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre></details></div>
@endif

@if($version)
<div class="mt-6 flex flex-wrap gap-2">
    @can('datasets.edit')<form method="POST" action="{{ route('admin.restrictions.duplicate', $version) }}">@csrf<button class="min-h-12 rounded-md border border-slate-300 px-4">Duplicar</button></form><form method="POST" action="{{ route('admin.restrictions.archive', $version) }}">@csrf<button class="min-h-12 rounded-md border border-red-200 px-4 text-red-700">Archivar</button></form>@endcan
    @can('datasets.review')<form method="POST" action="{{ route('admin.restrictions.validate', $version) }}">@csrf<button class="min-h-12 rounded-md bg-teal-700 px-4 font-medium text-white">Validar</button></form>@endcan
</div>
@endif
@endsection
