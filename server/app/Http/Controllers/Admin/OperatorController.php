<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OperatorRole;
use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\DatasetAuditLogger;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class OperatorController extends Controller
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function index(Request $request): View
    {
        Gate::authorize('operators.manage');

        return view('admin.operators.index', [
            'operator' => $request->user(),
            'operators' => User::query()->orderBy('name')->paginate(25),
            'roles' => OperatorRole::cases(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        Gate::authorize('operators.manage');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'role' => ['required', 'string', 'in:'.implode(',', array_column(OperatorRole::cases(), 'value'))],
            'password' => ['required', 'confirmed', Password::min(12)],
        ]);

        $created = User::query()->create($data + ['is_active' => true]);
        $this->audit->log($request->user(), 'operator.created', $created, [
            'role' => $created->role->value,
        ]);

        return redirect()->route('admin.operators.index')->with('status', 'Operador creado.');
    }

    public function update(Request $request, User $operator): RedirectResponse
    {
        Gate::authorize('operators.manage');
        $data = $request->validate([
            'role' => ['required', 'string', 'in:'.implode(',', array_column(OperatorRole::cases(), 'value'))],
            'is_active' => ['required', 'boolean'],
        ]);
        $nextRole = OperatorRole::from($data['role']);
        $nextActive = (bool) $data['is_active'];

        if ($operator->is($request->user()) && (! $nextActive || $nextRole !== OperatorRole::SuperAdmin)) {
            throw ValidationException::withMessages([
                'operator' => 'No puedes desactivar ni retirar tu propio rol de superadministrador.',
            ]);
        }

        DB::transaction(function () use ($operator, $nextRole, $nextActive, $request): void {
            $locked = User::query()->lockForUpdate()->findOrFail($operator->id);
            if ($locked->role === OperatorRole::SuperAdmin
                && $locked->isActive()
                && (! $nextActive || $nextRole !== OperatorRole::SuperAdmin)
                && User::query()->where('role', OperatorRole::SuperAdmin->value)->where('is_active', true)->count() <= 1) {
                throw ValidationException::withMessages([
                    'operator' => 'Debe permanecer al menos un superadministrador activo.',
                ]);
            }

            $previous = ['role' => $locked->role->value, 'isActive' => $locked->isActive()];
            $locked->forceFill(['role' => $nextRole, 'is_active' => $nextActive])->save();
            $this->audit->log($request->user(), 'operator.updated', $locked, [
                'previous' => $previous,
                'role' => $nextRole->value,
                'isActive' => $nextActive,
            ]);
        });

        return redirect()->route('admin.operators.index')->with('status', 'Operador actualizado.');
    }
}
