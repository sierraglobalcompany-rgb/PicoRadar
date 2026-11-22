<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('service_provider_imports', function (Blueprint $table): void {
            $table->id();
            $table->char('sha256', 64)->unique();
            $table->string('original_name', 255);
            $table->string('format', 8);
            $table->string('private_path', 512);
            $table->string('status', 24)->default('analyzed');
            $table->unsignedInteger('row_count')->default(0);
            $table->json('report')->nullable();
            $table->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('confirmed_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('expires_at');
            $table->timestamps();
        });

        Schema::create('service_provider_import_rows', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('service_provider_import_id')->constrained()->cascadeOnDelete();
            $table->unsignedInteger('row_number');
            $table->string('status', 40);
            $table->boolean('publishable')->default(false);
            $table->foreignId('service_provider_id')->nullable()->constrained('service_providers')->nullOnDelete();
            $table->json('normalized')->nullable();
            $table->json('errors')->nullable();
            $table->json('raw');
            $table->timestamps();
            $table->unique(['service_provider_import_id', 'row_number'], 'sp_import_rows_batch_row_unique');
            $table->index(['service_provider_import_id', 'status', 'publishable'], 'sp_import_rows_review');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_provider_import_rows');
        Schema::dropIfExists('service_provider_imports');
    }
};