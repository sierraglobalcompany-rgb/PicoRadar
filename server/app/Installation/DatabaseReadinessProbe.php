<?php

namespace App\Installation;

use PDO;
use RuntimeException;

class DatabaseReadinessProbe
{
    public function assertReady(PDO $pdo): void
    {
        if (! (new EmptyDatabaseVerifier)->isEmpty($pdo)) {
            throw new RuntimeException('database_not_empty');
        }

        $grants = $pdo->query('SHOW GRANTS FOR CURRENT_USER');
        if ($grants === false) {
            throw new RuntimeException('database_privileges_insufficient');
        }

        $database = (string) $pdo->query('SELECT DATABASE()')->fetchColumn();
        $scope = strtoupper(str_replace('`', '', $database)).'.*';
        $statements = array_map('strtoupper', $grants->fetchAll(PDO::FETCH_COLUMN));
        $combined = implode(' ', array_filter(
            $statements,
            static fn (string $grant): bool => str_contains(str_replace('`', '', $grant), ' ON '.$scope.' ')
                || str_contains($grant, ' ON *.* '),
        ));
        if (str_contains($combined, 'GRANT ALL PRIVILEGES')) {
            return;
        }

        foreach (['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'ALTER', 'INDEX', 'REFERENCES'] as $privilege) {
            if (! preg_match('/\b'.preg_quote($privilege, '/').'\b/', $combined)) {
                throw new RuntimeException('database_privileges_insufficient');
            }
        }
    }
}
