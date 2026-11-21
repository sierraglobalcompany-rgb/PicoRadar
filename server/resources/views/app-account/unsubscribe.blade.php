<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Preferencias de correo | PicoRadar</title></head>
<body style="font-family:system-ui,sans-serif;max-width:42rem;margin:3rem auto;padding:0 1rem;color:#0f172a">
    <h1>Preferencias de correo de PicoRadar</h1>
    @if(session('status'))
        <p role="status">{{ session('status') }}</p>
    @elseif($available)
        <p>Confirma que quieres dejar de recibir mensajes comerciales opcionales.</p>
        <form method="POST" action="{{ route('app-users.unsubscribe.store', ['token' => request()->route('token'), ...request()->query()]) }}">
            @csrf
            <button style="min-height:44px;padding:0 1rem">Cancelar suscripción</button>
        </form>
    @else
        <p>Este enlace ya fue usado o venció. No necesitas hacer nada más.</p>
    @endif
</body>
</html>
