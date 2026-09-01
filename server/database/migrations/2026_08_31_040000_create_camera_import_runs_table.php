<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('camera_import_runs', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('source_id')->constrained('camera_sources')->restrictOnDelete();
            $t->foreignId('default_jurisdiction_id')->nullable()->constrained('jurisdictions')->nullOnDelete();
            $t->string('format', 16);
            $t->string('import_mode', 16);
            $t->string('original_filename', 255);
            $t->string('stored_path', 255)->unique();
            $t->unsignedBigInteger('file_size');
            $t->string('file_sha256', 64);
            $t->string('status', 24)->default('uploaded');
            $t->unsignedSmallInteger('analysis_schema_version')->default(1);
            $t->string('importer_version', 64);
            $t->string('normalization_version', 64);
            $t->unsignedInteger('analysis_generation')->default(0);
            $t->json('source_snapshot');
            $t->json('parser_options');
            $t->json('column_mapping');
            $t->string('profile_key', 100)->nullable();
            $t->string('profile_sha256', 64)->nullable();
            $t->string('analysis_input_fingerprint', 64);
            $t->string('analysis_result_hash', 64)->nullable();
            foreach (['total_rows', 'valid_rows', 'invalid_rows', 'create_ready_rows', 'update_ready_rows', 'noop_rows', 'duplicate_review_rows', 'operational_change_rows', 'dense_scan_rows', 'blocked_rows', 'applied_rows'] as $column) {
                $t->unsignedInteger($column)->default(0);
            }
            $t->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->timestamp('analyzed_at')->nullable();
            $t->timestamp('apply_started_at')->nullable();
            $t->timestamp('apply_finished_at')->nullable();
            $t->json('error_summary')->nullable();
            $t->json('warning_summary')->nullable();
            $t->timestamps();
            $t->index(['source_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('camera_import_runs');
    }
};
