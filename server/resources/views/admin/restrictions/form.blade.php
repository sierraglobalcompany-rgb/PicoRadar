@extends('layouts.admin', ['title' => 'Borrador de reglas | PicoRadar'])

@php
    $formatDate = static fn ($value) => filled($value) ? \Carbon\CarbonImmutable::parse($value)->format('Y-m-d\TH:i') : '';
    $formatWindows = static function ($windows): string {
        if (! is_array($windows)) return '';
        return collect($windows)->map(static function ($window): string {
            $start = (int) ($window['startMinute'] ?? 0);
            $end = (int) ($window['endMinute'] ?? 0);
            return sprintf('%02d:%02d-%02d:%02d', intdiv($start, 60), $start % 60, intdiv($end, 60), $end % 60).(!empty($window['fullDay']) ? ' fullDay' : '');
        })->implode("\n");
    };
    $payloadCoverages = collect($version?->payload['coverages'] ?? [])->map(static function ($coverage) use ($formatDate, $formatWindows): array {
        return [
            'vehicle_kind' => $coverage['vehicleKind'] ?? 'car',
            'service_type' => $coverage['serviceType'] ?? 'private',
            'pair' => ($coverage['vehicleKind'] ?? 'car').'|'.($coverage['serviceType'] ?? 'private'),
            'coverage_completeness' => $coverage['coverageCompleteness'] ?? null,
            'verified_at' => $formatDate($coverage['verifiedAt'] ?? null),
            'stale_after' => $formatDate($coverage['staleAfter'] ?? null),
            'source_urls' => implode("\n", $coverage['sourceUrls'] ?? []),
            'confirmed_no_rules' => empty($coverage['rules']) && ($coverage['coverageCompleteness'] ?? 'legacy') !== 'partial',
            // Partial without rules cannot establish circulation permission.
            'suspend_consultation' => empty($coverage['rules']) && ($coverage['coverageCompleteness'] ?? null) === 'partial',
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
                'conditions_json' => json_encode($rule['conditions'] ?? [], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            ])->all(),
        ];
    })->all();
    $defaultRule = [
        'id' => '', 'priority' => 1000, 'effect' => 'restrict', 'valid_from' => '', 'valid_until' => '',
        'weekdays' => '1,2,3,4,5', 'date_parity' => '', 'digit_position' => 'lastNumeric', 'digits' => '',
        'time_windows' => '06:00-20:00', 'applies_on_holidays' => false, 'source_url' => '',
        'verified_at' => '', 'registration_origins' => '', 'conditions_json' => '[]',
    ];
    $defaultCoverage = [
        'vehicle_kind' => 'car', 'service_type' => 'private', 'pair' => 'car|private', 'coverage_completeness' => 'partial', 'verified_at' => '', 'stale_after' => '',
        'source_urls' => '', 'confirmed_no_rules' => false, 'suspend_consultation' => false, 'rules' => [$defaultRule],
    ];
    $templateCoverage = $defaultCoverage;
    $templateCoverage['rules'] = [];
    $isSchema2 = (int) $schemaVersion === 2;
    $pairOptions = [
        'car|private' => 'Carro · particular', 'car|taxi' => 'Carro · taxi', 'car|special' => 'Carro · especial',
        'motorcycle|private' => 'Moto · particular', 'truck|private' => 'Camión · particular',
        'truck|public_cargo' => 'Camión · carga pública', 'bus|public_passenger' => 'Bus · transporte público',
        'bus|special' => 'Bus · especial', 'motocarro|private' => 'Motocarro · particular',
    ];
    $coverages = old('coverages', $payloadCoverages ?: [$defaultCoverage]);
    $oldJurisdictionId = old('jurisdiction_id');
    $oldJurisdiction = (is_int($oldJurisdictionId) || (is_string($oldJurisdictionId) && strlen($oldJurisdictionId) <= 19 && ctype_digit($oldJurisdictionId)))
        ? $jurisdictions->first(fn ($jurisdiction) => (string) $jurisdiction->id === (string) $oldJurisdictionId)
        : null;
    $preselectedJurisdiction = isset($preselectedJurisdictionId)
        ? $jurisdictions->firstWhere('id', $preselectedJurisdictionId)
        : null;
    $formJurisdiction = $version?->jurisdiction ?? $oldJurisdiction ?? $preselectedJurisdiction;
    $primaryMunicipalityCode = $formJurisdiction?->primaryGeographicUnit?->code;
    $primaryMunicipalityCode = is_string($primaryMunicipalityCode) && preg_match('/^\d{5}$/', $primaryMunicipalityCode)
        ? $primaryMunicipalityCode
        : null;
    $payloadMunicipalityCodes = $version?->payload['municipalityCodes'] ?? null;
    $municipalityCodes = is_array($payloadMunicipalityCodes)
        ? array_values(array_filter($payloadMunicipalityCodes, static fn ($code) => is_string($code) && preg_match('/^\d{5}$/', $code)))
        : ($primaryMunicipalityCode !== null ? [$primaryMunicipalityCode] : []);
    $hasMunicipalityCode = $primaryMunicipalityCode !== null && in_array($primaryMunicipalityCode, $municipalityCodes, true);
    $oldJurisdictionIsScalar = is_int($oldJurisdictionId) || is_string($oldJurisdictionId);
    $oldJurisdictionMatches = $version
        ? (!session()->hasOldInput('jurisdiction_id') || ($oldJurisdictionIsScalar && (string) $oldJurisdictionId === (string) $formJurisdiction?->id))
        : ($oldJurisdiction !== null && $formJurisdiction?->is($oldJurisdiction));
    $consultationValue = session()->hasOldInput('consultation_enabled') && $oldJurisdictionMatches
        ? old('consultation_enabled')
        : ($version?->payload['consultationEnabled'] ?? false);
    $consultationEnabled = $hasMunicipalityCode && in_array($consultationValue, [true, 1, '1', 'true', 'on', 'yes'], true);
