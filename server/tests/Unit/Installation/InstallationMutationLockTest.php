<?php

namespace Tests\Unit\Installation;

use App\Installation\InstallationLockBusyException;
use App\Installation\InstallationMutationLock;
use PHPUnit\Framework\TestCase;

class InstallationMutationLockTest extends TestCase
{
    public function test_only_one_session_can_mutate_the_installer_at_a_time(): void
    {
        $path = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-install-lock-'.bin2hex(random_bytes(6));
        $first = new InstallationMutationLock($path);
        $second = new InstallationMutationLock($path);

        try {
            $first->acquire();
            $this->expectException(InstallationLockBusyException::class);
            $second->acquire(0);
        } finally {
            $second->release();
            $first->release();
            @unlink($path);
        }
    }
}
