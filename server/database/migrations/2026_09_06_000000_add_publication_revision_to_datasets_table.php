<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('datasets', function (Blueprint $table): void {
            $table->unsignedBigInteger('publication_revision')->default(0);
        });
        DB::table('datasets')
            ->whereNotNull('current_version')
            ->update(['publication_revision' => 1]);
    }

    public function down(): void
    {
        Schema::table('datasets', function (Blueprint $table): void {
            $table->dropColumn('publication_revision');
        });
    }
};
