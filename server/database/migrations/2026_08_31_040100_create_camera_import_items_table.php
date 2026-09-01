<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('camera_import_items', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('run_id')->constrained('camera_import_runs')->restrictOnDelete();
            $t->unsignedInteger('analysis_generation');
            $t->unsignedInteger('row_number');
            $t->string('raw_hash', 64);
            $t->string('normalized_hash', 64);
            $t->string('external_id')->nullable();
            $t->json('normalized_payload');
            $t->string('classification', 32);
            $t->string('status', 16)->default('pending');
            $t->foreignId('matched_camera_id')->nullable()->constrained('cameras')->nullOnDelete();
            $t->boolean('duplicate_scan_capped')->default(false);
            $t->json('duplicate_candidates')->nullable();
            $t->json('errors')->nullable();
            $t->json('warnings')->nullable();
            $t->json('resolution')->nullable();
            $t->foreignId('resolved_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->timestamp('resolved_at')->nullable();
            $t->foreignId('applied_camera_id')->nullable()->constrained('cameras')->nullOnDelete();
            $t->timestamp('applied_at')->nullable();
            $t->timestamps();
            $t->unique(['run_id', 'analysis_generation', 'row_number']);
            $t->index(['run_id', 'analysis_generation', 'classification']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('camera_import_items');
    }
};
