<?php

namespace App\Console\Commands;

use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class CreateOperatorCommand extends Command
{
    protected $signature = 'picoradar:admin:create {--name=} {--email=}';

    protected $description = 'Create the first active PicoRadar super administrator interactively.';

    public function handle(): int
    {
        $name = trim((string) ($this->option('name') ?: $this->ask('Operator name')));
        $email = strtolower(trim((string) ($this->option('email') ?: $this->ask('Operator email'))));

        if ($name === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->components->error('A name and a valid email address are required.');

            return self::FAILURE;
        }

        if (User::query()->where('email', $email)->exists()) {
            $this->components->error('An operator with that email already exists.');

            return self::FAILURE;
        }

        $password = (string) $this->secret('Password (at least 12 characters)');
        $confirmation = (string) $this->secret('Confirm password');

        if (mb_strlen($password) < 12 || ! hash_equals($password, $confirmation)) {
            $this->components->error('Passwords must match and contain at least 12 characters.');

            return self::FAILURE;
        }

        User::query()->create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make($password),
            'role' => OperatorRole::SuperAdmin,
            'is_active' => true,
        ]);

        $this->components->info('Super administrator created.');

        return self::SUCCESS;
    }
}
