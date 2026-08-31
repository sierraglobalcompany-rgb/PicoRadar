<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Dataset;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DatasetDatabaseTest extends TestCase
{
    use RefreshDatabase;

    public function test_dataset_and_release_constraints_are_enforced(): void
    {
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->releases()->create(['version' => 'one', 'status' => 'draft']);
        $this->expectException(UniqueConstraintViolationException::class);
        $dataset->releases()->create(['version' => 'one', 'status' => 'draft']);
    }

    public function test_dataset_key_and_schema_are_immutable_once_a_release_exists(): void
    {
        $dataset = Dataset::query()->create(['key' => 'restrictions', 'title' => 'Restrictions', 'schema_version' => 1, 'enabled' => true]);
        $dataset->releases()->create(['version' => 'one', 'status' => 'draft']);
        $this->expectException(\LogicException::class);
        $dataset->key = 'changed';
        $dataset->save();
    }

    public function test_audit_logs_are_append_only(): void
    {
        $log = AuditLog::query()->create(['action' => 'dataset.created', 'subject_type' => Dataset::class]);
        $this->expectException(\LogicException::class);
        $log->action = 'dataset.updated';
        $log->save();
    }
}
