<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('cameras', function (Blueprint $t): void {
            $t->string('operation_status', 80)->nullable()->after('notes');
            $t->string('traffic_authority')->nullable()->after('operation_status');
            $t->string('installation_type', 80)->nullable()->after('traffic_authority');
            $t->string('equipment_name')->nullable()->after('installation_type');
            $t->json('raw_infraction_codes')->nullable()->after('equipment_name');
            $t->string('raw_speed', 80)->nullable()->after('raw_infraction_codes');
            $t->date('operation_started_on')->nullable()->after('raw_speed');
            $t->date('operation_initial_ends_on')->nullable()->after('operation_started_on');
            $t->date('operation_extension_ends_on')->nullable()->after('operation_initial_ends_on');
            $t->string('source_snapshot_sha', 64)->nullable()->after('operation_extension_ends_on');
            $t->timestamp('source_fetched_at')->nullable()->after('source_snapshot_sha');
            $t->index(['operation_status', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('cameras', function (Blueprint $t): void {
            $t->dropIndex(['operation_status', 'status']);
            $t->dropColumn([
                'operation_status',
                'traffic_authority',
                'installation_type',
                'equipment_name',
                'raw_infraction_codes',
                'raw_speed',
                'operation_started_on',
                'operation_initial_ends_on',
                'operation_extension_ends_on',
                'source_snapshot_sha',
                'source_fetched_at',
            ]);
        });
    }
};
