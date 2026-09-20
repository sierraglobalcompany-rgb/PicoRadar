@extends('layouts.admin', ['title' => 'Publicar reglas | PicoRadar'])
@section('content')
<h1 class="text-3xl font-semibold">Revisar publicación selectiva</h1><p class="mt-2 text-sm text-slate-600">Base {{ $dataset->current_version ?? 'vacía' }} · revisión {{ $dataset->publication_revision }}</p>
@if($errors->any())<div class="mt-4 rounded bg-red-50 p-3 text-red-800">{{ $errors->first() }}</div>@endif
<form class="mt-6" method="POST" action="{{ route('admin.restrictions.publish') }}">@csrf<input type="hidden" name="publication_revision" value="{{ $dataset->publication_revision }}">@foreach($versions as $version)<input type="hidden" name="versions[]" value="{{ $version->id }}"><div class="border-b py-3"><strong>{{ $version->jurisdiction->name }}</strong><span class="ml-2 text-sm text-slate-600">v{{ $version->version }} · {{ $version->payload_sha256 }}</span></div>@endforeach<button class="mt-4 rounded bg-slate-900 px-4 py-2 text-white">Publicar ciudades seleccionadas</button></form>
@endsection
