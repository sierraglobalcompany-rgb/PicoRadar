@extends('layouts.admin', ['title' => 'Dashboard | PicoRadar Control Plane'])

@section('content')
    <div class="max-w-2xl">
        <p class="text-sm font-medium text-teal-700">Operator dashboard</p>
        <h1 class="mt-2 text-3xl font-semibold tracking-tight">Control plane is available.</h1>
        <p class="mt-3 text-slate-600">This foundation is ready for the approved dataset registry and publisher work. No datasets, mobile accounts, ads, or partners are active here.</p>
    </div>

    <section class="mt-8 grid gap-4 sm:grid-cols-2" aria-label="System status">
        <article class="rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
            <p class="text-sm font-medium text-slate-500">API</p>
            <p class="mt-2 text-lg font-semibold text-emerald-700">Available</p>
            <p class="mt-1 text-sm text-slate-600"><code>/api/v1/health</code> is public and rate limited.</p>
        </article>
        <article class="rounded-xl border border-slate-200 bg-white p-5 shadow-sm">
            <p class="text-sm font-medium text-slate-500">Operator access</p>
            <p class="mt-2 text-lg font-semibold text-slate-900">{{ $operator->role->label() }}</p>
            <p class="mt-1 text-sm text-slate-600">Active administrative session.</p>
        </article>
    </section>
    @can('datasets.view')
        <a class="mt-6 inline-flex rounded-md bg-slate-900 px-4 py-2 font-medium text-white" href="{{ route('admin.datasets.index') }}">Manage datasets</a>
        <a class="mt-6 inline-flex rounded-md border border-slate-300 px-4 py-2 font-medium text-slate-800" href="{{ route('admin.audit.index') }}">Audit log</a>
    @endcan
@endsection
