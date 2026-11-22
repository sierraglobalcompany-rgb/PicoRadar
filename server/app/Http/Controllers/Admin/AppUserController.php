<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Mail\AppAccountMarketingMail;
use App\Models\AppAccessToken;
use App\Models\AppUser;
use App\Models\AuditLog;
use App\Services\AppAccountAdministrationService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AppUserController extends Controller
{
    private const CATEGORIES = ['car', 'motorcycle', 'taxi', 'public_service'];

    public function index(Request $request)
    {
        Gate::authorize('app_users.manage');
        $filters = $this->validatedFilters($request);
        $query = $this->filteredUsers($filters);
        $total = (clone $query)->count();
        $this->audit($request, 'app_users.listed', $total, $filters);

        return view('admin.app_users.index', [
            'users' => $query->latest('created_at')->paginate(25)->withQueryString(),
            'total' => $total,
            'filters' => $filters,
            'operator' => $request->user(),
        ]);
    }

    public function export(Request $request): StreamedResponse
    {
        Gate::authorize('app_users.manage');
        $filters = $this->validatedFilters($request);
        $query = $this->filteredUsers($filters)->whereNotNull('email_verified_at');
        $count = (clone $query)->count();
        $this->audit($request, 'app_users.exported', $count, $filters);

        return response()->streamDownload(function () use ($query): void {
            $output = fopen('php://output', 'w');
            fputcsv($output, ['Nombre', 'Correo verificado', 'Teléfono', 'Municipio declarado', 'Categorías declaradas', 'Plan', 'Estado', 'Plan vigente hasta', 'Creada', 'Verificada', 'Marketing'], ',', '"', '');
            foreach ($query->orderBy('id')->cursor() as $user) {
                fputcsv($output, [
                    $this->safeCsv((string) $user->name),
                    $this->safeCsv((string) $user->email),
                    $this->safeCsv((string) $user->phone),
                    $this->safeCsv((string) $user->municipality),
                    $this->safeCsv(implode('|', $user->categories ?? [])),
                    $user->accountPlan(),
                    $user->accountStatus(),
                    $user->plan_valid_until?->toISOString(),
                    $user->created_at?->toISOString(),
                    $user->email_verified_at?->toISOString(),
                    $user->marketing_consent ? 'sí' : 'no',
                ], ',', '"', '');
            }
            fclose($output);
        }, 'picoradar-clientes.csv', [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Cache-Control' => 'no-store, private',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function preview(Request $request)
    {
        Gate::authorize('app_users.manage');
        $data = $this->marketingInput($request);
        $users = $this->selectedOptIns($data['user_ids'])->get();
        $this->audit($request, 'app_users.marketing_previewed', $users->count(), ['selection']);

        return view('admin.app_users.preview', [
            'users' => $users,
            'subject' => $data['subject'],
            'body' => $data['body'],
            'operator' => $request->user(),
        ]);
    }

    public function dispatch(Request $request)
    {
        Gate::authorize('app_users.manage');
        if (! $this->marketingDispatchAvailable()) {
            abort(503, 'El envío de marketing no está habilitado.');
        }
        $data = $this->marketingInput($request);
        $sent = 0;
        foreach ($this->selectedOptIns($data['user_ids'])->orderBy('id')->get() as $user) {
            // Consent is read again immediately before sending; each recipient receives a purpose-bound token.
            $user->refresh();
            if (! $user->email_verified_at || ! $user->marketing_consent) {
                continue;
            }
            $token = bin2hex(random_bytes(32));
            AppAccessToken::query()->create([
                'app_user_id' => $user->id,
                'purpose' => 'unsubscribe',
                'token_hash' => hash('sha256', $token),
                'expires_at' => now()->addDays(30),
            ]);
            $unsubscribeUrl = URL::temporarySignedRoute(
                'app-users.unsubscribe.show',
                now()->addDays(30),
                ['token' => $token],
            );
            Mail::to($user->email)->send(new AppAccountMarketingMail(
                $data['subject'],
                $data['body'],
                $unsubscribeUrl,
            ));
            $sent++;
        }

        $this->audit($request, 'app_users.marketing_dispatched', $sent, ['selection']);

        return redirect()->route('admin.app-users.index')->with('status', "Despacho simulado a {$sent} destinatarios elegibles.");
    }

    public function updateStatus(Request $request, AppUser $appUser, AppAccountAdministrationService $service)
    {
        Gate::authorize('app_users.manage');
        if (array_diff(array_keys($request->all()), ['status', 'reason', 'until', '_token', '_method']) !== []) {
            abort(422);
        }
        $data = $request->validate([
            'status' => ['required', 'in:active,suspended,banned'],
            'reason' => ['required', 'string', 'min:3', 'max:500'],
            'until' => ['nullable', 'date', 'after:now'],
        ]);
        if ($data['status'] !== 'suspended' && ! empty($data['until'])) {
            abort(422);
        }

        $service->changeStatus(
            $appUser,
            $data['status'],
            $data['reason'],
            isset($data['until']) ? Carbon::parse($data['until']) : null,
            $request->user(),
        );

        return back()->with('status', 'Estado de cuenta registrado y auditado. Las sesiones revocadas requieren iniciar sesión nuevamente.');
    }

    public function updatePlan(Request $request, AppUser $appUser, AppAccountAdministrationService $service)
    {
        Gate::authorize('app_users.manage');
        if (array_diff(array_keys($request->all()), ['plan', 'valid_from', 'valid_until', 'reference', '_token', '_method']) !== []) {
            abort(422);
        }
        $data = $request->validate([
            'plan' => ['required', 'in:free,pro'],
            'valid_from' => ['required_if:plan,pro', 'nullable', 'date'],
            'valid_until' => ['nullable', 'date', 'after:valid_from'],
            'reference' => ['required_if:plan,pro', 'nullable', 'string', 'min:4', 'max:120'],
        ]);

        $service->changePlan(
            $appUser,
            $data['plan'],
            isset($data['valid_from']) ? Carbon::parse($data['valid_from']) : null,
            isset($data['valid_until']) ? Carbon::parse($data['valid_until']) : null,
            $data['reference'] ?? null,
            $request->user(),
        );

        return back()->with('status', 'Plan registrado desde el servidor y auditado.');
    }

    private function marketingInput(Request $request): array
    {
        if (array_diff(array_keys($request->all()), ['user_ids', 'subject', 'body', '_token']) !== []) {
            abort(422);
        }
        $data = $request->validate([
            'user_ids' => ['required', 'array', 'min:1', 'max:100'],
            'user_ids.*' => ['required', 'integer', 'distinct'],
            'subject' => ['required', 'string', 'min:5', 'max:120', 'not_regex:/[\r\n\x00-\x1f\x7f]/'],
            'body' => ['required', 'string', 'min:10', 'max:4000'],
        ]);
        $data['user_ids'] = array_values(array_unique($data['user_ids']));

        return $data;
    }

    private function selectedOptIns(array $ids): Builder
    {
        return AppUser::query()
            ->whereIn('id', $ids)
            ->whereNotNull('email_verified_at')
            ->where('marketing_consent', true);
    }

    private function marketingDispatchAvailable(): bool
    {
        if (app()->environment('testing') && config('mail.default') === 'array') {
            return true;
        }

        return config('app_accounts.enabled')
            && config('app_accounts.marketing_send_enabled')
            && config('app_accounts.transactional_email_enabled')
            && ! in_array(config('mail.default'), ['log', 'array', 'null'], true);
    }

    private function validatedFilters(Request $request): array
    {
        if (array_diff(array_keys($request->query()), ['q', 'created_from', 'created_to', 'municipality', 'category', 'marketing', 'verified', 'plan', 'status', 'page']) !== []) {
            abort(422);
        }

        return $request->validate([
            'q' => ['sometimes', 'nullable', 'string', 'max:120'],
            'created_from' => ['sometimes', 'nullable', 'date_format:Y-m-d'],
            'created_to' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'after_or_equal:created_from'],
            'municipality' => ['sometimes', 'nullable', 'string', 'max:120'],
            'category' => ['sometimes', 'nullable', 'in:'.implode(',', self::CATEGORIES)],
            'marketing' => ['sometimes', 'nullable', 'in:0,1'],
            'verified' => ['sometimes', 'nullable', 'in:0,1'],
            'plan' => ['sometimes', 'nullable', 'in:free,pro'],
            'status' => ['sometimes', 'nullable', 'in:active,suspended,banned'],
            'page' => ['sometimes', 'integer', 'min:1'],
        ]);
    }

    private function filteredUsers(array $filters): Builder
    {
        $query = AppUser::query();
        if (isset($filters['q']) && trim($filters['q']) !== '') {
            $term = trim($filters['q']);
            $query->where(fn (Builder $builder) => $builder
                ->where('name', 'like', '%'.$term.'%')
                ->orWhere('email', 'like', '%'.$term.'%'));
        }
        if (! empty($filters['created_from'])) {
            $query->whereDate('created_at', '>=', $filters['created_from']);
        }
        if (! empty($filters['created_to'])) {
            $query->whereDate('created_at', '<=', $filters['created_to']);
        }
        if (! empty($filters['municipality'])) {
            $query->where('municipality', $filters['municipality']);
        }
        if (! empty($filters['category'])) {
            $query->whereJsonContains('categories', $filters['category']);
        }
        if (isset($filters['marketing']) && $filters['marketing'] !== '') {
            $query->where('marketing_consent', $filters['marketing'] === '1');
        }
        if (isset($filters['verified']) && $filters['verified'] !== '') {
            $filters['verified'] === '1'
                ? $query->whereNotNull('email_verified_at')
                : $query->whereNull('email_verified_at');
        }
        if (! empty($filters['plan'])) {
            $query->where('account_plan', $filters['plan']);
        }
        if (! empty($filters['status'])) {
            $query->where('account_status', $filters['status']);
        }

        return $query;
    }

    private function safeCsv(string $value): string
    {
        $significant = preg_replace('/^[\x00-\x20\x7f\xef\xbb\xbf]+/', '', $value) ?? $value;
        if ($significant !== '' && preg_match('/^[=+\-@]/', $significant)) {
            return "'".$value;
        }

        return $value;
    }

    private function audit(Request $request, string $action, int $count, array $filters): void
    {
        AuditLog::query()->create([
            'actor_id' => $request->user()->id,
            'action' => $action,
            'subject_type' => AppUser::class,
            'subject_id' => null,
            'metadata' => [
                'count' => $count,
                'filter_types' => array_values(array_intersect(
                    ['q', 'created_from', 'created_to', 'municipality', 'category', 'marketing', 'verified', 'plan', 'status', 'selection'],
                    array_keys($filters),
                )),
            ],
        ]);
    }
}
