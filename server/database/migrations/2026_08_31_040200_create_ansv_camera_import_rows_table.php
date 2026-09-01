<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ansv_camera_import_rows', function (Blueprint $t): void {
            $t->id();
            $t->foreignId('ansv_camera_import_id')->constrained('ansv_camera_imports')->cascadeOnDelete();
            $t->foreignId('camera_id')->nullable()->constrained('cameras')->nullOnDelete();
            $t->string('source_row_identity', 64);
            $t->string('codigo_solicitud')->nullable();
            $t->string('codigo_unico')->nullable();
            $t->string('operation_status', 80);
            $t->string('department');
            $t->string('municipality');
            $t->string('address');
            $t->decimal('lat', 10, 7)->nullable();
            $t->decimal('lon', 10, 7)->nullable();
            $t->string('traffic_authority')->nullable();
            $t->string('jurisdiction_label')->nullable();
            $t->json('raw_infraction_codes')->nullable();
            $t->string('raw_speed', 80)->nullable();
            $t->unsignedSmallInteger('reported_speed_kmh')->nullable();
            $t->string('technology')->nullable();
            $t->string('installation_type', 80)->nullable();
            $t->string('equipment_name')->nullable();
            $t->date('approval_date')->nullable();
            $t->date('operation_started_on')->nullable();
            $t->date('operation_initial_ends_on')->nullable();
            $t->date('operation_extension_ends_on')->nullable();
            $t->boolean('valid_colombia_coordinates')->default(false);
            $t->boolean('active_public_candidate')->default(false);
            $t->string('review_state', 32)->default('OK');
            $t->json('review_reasons')->nullable();
            $t->json('raw')->nullable();
            $t->timestamps();
            $t->unique(['ansv_camera_import_id', 'source_row_identity']);
            $t->index(['operation_status', 'active_public_candidate']);
            $t->index('source_row_identity');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ansv_camera_import_rows');
    }
};
