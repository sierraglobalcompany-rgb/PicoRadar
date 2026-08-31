<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('health', function (Request $request): Limit {
            return Limit::perMinute(60)
                ->by('health|'.$request->ip())
                ->response(function (Request $request, array $headers) {
                    return response()->json([
                        'error' => [
                            'code' => 'rate_limited',
                            'message' => 'Too many requests. Please try again later.',
                        ],
                    ], 429, $headers);
                });
        });

        RateLimiter::for('operator-login', function (Request $request): Limit {
            return Limit::perMinute(5)
                ->by(strtolower((string) $request->input('email')).'|'.$request->ip())
                ->response(function (Request $request, array $headers) {
                    return redirect()
                        ->route('login')
                        ->withInput($request->only('email'))
                        ->withErrors(['email' => __('Too many login attempts. Please try again later.')])
                        ->withHeaders($headers);
                });
        });
    }
}
