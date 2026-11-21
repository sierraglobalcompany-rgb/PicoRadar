@extends('layouts.admin', ['title' => 'Datasets | PicoRadar Control Plane'])
@section('content')
    <div class="flex items-center justify-between"><div><p class="text-sm font-medium text-teal-700">Dataset registry</p><h1 class="mt-1 text-3xl font-semibold">Datasets</h1></div>@can('datasets.edit')<a class="rounded-md bg-slate-900 px-4 py-2 text-white" href="{{ route('admin.datasets.create') }}">Create dataset</a>@endcan</div>
    <div class="mt-8 space-y-3">@forelse($datasets as $dataset)<a class="block rounded-xl border border-slate-200 bg-white p-5" href="{{ route('admin.datasets.show', $dataset) }}"><strong>{{ $dataset->title }}</strong><p class="text-sm text-slate-600">{{ $dataset->key }} · schema {{ $dataset->schema_version }} · current {{ $dataset->current_version ?? 'none' }} · {{ $dataset->enabled ? 'enabled' : 'disabled' }}</p></a>@empty<p class="text-slate-600">No datasets registered.</p>@endforelse</div>
@endsection
