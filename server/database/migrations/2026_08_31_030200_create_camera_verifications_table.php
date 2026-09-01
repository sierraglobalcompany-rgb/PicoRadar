<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('camera_verifications', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('camera_id')->constrained('cameras')->restrictOnDelete();
            $t->foreignId('reviewer_id')->nullable()->constrained('users')->nullOnDelete();
            $t->string('decision', 16);
            $t->string('fingerprint', 64);
            $t->foreignId('source_id')->constrained('camera_sources')->restrictOnDelete();
            $t->string('source_url_snapshot', 2048);
            $t->unsignedSmallInteger('speed_limit_snapshot')->nullable();
            $t->boolean('speed_limit_verified')->default(false);
            $t->text('notes')->nullable();
            $t->timestamp('created_at')->useCurrent();
            $t->index('camera_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('camera_verifications');
    }
};
