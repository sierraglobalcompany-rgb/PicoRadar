<?php

namespace App\Installation;

use PDO;
use RuntimeException;

class EmptyDatabaseVerifier
{
    public function isEmpty(PDO $pdo): bool
    {
        $statement = $pdo->query(
            'SELECT table_name FROM information_schema.tables '
            .'WHERE table_schema = DATABASE() LIMIT 1',
        );

        if ($statement === false) {
            throw new RuntimeException('The database inventory could not be read.');
        }

        return $statement->fetchColumn() === false;
    }
}
