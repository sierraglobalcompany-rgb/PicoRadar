@extends('layouts.admin', ['title' => 'Resumen | PicoRadar'])

@section('content')
    <div class="max-w-3xl">
        <p class="text-sm font-semibold text-teal-700">Panel administrativo</p>
        <h1 class="mt-2 text-3xl font-semibold tracking-tight">Operación de contenidos</h1>
        <p class="mt-3 text-slate-600">Consulta el estado real de las reglas, publicaciones y herramientas habilitadas. Guardar un borrador no modifica lo que consume la aplicación.</p>
    </div>

    @if($contentStats !== null)
        <section class="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-5" aria-label="Estado de pico y placa">
            @foreach([
                ['Jurisdicciones activas', $contentStats['activeJurisdictions']],
                ['Borradores de pico y placa', $contentStats['drafts']],
                ['Listas para publicar', $contentStats['validated']],
                ['Importaciones pendientes', $contentStats['pendingImports']],
                ['Publicaciones recientes', $contentStats['publications']],
            ] as [$label, $value])
                <article class="rounded-lg border border-slate-200 bg-white p-4">
                    <p class="text-2xl font-semibold text-slate-950">{{ $value }}</p>
                    <p class="mt-1 text-sm text-slate-600">{{ $label }}</p>
                </article>
            @endforeach
        </section>

        <section class="mt-8" aria-labelledby="recent-jurisdictions-title">
            <div class="flex flex-wrap items-center justify-between gap-3">
                <h2 id="recent-jurisdictions-title" class="text-xl font-semibold">Ciudades y coberturas recientes</h2>
                <a class="inline-flex min-h-12 items-center rounded-md bg-slate-900 px-4 py-2 font-medium text-white" href="{{ route('admin.jurisdictions.index') }}">Abrir jurisdicciones</a>
            </div>
            <div class="mt-3 overflow-hidden rounded-lg border border-slate-200 bg-white">
                @forelse($recentJurisdictions as $jurisdiction)
                    <a class="flex min-h-12 items-center justify-between gap-4 border-b border-slate-100 px-4 py-3 last:border-b-0 hover:bg-slate-50" href="{{ route('admin.jurisdictions.show', $jurisdiction) }}">
                        <span>
                            <span class="block font-medium text-slate-950">{{ $jurisdiction->name }}</span>
                            <span class="block text-sm text-slate-500">{{ $jurisdiction->enabled ? 'Activa' : 'Inactiva' }} · {{ $jurisdiction->restriction_rule_versions_count }} versiones</span>
                        </span>
                        <span aria-hidden="true">→</span>
                    </a>
                @empty
                    <p class="px-4 py-5 text-sm text-slate-600">Todavía no hay jurisdicciones configuradas.</p>
                @endforelse
            </div>
        </section>
    @endif

    <section class="mt-8" aria-labelledby="tools-title">
        <h2 id="tools-title" class="text-xl font-semibold">Herramientas disponibles</h2>
        <div class="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            @can('datasets.view')
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.datasets.index') }}">Datasets y publicaciones</a>
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.cameras.index') }}">Cámaras y fuentes</a>
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.audit.index') }}">Auditoría</a>
            @endcan
            @can('partner_inquiries.view')
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.partner-inquiries.index') }}">Solicitudes de aliados</a>
            @endcan
            @can('campaigns.view')
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.sponsors.index') }}">Patrocinadores</a>
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.campaigns.index') }}">Campañas del carrusel</a>
            @endcan
            @can('operators.manage')
                <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.operators.index') }}">Operadores</a>
            @endcan
            <a class="min-h-12 rounded-lg border border-slate-200 bg-white p-4 font-medium hover:border-teal-500" href="{{ route('admin.profile.edit') }}">Mi contraseña</a>
        </div>
    </section>
@endsection
