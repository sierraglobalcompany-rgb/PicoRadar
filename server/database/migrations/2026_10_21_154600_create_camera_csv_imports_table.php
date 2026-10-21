<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('camera_csv_imports', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('source_id')->constrained('camera_sources')->restrictOnDelete();
            $table->foreignId('jurisdiction_id')->constrained()->restrictOnDelete();
            $table->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('applied_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('mode', 8);
            $table->string('status', 16)->default('review');
            $table->string('original_path', 255);
            $table->char('original_sha256', 64);
            $table->string('analysis_path', 255);
            $table->char('analysis_sha256', 64);
            $table->json('counts');
            $table->unsignedInteger('row_count');
            $table->timestamp('applied_at')->nullable();
            $table->timestamps();
            $table->index(['source_id', 'jurisdiction_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('camera_csv_imports');
    }
};
