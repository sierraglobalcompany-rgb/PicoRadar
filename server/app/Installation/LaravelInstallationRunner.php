<?php

namespace App\Installation;

use App\Actions\Admin\InitialOperatorCreator;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Foundation\Application;
use Illuminate\Http\Request;
use Illuminate\Support\ViewErrorBag;
use Illuminate\View\Factory as ViewFactory;
use RuntimeException;

class LaravelInstallationRunner
{
    private ?Application $application = null;

    public function __construct(
        private readonly string $privateRoot,
        private readonly string $publicRoot,
    ) {}

    public function migrate(): void
    {
        $this->command('migrate', ['--force' => true, '--no-interaction' => true]);
    }

    public function createInitialOperator(
        string $name,
        string $email,
        string $password,
        string $passwordConfirmation,
    ): void {
        $this->boot()->make(InitialOperatorCreator::class)->create(
            $name,
            $email,
            $password,
            $passwordConfirmation,
        );
    }

    public function prepareApplication(): void
    {
        $this->command('storage:link', ['--force' => true]);
        $this->command('config:cache');
        $this->command('route:cache');
        $this->command('view:cache');
        $this->verifyHttpContract('/api/v1/health', function (int $status, string $body): bool {
            $payload = json_decode($body, true);

            return $status === 200
                && is_array($payload)
                && ($payload['status'] ?? null) === 'ok'
                && ($payload['service'] ?? null) === 'picoradar-control-plane'
                && ($payload['apiVersion'] ?? null) === 'v1';
        });
        $this->boot()->make(ViewFactory::class)->share('errors', new ViewErrorBag);
        $this->verifyHttpContract('/login', fn (int $status): bool => $status === 200);
    }

    private function command(string $command, array $parameters = []): void
    {
        $kernel = $this->boot()->make(ConsoleKernel::class);
        $status = $kernel->call($command, $parameters);
        if ($status !== 0) {
            throw new RuntimeException('Installer command failed: '.$command);
        }
    }

    private function boot(): Application
    {
        if ($this->application !== null) {
            return $this->application;
        }

        $_SERVER['PICORADAR_PUBLIC_PATH'] = $this->publicRoot;
        putenv('PICORADAR_PUBLIC_PATH='.$this->publicRoot);

        /** @var Application $application */
        $application = require $this->privateRoot.DIRECTORY_SEPARATOR.'bootstrap'.DIRECTORY_SEPARATOR.'app.php';
        $application->make(ConsoleKernel::class)->bootstrap();

        return $this->application = $application;
    }

    private function verifyHttpContract(string $path, callable $accepts): void
    {
        $kernel = $this->boot()->make(HttpKernel::class);
        $request = Request::create($path, 'GET', server: ['HTTP_ACCEPT' => 'application/json']);
        $response = $kernel->handle($request);

        try {
            if (! $accepts($response->getStatusCode(), (string) $response->getContent())) {
                throw new RuntimeException('The installed HTTP contract failed: '.$path);
            }
        } finally {
            $kernel->terminate($request, $response);
        }
    }
}
