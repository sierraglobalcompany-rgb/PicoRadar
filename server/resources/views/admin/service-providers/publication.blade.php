@extends('layouts.admin', ['title' => 'Publicación OTA de proveedores | PicoRadar'])

@section('content')
    <div class="mx-auto max-w-4xl space-y-6">
        <div>
            <a class="text-sm font-medium text-teal-800 underline" href="{{ route('admin.service-providers.index') }}">Volver al directorio</a>
            <p class="mt-4 text-sm font-semibold text-teal-700">Dataset versionado</p>
            <h1 class="mt-1 text-3xl font-semibold">Revisar publicación OTA</h1>
            <p class="mt-2 max-w-3xl text-slate-600">La aprobación editorial de una ficha no la distribuye. Esta vista compara el snapshot actual y solo crea un borrador; la validación, revisión humana, publicación y rollback siguen en el registro de datasets.</p>
        </div>

        @if($errors->any())
            <div class="rounded-lg border border-red-200 bg-red-50 p-4 text-red-800" role="alert">{{ $errors->first() }}</div>
        @endif

        @if($dataset)
            <section class="rounded-xl border border-slate-200 bg-white p-5">
                <h2 class="text-lg font-semibold">Estado del dataset</h2>
                <p class="mt-2 text-slate-700">{{ $dataset->key }} · schema {{ $dataset->schema_version }} · {{ $dataset->enabled ? 'habilitado' : 'deshabilitado' }}</p>
                <p class="mt-1 text-sm text-slate-600">Versión distribuida actual: {{ $dataset->current_version ?? 'ninguna' }}</p>
                <a class="mt-3 inline-flex min-h-11 items-center text-sm font-medium text-teal-800 underline" href="{{ route('admin.datasets.show', $dataset) }}">Abrir registro de releases, fuentes y rollback</a>
            </section>
        @else
            <section class="rounded-xl border border-amber-300 bg-amber-50 p-5">
                <h2 class="font-semibold text-amber-950">Falta registrar service_providers</h2>
                <p class="mt-2 text-amber-900">Crea el dataset con la clave exacta service_providers y schema 1; agrega y verifica una fuente HTTPS antes de generar un borrador.</p>
                <a class="mt-3 inline-flex min-h-11 items-center rounded-md bg-slate-900 px-4 text-white" href="{{ route('admin.datasets.create') }}">Abrir registro de datasets</a>
            </section>
        @endif

        @if($snapshot)
            <section class="rounded-xl border border-slate-200 bg-white p-5">
                <h2 class="text-lg font-semibold">Vista previa del snapshot</h2>
                <dl class="mt-4 grid gap-4 sm:grid-cols-2">
                    <div><dt class="text-sm text-slate-500">Fichas vigentes</dt><dd class="font-semibold">{{ $snapshot['count'] }}</dd></div>
                    <div><dt class="text-sm text-slate-500">Generado</dt><dd class="font-semibold">{{ $snapshot['generatedAt'] }}</dd></div>
                    <div><dt class="text-sm text-slate-500">Cambios frente a la versión actual</dt><dd class="font-semibold">+{{ $diff['added'] }} · {{ $diff['changed'] }} modificadas · −{{ $diff['removed'] }}</dd></div>
                    <div><dt class="text-sm text-slate-500">Vigencia más próxima</dt><dd class="font-semibold">{{ $snapshot['firstValidUntil'] ?? 'sin fecha' }}</dd></div>
                    <div class="sm:col-span-2"><dt class="text-sm text-slate-500">SHA-256 del borrador previsto</dt><dd class="break-all font-mono text-sm">{{ $snapshot['sha256'] }}</dd></div>
                </dl>
                <p class="mt-3 text-sm text-slate-600">SHA-256 comprueba integridad; no es una firma criptográfica. La app conserva la última versión válida ante errores.</p>
            </section>
        @endif

        @if($blockers !== [])
            <section class="rounded-xl border border-amber-300 bg-amber-50 p-5" aria-label="Bloqueos para crear borrador">
                <h2 class="font-semibold text-amber-950">Aún no se puede crear el borrador</h2>
                <ul class="mt-2 list-disc space-y-1 pl-5 text-amber-900">
                    @foreach($blockers as $blocker)<li>{{ $blocker }}</li>@endforeach
                </ul>
            </section>
        @endif

        @if($snapshot && $blockers === [] && $canCreateDraft)
            <form method="POST" action="{{ route('admin.datasets.releases.store', $dataset) }}" class="rounded-xl border border-teal-200 bg-teal-50 p-5">
                @csrf
                <input type="hidden" name="generate_from_provider_catalog" value="1">
                <input type="hidden" name="version" value="{{ $snapshot['version'] }}">
                <input type="hidden" name="generated_at" value="{{ $snapshot['generatedAt'] }}">
                <input type="hidden" name="preview_sha256" value="{{ $snapshot['sha256'] }}">
                <p class="font-medium text-teal-950">Crear borrador del snapshot revisado</p>
                <p class="mt-1 text-sm text-teal-900">Si alguna ficha cambia después de esta vista previa, el servidor rechazará el envío y pedirá revisar de nuevo.</p>
                <button class="mt-4 inline-flex min-h-11 items-center rounded-md bg-teal-800 px-4 py-2 font-semibold text-white">Crear borrador para revisión</button>
            </form>
        @elseif($snapshot && $blockers === [] && ! $canCreateDraft)
            <p class="rounded-lg bg-slate-100 p-4 text-slate-700">Tu rol puede consultar el snapshot, pero no crear borradores.</p>
        @endif
    </div>
@endsection
