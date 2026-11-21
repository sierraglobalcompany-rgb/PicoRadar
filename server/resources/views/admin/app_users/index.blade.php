@extends('layouts.admin', ['title' => 'Clientes de la app | PicoRadar'])

@section('content')
    <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
            <p class="text-sm font-semibold text-teal-700">Super Admin</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight">Cuentas opcionales</h1>
            <p class="mt-2 text-slate-600">Solo perfiles declarados y consentidos. Los datos de vehículos y documentos permanecen en el dispositivo.</p>
        </div>
        <a class="inline-flex min-h-12 items-center rounded-md border border-slate-300 bg-white px-4 font-medium" href="{{ route('admin.app-users.export', request()->query()) }}">Exportar CSV verificado</a>
    </div>

    <section class="mt-6 rounded-lg border border-slate-200 bg-white p-4" aria-label="Filtros de cuentas">
        <p class="mb-3 font-medium">{{ $total }} cuentas encontradas</p>
        <form method="GET" action="{{ route('admin.app-users.index') }}" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <label class="text-sm">Nombre o correo<input class="mt-1 block min-h-11 w-full rounded border-slate-300" name="q" maxlength="120" value="{{ $filters['q'] ?? '' }}"></label>
            <label class="text-sm">Desde<input class="mt-1 block min-h-11 w-full rounded border-slate-300" type="date" name="created_from" value="{{ $filters['created_from'] ?? '' }}"></label>
            <label class="text-sm">Hasta<input class="mt-1 block min-h-11 w-full rounded border-slate-300" type="date" name="created_to" value="{{ $filters['created_to'] ?? '' }}"></label>
            <label class="text-sm">Municipio declarado<input class="mt-1 block min-h-11 w-full rounded border-slate-300" name="municipality" maxlength="120" value="{{ $filters['municipality'] ?? '' }}"></label>
            <label class="text-sm">Categoría declarada<select class="mt-1 block min-h-11 w-full rounded border-slate-300" name="category"><option value="">Todas</option>@foreach(['car' => 'Carro', 'motorcycle' => 'Motocicleta', 'taxi' => 'Taxi', 'public_service' => 'Servicio público'] as $value => $label)<option value="{{ $value }}" @selected(($filters['category'] ?? '') === $value)>{{ $label }}</option>@endforeach</select></label>
            <label class="text-sm">Marketing<select class="mt-1 block min-h-11 w-full rounded border-slate-300" name="marketing"><option value="">Todos</option><option value="1" @selected(($filters['marketing'] ?? '') === '1')>Aceptado</option><option value="0" @selected(($filters['marketing'] ?? '') === '0')>No aceptado</option></select></label>
            <label class="text-sm">Correo verificado<select class="mt-1 block min-h-11 w-full rounded border-slate-300" name="verified"><option value="">Todos</option><option value="1" @selected(($filters['verified'] ?? '') === '1')>Sí</option><option value="0" @selected(($filters['verified'] ?? '') === '0')>No</option></select></label>
            <div class="flex items-end gap-2"><button class="min-h-11 rounded bg-slate-900 px-4 font-medium text-white">Filtrar</button><a class="min-h-11 rounded border border-slate-300 px-4 py-2" href="{{ route('admin.app-users.index') }}">Limpiar</a></div>
        </form>
    </section>

    <form method="POST" action="{{ route('admin.app-users.marketing.preview') }}" class="mt-6">
        @csrf
        <section class="overflow-hidden rounded-lg border border-slate-200 bg-white" aria-label="Cuentas registradas">
            <div class="overflow-x-auto">
                <table class="w-full text-left text-sm">
                    <thead class="bg-slate-100 text-slate-700"><tr><th class="p-3">Seleccionar</th><th class="p-3">Nombre / correo verificado</th><th class="p-3">Municipio y categorías declaradas</th><th class="p-3">Alta / marketing</th></tr></thead>
                    <tbody>
                    @forelse($users as $user)
                        <tr class="border-t border-slate-100">
                            <td class="p-3"><input aria-label="Seleccionar {{ $user->name ?: $user->email }}" type="checkbox" name="user_ids[]" value="{{ $user->id }}" @disabled(! $user->email_verified_at || ! $user->marketing_consent)></td>
                            <td class="p-3"><span class="block font-medium">{{ $user->name ?: 'Sin nombre' }}</span><span class="text-slate-600">{{ $user->email }}</span></td>
                            <td class="p-3">{{ $user->municipality ?: 'Sin municipio' }} · {{ implode(', ', $user->categories ?? []) ?: 'Sin categoría' }}</td>
                            <td class="p-3">{{ $user->created_at?->format('Y-m-d') }} · {{ $user->marketing_consent ? 'Opt-in vigente' : 'Sin opt-in' }}</td>
                        </tr>
                    @empty
                        <tr><td class="p-4 text-slate-600" colspan="4">No hay cuentas para estos filtros.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </section>
        <div class="mt-4 grid gap-3 rounded-lg border border-slate-200 bg-white p-4">
            <h2 class="text-xl font-semibold">Previsualización de correo consentido</h2>
            <p class="text-sm text-slate-600">Solo se consideran los seleccionados con correo verificado y opt-in actual. Máximo 100 destinatarios; el envío está desactivado por defecto.</p>
            <label class="text-sm">Asunto<input class="mt-1 block min-h-11 w-full rounded border-slate-300" name="subject" required minlength="5" maxlength="120"></label>
            <label class="text-sm">Mensaje<textarea class="mt-1 block w-full rounded border-slate-300" name="body" required minlength="10" maxlength="4000" rows="5"></textarea></label>
            <button class="min-h-11 justify-self-start rounded border border-slate-300 px-4 font-medium">Revisar destinatarios y mensaje</button>
        </div>
        <div class="mt-4">{{ $users->links() }}</div>
    </form>
@endsection
