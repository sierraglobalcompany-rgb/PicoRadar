@extends('layouts.admin',['title'=>'Camera CSV batches | PicoRadar'])
@section('content')
<div class="flex flex-wrap items-center justify-between gap-3">
    <h1 class="text-3xl font-semibold">CSV camera batches</h1>
    @can('cameras.edit')<a class="rounded bg-slate-900 px-4 py-2 text-white" href="{{ route('admin.camera-csv-imports.create') }}">Analyze new CSV</a>@endcan
</div>
<p class="mt-3 text-sm text-slate-600">Batches are private. Analysis does not activate, verify or publish cameras.</p>
<div class="mt-6 overflow-x-auto rounded border bg-white">
    <table class="w-full text-left text-sm">
        <thead><tr class="bg-slate-100"><th class="p-3">Batch</th><th class="p-3">Source</th><th class="p-3">Jurisdiction</th><th class="p-3">Mode</th><th class="p-3">Status</th><th class="p-3">Rows</th><th class="p-3">Created</th></tr></thead>
        <tbody>@forelse($batches as $batch)
            <tr class="border-t">
                <td class="p-3"><a class="underline" href="{{ route('admin.camera-csv-imports.show',$batch) }}">#{{ $batch->id }}</a></td>
                <td class="p-3">{{ $batch->source->title }}</td><td class="p-3">{{ $batch->jurisdiction->name }}</td>
                <td class="p-3">{{ $batch->mode }}</td><td class="p-3">{{ $batch->status }}</td>
                <td class="p-3">{{ $batch->row_count }}</td><td class="p-3">{{ $batch->created_at->format('Y-m-d H:i') }}</td>
            </tr>
        @empty<tr><td colspan="7" class="p-4">No CSV batches have been analyzed.</td></tr>@endforelse</tbody>
    </table>
</div>
<div class="mt-4">{{ $batches->links() }}</div>
@endsection
