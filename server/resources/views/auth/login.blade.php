<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Operator sign in | PicoRadar</title>
    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="grid min-h-screen place-items-center bg-slate-50 px-6 text-slate-900 antialiased">
    <main class="w-full max-w-md rounded-xl border border-slate-200 bg-white p-8 shadow-sm">
        <p class="text-sm font-medium text-teal-700">PicoRadar Control Plane</p>
        <h1 class="mt-2 text-2xl font-semibold tracking-tight">Operator sign in</h1>
        <p class="mt-2 text-sm text-slate-600">This access is only for authorized control-plane operators.</p>

        <form class="mt-7 space-y-5" method="POST" action="{{ route('login.store') }}">
            @csrf
            <div>
                <label class="block text-sm font-medium" for="email">Email</label>
                <input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" id="email" name="email" type="email" value="{{ old('email') }}" autocomplete="email" required autofocus>
            </div>
            <div>
                <label class="block text-sm font-medium" for="password">Password</label>
                <input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" id="password" name="password" type="password" autocomplete="current-password" required>
            </div>
            <label class="flex items-center gap-2 text-sm text-slate-600" for="remember">
                <input id="remember" name="remember" type="checkbox" value="1">
                Remember this device
            </label>
            @error('email')
                <p class="text-sm text-red-700" role="alert">{{ $message }}</p>
            @enderror
            <button class="w-full rounded-md bg-slate-900 px-4 py-2 font-medium text-white hover:bg-slate-700" type="submit">Sign in</button>
        </form>
    </main>
</body>
</html>
