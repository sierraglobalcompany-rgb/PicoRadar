@extends('layouts.admin',['title'=>'Review camera CSV | PicoRadar'])
@section('content')
<a class="text-sm underline" href="{{ route('admin.camera-csv-imports.index') }}">Back to CSV batches</a>
<div class="mt-4 flex flex-wrap items-center justify-between gap-3"><h1 class="text-3xl font-semibold">Camera CSV batch #{{ $batch->id }}</h1>
<a class="rounded border px-3 py-2 text-sm" href="{{ route('admin.camera-csv-imports.report',$batch) }}">Download safe CSV report</a></div>
<p class="mt-2 text-sm text-slate-700">{{ $batch->source->title }} · {{ $batch->jurisdiction->name }} · {{ $batch->mode }} · {{ $batch->status }}</p>
<p class="mt-1 break-all text-xs text-slate-500">Original SHA-256: {{ $batch->original_sha256 }}</p>
<div class="mt-5 flex flex-wrap gap-3 text-sm">
@foreach($analysis['counts'] as $status => $count)<span class="rounded border bg-white px-3 py-2">{{ str_replace('_',' ',$status) }}: <strong>{{ $count }}</strong></span>@endforeach
</div>
@if($batch->mode==='snapshot')
<p role="status" class="mt-4 rounded border bg-slate-100 p-3 text-sm"><strong>Absent identities: {{ $analysis['missing_advisory'] }}</strong>. This is advisory only. The import never retires or deletes cameras.</p>
@endif
@if($compareOptions->isNotEmpty())
<form method="GET" class="mt-5 flex flex-wrap items-end gap-3"><label class="grid gap-1 text-sm">Compare only same source/jurisdiction
<select class="rounded border p-2" name="compare" required><option value="">Choose prior batch</option>
@foreach($compareOptions as $option)<option value="{{ $option->id }}" @selected(request('compare')==$option->id)>Batch #{{ $option->id }} — {{ $option->created_at->format('Y-m-d H:i') }}</option>@endforeach
</select></label><button class="rounded border px-3 py-2">Compare</button></form>
@endif
@if($comparison)
<p class="mt-3 rounded border p-3 text-sm">Versus batch #{{ $comparison['other']->id }}: {{ $comparison['new'] }} identities new, {{ $comparison['changed'] }} changed, {{ $comparison['missing_advisory'] }} absent (advisory only).</p>
@endif

@php($mayApply=$batch->status==='review' && auth()->user()->can('cameras.edit') && auth()->user()->can('cameras.review'))
@if($mayApply)<form action="{{ route('admin.camera-csv-imports.apply',$batch) }}" method="POST" class="mt-5">
@csrf<input type="hidden" name="analysis_sha256" value="{{ $batch->analysis_sha256 }}">
<p class="mb-2 text-sm text-slate-700">Choose only safe rows. This is a single atomic apply; all selected rows are revalidated. A conflict stops all writes with HTTP 409.</p>
@else<div class="mt-5">@endif
<div class="max-h-[680px] overflow-auto rounded border bg-white">
<table class="w-full text-left text-sm">
<thead class="sticky top-0 bg-slate-100"><tr><th class="p-3">Select</th><th class="p-3">Record</th><th class="p-3">External ID</th><th class="p-3">Municipality</th><th class="p-3">Status</th><th class="p-3">Details</th></tr></thead>
<tbody>@forelse($analysis['rows'] as $row)
<tr class="border-t"><td class="p-3">
@if($mayApply && in_array($row['status'],['create_ready','update_ready'],true))
<input aria-label="Select record {{ $row['record'] }}" type="checkbox" name="records[]" value="{{ $row['record'] }}">
@endif</td>
<td class="p-3">{{ $row['record'] }}</td><td class="p-3">{{ $row['values']['external_id'] ?? '—' }}</td>
<td class="p-3">{{ $row['values']['municipality_code'] ?? '—' }}</td>
<td class="p-3">{{ $row['status'] }}</td><td class="p-3">{{ implode('; ',$row['errors']) ?: 'No errors' }}</td></tr>
@empty<tr><td class="p-4" colspan="6">No data rows found.</td></tr>@endforelse</tbody></table></div>
@if($mayApply)
<button type="submit" class="mt-5 rounded bg-slate-900 px-4 py-3 font-semibold text-white">Apply selected safe rows as draft only</button>
<p class="mt-2 text-xs text-slate-600">Requires both editor and reviewer permissions. No publish or verify operations are run.</p>
</form>
@else</div>@endif
@endsection
