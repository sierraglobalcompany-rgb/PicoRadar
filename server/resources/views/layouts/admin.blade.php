<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'PicoRadar Control Plane' }}</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50 text-slate-900 antialiased">
    <header class="border-b border-slate-200 bg-white">
        <div class="mx-auto flex max-w-5xl items-center justify-between gap-4 px-6 py-4">
            <a class="font-semibold tracking-tight text-slate-900" href="{{ route('admin.dashboard') }}" aria-label="PicoRadar Control Plane">PicoRadar <span class="font-normal text-slate-500">Control Plane</span></a>
            <nav class="hidden items-center gap-3 text-sm md:flex" aria-label="Administración">
                <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.dashboard') }}">Resumen</a>
                @can('datasets.view')<a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.datasets.index') }}">Datos</a>@endcan
                @can('datasets.view')<a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.restrictions.index') }}">Pico y placa</a>@endcan
                @can('campaigns.view')<a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.campaigns.index') }}">Campañas</a>@endcan
                <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.profile.edit') }}">Mi acceso</a>
            </nav>
            <div class="flex items-center gap-3 text-sm">
                <div class="text-right">
                    <p class="font-medium">{{ $operator->name }}</p>
                    <p class="text-slate-500">{{ $operator->role->label() }}</p>
                </div>
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button class="rounded-md border border-slate-300 px-3 py-2 font-medium text-slate-700 hover:bg-slate-100" type="submit">Log out</button>
                </form>
            </div>
        </div>
    </header>
    <main class="mx-auto max-w-5xl px-6 py-10">
        @if(session('status'))
            <div class="mb-5 rounded-md border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900" role="status">{{ session('status') }}</div>
        @endif
        @if($errors->any())
            <div class="mb-5 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900" role="alert">
                <p class="font-semibold">Revisa la información:</p>
                <ul class="mt-1 list-disc pl-5">@foreach($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
            </div>
        @endif
        @yield('content')
    </main>
</body>
</html>
