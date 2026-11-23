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
        <div class="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-3 px-4 py-4 sm:gap-4 sm:px-6">
            <a class="shrink-0 font-semibold tracking-tight text-slate-900" href="{{ route('admin.dashboard') }}" aria-label="PicoRadar Control Plane">PicoRadar <span class="font-normal text-slate-500">Control Plane</span></a>
            <nav class="hidden items-center gap-3 text-sm md:flex" aria-label="Administración">
                <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.dashboard') }}">Resumen</a>
                @can('datasets.view')
                    <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.datasets.index') }}">Datos</a>
                @endcan
                @can('datasets.view')
                    <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.restrictions.index') }}">Pico y placa</a>
                @endcan
                @can('campaigns.view')
                    <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.campaigns.index') }}">Campañas</a>
                @endcan
                @can('app_users.manage')
                    <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.app-users.index') }}">Clientes de la app</a>
                @endcan
                <a class="font-medium text-slate-700 hover:text-slate-950" href="{{ route('admin.profile.edit') }}">Mi acceso</a>
            </nav>
            <div class="ml-auto flex max-w-full min-w-0 items-center gap-3 text-sm">
                <div class="min-w-0 max-w-40 break-words text-right">
                    <p class="font-medium">{{ $operator->name }}</p>
                    <p class="text-slate-500">{{ $operator->role->label() }}</p>
                </div>
                <form method="POST" action="{{ route('logout') }}">
                    @csrf
                    <button class="min-h-11 rounded-md border border-slate-300 px-3 py-2 font-medium text-slate-700 hover:bg-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" type="submit">Log out</button>
                </form>
            </div>
            <details id="mobile-navigation" class="w-full md:hidden">
                <summary class="inline-flex min-h-11 cursor-pointer items-center rounded-md border border-slate-300 bg-white px-4 py-2 font-medium text-slate-800 hover:bg-slate-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700">Menú</summary>
                <nav class="mt-2 rounded-lg border border-slate-200 bg-white p-2" aria-label="Navegación móvil">
                    <ul class="grid gap-1">
                        <li>
                            <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.dashboard') }}">Resumen</a>
                        </li>
                        @can('datasets.view')
                            @can('jurisdictions.view')
                                <li>
                                    <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.operations.national') }}">Operación nacional</a>
                                </li>
                            @endcan
                            <li>
                                <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.restrictions.municipalities') }}">Matriz municipal</a>
                            </li>
                            <li>
                                <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.restrictions.index') }}">Pico y placa</a>
                            </li>
                        @endcan
                        @can('campaigns.view')
                            <li>
                                <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.campaigns.planning') }}">Planificación de campañas</a>
                            </li>
                        @endcan
                        @can('app_users.manage')
                            <li>
                                <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.app-users.index') }}">Clientes de la app</a>
                            </li>
                        @endcan
                        @can('operators.manage')
                            <li>
                                <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.operators.index') }}">Operadores</a>
                            </li>
                        @endcan
                        <li>
                            <a class="flex min-h-11 items-center rounded-md px-3 py-2 font-medium text-slate-700 hover:bg-slate-50 hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-teal-700" href="{{ route('admin.profile.edit') }}">Mi acceso</a>
                        </li>
                    </ul>
                </nav>
            </details>
        </div>
    </header>
    <main class="mx-auto max-w-5xl px-6 py-10">
        @if(session('status'))
            <div class="mb-5 rounded-md border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900" role="status">{{ session('status') }}</div>
        @endif
        @if($errors->any())
            <div class="mb-5 rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900" role="alert">
                <p class="font-semibold">Revisa la información:</p>
                <ul class="mt-1 list-disc pl-5">
                    @foreach($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif
        @yield('content')
    </main>
</body>
</html>
