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
            <label class="text-sm">Plan<select class="mt-1 block min-h-11 w-full rounded border-slate-300" name="plan"><option value="">Todos</option><option value="free" @selected(($filters['plan'] ?? '') === 'free')>Free</option><option value="pro" @selected(($filters['plan'] ?? '') === 'pro')>Pro</option></select></label>
            <label class="text-sm">Estado de cuenta<select class="mt-1 block min-h-11 w-full rounded border-slate-300" name="status"><option value="">Todos</option><option value="active" @selected(($filters['status'] ?? '') === 'active')>Activa</option><option value="suspended" @selected(($filters['status'] ?? '') === 'suspended')>Suspendida</option><option value="banned" @selected(($filters['status'] ?? '') === 'banned')>Baneada</option></select></label>
            <div class="flex items-end gap-2"><button class="min-h-11 rounded bg-slate-900 px-4 font-medium text-white">Filtrar</button><a class="min-h-11 rounded border border-slate-300 px-4 py-2" href="{{ route('admin.app-users.index') }}">Limpiar</a></div>
        </form>
    </section>

    <section class="mt-6">
        <section class="overflow-hidden rounded-lg border border-slate-200 bg-white" aria-label="Cuentas registradas">
            <div class="overflow-x-auto">
                <table class="w-full text-left text-sm">
                    <thead class="bg-slate-100 text-slate-700"><tr><th class="p-3">Seleccionar</th><th class="p-3">Nombre / correo verificado</th><th class="p-3">Municipio y categorías declaradas</th><th class="p-3">Plan / estado</th><th class="p-3">Administrar</th><th class="p-3">Alta (Bogotá) / marketing</th></tr></thead>
                    <tbody>
                    @forelse($users as $user)
                        <tr class="border-t border-slate-100">
                            <td class="p-3"><input form="app-user-marketing-preview" aria-label="Seleccionar {{ $user->name ?: $user->email }}" type="checkbox" name="user_ids[]" value="{{ $user->id }}" @disabled(! $user->email_verified_at || ! $user->marketing_consent)></td>
                            <td class="p-3"><span class="block font-medium">{{ $user->name ?: 'Sin nombre' }}</span><span class="text-slate-600">{{ $user->email }}</span></td>
                            <td class="p-3">{{ $user->municipality ?: 'Sin municipio' }} · {{ implode(', ', $user->categories ?? []) ?: 'Sin categoría' }}</td>
                            <td class="p-3"><span class="block">{{ $user->accountPlan() === 'pro' ? 'Pro' : ($user->accountPlan() === 'free' ? 'Free' : 'Sin confirmar') }} · {{ $user->entitlementStatus() }}</span><span class="text-slate-600">{{ ['active' => 'Activa', 'suspended' => 'Suspendida', 'banned' => 'Baneada'][$user->accountStatus()] ?? 'Sin confirmar' }}</span>@if($user->accountPlan() === 'pro')<span class="block text-slate-600">Vence: {{ $user->plan_valid_until?->format('Y-m-d') ?? 'sin fecha' }} · {{ $user->plan_source ?: 'sin fuente' }}</span>@endif</td>
                            <td class="p-3">
                                <details>
                                    <summary class="cursor-pointer font-medium">Plan y estado</summary>
                                    <form method="POST" action="{{ url('/admin/app-users/'.$user->id.'/plan') }}" class="mt-3 grid min-w-64 gap-2">
                                        @csrf @method('PATCH')
                                        <label>Plan<select class="block min-h-10 w-full rounded border-slate-300" name="plan"><option value="free" @selected($user->accountPlan() === 'free')>Free</option><option value="pro" @selected($user->accountPlan() === 'pro')>Pro</option></select></label>
                                        <label>Vigencia desde<input class="block min-h-10 w-full rounded border-slate-300" type="datetime-local" name="valid_from" value="{{ $user->plan_valid_from?->format('Y-m-d\\TH:i') }}"></label>
                                        <label>Vigencia hasta<input class="block min-h-10 w-full rounded border-slate-300" type="datetime-local" name="valid_until" value="{{ $user->plan_valid_until?->format('Y-m-d\\TH:i') }}"></label>
                                        <label>Referencia de autorización<input class="block min-h-10 w-full rounded border-slate-300" name="reference" maxlength="120" value="{{ $user->accountPlan() === 'pro' ? $user->plan_reference : '' }}"></label>
                                        <button class="min-h-10 rounded bg-slate-900 px-3 font-medium text-white">Guardar plan</button>
                                    </form>
                                    <form method="POST" action="{{ url('/admin/app-users/'.$user->id.'/status') }}" class="mt-4 grid min-w-64 gap-2 border-t border-slate-200 pt-3">
                                        @csrf @method('PATCH')
                                        <label>Estado<select class="block min-h-10 w-full rounded border-slate-300" name="status"><option value="active" @selected($user->accountStatus() === 'active')>Activa</option><option value="suspended" @selected($user->accountStatus() === 'suspended')>Suspendida</option><option value="banned" @selected($user->accountStatus() === 'banned')>Baneada</option></select></label>
                                        <label>Motivo del cambio<input class="block min-h-10 w-full rounded border-slate-300" name="reason" maxlength="500" required></label>
                                        <label>Fin de suspensión<input class="block min-h-10 w-full rounded border-slate-300" type="datetime-local" name="until" value="{{ $user->status_until?->format('Y-m-d\\TH:i') }}"></label>
                                        <button class="min-h-10 rounded border border-slate-300 px-3 font-medium">Guardar estado</button>
                                    </form>
                                </details>
                            </td>
                            <td class="p-3">{{ $user->created_at?->copy()->setTimezone('America/Bogota')->format('Y-m-d') }} · {{ $user->marketing_consent ? 'Opt-in vigente' : 'Sin opt-in' }}</td>
                        </tr>
                    @empty
                        <tr><td class="p-4 text-slate-600" colspan="6">No hay cuentas para estos filtros.</td></tr>
                    @endforelse
                    </tbody>
                </table>
            </div>
        </section>
        <form id="app-user-marketing-preview" method="POST" action="{{ route('admin.app-users.marketing.preview') }}" class="mt-4 grid gap-3 rounded-lg border border-slate-200 bg-white p-4">
            @csrf
            <h2 class="text-xl font-semibold">Previsualización de correo consentido</h2>
            <p class="text-sm text-slate-600">Solo se consideran los seleccionados con correo verificado y opt-in actual. Máximo 100 destinatarios; el envío está desactivado por defecto.</p>
            <label class="text-sm">Asunto<input class="mt-1 block min-h-11 w-full rounded border-slate-300" name="subject" required minlength="5" maxlength="120"></label>
            <label class="text-sm">Mensaje<textarea class="mt-1 block w-full rounded border-slate-300" name="body" required minlength="10" maxlength="4000" rows="5"></textarea></label>
            <button class="min-h-11 justify-self-start rounded border border-slate-300 px-4 font-medium">Revisar destinatarios y mensaje</button>
        </form>
        <div class="mt-4">{{ $users->links() }}</div>
    </section>
@endsection
