@extends('layouts.admin',['title'=>'Upload camera import | PicoRadar'])
@section('content')
<h1 class="text-3xl font-semibold">Upload camera import</h1>
<form class="mt-6 grid max-w-xl gap-4 rounded border bg-white p-6" method="POST" enctype="multipart/form-data" action="{{ route('admin.camera-imports.store') }}">@csrf
<label>Source<select name="source_id" required><option value="">Choose a source</option>@foreach($sources as $source)<option value="{{ $source->id }}" @selected(old('source_id') == $source->id)>{{ $source->title }}</option>@endforeach</select></label>
<label>Default jurisdiction<select name="default_jurisdiction_id"><option value="">Resolve per row</option>@foreach($jurisdictions as $jurisdiction)<option value="{{ $jurisdiction->id }}" @selected(old('default_jurisdiction_id') == $jurisdiction->id)>{{ $jurisdiction->name }}</option>@endforeach</select></label>
<label>Import mode<select name="import_mode" required><option value="delta">Delta</option><option value="snapshot">Snapshot</option></select></label>
<label>Private source file<input name="file" type="file" accept=".csv,.ndjson,.jsonl,.geojson" required></label>
<button class="rounded bg-slate-900 px-4 py-2 text-white">Upload</button></form>
@endsection
