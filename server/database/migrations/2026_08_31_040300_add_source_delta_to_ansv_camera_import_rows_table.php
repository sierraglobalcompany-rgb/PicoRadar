<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ansv_camera_import_rows', function (Blueprint $table): void {
            $table->json('source_delta')->nullable()->after('review_reasons');
        });
    }

    public function down(): void
    {
        Schema::table('ansv_camera_import_rows', function (Blueprint $table): void {
            $table->dropColumn('source_delta');
        });
    }
};
