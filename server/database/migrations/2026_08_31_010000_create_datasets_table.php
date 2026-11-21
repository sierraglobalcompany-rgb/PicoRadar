<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('datasets', function (Blueprint $table): void {
            $table->id();
            $table->string('key', 64)->unique();
            $table->string('title');
            $table->unsignedInteger('schema_version');
            $table->boolean('enabled')->default(true);
            $table->string('current_version', 128)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('datasets');
    }
};
