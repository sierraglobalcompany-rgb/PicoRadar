<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

$application = Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request, Throwable $exception): bool => $request->is('api/*') || $request->expectsJson(),
        );

        $exceptions->render(function (Throwable $exception, Request $request): ?Response {
            if (! $request->is('api/*')) {
                return null;
            }

            if ($exception instanceof HttpResponseException) {
                return $exception->getResponse();
            }

            $status = match (true) {
                $exception instanceof ValidationException => 422,
                $exception instanceof HttpExceptionInterface => $exception->getStatusCode(),
                default => 500,
            };

            [$code, $message] = match ($status) {
                401 => ['unauthorized', 'Authentication is required.'],
                403 => ['forbidden', 'You are not allowed to perform this action.'],
                404 => ['not_found', 'The requested API resource was not found.'],
                405 => ['method_not_allowed', 'This HTTP method is not allowed for this resource.'],
                422 => ['validation_failed', 'The request could not be validated.'],
                429 => ['rate_limited', 'Too many requests. Please try again later.'],
                503 => ['service_unavailable', 'The service is temporarily unavailable.'],
                default => ['server_error', 'The server could not complete this request.'],
            };

            return response()->json([
                'error' => [
                    'code' => $code,
                    'message' => $message,
                ],
            ], $status);
        });
    })->create();

$publicPath = $_SERVER['PICORADAR_PUBLIC_PATH'] ?? getenv('PICORADAR_PUBLIC_PATH') ?: null;
if (is_string($publicPath) && $publicPath !== '') {
    $application->usePublicPath($publicPath);
}

return $application;
