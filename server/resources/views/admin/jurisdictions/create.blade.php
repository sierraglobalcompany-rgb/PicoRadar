@extends('layouts.admin', ['title' => 'Create jurisdiction | PicoRadar Control Plane'])
@section('content')
    <h1 class="text-3xl font-semibold">Create jurisdiction</h1>
    @php
        $oldPrimaryGeographicUnitInput = old('primary_geographic_unit_id');
        $oldPrimaryGeographicUnitId = is_int($oldPrimaryGeographicUnitInput)
            ? $oldPrimaryGeographicUnitInput
            : (is_string($oldPrimaryGeographicUnitInput) && strlen($oldPrimaryGeographicUnitInput) <= 19
                ? filter_var($oldPrimaryGeographicUnitInput, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]])
                : false);
        $oldPrimaryGeographicUnitId = $oldPrimaryGeographicUnitId !== false && $oldPrimaryGeographicUnitId > 0
            ? (int) $oldPrimaryGeographicUnitId
            : null;
        $oldMunicipalityIsAvailable = $oldPrimaryGeographicUnitId !== null
            && $geography->contains(fn ($unit) => $unit->id === $oldPrimaryGeographicUnitId);
        $selectedPrimaryGeographicUnitId = $oldMunicipalityIsAvailable
            ? $oldPrimaryGeographicUnitId
            : $preselectedMunicipalityId;
    @endphp
    <form class="mt-6 space-y-4 rounded-xl border border-slate-200 bg-white p-6" method="POST" action="{{ route('admin.jurisdictions.store') }}">@csrf
        <label class="block">Key<input class="mt-1 block w-full rounded border-slate-300" name="key" value="{{ old('key') }}" required></label>
        <label class="block">Name<input class="mt-1 block w-full rounded border-slate-300" name="name" value="{{ old('name') }}" required></label>
        <label class="block">Kind<select class="mt-1 block w-full rounded border-slate-300" name="kind">@foreach($kinds as $kind)<option value="{{ $kind->value }}">{{ $kind->value }}</option>@endforeach</select></label>
        <label class="block">Primary geography<select class="mt-1 block w-full rounded border-slate-300" name="primary_geographic_unit_id"><option value="" @selected($selectedPrimaryGeographicUnitId === null)>Select a municipality</option>@foreach($geography as $unit)<option value="{{ $unit->id }}" @selected($selectedPrimaryGeographicUnitId === $unit->id)>{{ $unit->name }} — {{ $unit->parent?->name }}</option>@endforeach</select></label>
        <label class="block">Timezone<input class="mt-1 block w-full rounded border-slate-300" name="timezone" value="America/Bogota" required></label>
        <label class="flex items-center gap-2"><input type="hidden" name="enabled" value="0"><input type="checkbox" name="enabled" value="1"> Enabled</label>
        @if($errors->any())<p class="text-sm text-red-700">{{ $errors->first() }}</p>@endif
        <button class="rounded bg-slate-900 px-4 py-2 font-medium text-white">Create</button>
    </form>
@endsection
