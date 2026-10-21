@extends('layouts.admin', ['title' => 'Partner inquiry audit | PicoRadar Control Plane'])

@section('content')
    <h1 class="text-3xl font-semibold">Partner inquiry status audit</h1>
    <p class="mt-2 text-slate-600">Append-only status changes. Contact details are deliberately excluded from audit metadata.</p>
    <div class="mt-6 overflow-x-auto rounded border bg-white">
        <table class="min-w-full text-left text-sm">
            <thead class="bg-slate-100 text-slate-600"><tr><th class="p-3">When</th><th class="p-3">Actor</th><th class="p-3">Action</th><th class="p-3">Metadata</th></tr></thead>
            <tbody>@forelse($logs as $log)<tr class="border-t"><td class="p-3">{{ $log->created_at?->toAtomString() }}</td><td class="p-3">{{ $log->actor?->email ?? 'System' }}</td><td class="p-3">{{ $log->action }}</td><td class="p-3"><code>{{ json_encode($log->metadata, JSON_UNESCAPED_SLASHES) }}</code></td></tr>@empty<tr><td class="p-3" colspan="4">No status changes yet.</td></tr>@endforelse</tbody>
        </table>
    </div>
    <div class="mt-4">{{ $logs->links() }}</div>
@endsection
