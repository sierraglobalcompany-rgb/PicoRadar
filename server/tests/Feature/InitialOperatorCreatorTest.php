<?php

namespace Tests\Feature;

use App\Actions\Admin\InitialOperatorCreator;
use App\Enums\OperatorRole;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class InitialOperatorCreatorTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_creates_the_only_active_super_administrator(): void
    {
        $operator = app(InitialOperatorCreator::class)->create(
            name: '  Operador Inicial  ',
            email: '  OWNER@EXAMPLE.TEST ',
            password: 'a-secure-password',
            passwordConfirmation: 'a-secure-password',
        );

        $this->assertSame('Operador Inicial', $operator->name);
        $this->assertSame('owner@example.test', $operator->email);
        $this->assertSame(OperatorRole::SuperAdmin, $operator->role);
        $this->assertTrue($operator->isActive());
        $this->assertTrue(Hash::check('a-secure-password', $operator->password));
    }

    public function test_it_rejects_invalid_input_without_creating_an_operator(): void
    {
        try {
            app(InitialOperatorCreator::class)->create(
                name: '',
                email: 'not-an-email',
                password: 'short',
                passwordConfirmation: 'different',
            );
            $this->fail('ValidationException was not thrown.');
        } catch (ValidationException $exception) {
            $this->assertSame(
                ['name', 'email', 'password'],
                array_keys($exception->errors()),
            );
        }

        $this->assertDatabaseCount('users', 0);
    }

    public function test_it_refuses_to_create_a_second_initial_operator(): void
    {
        User::factory()->create();

        $this->expectException(ValidationException::class);

        app(InitialOperatorCreator::class)->create(
            name: 'Second Owner',
            email: 'second@example.test',
            password: 'a-secure-password',
            passwordConfirmation: 'a-secure-password',
        );
    }
}
