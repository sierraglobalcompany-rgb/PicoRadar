<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ansv_camera_imports', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('source_id')->constrained('camera_sources')->restrictOnDelete();
            $t->string('snapshot_sha', 64)->unique();
            $t->string('source_url');
            $t->timestamp('source_fetched_at');
            $t->unsignedInteger('row_count')->default(0);
            $t->unsignedInteger('master_imported_count')->default(0);
            $t->unsignedInteger('active_candidate_count')->default(0);
            $t->json('status_counts')->nullable();
            $t->json('report')->nullable();
            $t->timestamps();
            $t->index('source_fetched_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ansv_camera_imports');
    }
};