@endphp

@section('content')
<div class="flex flex-wrap items-start justify-between gap-3">
    <div>
        <p class="text-sm font-medium text-teal-700">Pico y placa</p>
        <h1 class="mt-1 text-3xl font-semibold">{{ $version ? 'Borrador '.$version->jurisdiction->name.' v'.$version->version : ($isSchema2 ? 'Nuevo borrador nacional schema2' : 'Nuevo borrador de ciudad') }}</h1>
        <p class="mt-2 max-w-3xl text-sm text-slate-600">Define coberturas y reglas con la fuente oficial. Este editor no consulta servicios externos. Guardar crea un borrador; no publica ni habilita consulta pública.</p>
    </div>
    <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 px-4 font-medium" href="{{ route('admin.restrictions.index') }}">Volver</a>
</div>

@if(!$version || ($editable ?? false))
<form class="mt-6 space-y-5" method="POST" action="{{ $version ? route('admin.restrictions.update', $version) : route('admin.restrictions.store') }}" id="restriction-form">
    @csrf
    @if($version) @method('PUT') @else
        <label class="block max-w-xl text-sm font-medium">Ciudad
            <select class="mt-1 block min-h-12 w-full rounded-md border border-slate-300 bg-white px-3" name="jurisdiction_id" required>
                <option value="" disabled @selected($formJurisdiction === null)>Selecciona municipio y jurisdicción</option>
                @foreach($jurisdictions as $jurisdiction)
                    @php($optionMunicipalityCode = $jurisdiction->primaryGeographicUnit?->code)
                    <option value="{{ $jurisdiction->id }}" data-municipality-code="{{ is_string($optionMunicipalityCode) && preg_match('/^\d{5}$/', $optionMunicipalityCode) ? $optionMunicipalityCode : '' }}" data-management-state="{{ $jurisdiction->enabled ? 'activa' : 'inactiva' }}" @selected($formJurisdiction?->is($jurisdiction))>{{ $jurisdiction->name }} · {{ $jurisdiction->key }}</option>
                @endforeach
            </select>
        </label>
    @endif

    @if($isSchema2)
        <section class="rounded-lg border border-sky-200 bg-sky-50 p-4 text-sm text-sky-950" aria-label="Disponibilidad de consulta schema2">
            <p class="font-semibold">Contrato schema2 · coberturas parciales</p>
            <p class="mt-1">Las coberturas nuevas quedan en <code>partial</code>. Esto no certifica cobertura nacional ni permite asumir circulación cuando falten datos.</p>
            <div class="mt-3 grid gap-3 md:grid-cols-2">
                <label class="font-medium">Código municipal DIVIPOLA
                    <input id="municipality-code" class="mt-1 min-h-12 w-full rounded-md border border-slate-300 bg-slate-100 px-3" value="{{ implode(', ', $municipalityCodes) }}" readonly aria-describedby="availability-help">
                </label>
                <div class="flex min-h-12 flex-wrap items-center gap-3 rounded-md bg-white px-3">
                    <input type="hidden" name="consultation_enabled" value="0">
                    <input id="consultation-enabled" type="checkbox" name="consultation_enabled" value="1" @checked($consultationEnabled) @disabled(!$hasMunicipalityCode)>
                    <label for="consultation-enabled" class="font-medium">Consulta pública habilitada</label>
                    <span id="consultation-availability-note" class="text-sm text-amber-900" @if($hasMunicipalityCode) hidden @endif>Selecciona un municipio con DIVIPOLA válido para habilitar esta opción.</span>
                </div>
            </div>
            <p id="availability-help" class="mt-2">Administración territorial: <strong id="jurisdiction-management-state">{{ $formJurisdiction ? ($formJurisdiction->enabled ? 'activa' : 'inactiva') : 'sin municipio seleccionado' }}</strong>. <code>Jurisdiction.enabled</code> solo controla la gestión y no cambia el dataset publicado. El código procede del municipio seleccionado y no se edita aquí; cambiar de municipio desactiva la casilla hasta una decisión manual.</p>
        </section>
    @endif

    <div class="space-y-5" id="coverage-list">
        @foreach($coverages as $coverageIndex => $coverage)
            @include('admin.restrictions.partials.coverage-fields', ['coverageIndex' => $coverageIndex, 'coverage' => $coverage, 'schemaVersion' => (int) $schemaVersion, 'pairOptions' => $pairOptions])
        @endforeach
    </div>
    @error('coverages')<p class="rounded-md bg-red-50 p-3 text-sm text-red-800" role="alert">{{ $message }}</p>@enderror
    <div class="flex flex-wrap items-center gap-3"><button class="min-h-12 rounded-md border border-slate-300 px-4 font-medium" id="add-coverage" type="button">Agregar cobertura</button><button class="min-h-12 rounded-md bg-slate-900 px-5 font-semibold text-white" type="submit">Guardar borrador</button></div>
