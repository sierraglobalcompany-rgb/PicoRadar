<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('restriction_rule_versions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('jurisdiction_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('version');
            $table->string('status', 16)->default('draft');
            $table->json('payload');
            $table->string('payload_sha256', 64);
            $table->unsignedBigInteger('base_publication_revision')->default(0);
            $table->json('vehicle_kinds')->nullable();
            $table->date('valid_from')->nullable();
            $table->date('valid_until')->nullable();
            $table->timestamp('stale_after')->nullable();
            $table->timestamp('source_checked_at')->nullable();
            $table->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('validated_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('validated_at')->nullable();
            $table->foreignId('archived_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();
            $table->unique(['jurisdiction_id', 'version'], 'restriction_rule_versions_jurisdiction_version_unique');
            $table->index(['jurisdiction_id', 'status'], 'restriction_rule_versions_jurisdiction_status_index');
            $table->index(['status', 'valid_until'], 'restriction_rule_versions_status_valid_until_index');
        });

        Schema::create('restriction_imports', function (Blueprint $table): void {
            $table->id();
            $table->string('sha256', 64)->unique();
            $table->string('original_name');
            $table->string('format', 8);
            $table->string('private_path');
            $table->string('sheet')->nullable();
            $table->string('status', 16)->default('analyzed');
            $table->unsignedInteger('row_count')->default(0);
            $table->unsignedInteger('valid_count')->default(0);
            $table->unsignedInteger('invalid_count')->default(0);
            $table->unsignedInteger('excluded_count')->default(0);
            $table->json('report')->nullable();
            $table->foreignId('created_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('confirmed_by_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('analyzed_at')->nullable();
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamps();
            $table->index(['status', 'created_at']);
        });

        Schema::create('restriction_import_rows', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('restriction_import_id')->constrained('restriction_imports')->cascadeOnDelete();
            $table->unsignedInteger('row_number');
            $table->foreignId('jurisdiction_id')->nullable()->constrained()->restrictOnDelete();
            $table->string('state', 16);
            $table->boolean('publishable')->default(false);
            $table->json('normalized')->nullable();
            $table->json('errors')->nullable();
            $table->json('raw')->nullable();
            $table->timestamps();
            $table->unique(['restriction_import_id', 'row_number'], 'restriction_import_rows_import_row_unique');
            $table->index(['restriction_import_id', 'state'], 'restriction_import_rows_import_state_index');
        });

        Schema::create('restriction_publications', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('dataset_release_id')->unique()->constrained('dataset_releases')->restrictOnDelete();
            $table->string('action', 16);
            $table->unsignedBigInteger('base_publication_revision');
            $table->unsignedBigInteger('result_publication_revision');
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->json('summary')->nullable();
            $table->timestamps();
            $table->index(['action', 'created_at']);
        });

        Schema::create('restriction_publication_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('restriction_publication_id');
            $table->foreignId('jurisdiction_id');
            $table->foreignId('restriction_rule_version_id');
            $table->foreignId('previous_rule_version_id')->nullable();
            $table->string('action', 16);
            $table->timestamps();
            $table->foreign('restriction_publication_id', 'rpi_publication_fk')->references('id')->on('restriction_publications')->cascadeOnDelete();
            $table->foreign('jurisdiction_id', 'rpi_jurisdiction_fk')->references('id')->on('jurisdictions')->restrictOnDelete();
            $table->foreign('restriction_rule_version_id', 'rpi_rule_version_fk')->references('id')->on('restriction_rule_versions')->restrictOnDelete();
            $table->foreign('previous_rule_version_id', 'rpi_previous_rule_fk')->references('id')->on('restriction_rule_versions')->restrictOnDelete();
            $table->unique(['restriction_publication_id', 'jurisdiction_id'], 'restriction_publication_items_publication_jurisdiction_unique');
            $table->index(['jurisdiction_id', 'created_at'], 'restriction_publication_items_jurisdiction_created_index');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('restriction_publication_items');
        Schema::dropIfExists('restriction_publications');
        Schema::dropIfExists('restriction_import_rows');
        Schema::dropIfExists('restriction_imports');
        Schema::dropIfExists('restriction_rule_versions');
    }
};
