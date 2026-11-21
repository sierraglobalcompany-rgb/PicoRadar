@extends('layouts.admin', ['title' => 'Geography | PicoRadar Control Plane'])
@section('content')
    <div><p class="text-sm font-medium text-teal-700">Canonical DANE geography</p><h1 class="mt-1 text-3xl font-semibold">Geography</h1><p class="mt-2 text-slate-600">Read-only DIVIPOLA/MGN identity and hierarchy. No geometry is stored.</p></div>
    <form class="mt-6 grid gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4" method="GET">
        <input class="rounded border-slate-300" name="q" value="{{ request('q') }}" placeholder="Medellín or 05001">
        <select class="rounded border-slate-300" name="level"><option value="">All levels</option>@foreach($levels as $level)<option value="{{ $level->value }}" @selected(request('level') === $level->value)>{{ $level->value }}</option>@endforeach</select>
        <select class="rounded border-slate-300" name="department"><option value="">All departments</option>@foreach($departments as $department)<option value="{{ $department->id }}" @selected((int) request('department') === $department->id)>{{ $department->name }}</option>@endforeach</select>
        <button class="rounded bg-slate-900 px-4 py-2 font-medium text-white">Search</button>
    </form>
    <div class="mt-6 overflow-x-auto rounded-xl border border-slate-200 bg-white"><table class="min-w-full text-sm"><thead class="bg-slate-50 text-left text-slate-600"><tr><th class="p-3">Level</th><th class="p-3">Code</th><th class="p-3">Name</th><th class="p-3">Parent</th><th class="p-3">Source</th><th class="p-3">Active</th></tr></thead><tbody>@forelse($units as $unit)<tr class="border-t"><td class="p-3">{{ $unit->level->value }}</td><td class="p-3 font-mono">{{ $unit->code }}</td><td class="p-3">{{ $unit->name }}</td><td class="p-3">{{ $unit->parent?->name ?? '—' }}</td><td class="p-3">{{ $unit->source_system }} / {{ $unit->source_version }}</td><td class="p-3">{{ $unit->is_active ? 'yes' : 'no' }}</td></tr>@empty<tr><td class="p-3" colspan="6">No geographic units found.</td></tr>@endforelse</tbody></table></div>
    <div class="mt-4">{{ $units->links() }}</div>
@endsection
