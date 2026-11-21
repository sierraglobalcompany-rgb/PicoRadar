<?php

namespace Tests\Unit\Installation;

use App\Installation\InstallationStage;
use App\Installation\InstallationStateStore;
use PHPUnit\Framework\TestCase;

class InstallationStateStoreTest extends TestCase
{
    private string $directory;

    protected function setUp(): void
    {
        parent::setUp();

        $this->directory = sys_get_temp_dir().DIRECTORY_SEPARATOR.'picoradar-state-'.bin2hex(random_bytes(6));
        mkdir($this->directory, 0700, true);
    }

    protected function tearDown(): void
    {
        foreach (glob($this->directory.DIRECTORY_SEPARATOR.'*') ?: [] as $file) {
            unlink($file);
        }
        rmdir($this->directory);

        parent::tearDown();
    }

    public function test_it_starts_new_and_persists_non_secret_progress_atomically(): void
    {
        $path = $this->directory.DIRECTORY_SEPARATOR.'installation-state.json';
        $store = new InstallationStateStore($path);

        $this->assertSame(InstallationStage::New, $store->read()->stage);

        $store->write(InstallationStage::Configured, 'release-test');
        $store->write(InstallationStage::Migrated, 'release-test');

        $state = $store->read();
        $this->assertSame(InstallationStage::Migrated, $state->stage);
        $this->assertSame('release-test', $state->releaseId);
        $this->assertFileDoesNotExist($path.'.tmp');
        $this->assertStringNotContainsString('password', file_get_contents($path));
    }

    public function test_completed_installations_cannot_move_backwards(): void
    {
        $store = new InstallationStateStore($this->directory.DIRECTORY_SEPARATOR.'state.json');
        $store->write(InstallationStage::Configured, 'release-test');
        $store->write(InstallationStage::Migrated, 'release-test');
        $store->write(InstallationStage::OperatorCreated, 'release-test');
        $store->write(InstallationStage::Completed, 'release-test');

        $this->expectException(\LogicException::class);
        $store->write(InstallationStage::Configured, 'release-test');
    }

    public function test_a_failed_stage_records_only_a_retry_stage_and_sanitized_code(): void
    {
        $path = $this->directory.DIRECTORY_SEPARATOR.'failed-state.json';
        $store = new InstallationStateStore($path);

        $store->fail(
            retryStage: InstallationStage::Configured,
            releaseId: 'release-test',
            errorCode: 'migration_failed',
        );

        $state = $store->read();
        $this->assertSame(InstallationStage::Failed, $state->stage);
        $this->assertSame(InstallationStage::Configured, $state->retryStage);
        $this->assertSame('migration_failed', $state->errorCode);
        $this->assertStringNotContainsString('password', file_get_contents($path));
    }

    public function test_it_recovers_from_a_valid_backup_when_the_primary_state_is_corrupt(): void
    {
        $path = $this->directory.DIRECTORY_SEPARATOR.'recovery-state.json';
        file_put_contents($path, '{');
        file_put_contents($path.'.bak', json_encode([
            'stage' => 'migrated',
            'releaseId' => 'release-test',
            'updatedAt' => '2026-09-20T00:00:00+00:00',
            'retryStage' => null,
            'errorCode' => null,
        ], JSON_THROW_ON_ERROR));

        $state = (new InstallationStateStore($path, 'release-test'))->read();

        $this->assertSame(InstallationStage::Migrated, $state->stage);
        $this->assertSame('release-test', $state->releaseId);
    }

    public function test_fail_cannot_degrade_a_completed_installation(): void
    {
        $store = new InstallationStateStore($this->directory.DIRECTORY_SEPARATOR.'completed-state.json');
        $store->write(InstallationStage::Configured, 'release-test');
        $store->write(InstallationStage::Migrated, 'release-test');
        $store->write(InstallationStage::OperatorCreated, 'release-test');
        $store->write(InstallationStage::Completed, 'release-test');

        $this->expectException(\LogicException::class);
        $store->fail(InstallationStage::OperatorCreated, 'release-test', 'finalization_failed');
    }

    public function test_state_from_another_release_is_rejected(): void
    {
        $path = $this->directory.DIRECTORY_SEPARATOR.'release-state.json';
        file_put_contents($path, json_encode([
            'stage' => 'configured',
            'releaseId' => 'old-release',
            'updatedAt' => '2026-09-20T00:00:00+00:00',
        ], JSON_THROW_ON_ERROR));

        $this->expectException(\RuntimeException::class);
        (new InstallationStateStore($path, 'current-release'))->read();
    }

    public function test_it_rejects_skipping_an_installation_stage(): void
    {
        $store = new InstallationStateStore($this->directory.DIRECTORY_SEPARATOR.'skip-state.json');

        $this->expectException(\LogicException::class);
        $store->write(InstallationStage::Migrated, 'release-test');
    }
}
