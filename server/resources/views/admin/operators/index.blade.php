@extends('layouts.admin', ['title' => 'Operadores | PicoRadar'])

@section('content')
    <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
            <p class="text-sm font-medium text-teal-700">Seguridad del panel</p>
            <h1 class="mt-1 text-2xl font-semibold">Operadores</h1>
            <p class="mt-2 text-sm text-slate-600">Crea accesos separados y asigna únicamente el rol necesario.</p>
        </div>
    </div>

    <section class="mt-6 rounded-lg border border-slate-200 bg-white p-5">
        <h2 class="text-lg font-semibold">Nuevo operador</h2>
        <form class="mt-4 grid gap-4 md:grid-cols-2" method="POST" action="{{ route('admin.operators.store') }}">
            @csrf
            <label class="text-sm font-medium">Nombre<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" name="name" required></label>
            <label class="text-sm font-medium">Correo<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" type="email" name="email" required></label>
            <label class="text-sm font-medium">Rol<select class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" name="role">@foreach($roles as $role)<option value="{{ $role->value }}">{{ $role->label() }}</option>@endforeach</select></label>
            <label class="text-sm font-medium">Contraseña temporal<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" type="password" name="password" minlength="12" required></label>
            <label class="text-sm font-medium">Confirmar contraseña<input class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" type="password" name="password_confirmation" minlength="12" required></label>
            <div class="flex items-end"><button class="min-h-12 rounded-md bg-slate-900 px-4 py-2 font-medium text-white" type="submit">Crear operador</button></div>
        </form>
    </section>

    <div class="mt-6 overflow-x-auto rounded-lg border border-slate-200 bg-white">
        <table class="w-full text-left text-sm">
            <thead class="bg-slate-100"><tr><th class="px-4 py-3">Operador</th><th class="px-4 py-3">Rol y estado</th><th class="px-4 py-3">Acción</th></tr></thead>
            <tbody class="divide-y divide-slate-200">
            @foreach($operators as $item)
                <tr>
                    <td class="px-4 py-3"><p class="font-medium">{{ $item->name }}</p><p class="text-slate-500">{{ $item->email }}</p></td>
                    <td class="px-4 py-3">
                        <select class="rounded-md border border-slate-300 px-2 py-2" name="role" form="operator-{{ $item->id }}">@foreach($roles as $role)<option value="{{ $role->value }}" @selected($item->role === $role)>{{ $role->label() }}</option>@endforeach</select>
                        <select class="rounded-md border border-slate-300 px-2 py-2" name="is_active" form="operator-{{ $item->id }}"><option value="1" @selected($item->is_active)>Activo</option><option value="0" @selected(!$item->is_active)>Inactivo</option></select>
                    </td>
                    <td class="px-4 py-3">
                        <form id="operator-{{ $item->id }}" method="POST" action="{{ route('admin.operators.update', $item) }}">@csrf @method('PUT')<button class="min-h-11 rounded-md border border-slate-300 px-3 py-2 font-medium" type="submit">Guardar</button></form>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </div>
    <div class="mt-4">{{ $operators->links() }}</div>
@endsection
