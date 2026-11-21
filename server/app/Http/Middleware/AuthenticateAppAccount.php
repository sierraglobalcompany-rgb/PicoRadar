<?php

namespace App\Http\Middleware;

use App\Models\AppAccessToken;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateAppAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! config('app_accounts.enabled') && ! app()->environment('testing')) {
            return response()->json(['error' => ['code' => 'not_configured']], 503);
        }

        $plainToken = $request->bearerToken();
        if (! is_string($plainToken) || ! preg_match('/^[a-f0-9]{64}$/D', $plainToken)) {
            return $this->unauthorized();
        }

        $tokenHash = hash('sha256', $plainToken);
        $access = AppAccessToken::query()
            ->with('appUser')
            ->where('purpose', 'session')
            ->where('token_hash', $tokenHash)
            ->whereNull('revoked_at')
            ->where('expires_at', '>', now())
            ->first();

        if (
            ! $access?->appUser
            || ! $access->appUser->email_verified_at
            || ! hash_equals($access->token_hash, $tokenHash)
        ) {
            return $this->unauthorized();
        }

        $request->attributes->set('appAccount', $access->appUser);
        $request->attributes->set('appAccountToken', $access);

        return $next($request);
    }

    private function unauthorized(): Response
    {
        return response()->json(['error' => ['code' => 'unauthorized']], 401);
    }
}
