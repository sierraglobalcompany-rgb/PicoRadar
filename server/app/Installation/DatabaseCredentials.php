<?php

namespace App\Installation;

use InvalidArgumentException;

readonly class DatabaseCredentials
{
    public function __construct(
        public string $host,
        public int $port,
        public string $database,
        public string $username,
        public string $password,
    ) {
        if (! preg_match('/^(?=.{1,253}$)[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$/', $host)) {
            throw new InvalidArgumentException('The database host is invalid.');
        }
        if ($port < 1 || $port > 65535) {
            throw new InvalidArgumentException('The database port is invalid.');
        }
        if (! preg_match('/^[a-zA-Z0-9_$-]{1,64}$/', $database)) {
            throw new InvalidArgumentException('The database name is invalid.');
        }
        if (! preg_match('/^[a-zA-Z0-9_$-]{1,128}$/', $username)) {
            throw new InvalidArgumentException('The database username is invalid.');
        }
        if ($password === '' || preg_match('/[\r\n\x00]/', $password)) {
            throw new InvalidArgumentException('The database password is invalid.');
        }
    }

    public function dsn(): string
    {
        return sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            $this->host,
            $this->port,
            $this->database,
        );
    }
}
