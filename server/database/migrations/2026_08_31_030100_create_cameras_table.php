<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cameras', function (Blueprint $t): void {
            $t->id();
            $t->string('camera_id', 40)->unique();
            $t->foreignId('jurisdiction_id')->constrained()->restrictOnDelete();
            $t->foreignId('geographic_unit_id')->constrained('geographic_units')->restrictOnDelete();
            $t->foreignId('source_id')->constrained('camera_sources')->restrictOnDelete();
            $t->string('external_id')->nullable();
            $t->string('name')->nullable();
            $t->decimal('lat', 10, 7);
            $t->decimal('lon', 10, 7);
            $t->string('type', 16);
            $t->string('direction', 255)->nullable();
            $t->unsignedSmallInteger('bearing')->nullable();
            $t->string('corridor', 255)->nullable();
            $t->unsignedSmallInteger('speed_limit')->nullable();
            $t->boolean('speed_limit_verified')->default(false);
            $t->timestamp('speed_limit_verified_at')->nullable();
            $t->foreignId('speed_limit_verified_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->string('status', 16)->default('draft');
            $t->timestamp('submitted_at')->nullable();
            $t->timestamp('verified_at')->nullable();
            $t->foreignId('verified_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->string('verification_fingerprint', 64)->nullable();
            $t->timestamp('retired_at')->nullable();
            $t->foreignId('retired_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->foreignId('updated_by_id')->nullable()->constrained('users')->nullOnDelete();
            $t->text('notes')->nullable();
            $t->timestamps();
            $t->unique(['source_id', 'external_id']);
            $t->index(['jurisdiction_id', 'status']);
            $t->index(['geographic_unit_id', 'status']);
            $t->index(['source_id', 'status']);
            $t->index(['type', 'status']);
            $t->index(['speed_limit_verified', 'status']);
            $t->index('status');
            $t->index(['jurisdiction_id', 'lat', 'lon']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cameras');
    }
};
