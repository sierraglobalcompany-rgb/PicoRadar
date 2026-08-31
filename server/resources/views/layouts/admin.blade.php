<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'PicoRadar Control Plane' }}</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-slate-50 text-slate-900 antialiased">
    <header class="border-b border-slate-200 bg-white">
        <div class="mx-auto flex max-w-5xl items-center justify-between gap-4 px-6 py-4">
            <a class="font-semibold tracking-tight text-slate-900" href="{{ route('admin.dashboard') }}">PicoRadar <span class="font-normal text-slate-500">Control Plane</span></a>
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
        @yield('content')
    </main>
</body>
</html>
