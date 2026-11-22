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
            ->whereIn('purpose', ['session', 'suppression'])
            ->where('token_hash', $tokenHash)
            ->where('expires_at', '>', now())
            ->first();

        if (
            ! $access?->appUser
            || ! $access->appUser->email_verified_at
            || ! hash_equals($access->token_hash, $tokenHash)
        ) {
            return $this->unauthorized();
        }

        if ($access->purpose === 'session' && $access->revoked_at) {
            return $this->unauthorized();
        }

        if ($access->purpose === 'suppression') {
            if ($access->revoked_at) {
                return $this->unauthorized();
            }
            if (! $request->isMethod('DELETE') || ! $request->routeIs('api.v1.app-account.destroy')) {
                return response()->json(['error' => ['code' => 'suppression_action_only']], 403);
            }
        } elseif ($access->appUser->isAccessBlocked()) {
            $errorCode = match ($access->appUser->accountStatus()) {
                'banned' => 'account_banned',
                'suspended' => 'account_suspended',
                default => 'account_unavailable',
            };
            return response()->json([
                'error' => ['code' => $errorCode],
            ], 403);
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
