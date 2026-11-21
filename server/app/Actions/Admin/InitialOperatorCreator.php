<?php

namespace App\Actions\Admin;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class InitialOperatorCreator
{
    /**
     * @throws ValidationException
     */
    public function create(
        string $name,
        string $email,
        string $password,
        string $passwordConfirmation,
    ): User {
        $input = [
            'name' => trim($name),
            'email' => strtolower(trim($email)),
            'password' => $password,
            'password_confirmation' => $passwordConfirmation,
        ];

        $validated = Validator::make($input, [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['required', 'string', 'min:12', 'confirmed'],
        ])->validate();

        return DB::transaction(function () use ($validated): User {
            if (User::query()->lockForUpdate()->exists()) {
                throw ValidationException::withMessages([
                    'email' => 'The initial operator has already been created.',
                ]);
            }

            return User::query()->create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => $validated['password'],
                'role' => OperatorRole::SuperAdmin,
                'is_active' => true,
            ]);
        }, 3);
    }
}
