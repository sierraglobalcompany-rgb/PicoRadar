<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequireSecureAppAccountTransport
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->isSecure()) {
            return $next($request);
        }

        $host = strtolower($request->getHost());
        $isLoopback = in_array($host, ['localhost', '127.0.0.1', '::1'], true);
        if (app()->environment('testing') && $isLoopback) {
            return $next($request);
        }
        if (app()->environment('dev') && config('app_accounts.allow_insecure_local') && $isLoopback) {
            return $next($request);
        }

        return response()->json(['error' => ['code' => 'secure_transport_required']], 400);
    }
}
