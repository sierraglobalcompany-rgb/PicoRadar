<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('geographic_units', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('parent_id')->nullable()->constrained('geographic_units')->restrictOnDelete();
            $table->string('key', 64)->unique();
            $table->string('level', 16);
            $table->string('code', 5)->unique();
            $table->string('name', 255);
            $table->string('normalized_name', 255)->index();
            $table->boolean('is_active')->default(true);
            $table->string('source_system', 64);
            $table->string('source_version', 32);
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->unique(['parent_id', 'normalized_name'], 'geographic_units_parent_normalized_name_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('geographic_units');
    }
};
