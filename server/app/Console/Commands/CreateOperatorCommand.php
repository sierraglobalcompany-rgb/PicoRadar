<?php

namespace App\Console\Commands;

use App\Actions\Admin\InitialOperatorCreator;
use Illuminate\Console\Command;
use Illuminate\Validation\ValidationException;

class CreateOperatorCommand extends Command
{
    protected $signature = 'picoradar:admin:create {--name=} {--email=}';

    protected $description = 'Create the first active PicoRadar super administrator interactively.';

    public function handle(InitialOperatorCreator $creator): int
    {
        $name = (string) ($this->option('name') ?: $this->ask('Operator name'));
        $email = (string) ($this->option('email') ?: $this->ask('Operator email'));
        $password = (string) $this->secret('Password (at least 12 characters)');
        $confirmation = (string) $this->secret('Confirm password');

        try {
            $creator->create($name, $email, $password, $confirmation);
        } catch (ValidationException $exception) {
            $this->components->error(collect($exception->errors())->flatten()->first() ?? 'The operator could not be created.');

            return self::FAILURE;
        }

        $this->components->info('Super administrator created.');

        return self::SUCCESS;
    }
}
