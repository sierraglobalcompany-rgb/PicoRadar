@extends('layouts.admin', ['title' => 'Audit log | PicoRadar Control Plane'])

@section('content')
    <h1 class="text-3xl font-semibold">Dataset audit log</h1>
    <p class="mt-2 text-slate-600">Append-only B01 administrative events. Raw dataset files are never shown or stored here.</p>

    <div class="mt-6 overflow-x-auto rounded border bg-white">
        <table class="min-w-full text-left text-sm">
            <thead class="bg-slate-100 text-slate-600"><tr><th class="p-3">When</th><th class="p-3">Actor</th><th class="p-3">Action</th><th class="p-3">Subject</th><th class="p-3">Metadata</th></tr></thead>
            <tbody>@forelse($logs as $log)<tr class="border-t"><td class="p-3">{{ $log->created_at?->toAtomString() }}</td><td class="p-3">{{ $log->actor?->email ?? 'System' }}</td><td class="p-3">{{ $log->action }}</td><td class="p-3">{{ class_basename($log->subject_type) }} #{{ $log->subject_id ?? '—' }}</td><td class="p-3"><code>{{ json_encode($log->metadata, JSON_UNESCAPED_SLASHES) }}</code></td></tr>@empty<tr><td class="p-3" colspan="5">No events yet.</td></tr>@endforelse</tbody>
        </table>
    </div>
@endsection
