<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dataset_releases', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('dataset_id')->constrained()->restrictOnDelete();
            $table->string('version', 128);
            $table->string('status', 16);
            $table->string('draft_path')->nullable();
            $table->string('asset_path')->nullable();
            $table->string('sha256', 64)->nullable();
            $table->string('content_encoding', 32)->nullable();
            $table->timestamp('generated_at')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('validated_at')->nullable();
            $table->timestamp('published_at')->nullable();
            $table->timestamp('retired_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->unique(['dataset_id', 'version']);
            $table->index(['dataset_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dataset_releases');
    }
};
