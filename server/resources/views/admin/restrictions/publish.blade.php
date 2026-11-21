@extends('layouts.admin', ['title' => 'Publicar reglas | PicoRadar'])
@section('content')
<h1 class="text-3xl font-semibold">Revisar publicación selectiva</h1>
<p class="mt-2 text-sm text-slate-600">Base {{ $dataset->current_version ?? 'vacía' }} · revisión {{ $dataset->publication_revision }}</p>
@if($errors->any())<div class="mt-4 rounded bg-red-50 p-3 text-red-800">{{ $errors->first() }}</div>@endif
@if(session('status'))<div class="mt-4 rounded bg-green-50 p-3 text-green-800">{{ session('status') }}</div>@endif

@foreach($versions as $version)
    @php($review = $materialReviews[$version->id] ?? [])
    <section class="mt-6 rounded border border-slate-200 p-4">
        <h2 class="text-lg font-semibold">{{ $version->jurisdiction->name }}</h2>
        <p class="mt-1 break-all text-xs text-slate-600">Versión {{ $version->version }} · SHA de versión {{ $version->payload_sha256 }}</p>
        @if(isset($review['error']))
            <p class="mt-3 text-sm text-amber-800">Vista previa no disponible: {{ $review['error'] }}</p>
        @elseif(($review['changes'] ?? []) === [])
            <p class="mt-3 text-sm text-slate-700">No se detectan cambios materiales.</p>
        @else
            <dl class="mt-3 grid gap-2 text-sm md:grid-cols-2">
                <div><dt class="font-medium">SHA ciudad anterior</dt><dd class="break-all">{{ $review['before']['sha256'] }}</dd></div>
                <div><dt class="font-medium">SHA propuesta</dt><dd class="break-all">{{ $review['after']['sha256'] }}</dd></div>
                <div><dt class="font-medium">Cambios</dt><dd>{{ implode(', ', $review['changes']) }}</dd></div>
                <div><dt class="font-medium">Coberturas</dt><dd>{{ implode(', ', $review['coverageIdentities']) }}</dd></div>
                <div><dt class="font-medium">Reglas añadidas</dt><dd>{{ implode(', ', $review['ruleDiff']['added']) ?: 'Ninguna' }}</dd></div>
                <div><dt class="font-medium">Reglas retiradas</dt><dd>{{ implode(', ', $review['ruleDiff']['removed']) ?: 'Ninguna' }}</dd></div>
                <div><dt class="font-medium">Reglas modificadas</dt><dd>{{ implode(', ', $review['ruleDiff']['modified']) ?: 'Ninguna' }}</dd></div>
                <div><dt class="font-medium">Verificado / vence revisión</dt><dd>{{ $review['sourceCheckedAt'] ?? 'Sin fecha' }} / {{ $review['staleAfter'] ?? 'Sin fecha' }}</dd></div>
            </dl>
            <div class="mt-3 text-sm">
                <p class="font-medium">Fuentes registradas</p>
                <ul class="list-inside list-disc break-all">@foreach($review['sources'] as $source)<li>{{ $source }}</li>@endforeach</ul>
            </div>
            <p class="mt-3 text-xs text-slate-600">La aprobación es editorial y no certifica cobertura completa ni resuelve corredores o exenciones desconocidos.</p>
            @if($canApproveMaterial && !in_array(auth()->id(), [$version->created_by_id, $version->updated_by_id], true))
                <form class="mt-4 grid gap-3 border-t border-slate-200 pt-4" method="POST" action="{{ route('admin.restrictions.approve-material-change', $version) }}">
                    @csrf
                    <input type="hidden" name="publication_revision" value="{{ $dataset->publication_revision }}">
                    <label class="grid gap-1 text-sm">Fuente oficial que respalda la revisión
                        <select name="evidence_url" required class="rounded border border-slate-300 p-2">
                            <option value="">Selecciona una fuente del cambio</option>
                            @foreach($review['sources'] as $source)<option value="{{ $source }}">{{ $source }}</option>@endforeach
                        </select>
                    </label>
                    <label class="grid gap-1 text-sm">Motivo editorial (10–1000 caracteres)
                        <textarea name="reason" required minlength="10" maxlength="1000" rows="3" class="rounded border border-slate-300 p-2"></textarea>
                    </label>
                    <button class="w-fit rounded bg-amber-700 px-4 py-2 text-white">Registrar aprobación editorial</button>
                </form>
            @endif
        @endif
    </section>
@endforeach

<form class="mt-6" method="POST" action="{{ route('admin.restrictions.publish') }}">
    @csrf
    <input type="hidden" name="publication_revision" value="{{ $dataset->publication_revision }}">
    @foreach($versions as $version)<input type="hidden" name="versions[]" value="{{ $version->id }}">@endforeach
    <button class="rounded bg-slate-900 px-4 py-2 text-white">Publicar ciudades seleccionadas</button>
</form>
@endsection
