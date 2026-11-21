<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('jurisdictions', function (Blueprint $table): void {
            $table->id();
            $table->string('key', 64)->unique();
            $table->string('name', 255);
            $table->string('kind', 16);
            $table->foreignId('primary_geographic_unit_id')->constrained('geographic_units')->restrictOnDelete();
            $table->boolean('enabled')->default(false);
            $table->string('timezone', 64)->default('America/Bogota');
            $table->json('metadata')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('jurisdictions');
    }
};
