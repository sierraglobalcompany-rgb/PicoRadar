<?php

namespace App\Providers;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
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
        Gate::define('datasets.view', fn (User $user): bool => $user->role !== OperatorRole::Commercial);
        Gate::define('datasets.edit', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Editor], true));
        Gate::define('datasets.review', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Reviewer], true));
        Gate::define('geography.view', fn (User $user): bool => $user->role !== OperatorRole::Commercial);
        Gate::define('geography.bootstrap', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin], true));
        Gate::define('jurisdictions.view', fn (User $user): bool => $user->role !== OperatorRole::Commercial);
        Gate::define('jurisdictions.edit', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Editor], true));
        Gate::define('camera_sources.view', fn (User $user): bool => $user->role !== OperatorRole::Commercial);
        Gate::define('camera_sources.edit', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Editor], true));
        Gate::define('cameras.view', fn (User $user): bool => $user->role !== OperatorRole::Commercial);
        Gate::define('cameras.edit', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Editor], true));
        Gate::define('cameras.review', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin, OperatorRole::Reviewer], true));
        Gate::define('cameras.reopen', fn (User $user): bool => in_array($user->role, [OperatorRole::SuperAdmin, OperatorRole::Admin], true));
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
