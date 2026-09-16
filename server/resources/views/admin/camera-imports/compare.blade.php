@extends('layouts.admin',['title'=>'Camera import comparison | PicoRadar'])
@section('content')
<h1 class="text-3xl font-semibold">Import comparison</h1>
<p class="mt-2">Run #{{ $run->id }} → #{{ $otherRun->id }}. Removed rows are advisory only; no camera lifecycle is changed.</p>
<dl class="mt-6 grid gap-3 rounded border bg-white p-4 md:grid-cols-3">@foreach($comparison['counts'] as $category => $count)<div><dt>{{ str_replace('_',' ',$category) }}</dt><dd>{{ $count }}</dd></div>@endforeach</dl>
@if($comparison['suspiciousSnapshotDrop'])<p class="mt-4 rounded border bg-amber-50 p-3">Suspicious snapshot drop: {{ $comparison['snapshotDropPercent'] }}%.</p>@endif
<div class="mt-6 overflow-x-auto rounded border bg-white"><table class="w-full text-left"><thead><tr><th>External ID</th><th>Changed fields</th><th>Distance (m)</th><th>High risk</th></tr></thead><tbody>@forelse($comparison['changed'] as $row)<tr class="border-t"><td>{{ $row['externalId'] }}</td><td>{{ implode(', ', $row['fields']) }}</td><td>{{ $row['distanceMeters'] }}</td><td>{{ $row['highRisk'] ? 'Yes' : 'No' }}</td></tr>@empty<tr><td class="p-4" colspan="4">No changed identities.</td></tr>@endforelse</tbody></table></div>
@endsection
