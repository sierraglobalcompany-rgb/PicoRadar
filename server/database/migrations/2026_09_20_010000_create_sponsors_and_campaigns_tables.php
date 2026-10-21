<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sponsors', function (Blueprint $table): void {
            $table->id();
            $table->string('public_id', 64)->unique();
            $table->string('name', 255);
            $table->string('contact_name', 255)->nullable();
            $table->string('contact_email', 320)->nullable();
            $table->string('contact_phone', 64)->nullable();
            $table->text('notes')->nullable();
            $table->string('status', 16)->index();
            $table->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('archived_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
        });

        Schema::create('campaigns', function (Blueprint $table): void {
            $table->id();
            $table->string('public_id', 64)->unique();
            $table->foreignId('sponsor_id')->constrained('sponsors')->restrictOnDelete();
            $table->string('status', 16)->index();
            $table->string('placement', 32)->index();
            $table->string('eyebrow', 80);
            $table->string('title', 120);
            $table->string('subtitle', 240);
            $table->string('cta_text', 64);
            $table->string('cta_url', 2048);
            $table->unsignedInteger('priority')->default(100)->index();
            $table->string('scope', 16)->index();
            $table->foreignId('geographic_unit_id')->nullable()->constrained('geographic_units')->restrictOnDelete();
            $table->timestamp('starts_at')->index();
            $table->timestamp('ends_at')->index();
            $table->string('source_image_path', 1024);
            $table->string('public_image_path', 1024)->nullable();
            $table->string('image_sha256', 64);
            $table->string('image_mime', 32);
            $table->unsignedInteger('image_width');
            $table->unsignedInteger('image_height');
            $table->unsignedBigInteger('image_bytes');
            $table->unsignedInteger('content_revision')->default(1);
            $table->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('activated_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('paused_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('archived_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('activated_at')->nullable();
            $table->timestamp('paused_at')->nullable();
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'placement', 'starts_at', 'ends_at'], 'campaigns_catalog_eligibility_index');
            $table->index(['scope', 'geographic_unit_id'], 'campaigns_territory_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('campaigns');
        Schema::dropIfExists('sponsors');
    }
};
