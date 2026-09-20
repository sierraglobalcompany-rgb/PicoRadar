<?php

namespace App\Installation;

use App\Actions\Admin\InitialOperatorCreator;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Foundation\Application;
use Illuminate\Http\Request;
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
        $this->ensurePublicLinkTargets();
        $this->command('storage:link', ['--force' => true]);
        $this->verifyPublicLinks();
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
        $this->verifyLoginContract();
    }

    private function ensurePublicLinkTargets(): void
    {
        foreach ([
            $this->privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public',
            $this->privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'manifest'.DIRECTORY_SEPARATOR.'v1',
        ] as $directory) {
            if (! is_dir($directory) && ! mkdir($directory, 0755, true) && ! is_dir($directory)) {
                throw new RuntimeException('The installer could not prepare a public-link target.');
            }
        }
    }

    private function verifyPublicLinks(): void
    {
        foreach ([
            $this->publicRoot.DIRECTORY_SEPARATOR.'storage' => $this->privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public',
            $this->publicRoot.DIRECTORY_SEPARATOR.'v1' => $this->privateRoot.DIRECTORY_SEPARATOR.'storage'.DIRECTORY_SEPARATOR.'app'.DIRECTORY_SEPARATOR.'public'.DIRECTORY_SEPARATOR.'manifest'.DIRECTORY_SEPARATOR.'v1',
        ] as $link => $target) {
            $resolvedLink = realpath($link);
            $resolvedTarget = realpath($target);
            if ($resolvedLink === false || $resolvedTarget === false || $resolvedLink !== $resolvedTarget) {
                throw new RuntimeException('A required public link does not resolve to its private target.');
            }
        }
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

    private function verifyLoginContract(): void
    {
        $application = $this->boot();
        $route = $application->make('router')->getRoutes()->getByName('login');
        $view = $application->make('view');

        if ($route === null
            || $route->uri() !== 'login'
            || ! in_array('GET', $route->methods(), true)
            || ! $view->exists('auth.login')) {
            throw new RuntimeException('The installed login contract failed.');
        }
    }
}
