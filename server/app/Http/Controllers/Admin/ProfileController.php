<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Services\DatasetAuditLogger;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;

class ProfileController extends Controller
{
    public function __construct(private readonly DatasetAuditLogger $audit) {}

    public function edit(Request $request): View
    {
        return view('admin.profile.edit', ['operator' => $request->user()]);
    }

    public function updatePassword(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'current_password'],
            'password' => ['required', 'confirmed', Password::min(12)],
        ]);

        $operator = $request->user();
        $operator->forceFill([
            'password' => Hash::make($data['password']),
            'remember_token' => null,
        ])->save();
        $this->audit->log($operator, 'operator.password_changed', $operator);

        return redirect()->route('admin.profile.edit')->with('status', 'Contraseña actualizada.');
    }
}
