@extends('layouts.admin',['title'=>'CSV review needs attention | PicoRadar'])
@section('content')
<a class="text-sm underline" href="{{ route('admin.camera-csv-imports.index') }}">Back to CSV batches</a>
<section class="mt-4 max-w-3xl rounded border border-amber-300 bg-amber-50 p-5 text-amber-950" role="alert">
    <h1 class="text-2xl font-semibold">CSV review needs attention</h1>
    <p class="mt-3">This review is no longer current or could not be verified.</p>
    <p class="mt-2">No camera changes were made by this request. Analyze the CSV again against the current source and jurisdiction before applying it.</p>
    <div class="mt-5 flex flex-wrap gap-3">
        <a class="rounded bg-slate-900 px-4 py-3 font-semibold text-white" href="{{ route('admin.camera-csv-imports.create') }}">Analyze a new CSV</a>
        <a class="rounded border border-amber-700 px-4 py-3 font-semibold" href="{{ route('admin.camera-csv-imports.index') }}">Return to CSV batches</a>
    </div>
</section>
@endsection