</form>

<template id="rule-template">@include('admin.restrictions.partials.rule-fields', ['coverageIndex' => '__COVERAGE__', 'ruleIndex' => '__RULE__', 'rule' => $defaultRule, 'schemaVersion' => (int) $schemaVersion])</template>
<template id="coverage-template">@include('admin.restrictions.partials.coverage-fields', ['coverageIndex' => '__COVERAGE__', 'coverage' => $templateCoverage, 'schemaVersion' => (int) $schemaVersion, 'pairOptions' => $pairOptions])</template>
<script>
document.addEventListener('DOMContentLoaded', () => {
    const coverageList = document.getElementById('coverage-list');
    const coverageTemplate = document.getElementById('coverage-template').innerHTML;
    const ruleTemplate = document.getElementById('rule-template').innerHTML;
    const maximumCoverages = {{ $isSchema2 ? 9 : 8 }};
    const addCoverageButton = document.getElementById('add-coverage');
    let nextCoverage = Math.max(-1, ...Array.from(coverageList.querySelectorAll('.coverage-card')).map((card) => Number(card.dataset.coverageIndex))) + 1;
    function refreshCoverageLimit() {
        const atLimit = coverageList.querySelectorAll('.coverage-card').length >= maximumCoverages;
        addCoverageButton.disabled = atLimit;
        addCoverageButton.setAttribute('aria-disabled', String(atLimit));
        addCoverageButton.title = atLimit ? `Máximo ${maximumCoverages} coberturas` : '';
    }
    function addRule(card) {
        const coverage = card.dataset.coverageIndex;
        const list = card.querySelector('.rule-list');
        const rule = Math.max(-1, ...Array.from(list.querySelectorAll('.rule-card')).map((item) => Number(item.dataset.ruleIndex))) + 1;
        list.insertAdjacentHTML('beforeend', ruleTemplate.replaceAll('__COVERAGE__', coverage).replaceAll('__RULE__', rule));
    }
    addCoverageButton.addEventListener('click', () => {
        if (coverageList.querySelectorAll('.coverage-card').length >= maximumCoverages) return;
        const index = nextCoverage++;
        coverageList.insertAdjacentHTML('beforeend', coverageTemplate.replaceAll('__COVERAGE__', index));
        addRule(coverageList.lastElementChild);
        refreshCoverageLimit();
    });
    coverageList.addEventListener('click', (event) => {
        if (event.target.closest('.add-rule')) addRule(event.target.closest('.coverage-card'));
        const removeRule = event.target.closest('.remove-rule');
        if (removeRule) removeRule.closest('.rule-card').remove();
        const removeCoverage = event.target.closest('.remove-coverage');
        if (removeCoverage && coverageList.querySelectorAll('.coverage-card').length > 1) {
            removeCoverage.closest('.coverage-card').remove();
            refreshCoverageLimit();
        }
    });
    const jurisdictionSelect = document.querySelector('select[name="jurisdiction_id"]');
    if (jurisdictionSelect) jurisdictionSelect.addEventListener('change', () => {
        const codeInput = document.getElementById('municipality-code');
        const consultationCheckbox = document.getElementById('consultation-enabled');
        const consultationNote = document.getElementById('consultation-availability-note');
        const managementState = document.getElementById('jurisdiction-management-state');
        const selectedOption = jurisdictionSelect.selectedOptions[0];
        const selectedCode = selectedOption?.dataset.municipalityCode ?? '';
        const hasMunicipalityCode = /^\d{5}$/.test(selectedCode);
        if (managementState) managementState.textContent = selectedOption?.dataset.managementState ?? 'sin municipio seleccionado';
        if (codeInput) codeInput.value = hasMunicipalityCode ? selectedCode : '';
        if (consultationNote) consultationNote.hidden = hasMunicipalityCode;
        if (consultationCheckbox) {
            consultationCheckbox.checked = false;
            consultationCheckbox.disabled = !hasMunicipalityCode;
        }
    });
    refreshCoverageLimit();
});
</script>
@else
<div class="mt-6 rounded-lg border border-slate-200 bg-white p-5"><p class="font-medium">Esta versión no se puede editar con este formulario.</p>
<p class="mt-1 text-sm text-slate-600">Duplica la versión para crear un nuevo borrador sin alterar el historial.</p>
<details class="mt-4"><summary class="cursor-pointer font-medium">Ver contrato técnico conservado</summary><pre class="mt-3 max-h-[36rem] overflow-auto rounded bg-slate-950 p-3 text-xs text-slate-100">{{ json_encode($version->payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) }}</pre></details></div>
@endif

@if($version)
<div class="mt-6 flex flex-wrap gap-2">
    @can('datasets.edit')<form method="POST" action="{{ route('admin.restrictions.duplicate', $version) }}">@csrf<button class="min-h-12 rounded-md border border-slate-300 px-4">Duplicar</button></form><form method="POST" action="{{ route('admin.restrictions.archive', $version) }}">@csrf<button class="min-h-12 rounded-md border border-red-200 px-4 text-red-700">Archivar</button></form>@endcan
    @can('datasets.review')<form method="POST" action="{{ route('admin.restrictions.validate', $version) }}">@csrf<button class="min-h-12 rounded-md bg-teal-700 px-4 font-medium text-white">Validar</button></form>@endcan
</div>
@endif
@endsection
