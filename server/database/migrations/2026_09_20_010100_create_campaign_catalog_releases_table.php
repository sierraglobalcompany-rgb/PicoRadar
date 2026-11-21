<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('campaign_catalog_releases', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('version')->unique();
            $table->string('asset_path', 1024)->unique();
            $table->string('sha256', 64)->unique();
            $table->unsignedInteger('campaign_count');
            $table->timestamp('generated_at');
            $table->timestamp('expires_at');
            $table->foreignId('published_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('created_at')->useCurrent();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('campaign_catalog_releases');
    }
};
