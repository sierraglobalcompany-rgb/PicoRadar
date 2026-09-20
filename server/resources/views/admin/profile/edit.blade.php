@extends('layouts.admin', ['title' => 'Mi acceso | PicoRadar'])

@section('content')
    <div class="max-w-xl">
        <p class="text-sm font-medium text-teal-700">Cuenta administrativa</p>
        <h1 class="mt-1 text-2xl font-semibold">Cambiar contraseña</h1>
        <p class="mt-2 text-sm text-slate-600">La contraseña se cambia dentro de tu sesión; el instalador no se reutiliza.</p>
        <form class="mt-6 space-y-4 rounded-lg border border-slate-200 bg-white p-5" method="POST" action="{{ route('admin.profile.password') }}">
            @csrf @method('PUT')
            <label class="block text-sm font-medium">Contraseña actual<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" type="password" name="current_password" required></label>
            <label class="block text-sm font-medium">Nueva contraseña<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" type="password" name="password" minlength="12" required></label>
            <label class="block text-sm font-medium">Confirmar nueva contraseña<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" type="password" name="password_confirmation" minlength="12" required></label>
            <button class="min-h-12 rounded-md bg-slate-900 px-4 py-2 font-medium text-white" type="submit">Actualizar contraseña</button>
        </form>
    </div>
@endsection
