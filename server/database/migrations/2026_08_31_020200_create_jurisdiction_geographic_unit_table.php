<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('jurisdiction_geographic_unit', function (Blueprint $table): void {
            $table->foreignId('jurisdiction_id')->constrained('jurisdictions')->cascadeOnDelete();
            $table->foreignId('geographic_unit_id')->constrained('geographic_units')->restrictOnDelete();
            $table->timestamps();
            $table->unique(['jurisdiction_id', 'geographic_unit_id'], 'jurisdiction_geo_unit_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('jurisdiction_geographic_unit');
    }
};
