@extends('layouts.admin', ['title' => 'Jurisdictions | PicoRadar Control Plane'])
@section('content')
    <div class="flex items-center justify-between"><div><p class="text-sm font-medium text-teal-700">Operational territories</p><h1 class="mt-1 text-3xl font-semibold">Jurisdictions</h1></div>@can('jurisdictions.edit')<a class="rounded bg-slate-900 px-4 py-2 font-medium text-white" href="{{ route('admin.jurisdictions.create') }}">Create jurisdiction</a>@endcan</div>
    <div class="mt-6 space-y-3">@forelse($jurisdictions as $jurisdiction)<a class="block rounded-xl border border-slate-200 bg-white p-4" href="{{ route('admin.jurisdictions.show', $jurisdiction) }}"><strong>{{ $jurisdiction->name }}</strong><p class="text-sm text-slate-600">{{ $jurisdiction->key }} · {{ $jurisdiction->kind->value }} · primary {{ $jurisdiction->primaryGeographicUnit->name }} · {{ $jurisdiction->enabled ? 'enabled' : 'disabled' }}</p></a>@empty<p class="text-slate-600">No jurisdictions.</p>@endforelse</div>
    <div class="mt-4">{{ $jurisdictions->links() }}</div>
@endsection
