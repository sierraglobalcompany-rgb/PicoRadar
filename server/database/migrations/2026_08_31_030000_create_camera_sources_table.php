<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('camera_sources', function (Blueprint $t): void {
            $t->id();
            $t->string('key', 64)->unique();
            $t->string('title');
            $t->string('authority');
            $t->string('url', 2048);
            $t->string('source_type', 16);
            $t->boolean('is_active')->default(true);
            $t->timestamp('verified_at')->nullable();
            $t->text('notes')->nullable();
            $t->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('camera_sources');
    }
};
