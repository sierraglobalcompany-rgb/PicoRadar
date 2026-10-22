@extends('layouts.admin',['title'=>'Analyze camera CSV | PicoRadar'])
@section('content')
<a class="text-sm underline" href="{{ route('admin.camera-csv-imports.index') }}">Back to CSV batches</a>
<h1 class="mt-4 text-3xl font-semibold">Analyze camera CSV</h1>
<p class="mt-2 text-sm text-slate-600">Upload up to 5 MiB and 2,000 records. Each batch belongs to one verified source and one jurisdiction. Only draft/rejected cameras may be changed; uploads never publish cameras.</p>
<a class="mt-3 inline-block text-sm underline" href="{{ route('admin.camera-csv-imports.template') }}">Download exact CSV header template</a>
<form method="POST" action="{{ route('admin.camera-csv-imports.store') }}" enctype="multipart/form-data" class="mt-6 grid gap-5 rounded border bg-white p-5">
    @csrf
    <label class="grid gap-1 text-sm font-medium" for="csv-source">Verified source
        <select id="csv-source" name="source_id" class="rounded border p-2" required>
            <option value="">Choose source</option>
            @foreach($sources as $source)<option value="{{ $source->id }}" @selected(old('source_id')==$source->id)>{{ $source->title }}</option>@endforeach
        </select>
    </label>
    <label class="grid gap-1 text-sm font-medium" for="csv-jurisdiction">Jurisdiction
        <select id="csv-jurisdiction" name="jurisdiction_id" class="rounded border p-2" required>
            <option value="">Choose jurisdiction</option>
            @foreach($jurisdictions as $jurisdiction)<option value="{{ $jurisdiction->id }}" @selected(old('jurisdiction_id')==$jurisdiction->id)>{{ $jurisdiction->name }}</option>@endforeach
        </select>
    </label>
    <fieldset class="flex flex-wrap gap-5"><legend class="mb-2 text-sm font-medium">Import mode</legend>
        <label><input type="radio" name="mode" value="delta" @checked(old('mode','delta')==='delta')> Delta (no implied deletes)</label>
        <label><input type="radio" name="mode" value="snapshot" @checked(old('mode')==='snapshot')> Snapshot (missing are advisory only)</label>
    </fieldset>
    <label class="grid gap-1 text-sm font-medium" for="csv-file">UTF-8 CSV
        <input id="csv-file" type="file" accept=".csv,text/csv" name="csv" class="rounded border p-2" required>
    </label>
    <p class="text-xs text-slate-600">Required columns: external_id, municipality_code, lat, lon, type. Other known columns are optional. No lifecycle fields. Reimport corrected CSV rather than editing past batches.</p>
    <button type="submit" class="rounded bg-slate-900 px-4 py-3 font-semibold text-white">Analyze privately</button>
</form>
@endsection
