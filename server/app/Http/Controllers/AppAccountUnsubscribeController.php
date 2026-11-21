<?php

namespace App\Http\Controllers;

use App\Models\AppAccessToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AppAccountUnsubscribeController extends Controller
{
    public function show(string $token)
    {
        $access = $this->findToken($token);

        return view('app-account.unsubscribe', ['available' => $access !== null]);
    }

    public function store(Request $request, string $token)
    {
        DB::transaction(function () use ($token): void {
            $access = $this->findToken($token, lock: true);
            if ($access?->appUser && $access->purpose === 'unsubscribe') {
                $access->appUser->forceFill([
                    'marketing_consent' => false,
                    'marketing_version' => null,
                    'marketing_consented_at' => null,
                ])->save();
                $access->forceFill(['used_at' => now()])->save();
            }
        });

        return redirect()->route('app-users.unsubscribe.show', ['token' => $token, ...$request->query()])
            ->with('status', 'Tu preferencia de comunicaciones fue actualizada.');
    }

    private function findToken(string $plain, bool $lock = false): ?AppAccessToken
    {
        if (! preg_match('/^[a-f0-9]{64}$/D', $plain)) {
            return null;
        }
        $query = AppAccessToken::query()
            ->with('appUser')
            ->where('purpose', 'unsubscribe')
            ->where('token_hash', hash('sha256', $plain))
            ->whereNull('used_at')
            ->whereNull('revoked_at')
            ->where('expires_at', '>', now());
        if ($lock) {
            $query->lockForUpdate();
        }
        $access = $query->first();

        return $access && hash_equals($access->token_hash, hash('sha256', $plain)) ? $access : null;
    }
}
