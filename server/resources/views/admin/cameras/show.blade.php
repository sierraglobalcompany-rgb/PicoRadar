@extends('layouts.admin', ['title' => 'Camera | PicoRadar'])

@section('content')
<div class="flex justify-between"><div><h1 class="text-3xl font-semibold">{{ $camera->camera_id }}</h1><p>{{ $camera->status->value }} · {{ $camera->lat }}, {{ $camera->lon }}</p></div>@can('cameras.edit')<a class="underline" href="{{ route('admin.cameras.edit', $camera) }}">Edit</a>@endcan</div>
<dl class="mt-6 grid gap-3 rounded border bg-white p-5 md:grid-cols-2"><div><dt>Jurisdiction</dt><dd>{{ $camera->jurisdiction->name }}</dd></div><div><dt>Municipality</dt><dd>{{ $camera->geographicUnit->name }}</dd></div><div><dt>Source</dt><dd>{{ $camera->source->title }}</dd></div><div><dt>Type / speed</dt><dd>{{ $camera->type->value }} · {{ $camera->speed_limit ?? 'not recorded' }} · {{ $camera->speed_limit_verified ? 'verified' : 'not verified' }}</dd></div></dl>
@can('cameras.edit')
<div class="mt-5 flex flex-wrap gap-2">
@if(in_array($camera->status->value, ['draft', 'rejected']))<form method="POST" action="{{ route('admin.cameras.submit', $camera) }}">@csrf<button class="rounded border px-3">{{ $camera->status->value === 'rejected' ? 'Resubmit for review' : 'Submit for review' }}</button></form>@endif
@if($camera->status->value === 'in_review')<form method="POST" action="{{ route('admin.cameras.withdraw', $camera) }}">@csrf<button class="rounded border px-3">Withdraw</button></form>@endif
</div>
@endcan
@can('cameras.reopen')
@if(in_array($camera->status->value, ['active', 'verified', 'inactive']))<form class="mt-3" method="POST" action="{{ route('admin.cameras.reopen', $camera) }}">@csrf<input required name="reason" placeholder="Correction reason"><button class="rounded border px-3">Reopen</button></form>@endif
@endcan
@can('cameras.review')
@if($camera->status->value === 'active')<form class="mt-3" method="POST" action="{{ route('admin.cameras.deactivate', $camera) }}">@csrf<input required name="reason" placeholder="Deactivation reason"><button class="rounded border px-3">Deactivate</button></form>@endif
@if(in_array($camera->status->value, ['active', 'inactive']))<form class="mt-3" method="POST" action="{{ route('admin.cameras.retire', $camera) }}">@csrf<input required name="reason" placeholder="Retirement reason"><button class="rounded border px-3">Retire</button></form>@endif
@if($camera->status->value === 'in_review')<div class="mt-5 flex gap-3"><form method="POST" action="{{ route('admin.cameras.verify', $camera) }}">@csrf<label><input type="checkbox" name="speed_limit_verified" value="1"> Speed limit verified</label><button class="rounded bg-slate-900 px-3 py-1 text-white">Verify</button></form><form method="POST" action="{{ route('admin.cameras.reject', $camera) }}">@csrf<input required name="reason" placeholder="Rejection reason"><button class="rounded border px-3">Reject</button></form></div>@endif
@if(in_array($camera->status->value, ['verified', 'inactive']))<form class="mt-3" method="POST" action="{{ route('admin.cameras.activate', $camera) }}">@csrf<button class="rounded bg-slate-900 px-3 py-1 text-white">Activate</button></form>@endif
@endcan
<section class="mt-8"><h2 class="text-xl font-semibold">Verification history</h2><table class="mt-2 w-full"><thead><tr><th>Decision</th><th>Reviewer</th><th>Notes</th><th>Recorded</th></tr></thead><tbody>@forelse($camera->verifications as $verification)<tr><td>{{ $verification->decision->value }}</td><td>{{ $verification->reviewer_id ?? 'system' }}</td><td>{{ $verification->notes ?: '—' }}</td><td>{{ $verification->created_at }}</td></tr>@empty<tr><td colspan="4">No verification history.</td></tr>@endforelse</tbody></table></section>
<section class="mt-8"><h2 class="text-xl font-semibold">Possible nearby duplicates</h2>@if($duplicateScanCapped)<p class="mt-2 rounded border border-amber-400 bg-amber-50 p-3 text-amber-900">Candidate scan capped; additional nearby records may exist.</p>@endif<table class="mt-2 w-full"><thead><tr><th>Camera</th><th>Distance</th><th>Source</th></tr></thead><tbody>@forelse($duplicates as $duplicate)<tr><td><a class="underline" href="{{ route('admin.cameras.show', $duplicate['camera']) }}">{{ $duplicate['camera']->camera_id }}</a></td><td>{{ round($duplicate['distanceMeters'], 2) }} m</td><td>{{ $duplicate['camera']->source->title }}</td></tr>@empty<tr><td colspan="3">{{ $duplicateScanCapped ? 'No candidates in the bounded scan.' : 'None.' }}</td></tr>@endforelse</tbody></table></section>
@endsection
