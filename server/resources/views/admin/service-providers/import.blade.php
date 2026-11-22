@extends('layouts.admin', ['title' => 'Importar proveedores | PicoRadar'])

@section('content')
    <div class="max-w-3xl">
        <a class="text-sm font-medium text-teal-800 underline" href="{{ route('admin.service-providers.index') }}">← Directorio</a>
        <h1 class="mt-4 text-3xl font-semibold tracking-tight">Importar proveedores</h1>
        <p class="mt-2 text-slate-600">Carga un CSV o XLSX para revisar fichas de CDA, SOAT, talleres, grúas y aliados. El análisis no cambia el catálogo. La confirmación crea o actualiza únicamente borradores y no publica el dataset.</p>
        <p class="mt-3 rounded-md border border-amber-300 bg-amber-50 p-4 text-sm text-amber-950">Las fichas comerciales CDA no sustituyen ni certifican el catálogo oficial de CDA. Una fuente declarada no equivale a aprobación editorial.</p>

        <div class="mt-5 rounded-lg border border-slate-200 bg-white p-5">
            <h2 class="font-semibold">Columnas CSV</h2>
            <p class="mt-2 text-sm text-slate-600">Obligatorias: category, department_code, municipality_code, name, source_url, verified_at, valid_until. Opcionales: service_provider_id, address, latitude, longitude, contact_url.</p>
            <p class="mt-2 break-all font-mono text-xs text-slate-700">category,department_code,municipality_code,name,address,latitude,longitude,source_url,verified_at,valid_until,contact_url</p>
            <form class="mt-5 space-y-4" method="POST" action="{{ route('admin.service-providers.imports.analyze') }}" enctype="multipart/form-data">
                @csrf
                <label class="block text-sm font-medium">Archivo CSV o XLSX
                    <input class="mt-2 block min-h-12 w-full rounded-md border border-slate-300 p-2" type="file" name="file" accept=".csv,.xlsx" required>
                </label>
                @error('file')<p class="text-sm text-red-700">{{ $message }}</p>@enderror
                <button class="inline-flex min-h-12 items-center rounded-md bg-slate-900 px-5 font-medium text-white" type="submit">Analizar archivo</button>
            </form>
        </div>
    </div>
@endsection