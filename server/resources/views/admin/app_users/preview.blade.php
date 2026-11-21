@extends('layouts.admin', ['title' => 'Previsualizar correo | PicoRadar'])

@section('content')
    <div class="max-w-3xl">
        <p class="text-sm font-semibold text-teal-700">Revisión antes del despacho</p>
        <h1 class="mt-2 text-3xl font-semibold tracking-tight">{{ $users->count() }} destinatario(s) con consentimiento actual</h1>
        <p class="mt-2 text-slate-600">La elegibilidad se comprobará otra vez al enviar. No se incluye ningún destinatario sin verificación y opt-in vigente.</p>
        <section class="mt-5 rounded-lg border border-slate-200 bg-white p-4">
            <h2 class="font-semibold">{{ $subject }}</h2>
            <p class="mt-3 whitespace-pre-wrap text-slate-700">{{ $body }}</p>
        </section>
        <ul class="mt-4 rounded-lg border border-slate-200 bg-white">
            @forelse($users as $user)
                <li class="border-b border-slate-100 p-3 last:border-0">{{ $user->name ?: 'Sin nombre' }} · {{ $user->email }}</li>
            @empty
                <li class="p-3">No quedan destinatarios elegibles.</li>
            @endforelse
        </ul>
        @if($users->isNotEmpty())
            <form method="POST" action="{{ route('admin.app-users.marketing.dispatch') }}" class="mt-5 flex flex-wrap gap-3">
                @csrf
                @foreach($users as $user)<input type="hidden" name="user_ids[]" value="{{ $user->id }}">@endforeach
                <input type="hidden" name="subject" value="{{ $subject }}">
                <input type="hidden" name="body" value="{{ $body }}">
                <button class="min-h-12 rounded bg-slate-900 px-4 font-medium text-white">Despachar a esta selección</button>
                <a class="min-h-12 rounded border border-slate-300 px-4 py-3" href="{{ route('admin.app-users.index') }}">Cancelar</a>
            </form>
        @endif
    </div>
@endsection
